#!/usr/bin/env perl
#
# $FML$
#

push(@INC, "../../../");
push(@INC, "../../../kern");
push(@INC, "../../../proc");
require 'kern/libloadconfig.pl';
require 'proc/libkern.pl';
require 'kern/libenvf.pl';

$a = q{
親狸様

お世話様でございます。
たんたんたぬきのきんどけい
かーぜもないのにぶーらぶら
-------------------------------
 たぬき株式会社
 人事部人事課      たぬきたぬぞう
  tanuki@tanuki.jp
 Tel.03-1234-5678/Fax.03-1234-5678
};

$b = q{unsubscribe};


for ($a, $b) {
    my $x = $_;

    $DO_NOTHING = 0;
    $debug = $debug_envf = 1;


    require 'jcode.pl';
    &jcode::convert(\$x, 'jis');

    $e{'h:message-id:'} = 'fukachan@fml.org';
    $e{'Body'}          = $x;
    $r = __EnvelopeFilter(*e);

    unless ($DO_NOTHING) {
	print STDERR "\no.k.\n";
    }
    else {
	print STDERR "\ntrapped.\n";
    }
}

exit 0;


sub Log { print STDERR ">>> ", @_;}

sub Sendmail { print STDERR "Sendmail()\n";}
