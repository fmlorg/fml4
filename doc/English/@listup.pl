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
&Getopts("dh");

while (<>) {
    if (/^\.C/) {
	print "\n";
	print $_;
    }

    if (/^\.S/) {
	print $_;
    }

}

exit 0;
