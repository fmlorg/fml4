#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
# $NetBSD$
# $FML$
#

# getopt()
require 'getopts.pl';
&Getopts("dhr");

$re_euc_c  = '[\241-\376][\241-\376]';

while (<>) {
    if ($opt_r) {
	if (/$re_euc_c/) { print;}
    }
    else {
	next if /$re_euc_c/;
	print;
    }
}

exit 0;
