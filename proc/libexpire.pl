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
#
# $Id$;

##### LIBRARY #####
sub Expire_with_date { &Expire(@_);}
sub Expire
{
    local($spool_dir, $expire, $ctl_by_number) = @_;
    local($d, $f, @f, $OneDay, $unlink_seq, $last_seq, $first_seq);

    ### CONFIGURATION
    $spool_dir = $spool_dir || $SPOOL_DIR || "spool"; # expire spool articles;
    $expire    = $expire    || 7;                     # days (7 == one week)
    $OneDay    = 24*3600;	                      # seconds for one day

    ### opendir
    opendir(F, $spool_dir)  || (return $NULL);
    foreach $f (readdir(F)) {
	next if $f =~ /^\./;
	$unlink_seq = $f; 

	if ($ctl_by_number)  {
	    push(@f, $f); # without 'spool' for numeric qsort
	}
	# DO UNLINK WHEN DATE EXPIRATION
	else {
	    # expire with date(default)
	    $f  = "$spool_dir/$f";
	    $d  = time - (stat($f))[10];
	    $d /= $OneDay;
	    
	    &Debug("?:expire $f if $d > $expire") if $debug; 
	    &Debug("?:expire $f(NOT -f)")         if $debug && (! -f $f);  

	    if ((!$debug) && (-f $f) && ($d > $expire)) {
		# Init(NOT SET last_seq);
		# fixed by OGAWA Kunihiko <kuni@edit.ne.jp> ;fml-support:6260 
                $first_seq || ($last_seq = $first_seq = $unlink_seq);

		# unlink($f)? &Debug("unlink $f"): &Debug("CANNOT unlink $f");
		unlink($f) || &Log("fail to unlink $f");

		# store the largest sequence
		$last_seq  = $last_seq > $unlink_seq ? $last_seq : $unlink_seq;
		$first_seq = $first_seq<$unlink_seq  ? $first_seq: $unlink_seq;
	    }
	}
    }
    closedir(F);

    # DO UNLINK HERE WHEN LEFT ARTICLE COUNT EXPIRATION
    # not believing the counter by $DIR/seq 
    if ($ctl_by_number)  {
	# sort ->  1, 2, 3, ... incresing order.
	$d = scalar(@f) - $expire;
	&Debug("Unlink the first [$d] files left in spool") if $debug;

	foreach (sort {$a <=> $b;} @f) {
	    $unlink_seq = $_; 
	    $_ = "$spool_dir/$_"; # here for numeric qsoring

	    if ($d <= 0) { 
		&Debug("END\t\t\t[$d<=0]\n") if $debug;
		last;
		&Debug("Try\t$_\t[more $d files]") if $debug;
	    }

	    if (-f $_ && unlink($_)) {
		$d--;
		&Debug("unlink\t$_\t[more $d files]") if $debug;

		# store the largest sequence
		$last_seq = $last_seq > $unlink_seq ? $last_seq : $unlink_seq;
		$first_seq = $first_seq < $unlink_seq ? $first_seq : $unlink_seq;
	    }
	}#foreach;
    }

    &Log("unlink $first_seq -> $last_seq") if $first_seq && $last_seq;

    if ($EXPIRE_SUMMARY) {
	&ExpireSummary($first_seq, $last_seq);
    }

    1;
}


sub CtlExpire
{
    local($limit) = @_;

    if ($limit =~ /^(\d+)(day|days)$/i) {
	&Expire($SPOOL_DIR, $1, 0);
    }
    elsif ($limit =~ /^(\d+)$/i) {
	&Expire($SPOOL_DIR, $1, 1);
    }
    else {
	&Log("Unknown expire limit = [$limit]");
    }
}


sub ExpireSummary
{
    local($first, $last) = @_;
    local($backf) = "$VARLOG_DIR/summary.bak";
    local($tmpf)  = "$TMP_DIR/summary.tmp";

    open(IN,  $SUMMARY_FILE) || (&Log($!), return);
    open(BAK, "> $backf")    || (&Log($!), return);
    open(NEW, "> $tmpf")     || (&Log($!), return);
    select(BAK); $| = 1; select(STDOUT);
    select(NEW); $| = 1; select(STDOUT);    

    # FORMAT: 96/04/23 15:16:00 [493:fukachan@beth.s] subject...
    while (<IN>) {
	print BAK $_;

	if (/^\d\d\/\d\d\/\d\d\s+\d\d:\d\d:\d\d\s+\[(\d+):\S+\]/) {
	    next if $1 <= $last;
	}

	print NEW $_;
    }

    close(IN);
    close(BAK);
    close(NEW);

    if (! rename($tmpf, $SUMMARY_FILE)) {
	&Log("fail to rename $tmpf"); 
	return $NULL;
    }
    else {
	&Log("Expiring \$SUMMARY_FILE has succeeded");
    }
}

1;
