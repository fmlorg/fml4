#!/usr/local/bin/perl
#
# Copyright (C) 1995 fukachan@phys.titech.ac.jp

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

##### LIBRARY #####
sub Expire_with_date { &Expire(@_);}
sub Expire
{
    local($spool_dir, $expire, $ctl_by_number) = @_;
    local($d, *f, $OneDay);

    ### CONFIGURATION
    $spool_dir = $spool_dir || $SPOOL_DIR || "spool";# expire spool articles;
    $expire    = $expire    || 7;	# days (7 == one week)
    $OneDay    = 24*3600;		# seconds for one day

    ### opendir
    opendir(F, $spool_dir)  || (return $NULL);
    foreach $f (readdir(F)) {
	next if $f =~ /^\./;

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
	    $_ = "$spool_dir/$_"; # here for numeric qsoring

	    if ($d <= 0) { 
		&Debug("END\t\t\t[$d<=0]\n") if $debug;
		last;
		&Debug("Try\t$_\t[more $d files]") if $debug;
	    }

	    if (-f $_ && unlink($_)) {
		$d--;
		&Debug("unlink\t$_\t[more $d files]") if $debug;
	    }
	}#foreach;
    }

    1;
}

1;
