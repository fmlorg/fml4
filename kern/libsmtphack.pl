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

sub SmtpHackInit
{
    local($howold, $renew);

    if (! $DISTRIBUTE_DUMMY_RECIPIENT) {
	&Log("\$DISTRIBUTE_DUMMY_RECIPIENT is not defined.");
    }
    
    $DISTRIBUTE_DUMMY_RCPTLIST = $DISTRIBUTE_DUMMY_RCPTLIST || "$VARDB_DIR/rcptlist";

    -f $DISTRIBUTE_DUMMY_RCPTLIST || &Touch($DISTRIBUTE_DUMMY_RCPTLIST);

    $howold = -M $DISTRIBUTE_DUMMY_RCPTLIST;

    for (@ACTIVE_LIST) { if ($howold > (-M $_)) { $renew = 1;}}

    &SmtpHackRebuildList if $renew;
}


sub SmtpHackRebuildList
{
    local($new) = "$DISTRIBUTE_DUMMY_RCPTLIST.new";

    open(OUT, "> $new") || do { 
	&Log("SmtpHackRebuildList: cannot open $new");
	return $NULL;
    };
    select(OUT); $| = 1; select(STDOUT);

    for (@ACTIVE_LIST) {
	next unless -f $_;

	if (open(IN, $_)) {
	    while (<IN>) {
		next if /^\#/o;
		next if /^\s*$/;
		next if /m=/;	# fml specific condition
		next if /s=/;	# fml specific condition

		print OUT $_;
	    }
	    close(IN);
	}
	else {
	    &Log("SmtpHackRebuildList: cannot open $_");
	}
    }

    close(NEW);

    if (-z $new) { 
	&Log("\$DISTRIBUTE_DUMMY_RCPTLIST.new is size 0, not replaced");
    }
    else {
	rename($new, $DISTRIBUTE_DUMMY_RCPTLIST) ||
	    &Log("fail to rename $DISTRIBUTE_DUMMY_RCPTLIST");

	&Log("rebuild $DISTRIBUTE_DUMMY_RCPTLIST") if $debug_smtp_hack;
    }
}


1;
