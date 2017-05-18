use System::Query;
use Zef;
use NativeCall;

use Data::Dump;

class Zef::Utils::BuildCheck {
    method !test-lib($lib) {
        my $x = False;
        try {
            my $test = sub :: { * };
            trait_mod:<is>($test, :native("$lib"));
            $test();
            $x = True;
            CATCH { 
                default { 
                    $x = True 
                        unless $_.Str ~~ /^'Cannot locate native library'/ ; 
                } 
            };
        };
        $x;
    }

    method !test-bin($bin) {
        my $x = False;
        try {
            if $*DISTRO.is-win {
                my @results = qqx`for \%i in ($bin) do \@echo.   \%~\$PATH:i`.trim.split("\n");
                $x = @results.elems > 0;
            } else {
                # try `type`, `which`
                for qw<type which> -> $cmd {
                    my $proc = run "$cmd", "$bin", :out;
                    next unless $proc.exitcode == 0;
                    my $out = $proc.out.slurp-rest;
                    next unless $out ne '' && $out.trim.split("\n").elems > 0;
                    $x = True;
                    last;
                }
            }
            CATCH {
                default {
                }
            };
        };
        $x;
    }

    method check($distribution) {
        return True 
            unless $distribution.meta.defined && 
                   ( $distribution.meta<depends>:exists );
        my $processed = system-collapse($distribution.meta<depends>)
                          .grep({ $_<from>:exists && $_<from> eq qw<native bin>.any });
        #check lib
        my %results;
        my ($*CKEY, $*CTYPE);
        for @($processed) -> $collection {
            for $collection.grep({ $_.key ne 'from' }).map({ %results{$*CKEY = $_.key} = {}; |@(.value) }) -> $library {
                %results{$*CKEY}.push: $library => self!"test-{$collection<from> eq 'native' ?? 'lib' !! $collection<from> eq 'bin' ?? 'bin' !! die 'cannot find handler for "from" => "' ~ $*CTYPE ~ '"'; }"($library);
            }
        }
        say Dump %results; 
        return %results;
    }
}
