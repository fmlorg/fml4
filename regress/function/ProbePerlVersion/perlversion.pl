#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");

&ProbePerlVersion;

printf "%10s   %s\n",  "Version", $];
printf "%10s   %s\n",  "jperl?", ($UNDER_JPERL ? "yes" : "no");
if ($UNDER_JPERL) {
    printf "%10s   %s\n",  "jperl mode", $JPERL_MODE;
}
	
exit 0;


sub ProbePerlVersion
{
    print STDERR "ProbePerlVersion: $^X -v \n" if $debug;
    open(PERL, "$^X -v |");
    while (<PERL>) {
	$UNDER_JPERL = 1 if /jperl/;
    }
    close(PERL);

    # if jperl 4, always bad.
    if ($UNDER_JPERL && ($] =~ /Revision.*4\.0/)) { $jperl4 = 1;}

    # if jperl 5, check jperl or perl ?
    # try to check regexp working
    if ("\xa4\xa2" =~ m/^.$/) {
	$JPERL_MODE = "euc";
    }
    elsif ("\x80\xa0" =~ m/^.$/) {
	$JPERL_MODE = "sjis";
    }
    else { # must be usual perl
	$JPERL_MODE = "unknown"; # jperl4 matches here?
	$UNDER_JPERL = 0;
    }

    # if jperl 4, always jperl is jperl.
    $UNDER_JPERL = 1 if $jperl4;
}
