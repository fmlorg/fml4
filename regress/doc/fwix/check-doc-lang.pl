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

$| = 1;
$re_euc_c  = '[\241-\376][\241-\376]';

for $f (@ARGV) {

    open($f, "nkf -e $f|") || die($!);
    $. = 0;
    while (<$f>) {

	if (/$re_euc_c/) {
	    print "$f:$.\n";
	    print $_;
	    print "\n";
	}
    }  

    close($f);
    
}

exit 0;
