#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
require 'getopts.pl';
&Getopts("dh");

# 
require 'module/Japanese/libhankaku2zenkaku.pl';

while (<>) {
    next if (1 .. /^$/);
    $e{'Body'} .= $_;
}

# split() to each line
$pp = 0;
while (1) {
    if (($p = index($e{'Body'}, "\n", $pp)) > 0) {
	$line++;
	$buf  = substr($e{'Body'}, $pp, $p - $pp);
	$xbuf = $buf;
	printf "%3d:{ %s }\n", $line, $buf;
	$buf = &ConvertHankakuToZenkaku($buf);
	if ($buf ne $xbuf) {
	    printf "%4s[ %s ]\n", $NULL, $buf;
	    printf "%4s  %d \n", $NULL, ord($buf);
	    printf "%4s  %d \n", $NULL, ord($xbuf);
	}
	
	$pp = $p + 1;
    }
    else {
	last;
    }
}

exit (0);
