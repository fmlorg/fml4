#-*- perl -*-
# Copyright (C) 1993-1999,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#
# SMTP recipient arrray Window Control


use vars qw($debug $debug_smtp);
use vars qw(%MCIWindowCB $MCIType);


sub LineCount
{
    my ($f) = @_;
    my ($lines) = 0;

    open(TMP, $f) || return 0;
    while (<TMP>) { 
	next if /^\#/o;	 # skip comment and off member
	next if /^\s*$/o; # skip null line
	next if /\s[ms]=/o;
	$lines++;
    }
    close(TMP);

    $lines;
}


sub GetMCIWindow
{
    my ($file) = @_;
    my ($n, $size, $start, $end);

    # The first time, the line number is not set up.
    if ($MCIWindowCB{$file}) {
	($size, $start, $end) = split(/:/, $MCIWindowCB{$file});
    }
    else {
	$n = &LineCount($file);
    }

    # initialize when $MCI_TYPE eq 'window'
    if ($MCIType eq 'window') {
	# first time 
	if ($size == 0) {
	    # 100 for 399/4;
	    $size  = &MCIWindowUnit($n, $MCI_SMTP_HOSTS || 1);
	    $start = 0;
	    $end   = $size;

	}
	else {
	    $start += $size;
	    $end   += $size;
	}
    }
    else {
	&Log("unknown \$MCIType = $MCIType");
    }

    $MCIWindowCB{$file} = "${size}:${start}:${end}";
    ($size, $start, $end);
}


sub MCIWindowUnit
{
    my ($n, $u) = @_;
    my ($x);

    if ($u <= 0) { &Log("N_MCIUnit: $u < 0"); return 0;}

    # trivial
    if ($u == 1) { return $n;}

    # e.g. &N_MCIUnit(399,  4) return 100;
    $x = ($u > 0) ? int(($n+$u)/ $u) : $n;
}


1;
