#!/usr/local/bin/perl --    # -*-Perl-*-
# 
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

$CACHE_PROG = 'GenApplyDB';

sub GenApplyDB
{
    local(*hdr, *body) = @_;
    local($s);

    $DISCARD_HDR_PAT  = 'Subject:.*IIJ Project';
    $DISCARD_BODY_PAT = 'c.\s+\[Project\]\s+IIJ Internet';

    # 822 unfolding
    $hdr  =~ s/\n\s+/\n/g;
    $body =~ s/\n\s+/\n/g;

    for (split(/\n/, $hdr)) {
	return 0 if /^($DISCARD_HDR_PAT)/i;
    }

    for (split(/\n/, $body)) {
	return 0 if /^($DISCARD_BODY_PAT)/i;

	# IP Addr or DOMAIN NAME ENTRIES except IIJ
	if ((/\d+\.\d+\.\d+/) && /(\S+\.jp)/i && 
	    (! /\S+nic.ad.jp/i) && 
	    (! /\S+iij-mc.co.jp/i) && 
	    (! /\S+iij.ad.jp/i)) {
	    s/ドメイン//g;
	    $s .= "$1 ";
	}

	# NETWORK ADDRESS
	/^a\.\s+\[IP.*\]\s+(\S+)/  && ($s .= "$1 ");

	# ORGANIZATION 		
	/\[Organization\]\s+(.*)/  && ($s .= "$1 ");

	# JPNIC HANDLE
	/^[mn]\.\s+\[.*\]\s+(\w\w\d\d\d\w\w)/ && ($s .= "$1 ");
    }

    $s;
}

1;
