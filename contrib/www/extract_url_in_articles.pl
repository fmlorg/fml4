#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
# $Id$

require 'getopts.pl';
&Getopts("hHdr");

$debug = $opt_d;
$raw   = $opt_r ? 1 : 0;

if ($raw) {
    $\ = "\n";
}
else {
    $/ = "\n\n";
    $\ = "\n";
}

while (<>) {
    if ($raw) {
	if (m#(http://\S+)#) {
	    print $1;
	}
	
	next;
    }

    next if /Return-Path:/ && /X-MLServer:/i; # header

    # cut the 'not \243'[\241-\376]
    s/[\241-\242\244-\376][\241-\376]//g;

    if (/\w\@\w|Email/i) { # must be a signature (may be)
	print STDERR "SKIP: MATCH [$&] for <$_>\n" if $debug;
	next;
    }

    $buf = $_;

    if (m#http://([\w\-\_\#/\.\~\%\&\=\+]+)#) {
	$_ = $1;
	print STDERR "CANDIDATE\t$_\n";

	s/index\.htm$//i;
	s/index\.html$//i;

	local($host, @x) = split(/\//, $_);
	next if $host !~ /\./; # not normal domain;

	$e{$_} = $_;

	if (! m#/#) { 
	    $_ = "$_/"; 
	    $e{$_}     = $_;
	    $buf{$_}  .= $buf;
	}
    }
}

foreach (keys %e) {
    next if $e{$_} && $e{"$_/"};
    print "http://".$e{$_};
}

exit 0;
