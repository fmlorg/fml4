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
printf "%10s   %s\n",  "jperl?", ($UnderJPerl ? "yes" : "no");
if ($UnderJPerl) {
    printf "%10s   %s\n",  "jperl mode", $JPerlMode;
}
	
exit 0;


sub ProbePerlVersion
{
    local($jperl4);

    print STDERR "ProbePerlVersion: $^X -v \n" if $debug;
    open(PERL, "$^X -v |");
    while (<PERL>) {
	$UnderJPerl = 1 if /jperl/;
    }
    close(PERL);

    # if jperl 4, always bad.
    if ($UnderJPerl && ($] =~ /Revision.*4\.0/)) { $jperl4 = 1;}

    # if jperl 5, check jperl or perl ?
    # try to check regexp working
    if ("\xa4\xa2" =~ m/^.$/) {
	$JPerlMode = "euc";
    }
    elsif ("\x80\xa0" =~ m/^.$/) {
	$JPerlMode = "sjis";
    }
    else { # must be usual perl
	$JPerlMode = "unknown"; # jperl4 matches here?
	$UnderJPerl = 0;
    }

    # if jperl 4, always jperl is jperl.
    $UnderJPerl = 1 if $jperl4;
}
