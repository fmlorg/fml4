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
# MEAD: Mail Error Analyze Daemon
# $Id$

&Init;

chdir $DIR || die "Can't chdir to $DIR\n";

$error_code_pat = '55\d';
$new_block = 1;
$gabble = 0;

while (<>) {
    chop;

    &Debug("   | $_") if $debug;

    $new_block = 1 if /^\s*$/;

    if (/^From:.*mailer-daemon/i ||
	/^From:.*postmaster/) {
	undef %return_addr;
    }

    # get returned addresses
    if (/^(To|Cc):.*/i) {
	if ($new_block && $gabbble == 0) {
	    &Debug("$new_block, $gabble> rset \%return_addr\n") if $debug;
	    undef %return_addr;
	}

	$new_block = 0;
	$gabbble = 1;

	&ExtractAddr($_);
	next;
    }
    elsif (/^\s+/ && $gabble) {
	&ExtractAddr($_);
	next;	
    }

    $gabble = 0;

    # error message line
    next if /<<<.*\@/;
    next if /^Diagnostic-Code:/i;
    if (/\@/ && /(5\d\d)/) { &ErrorAnal($_);}
}

&DeadOrAlive;

exit 0;


sub ExtractAddr
{
    &Debug("ExtractAddr:$new_block,$gabbble> $_[0]") if $debug;

    for (split(/,/, $_[0])) {
	s/</ /g; s/>/ /g; s/\.\.\./ /;
	if (/(\S+\@[\.A-Za-z0-9\-]+)/) { 
	    $return_addr{$1} = 1;
	    &Debug("add \$return_addr{$1}") if $debug;
	}
    }
}


sub ErrorAnal
{
    $ErrorAnal++;

    local($addr);

    &Debug("$.:ErrorAnal(@_)") if $debug;

    $_ = $_[0]; s/</ /g; s/>/ /g; s/\.\.\./ /;

    if (/(\S+\@[\.A-Za-z0-9\-]+)/) {
	$addr = $1;

	if (/^($error_code_pat)|\D$error_code_pat\D/) {
	    for (keys %return_addr) {
		next if /^\s*$/;
		next if $_ eq $addr;
		
		&CacheOn(sprintf("%s %s\t%s\n", time, $addr, $_))
		    if $addr && $_;
	    }
	}
    }
    else {
	&Debug("ErrorAnal: invalid input <$_>") if $debug;
    }
}


sub CacheOn
{
    local($s) = @_;

    open(APP, ">> $CACHE") || die("CacheOn: cannot open CACHE $CACHE\n");
    select(APP); $| = 1; select(STDOUT);
    print APP $s;
    close(APP);
}


sub DeadOrAlive
{
    local($buf, $now, $last);

    $now = time;

    ### check time arrival?

    open(CACHE, $CACHE) || die("CacheOn: cannot read CACHE $CACHE\n");
    while (<CACHE>) { 
	$buf = $_ if /^\#check/;
    }
    close(CACHE);

    ($last) = (split(/\s+/, $buf))[1];

    &Debug("if ($now - $last > $CHECK_INTERVAL) {");
    if ($now - $last > $CHECK_INTERVAL) {
	&MLEntryOn($ML_DIR);	# set %ml'ML
	&Debug("check time comes");
    }
    else {
	&Debug("check time comes not yet") if $debug;
	return;
    }


    ### check whether a user is dead or alive
    ### expire old entries 
    local($time, $addr, $ml);
    local($new) = "$CACHE.new";
    local($expire_time) = $now - $EXPIRE*24*3600;

    open(CACHE, $CACHE) || die("CacheOn: cannot read CACHE $CACHE\n");
    open(NEW, "> $new") || die("CacheOn: cannot open $new\n");
    select(NEW); $| = 1; select(STDOUT);

    while (<CACHE>) {
	($time, $addr, $ml) = split;

	if ($time eq '#remove') {
	    $IgnoreAddr{$addr} = 1;
	}

	# specaial info
	next if /^\#/;

	# back up (after expired)
	print NEW $_ if $time > $expire_time;

	# count; sum up for each address
	$addr{"$addr $ml"}++;
    }

    print NEW "#check $now\n";
    close(CACHE);

    rename($new, $CACHE) || die("CacheOn: cannot rename $new $CACHE");

    for (keys %addr) {
 	# already removed address
	next if $IgnoreAddr{$addr};

	# dead
	if ($addr{$_} > $LIMIT) {
	    ($addr, $ml) = split;
	    $ml = $ml'ML{$ml}; #';

	    if ($ml) {
		&Out("dead:\t$_ <$ml>");
		&MakeFml("bye $ml $addr", $addr);
	    }
	    else {
		&Debug("ml is not found, ignore <$_>") if $debug;
	    }
	}
	# alive
	else {
	    &Debug("alive:\t$_") if $debug;
	}
    }
}


