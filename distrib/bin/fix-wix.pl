#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("dRX:");

$FML = $opt_X || $ENV{'FML'};
chop($ID = `perl "$FML/distrib/bin/fml_version.pl -X $FML" -s`);
chop($date = `date`);

while(<>) {
    if (/^\s+Last modified:/) {
	if ($opt_R) {
	    &P("\n   $ID\n");
	}
	else {
	    &P("\n   [ Last modified: $date ]\n");
	}
	next;
    }

    print;
}

1;


sub P
{
    print STDERR "fix-wix> " unless $First++;
    print STDOUT @_;
    print STDERR @_;
}
