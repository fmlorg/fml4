# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


while(<>) {
	/^>>> fml/ && ( print ('-' x 30)."\n") && next;

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
