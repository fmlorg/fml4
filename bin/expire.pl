#!/usr/local/bin/perl
#
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# $rcsid   = q$Id$;
#

# CONFIGURATION
$SPOOL_DIR = $SPOOL_DIR || "spool";	# expire spool articles
$EXPIRE	   = $EXPIRE    || 7;		# days (7 == one week)
$ONEDAY    = 24*3600;			# seconds for one day

if ($0 eq __FILE__) {
	require 'getopts.pl';
	&Getopts("hs:e:dn");

	die(&USAGE) if $opt_h;
	$SPOOL_DIR = $opt_s || $SPOOL_DIR;
	$EXPIRE	   = $opt_e || $EXPIRE;
	$WITH_NUMBER = $opt_n;	# number
	$debug     = $opt_d;
	
	print STDERR "&Expire($SPOOL_DIR, $EXPIRE);\n" if $debug;
	if ($WITH_NUMBER) {
	    &Expire($SPOOL_DIR, $EXPIRE, $WITH_NUMBER);
	}
	else {
	    &Expire($SPOOL_DIR, $EXPIRE);
	}

	exit 0;
}
else {
	print STDERR "Loading Expire Library\n" if $debug;
}

##### LIBRARY #####
sub Expire_with_date { &Expire(@_);}
sub Expire
{
	local($SPOOL_DIR, $EXPIRE, $WITH_NUMBER) = @_;
	local($d, *f);

	opendir(F, $SPOOL_DIR) || (return $NULL);
	foreach $f (readdir(F)) {
		next if $f =~ /^\.$/;
		next if $f =~ /^\.\.$/;

		if ($WITH_NUMBER)  {
		    push(@f, "$SPOOL_DIR/$f");
		}
		else {
		    # expire with date(default)
		    $f = "$SPOOL_DIR/$f";
		    $d = time - (stat($f))[10];
		    $d /= $ONEDAY;
		    print STDERR "unlink $f if $d > $EXPIRE\n" if $debug;
		    if ( !$debug && -f $f && $d > $EXPIRE && unlink $f ) {
			print STDERR "canont unlink $f\n";
		    }
		}
	}
	closedir(F);

	# Suppose I do not believe the counter by $DIR/seq 
	if ($WITH_NUMBER)  {
	    # sort ->  1 , 2, 3, ... incresing order.
	    @f = sort {$a <=> $b} @f;
	    $d = scalar(@f) - $EXPIRE;

	    foreach(@f) {
		last if $d <= 0;
		print STDERR "unlink $_ [$d files left]\n" if $debug;
		-f $_ && unlink($_) && $d--;
	    }
	}

}


sub USAGE
{
q#expire.pl [-h] [-e expire_days] [-s spool_directry] [-n]
    -h                 : this HELP
    -e expire_days(or max number of files left in the spool) 
    -s spool_directry  : spool
    -n                 : expire with the max number(number is -e option)   
#;
}

1;
