# Copyright (C) 1993-1998,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

use vars qw($debug $debug_smtp);
use vars qw(@RcptLists
	    $OUTGOING_RCPTLIST);

sub SmtpHackInit
{
    my ($howold, $renew);

    if (! $OUTGOING_ADDRESS) {
	&Log("\$OUTGOING_ADDRESS is not defined.");
    }
    
    $OUTGOING_RCPTLIST = $OUTGOING_RCPTLIST || "$VARDB_DIR/rcptlist";

    -f $OUTGOING_RCPTLIST || do {
	$renew++;
	&Touch($OUTGOING_RCPTLIST);
    };

    $howold = -M $OUTGOING_RCPTLIST;

    for (@RcptLists) { if ($howold > (-M $_)) { $renew = 1;}}

    &SmtpHackRebuildList if $renew;

    if (-z $OUTGOING_RCPTLIST) {
	my ($f) = $OUTGOING_RCPTLIST;
	$f =~ s#^$DIR/##;
	&Log("ERROR: $f is size 0");
	&Log("disable \$USE_OUTGOING_ADDRESS and back to normal delivery");
	undef $USE_OUTGOING_ADDRESS;
	0;
    }
    else {
	1;
    }
}


sub SmtpHackRebuildList
{
    my ($new) = "$OUTGOING_RCPTLIST.new";

    open(OUT, "> $new") || do { 
	&Log("SmtpHackRebuildList: cannot open $new");
	return $NULL;
    };
    select(OUT); $| = 1; select(STDOUT);

    for (@RcptLists) {
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

    close(OUT);

    if (-z $new) { 
	&Log("\$OUTGOING_RCPTLIST.new is size 0, not replaced");
    }
    else {
	rename($new, $OUTGOING_RCPTLIST) ||
	    &Log("fail to rename $OUTGOING_RCPTLIST");

	&Log("rebuild $OUTGOING_RCPTLIST") if $debug_smtp;
    }
}


1;
