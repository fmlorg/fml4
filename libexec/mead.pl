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

&Report;

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
		
		&CacheOn(sprintf("%s %s\t%s", time, $addr, $_))
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
    &Append($s, $CACHE);
}


sub Append
{
    local($s, $file) = @_;

    open(APP, ">> $file") || die("Append: cannot open $file\n");
    select(APP); $| = 1; select(STDOUT);
    print APP "$s\n";
    close(APP);
}


sub DeadOrAlive
{
    local($buf, $now, $last, $prev);

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
    local($time, $addr, $ml, $expire_range);
    local($new) = "$CACHE.new";
    local($expire_time) = $now - int($EXPIRE*24*3600);

    &Debug("expire time is". ($EXPIRE*24*3600)/3600 ."hour(s)") if $debug;

    open(CACHE, $CACHE) || die("CacheOn: cannot read CACHE $CACHE\n");
    open(NEW, "> $new") || die("CacheOn: cannot open $new\n");
    select(NEW); $| = 1; select(STDOUT);

    while (<CACHE>) {
	# uniq
	next if $prev eq $_;
	$prev = $_;

	($time, $addr, $ml) = split;

	if (/^\#/) {
	    # remove info is also expired
	    if ($time eq '#remove') {
		$IgnoreAddr{$addr} = 1;
		&Debug("Add \$IgnoreAddr{$addr}");
	    }

	    # not print within expire range
	    print NEW $_ unless $expire_range;
	    next;
	} 

	# expire check, not print, so remove them
	if ($time < $expire_time) {
	    $expire_range = 1;
	    next;
	}
	else {
	    $expire_range = 0;

	    # back up (after expired)
	    print NEW $_;

	    # count; sum up for each address
	    $addr{"$addr $ml"}++;
	}
    }

    print NEW "#check $now\n";
    close(CACHE);

    rename($new, $CACHE) || die("CacheOn: cannot rename $new $CACHE");

    ### remove address 
    local($addr, $admin);

    # %addr = ("recipients return-address" => number-of-errors); 
    for (keys %addr) {
	($addr, $admin) = split;

 	# already removed address
	&Debug("ignore $addr (already warned)") if $debug && $IgnoreAddr{$addr};
	next if $IgnoreAddr{$addr};

	# dead
	if ($addr{$_} > $LIMIT) {
	    ($addr, $admin) = split;

	    &Debug("\$ml = \$ml'ML{$admin}; #';");

	    $ml = $ml'ML{$admin}; #';

	    &Debug("$admin => $ml map") if $debug;

	    if ($ml) {
		&Debug("dead:\t$_ <$ml>") if $debug;
		&Action($addr, $ml);
	    }
	    else {
		&Debug("$ml for <$admin> is not found, ignore <$_>") if $debug;
	    }
	}
	# alive
	else {
	    &Debug("alive:\t$_") if $debug;
	}
    }
}


### makefml -> $LogBuf{$ml}
### report     $Template{$ml} (command template)
###            $MakeFmlTemplate{$ml} (e.g. "makefml bye $ml $addr");
sub Report
{
    &GetTime;

    if ($MODE eq 'report') {
	# make "makefml ..." shell script for convenience
	# This file includes all ML's script if 
	# each ML-admin -> mead.pl is not set but 
	# all erros are input to mead.pl.
	if (%MakeFmlTemplate) {
	    local($tmp)  = "$DIR/,mead.sh$$";
	    local($file) = "$DIR/remove${CurrentTime}.sh";

	    &Append("\#!/bin/sh", $tmp);

	    for $ml (keys %MakeFmlTemplate) {
		&Append($MakeFmlTemplate{$ml}, $tmp);

		&Mesg($ml, "\n");
		&Mesg($ml, "2. The script to remove dead users is also generated.");
		&Mesg($ml, "Please log in the fml server host and run (\% is the prompt):\n");
		&Mesg($ml, "\t\% cd $DIR");
		&Mesg($ml, "\t\% sh $file");
	    }

	    rename($tmp, $file) || &Debug("cannot rename $tmp $file");
	    chmod 755, $file;
	}
    }

    ### send reports by mail.

    if ($MODE eq 'auto') {
	for $ml (keys %LogBuf) {
	    &Mail($ml, $LogBuf{$ml});
	}
    }
    elsif ($MODE eq 'report') {    
	if (%Template) {
	    for $ml (keys %Template) {
		$prepend = "Hi, I am fml Mail Error Analyzer Daemon (mead).\n";
		$prepend .= "I think you should remove mail unreachable addresses\n\n";

		$prepend .= "1. If you use remote administration mode,\n";
		$prepend .= "send the following command(s) to <";
		$prepend .= $ml'CA{$ml} .">.\n\n"; #';
	
		# prepend
		$Template{$ml} = $prepend. $Template{$ml};
		&Mesg($ml, "\n--mead, fml\'s Mail Error Analyze Daemon");

		&Mail($ml, $Template{$ml});
	    }
	}
    }
    else {
	;
    }
}


sub Mesg
{
    local($ml, $buf) = @_;
    $Template{$ml} .= "$buf\n";
}


