# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

package sd;

sub Log 
{
    &main'Log(@_); #';
}

sub main'SDInit #';
{
    local(*list) = @_;
    local($tmp_dir, $dir);

    $tmp_dir  = $main'FP_TMP_DIR; #';
    $dir      = $main'DIR; #';
    $TmpFile  = "$tmp_dir/sd$$";
    $SDCache = "$dir/sd.cache";

    if (open(OUTLIST, "| sort > $TmpFile")) {
	select(OUTLIST); $| = 1; select(STDOUT);
    }
    else {
	&Log("SDInit: $!");
	return 0;
    }

    # file list
    for (@list) {
	open(LIST, $_) || do { &Log("SDInit: cannot open $_"); next;};
	while (<LIST>) {
	    chop;
	    next if /^\#/;
	    next if /s=|m=/;

	    ($addr, $domain) = split(/\@/, $_);
	    $domain =~ tr/A-Z/a-z/;
	    @rev = split(//, $domain);
	    @rev = reverse @rev;
	    $rev = join("", @rev);

	    print OUTLIST "$rev\t$_\n";
	}
	close(LIST);
    } 
    close(OUTLIST);

    ### cache out
    if (open(OUTLIST, "> $SDCache")) {
	select(OUTLIST); $| = 1; select(STDOUT);
    }
    else {
	&Log("SDInit: $!");
	return 0;
    }

    open(LIST, $TmpFile) || do { &Log("SDInit: cannot open $TmpFile"); next;};
    while (<LIST>) {
	chop;
	($domain, $_) = split(/\s+/, $_);

	print OUTLIST "$_\n";
    }

    close(OUTLIST);
    close(LIST);

    unlink $TmpFile;

    # save list
    @OrgList = @list;
    @list = ($SDCache);
}


sub main'SDFin #';
{
    local(*list) = @_;

    unlink $SDCache;
    @list = @OrgList;
}


1;
