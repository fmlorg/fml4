#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.

while(<>) {
    if (/^\>\>> fml/) {
	print '-' x 30;
	print "\n";
	next;
    }

    # mh
    next if /mhl.format|\(Message\s+inbox:\d+\)/;

    print "\n" if /Return-Path/i;

    # headers to skip
    next if /^(Lines|Posted|Precedence|Reply-To|Return-Path|Subject):/i;
    next if /^(errors-to|message-id|mime-version|content-type):/i;
    next if /X-.*:/i && !/Count/i;

    print " $_";
}

1;
