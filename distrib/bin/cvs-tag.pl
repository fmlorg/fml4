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

# e.g. "fml-2-2A-end";
$symbol = $ARGV[0] || 
    die("define tag\nUsage: cvs-tag.pl fml-2-2A-end < listfile");

while (<>) {
	next unless /^\w/;
	($file, $version) = split();

	$version =~ s/^(\d+\.\d+)\..*/$1/;

	print "rcs -n${symbol}:$version\t${file},v\n";
}

exit 0;