sub Mail
{
    local($ml, $buf) = @_;
    local($maintainer) = $ml'MAA{$ml} ;#';

    return unless $ml;

    if (! $maintainer) {
	&Debug("Mail: maintainer is not defined for ML <$ml>");
	return $NULL;
    }

    open(MAIL, "| $EXEC_DIR/bin/sendmail -t") || 
	die("cannot execute $EXEC_DIR/bin/sendmail");

    print MAIL "From: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "Reply-To: ". $ml'CA{$ml} . "\n"; #';
    print MAIL "Subject: mead report for ML <$ml>\n";
    print MAIL "To: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "\n";
    print MAIL $buf;

    close(MAIL);
}


sub Action
{
    local($addr, $ml) = @_;

    ### makefml -> $LogBuf{$ml}
    ### report     $Template{$ml} (command template)
    ###            $MakeFmlTemplate{$ml} (e.g. "makefml bye $ml $addr");

    if ($MODE eq 'auto') {
	&MakeFml("bye $ml $addr", $addr, $ml);
    }
    elsif ($MODE eq 'report') {
	$Template{$ml} .= "\# admin bye $addr\n";
	$MakeFmlTemplate{$ml} .= "makefml bye $ml $addr\n";
    }
    else {
	&Debug("mode $MODE is unknown");
    }

    # record the addr irrespective of succeess or fail
    # to avoid a log of warning mails "remove ... but fails" ;-)
    &CacheOn("#remove $addr");
}


sub MakeFml
{
    local($buf, $addr, $ml) = @_;
    local($r, $ok, $logbuf);

    $ok = 0;

    $LogBuf{$ml} .= "mead> bye $ml $addr\n";

    if (&open2(RS, S, "$MAKEFML -i -u mead 2>&1")) { 
	select(S); $| = 1; select(STDOUT);
	print S $buf;
	close(S);
	while (<RS>) {
	    $logbuf .= $_;

	    if (/\#\#BYE\s+$addr/i) {
		$ok = 1;
		$LogBuf{$ml} .= "\tsucceeds.\n";
	    }
	    else {
		$LogBuf{$ml} .= "\tfails.\n";
		$LogBuf{$ml} .= "\tPlease remove $addr by hand.\n";
	    }
	}
	close(RS);

	$LogBuf{$ml} .= $logbuf;
    }
    else {
	print "Mead error: cannot execute makefml [$MAKEFML]\n";
    }
}


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime  = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
    $PCurrentTime = sprintf("%04d%02d%02d%02d%02d%02d", 
			    1900 + $year, $mon + 1, $mday, $hour, $min, $sec);
}


sub Init
{
    &GetTime;
    $| = 1;

    require 'getopts.pl';
    &Getopts("dD:e:S:hC:i:l:M:m:E:");
    $opt_h && die(&Usage);
    $debug  = $opt_d;
    $EXPIRE = $opt_e || 14; # days

    # expire check interval
    $CHECK_INTERVAL = $opt_i || 3*3600;

    $LIMIT  = $opt_l || 5;

    $DIR    = $opt_D || 
	die("Please define -D \$DIR, mead.pl working directory\n");
    $ML_DIR = $opt_S || die("Please define -S ML_DIR e.g. -S /var/spool/ml\n");
    $CACHE  = $opt_C || "$DIR/errormaillog";

    # program
    $EXEC_DIR = $0;
    $EXEC_DIR =~ s#/libexec/mead.pl##;
    $EXEC_DIR = $opt_E || $EXEC_DIR;
    $MAKEFML  = $opt_M || "$EXEC_DIR/makefml";

    # mode
    $MODE = $opt_m || 'report';

    # touch
    &Touch($CACHE);
}


sub Usage
{
"Usage: mead.pl [options]

Options:
    -h              help
    -d              debug mode on
    -m mode         mode; report or auto ('report' in default).

    -e number      expire of error data cache (unit is 'day')
    -i number      check interval (unit is 'second')

    -C cachefile    mead data cache file
    -D directory    \$DIR (mead.pl working directory)
    -E directory    \$EXEC_DIR (e.g. /usr/local/fml)
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

sub Debug
{
    &main'Debug(@_); #';
}

sub main'MLEntryOn #';
{
    local($spool) = @_;

    $ml_debug = $ml'debug = $main'debug;

    opendir(DIRD, $spool) || die("cannot opendir $spool");
    for (readdir(DIRD)) {
	next if /^\./;
	next if /^etc/;
	next if /^fmlserv/;

	$ml = $_;

	$config = "$spool/$_/config.ph";

	if (-f $config) {
	    &Debug("eval $config") if $debug;

	    undef $buf;
	    open(CF, $config);
	  CF: 
	    while (<CF>) {
		$buf .= $_;
		last CF if /^\s*\$MAINTAINER/;
	    }
	    close(CF);

	    eval($buf);
	    &Debug($@) if $@;

	    # reset required (config.ph overwrite it).
	    $debug = $ml_debug;
	    &Debug("\$ML{$MAINTAINER} = $ml;") if $debug;

	    $ML{$MAINTAINER} = $ml;
	    $MAA{$ml} = $MAINTAINER; # ML Admin Address
	    $CA{$ml}  = $CONTROL_ADDRESS || $MAINTAINER;
	}

    }
    closedir(DIRD);

    if ($debug) {
	while (($k, $v) = each %ML) { print "$k -> $v\n";}
    }
}

1;
