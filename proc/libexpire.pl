#!/usr/local/bin/perl
#
# Copyright (C) 1995-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

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
	$first_seq || ($first_seq = $f); # Init(NOT SET last_seq)

	if ($ctl_by_number)  {
	    push(@f, $f); # without 'spool' for numeric qsort
	}
	else {
	    # expire with date(default)
	    $f  = "$spool_dir/$f";
	    $d  = time - (stat($f))[10];
	    $d /= $OneDay;
	    
	    &Debug("?:expire $f if $d > $expire") if $debug; 

	    if ((!$debug) && (-f $f) && ($d > $expire)) {
		unlink $f && &Debug("unlink $f");

		# store the largest sequence
		$last_seq = $last_seq > $unlink_seq ? $last_seq : $unlink_seq;
		$first_seq = $first_seq < $unlink_seq ? $first_seq : $unlink_seq;
	    }
	}
    }
    closedir(F);

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

    &Log("unlink $first_seq -> $last_seq");

    &ExpireSummary($first_seq, $last_seq);

    1;
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

	if (/\d\d:\d\d:\d\d\s+\[(\d+):\S+\]/) {
	    next if $1 <= $last;
	}

	print NEW $_;
    }

    close(S);
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
