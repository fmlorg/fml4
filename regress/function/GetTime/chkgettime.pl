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

print "--- $ARGV[0]\n";

while (<>) {
    if (/^\}/)          { $found = 0;}
    if (/^sub GetTime/) { $found = 1;}

    if ($found) {
	next if /^\s*\#/;
	next if /localtime/;

	# O.K.
	next if /\$year \% 100/;
	next if /1900 \+ \$year/;
	next if /\$Now.*\"\%02d/;

	if (/year/ || /Now/) { 
	    print "$.\t", $_;
	}
    }
}

exit 0;