sub MakeFml
{
    local($buf, $addr) = @_;
    local($r, $ok);

    $ok = 0;

    if (&open2(RS, S, "$MAKEFML -i -u mead")) { 
	select(S); $| = 1; select(STDOUT);
	print S $buf;
	close(S);
	while (<RS>) {
	    print $_;

	    if (/\#\#BYE\s+$addr/i) {
		$ok = 1;
	    }
	}
	close(RS);

	&CacheOn("#remove $addr");
    }
    else {
	print "Mead error: cannot execute makefml [$MAKEFML]\n";
    }
}


sub Init
{
    $| = 1;

    require 'getopts.pl';
    &Getopts("dD:e:S:hC:i:l:M:");
    $opt_h && die(&Usage);
    $debug  = $opt_d;
    $EXPIRE = $opt_e || 14; # days

    # expire check interval
    $CHECK_INTERVAL = $opt_i || 3*3600;

    $LIMIT  = $opt_l || 5;

    $DIR    = $opt_D || 
	die("Please define -D \$DIR, mead.pl working directory\n");
    $ML_DIR = $opt_S || die("Please define -S ML_DIR e.g. -S /var/spool/ml\n");
    $CACHE  = $opt_C || "$DIR/mead.cache";

    # program
    $MAKEFML = $0;
    $MAKEFML =~ s#libexec/mead.pl#sbin/makefml#;
    $MAKEFML = $opt_M || $MAKEFML;

    # 
    &Touch($CACHE);
}


sub Usage
{
"Usage: mead.pl [options]

Options:
    -h              help
    -d              debug mode on

    -e number      expire of error data cache (unit is 'day')
    -i number      check interval (unit is 'second')

    -C cachefile    mead data cache file
    -D directory    \$DIR (mead.pl working directory)
    -S directory    \$ML_DIR (e.g. /var/spool/ml)

    -M path         makefml path
"
}


sub Touch  { open(APP, ">>$_[0]"); close(APP); chown $<, $GID, $_[0] if $GID;}

sub Debug
{
    print STDERR "$_[0]\n";
}


sub Out
{
    print STDERR "$_[0]\n";
}


package ml;

sub main'MLEntryOn #';
{
    local($spool) = @_;

    opendir(DIRD, $spool) || die("cannot opendir $spool");
    for (readdir(DIRD)) {
	next if /^\./;
	next if /^etc/;
	next if /^fmlserv/;

	$ml = $_;

	$config = "$spool/$_/config.ph";

	if (-f $config) {
	    undef $buf;
	    open(CF, $config);
	    while (<CF>) {
		$buf .= $_;
		last if /^\s*\$MAINTAINER/;
	    }
	    close(CF);

	    eval($buf);
	    $ML{$MAINTAINER} = $ml;
	}

    }
    closedir(DIRD);

    if ($debug) {
	while (($k, $v) = each %ML) { print "$k -> $v\n";}
    }
}

1;
