#!/usr/local/bin/perl
#
# Copyright (C) 1993-2002 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2002 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# MEAD: Mail Error Analyze Daemon
# $FML: mead.pl,v 1.32.2.2 2002/05/22 15:26:42 fukachan Exp $
#

$Rcsid = 'mead 4.0';

### VERY FUNDAMENTAL CONFIG ###
$ErrorCodePat = '55\d|5\.\d\.\d';
$TrapWord     = 'unknown \S+|\S+ unknown|\S+ not known| not found';

# regexp
$RE_SJIS_C = '[\201-\237\340-\374][\100-\176\200-\374]';
$RE_SJIS_S = "($RE_SJIS_C)+";
$RE_EUC_C  = '[\241-\376][\241-\376]';
$RE_EUC_S  = "($RE_EUC_C)+";
$RE_JIN    = '\033\$[\@B]';
$RE_JOUT   = '\033\([BJ]';
###############################


### MAIN ###
&Init;

chdir $DIR || die "Can't chdir to $DIR\n";

&Parse;

&CacheHints;
&CacheOut;

&DeadOrAlive;

&Report;

if ($ParseFail) { &SaveMail;}

exit 0;


sub Parse
{
    my ($new_block, $gobble, $curf, $first_header_part);
    my ($mp_block, $p, $pmax);

    $new_block = 1;
    $gobble    = 0;
    $curf      = $NULL;
    $first_header_part = 1;

    # gobble error mail
    {
	$pmax = sysread(STDIN, 
			$MessageBuffer, 
			$MEAD_INCOMING_MAIL_SIZE_LIMIT);

	if ($pmax >= $MEAD_INCOMING_MAIL_SIZE_LIMIT) {
	    &Log("warn: input mail is too large");
	    &Log("warn: check the fisrt $MEAD_INCOMING_MAIL_SIZE_LIMIT bytes");
	}
	&Log("log: read $pmax bytes") if $debug;
    }

    my ($msgbufp, $msgbufp1);
    for ($msgbufp = 0; $msgbufp <= $pmax; ) {
	$msgbufp1 = index($MessageBuffer, "\n", $msgbufp);
	last if $msgbufp1 < 0;
	$_        = substr($MessageBuffer, $msgbufp, $msgbufp1 - $msgbufp);
	$msgbufp  = $msgbufp1 + 1;

	# reread input buffer since this buffer ends incomletely.
	# we ends it up with "\n" correctly.
	$SavedBuffer .= $_."\n" if $InputLines++ < 1024;

	# ignore the first header
	# we should ignore header for <maintainer>
	$first_header_part = 0 if /^$/;

	# save excursion
	$PrevLine = $CurLine;
	$CurLine  = $_;

	# check the current block
	if (/^Content-Type:\s*(.*)/i) { 
	    &Debug("<<< $_ >>>");
	    $mp_block = $1;
	}

	if (/^(Content-Description:\s*Notification).*/i) { 
	    &Debug("<<< $_ >>>");
	    $mp_block = $1;
	}

	# Store Received: field 
	if (! $first_header_part) {
	    if (/^([-A-Za-z]+):(.*)/) {
		$curf  = $1;
		$value = $2;
		$Received .= "\n".$value if $curf =~ /Received/i;
	    }
	    elsif (/^\s+(.*)/) {
		$value = $1;
		$Received .= $value if $curf =~ /Received/i;
	    }
	}

	if ($original_mail && $found && $debug) {
	    &Debug("   --- $_") if $debug;
	}
	elsif ($debug) {
	    &Debug("   | $_") if $debug;
	}

	$new_block = 1 if /^\s*$/;

	if (/^From:.*mailer-daemon/i || /^From:.*postmaster/) {
	    undef %return_addr;
	    $original_mail = $found = 0;
	    undef $MTA;
	    undef $CurAddr;
	}

	# guess MTA ...
	if (/^Message-ID:\s+\<[\w\d]+\-[\w\d]+\-[\w\d]+\@/i) { 
	    $MTA = "exim";
	    next;
	}
	if (/qmail-send/) {
	    $MTA = "qmail";
	    next;
	}

	# get returned addresses
	if ($first_header_part) {
	    if (/^(To|Cc):.*/i) {
		if ($new_block && $gabbble == 0) {
		    &Debug("$new_block, $gobble> rset \%return_addr\n") if $debug;
		    undef %return_addr;
		}

		$new_block = 0;
		$gabbble = 1;

		&ExtractAddr($_);
		next;
	    }
	    elsif (/^X\-MLServer:/i) { # this is the commnd mail from fml.
		$NotSavedBuffer = 1;
	    }
	    # 822 folding
	    elsif (/^\s+/ && $gobble) {
		&ExtractAddr($_);
		next;	
	    }
	}


	###
	### RFC1891,1894 DSN
	###
	if ($mp_block =~ /delivery\-status/i) {
	    if (/^Final-Recipient:.*\s+(\S+\@\S+)/i) {
		$DSN_FinalRecipient = &BareAddr($1);
	    }
	    elsif (/^Original-Recipient:.*\s+(\S+\@\S+)/i) {
		$DSN_OriginalRecipient =  &BareAddr($1);
	    }
	    elsif (/^Status:\s*5/i) {
		if ($DSN_OriginalRecipient) {
		    &CacheOn($DSN_OriginalRecipient, " ");
		}
		if ($DSN_FinalRecipient) {
		    &CacheOn($DSN_FinalRecipient, " ");
		}

		$found++;	    
	    }
	}

	# smtpfeed -1 -F hack
	if (/^To: \(original recipient in envelope at \S+\) <(\S+)>/) {
	    &PickUpHint($1);
	}

	#####
	##### MTA szpecific
	#####
	# postfix
	# <uja@beth.fml.org>: unknown user
	if ($mp_block eq 'Content-Description: Notification') {
	    if (/^\s*(\S+\@\S+):\s*(unknown user|.*:\s+5\d\d\s+.*)/) {
		$CurAddr = $1;
		$CurAddr =~ s/[\<\>]//g;
		$CurAddr =~ s/\s*//g;	
		&Debug("CurAddr => $CurAddr") if $debug && $CurAddr;
		$MTA = 'postfix';
	    }
	}

	# exim || qmail
	if ($MTA eq 'qmail' && /This is a permanent error/) {
	    $RABuf .= $_;
	}

	if ($MTA eq 'exim' || $MTA eq 'qmail') {
	    /^\s*(\S+\@\S+):\s*$/ && ($CurAddr = $1);
	    $CurAddr =~ s/[\<\>]//g;
	    $CurAddr =~ s/\s*//g;
	    &Debug("CurAddr => $CurAddr") if $debug && $CurAddr;
	}

	$gobble = 0;

	# ignore Japanese strings.
	next if /$RE_JIN/;
	next if /$RE_JOUT/;
	next if /$RE_SJIS_S/;
	next if /$RE_EUC_S/;

	### unknown MTA  ###
	if (/(\S+\@[-A-Z0-9\.]+)/i) {
	    /(\S+\@[-A-Z0-9\.]+)/i && ($P_CurAddr = $1); # pseudo
	    $P_CurAddr =~ s/[\<\>]//g;
	    $P_CurAddr =~ s/\s*//g;
	    &Debug("P_CurAddr => $P_CurAddr") if $debug && $P_CurAddr;
	}

	# error message line
	# next if /<<<.*\@/;
	# next if /^Diagnostic-Code:/i;

	# ignore the original mails
	# &Debug("next") if $original_mail && $found;
	next if $original_mail && $found;
	$original_mail = 1 if /^received:/i;

	##### TRAP CODE #####
	if (/fatal error/i) { $fatal++;}

	if (/\@/ && /(5\d\d)/)    { &AnalyzeErrorCode($_); $found++; }
	if (/\@/ && /$TrapWord/i) { &AnalyzeErrorWord($_); $found++; }

	### unknown MTA
	# e.g. uset not known
	if (/$TrapWord/i && $P_CurAddr) {
	    &AnalyzeErrorWord($_, $P_CurAddr); 
	    $found++;	
	}

	### postfix
	if (/$TrapWord/i && $MTA eq 'postfix') { 
	    &AnalyzeErrorWord($_, $CurAddr); 
	    $found++;
	} 

	###
	### exim
	###
	if (/$TrapWord/i && $MTA eq 'exim') { 
	    &AnalyzeErrorWord($_, $CurAddr); 
	    $found++;
	}

	# EXIM pattern
	if (/failed/i && $MTA eq 'exim') { 
	    $trap_want_addr = $_;
	    next;
	}
	if ($trap_want_addr && /\@/ && $MTA eq 'exim') { 
	    local($a);
	    /^\s*(\S+\@\S+)/ && ($a = $1);
	    $a =~ s/[\<\>:]//g;
	    &CacheOn($a, " ") if $a; # space is a dummy
	    undef $trap_want_addr;
	}

	if (/($ErrorCodePat)/ && $MTA eq 'exim') { 
	    &AnalyzeErrorWord($_, $CurAddr); 
	    $found++;
	}

	###
	### qmail
	###
	if (/\#5\.\d+\.\d+/ && $MTA eq 'qmail') { 
	    &AnalyzeErrorWord($_, $CurAddr);
	    $found++;
	}

	if ($MTA eq 'qmail' && $CurAddr && $RABuf) {
	    &AnalyzeErrorWord($RABuf, $CurAddr);
	    $found++;
	}

	###
	### sendmail
	###
	if ($fatal) {
	    local($a);
	    /^\s*(\S+\@\S+)/ && ($a = $1);
	    $a =~ s/[\<\>]//g;
	    &CacheOn($a, " ") if $a; # space is a dummy
	}
	# end of fatal block
	if ($fatal && /^$/) {    
	    undef $fatal;
	}
    }

    # VERPs: qmail specific
    # Suppose list-admin-account=domain@$mydomain syntax, ...
    {
	local($ra, $addr);

	$addr = $ENV{'RECIPIENT'};
	$ra   = $ENV{'RECIPIENT'};

	if ($addr =~ /=/) {
	    $addr =~ s/\@\S+$//;
	    $addr =~ s/=/\@/;
	    $addr =~ s/^\S+\-admin\-//; # fml specific 

	    # postfix style
	    if ($ra =~ /admin\+\S+/) {
		$ra =~ s/admin\+\S+\@/admin@/;

		&Debug("postfix:". $addr);
		&Debug("postfix return_addr:". $ra);
		$return_addr{$ra} = 1;
		&CacheOn($addr, " ");
	    }
	    # qmail style
	    elsif ($ra =~ /admin\-\S+/) {
		$ra =~ s/admin\-\S+\@/admin@/;

		&Debug("qmail:". $addr);
		&Debug("qmail return_addr:". $ra);
		$return_addr{$ra} = 1;
		&CacheOn($addr, " ");
	    }
	}
    }
}


sub BareAddr
{
    local($s) = @_;
    $s =~ s/<//g;
    $s =~ s/>//g;
    $s;
}


sub ExtractAddr
{
    my ($addr, $pickup_p) = @_;
    my ($pickup_addr);

    &Debug("ExtractAddr:$new_block,$gabbble> $addr") if $debug;

    for (split(/,/, $addr)) {
	s/</ /g; s/>/ /g; s/\.\.\./ /;
	if (/(\S+\@[\.A-Za-z0-9\-]+)/) { 
	    my $a = $1; $a =~ s/admin\+\S+\=\S+\@/admin/;
	    $return_addr{$a} = 1;
	    $pickup_addr = $a if $pickup_p;
	    &Debug("add \$return_addr{$a}") if $debug;
	}
    }

    $pickup_addr;
}


sub PickUpHint
{
   my ($addr) = @_;
   my ($pickup_addr);
   
   $pickup_addr = &ExtractAddr($addr, 'pickup');
   &Touch($ERROR_ADDR_HINT_FILE);
   &Append($pickup_addr, $ERROR_ADDR_HINT_FILE) if -f $ERROR_ADDR_HINT_FILE;
   &Log("erroraddr.hint: <$pickup_addr>");
}


sub DeadCache
{
   my ($addr) = @_;
   my ($pickup_addr);
   
   $pickup_addr = &ExtractAddr($addr, 'pickup');
   &Touch($DEAD_ADDR_HINT_FILE);
   &Append($pickup_addr, $DEAD_ADDR_HINT_FILE) if -f $DEAD_ADDR_HINT_FILE;
   &Log("deadaddr.hint: <$pickup_addr>");
}


sub AnalWord
{
    local($reason);

    &Debug("AnalWord: @_") if $debug;

    $_ = $_[0];

    if (/user unknown|unknown user|user not known/i) { $reason = 'uu';}
    if (/host unknown|unknown host/i) { $reason = 'uh';}
    if (/service unavailable/i)       { $reason = 'us';}
    if (/address\w+ unknown|unknown address/i) { $reason = 'ua';}

    # postfix
    if (/host not found/i) { $reason = 'uh';}

    # qmail
    if (/couldn\'t find any host/) { $reason = 'uh';}
    if (/can\'t accept addresses/) { $reason = 'ua';}
    if (/no mailbox here/)         { $reason = 'uu';}
    # qmail loop
    if (/This message is looping/) { $reason = 'us';}
    if (/This is a permanent error/) { $reason = 'us';}

    # exim ?
    if (/unknown local-part/i)  { $reason = 'uu';}
    if (/unknown mail domain/i) { $reason = 'uh';}
    if (/unrouteable mail domain/) { $reason = 'uh';}

    &Debug("AnalWord: $reason") if $debug;
    $reason;
}


sub AnalyzeErrorCode
{
    local($addr, $reason, $r);

    $AnalyzeErrorCode++;

    &Debug("$.:AnalyzeErrorCode(@_)") if $debug;

    $_ = $_[0]; s/</ /g; s/>/ /g; s/\.\.\./ /;


    if (/(\S+\@[\.A-Za-z0-9\-]+)/) {
	$addr = $1;

	if (/^($ErrorCodePat)|\D($ErrorCodePat)\D/) {
	    &CacheOn($addr, $r = &AnalWord($_));
	}
    }
    elsif ($addr = $_[1]) {
	    &CacheOn($addr, $r = &AnalWord($_));
    }
    else {
	&Debug("AnalyzeErrorCode: invalid input <$_>") if $debug;
    }

    $CurReason = $r;
}


sub AnalyzeErrorWord
{
    local($addr, $r);

    $_ = $_[0]; s/</ /g; s/>/ /g; s/\.\.\./ /;
    $addr = $_[1];

    &Debug("AnalyzeErrorWord(@_)") if $debug;

    if (/user unknown|unknown user/i && /(\S+\@[\.A-Za-z0-9\-]+)/) {
	&CacheOn($addr = $1, $r = &AnalWord($_));
    }
    elsif ($addr) {
	&CacheOn($addr, $r = &AnalWord($_));
    }
    elsif ($debug) {
	&Debug("AnalyzeErrorWord: invalid input");	
    }

    $CurReason = $r;
}


sub CacheOn
{
    local($addr, $reason) = @_;
    local($hit);

    &Debug("--CacheOn ($addr, $reason);") if $debug;

    # cache check
    if ($debug && $Cached{"$addr:$reason"}) {
	&Debug("CacheOn already cached");
    }

    return if $Cached{"$addr:$reason"};
    $Cached{"$addr:$reason"} = 1;

    if ($debug) {
	unless (%return_addr)   { &Debug("no return_addr");}
	for (keys %return_addr) { &Debug("return_addr = $_");}
    }

    for (keys %return_addr) {
	if ($debug) {
	    if (/^\s*$/ || ($_ eq $addr)) {
		&Debug("ignore null return_addr") unless $_;
		&Debug("ignore $_ (eq \$addr)") if $_ eq $addr;
	    }
	}

	next if /^\s*$/;
	next if $_ eq $addr;

	# %AddrCache
	&AddrCache(time, $addr, $_, $reason);
	$hit++

	# &DoCacheOn(sprintf("%s %s\t%s\tr=%s", time, $addr, $_, $reason))
	# if $addr && $_;
    }

    if (! $hit) {
	&Debug("not hit") if $debug;
    }
}


sub AddrCache 
{
    local($time, $addr, $_, $reason) = @_;
    local($k);

    $k = sprintf("%s %s\t%s\t", $time, $addr, $_);

    if (&ValidAddressP($addr)) {
	&Log("cache: <$addr> reason=$reason");
	&Debug("AddrCache => $AddrCache{$k}, \"r=$reason\"") if $debug;
    }
    else {
	&Log("warn: cache: <$addr> is invalid (ignored)");
	return;
    }

    if ($reason) {
	$AddrCache{$k} = "r=$reason";
    }
    ### no speculated reason ###
    # If already "r=something", should not overwrite it!
    elsif ($AddrCache{$k} ne 'r=') {
	; # not overwrite
	&Debug("no \$AddrCache{$k} !") if $debug;
    }
    # elsif ($AddrCache{$k} eq 'r=') {
    # first time
    else {
	$AddrCache{$k} = "r=$reason";
    }

    &Debug("\$AddrCache{$k} = \"r=$reason\"") if $debug;
}


sub CacheOut
{
    my ($a, $s);
    &Debug("--- CacheOut") if $debug;

    if (%AddrCache) {
	for $a (keys %AddrCache) {
	    $s = $a.$AddrCache{$a};
	    &Append($s, $CACHE_FILE);
	    &Debug($s) if $debug;
	    # &Log("cache.out: <$a>");
	}
    }
    else {
	$ParseFail = 1;
    }

    &Debug("--- CacheOut End.") if $debug;
} 	


sub DoCacheOn
{
    local($s) = @_;
    &Append($s, $CACHE_FILE);
}


sub Append
{
    local($s, $file) = @_;

    open(APP, ">> $file") || die("Append: cannot open $file\n");
    select(APP); $| = 1; select(STDOUT);
    print APP $s, "\n";
    close(APP);
}

sub Log
{
    my ($s) = @_;
    &GetTime;
    &Append($Now." ".$s, $LOGFILE);
}

sub Die
{
    my ($s) = @_;
    &GetTime;
    &Log($s);
    exit 0;
}


sub DeadOrAlive
{
    local($buf, $now, $last, $prev);
    local(%addr);

    $now = time;

    ### check time arrival?

    open(CACHE_FILE, $CACHE_FILE) || 
	&Die("CacheOn: cannot read CACHE_FILE $CACHE_FILE\n");
    while (<CACHE_FILE>) { 
	$buf = $_ if /^\#check/;
    }
    close(CACHE_FILE);

    ($last) = (split(/\s+/, $buf))[1];

    if ($now - $last > $CHECK_INTERVAL) {
	&MLEntryOn($ML_DIR);	# set %ml'ML
	&Debug("check time comes") if $debug;
	&Log("info: dead-or-alive-p() time comes");
    }
    else {
	&Debug("check time comes not yet") if $debug;
	return;
    }


    ### check whether a user is dead or alive
    ### expire old entries 
    local($time, $addr, $ml, $expire_range, $debugbuf);
    local($new) = "$CACHE_FILE.".$$."new";
    local($expire_time) = $now - int($EXPIRE*24*3600);

    &Debug("expire time is " . ($EXPIRE*24*3600)/3600 ." hour(s)") if $debug;

    open(CACHE_FILE, $CACHE_FILE) || 
	&Die("CacheOn: cannot read CACHE_FILE $CACHE_FILE\n");
    open(NEW, "> $new") || &Die("CacheOn: cannot open $new\n");
    select(NEW); $| = 1; select(STDOUT);

    my (%logaddr);
    while (<CACHE_FILE>) {
	# uniq
	next if $prev eq $_;
	$prev = $_;

	($time, $addr, $ml, @opts) = split;

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

	$logaddr{$addr} = $addr;

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
	    $pri = $NULL;
	    for (@opts) { /r=(\S+)/ && ($pri = $1);}

	    # algorithm
	    my (%info);
	    $info{'key'}  = "$addr $ml";
	    $info{'time'} = $time;
	    $info{'addr'} = $addr;
	    $info{'ml'}   = $ml;

	    if (1) {
		&MeadSimpleEvaluator(*addr, \%info);
	    }
	    else {
		$debugbuf = "$addr : $addr{\"$addr $ml\"}\t" if $debug;
		$addr{"$addr $ml"} += 
		    $PRI{$pri} != 0 ? $PRI{$pri} : $PRI{'default'};
		$debugbuf .= "=>\t$addr{\"$addr $ml\"} (pri=$pri)\n" if $debug;
		&Debug($debugbuf) if $debug;
	    }
	}
    }

    # fml 4.0 log
    {
	my ($a);
	for $a (keys %logaddr) {
	    if ($addr{"$a $ml"} > 0) {
		&Log(sprintf("eval: %-40s = %2.1f points", 
			     "<$a>", $addr{"$a $ml"}));
	    }
	}
    }

    print NEW "#check $now\n";
    close(CACHE_FILE);

    rename($new, $CACHE_FILE) || 
	&Die("CacheOn: cannot rename $new $CACHE_FILE");

    # show profile
    &ShowProfile(*addr);

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
	    &Log("dead-or-alive: <$addr> ($addr{$_} points) is dead");

	    ($addr, $admin) = split;

	    &Debug("\$ml = \$ml'ML{$admin}; #';");

	    $ml = $ml'ML{$admin}; #';

	    &Debug("$admin => $ml map") if $debug;

	    if ($ml) {
		&Debug("dead($addr{$_}/$LIMIT):\t$_ <$ml>") if $debug;
		&Action($addr, $ml);
	    }
	    else {
		&Debug("$ml for <$admin> is not found, ignore <$_>") if $debug;
		&Log("warn: ml='$ml' for '$admin' is not found");
		&Log("warn: ignore to remove <$addr>");
	    }
	}
	# alive
	else {
	    &Debug("alive($addr{$_}/$LIMIT):\t$_") if $debug;
	}
    }
}

# dummary
sub MeadSimpleEvaluator 
{ 
    local(*addr, $info) = @_;
    my ($time, $addr, $ml, $pri) = (
				    $info->{'time'},
				    $info->{'addr'},
				    $info->{'ml'},
				    $info->{'pri'},
				    );

    if ($MEAD_ERROR_ESTIMATION_METHOD eq 'simple_sum_up_errors') {
	my $debugbuf = "EVAL> $addr : $addr{\"$addr $ml\"}\t" if $debug;

	$addr{"$addr $ml"} += 
	    $PRI{$pri} != 0 ? $PRI{$pri} : $PRI{'default'};

	$debugbuf .= "=>\t$addr{\"$addr $ml\"} (pri=$pri)\n" if $debug;
	&Debug($debugbuf) if $debug;
    }

    # for better profile
    {
	# cache oldest log for better ESTIMATION
	if (! $OldestLog{$addr}) { $OldestLog{$addr} = $time;}

	# total errors
	$SumUp{$addr}++;

	# profile
	my ($when) = int((time - $time)/(24*3600));
	$Profile{$addr}{$when}++;
    }
}


sub ShowProfile
{
    local(*addr) = @_;
    my ($key);
    my ($max) = ($LIMIT/2);

    for $key (keys %addr) {
	my ($a, $ml) = split(/\s+/, $key);

	# ignore the first case
	next if $SumUp{$a} < $max;

	my ($profile, $profile_sum);
	for $when (0 .. 6) {
	    $profile_sum++ if $Profile{$a}{$when};
	    $profile .= $Profile{$a}{$when} || '0';
	    $profile .= " ";
	}

	&Log("prof: <$a> sum=$profile_sum/total=$SumUp{$a} [$profile]");

	if ($MEAD_ERROR_ESTIMATION_METHOD eq 'simple_sum_up_error_days') {
	    $addr{$key} = $profile_sum;
	}
    }
}



### makefml -> $LogBuf{$ml}
### report     $Template{$ml} (command template)
###            $MakeFmlTemplate{$ml} (e.g. "makefml bye $ml $addr");
sub Report
{
    &GetTime;

    if ($debug) {
	&Debug( "--report MODE=$MODE\n{".
	        join(" ", %MakeFmlTemplate) .
	       "}\n" );
    }

    if ($MODE eq 'report') {
	# make "makefml ..." shell script for convenience
	# This file includes all ML's script if 
	# each ML-admin -> mead.pl is not set but 
	# all erros are input to mead.pl.
	if (%MakeFmlTemplate) {
	    local($tmp)  = "$DIR/,mead.sh$$";
	    local($file) = "$DIR/remove${CurrentTime}.sh";
	    local($addr, @addr);

	    &Append("\#!/bin/sh", $tmp);

	    # [format]
	    # $MakeFmlTemplate{$ml} .= "$MAKEFML $ACTION $ml $addr\n";
	    for $ml (keys %MakeFmlTemplate) {
		@addr = split(/\s+/, $MakeFmlTemplateAddr{$ml});
		$addr = $addr[0];

		if ($MEAD_REPORT_HOOK) {
		    eval($MEAD_REPORT_HOOK);
		    &Debug($@) if $@;
		    print STDERR $@,"\n" if $@;
		}
		else {
		    &Append($MakeFmlTemplate{$ml}, $tmp);
		}

		&Mesg($ml, "\n");
		&Mesg($ml, "2. The script to remove dead users is also generated.");
		&Mesg($ml, "Please log in the fml server host and run (\% is the prompt):\n");
		&Mesg($ml, "\t\% cd $DIR");
		&Mesg($ml, "\t\% sh $file");
	    }

	    rename($tmp, $file) || &Debug("cannot rename $tmp $file");
	    chmod 0755, $file;
	    &Log("create $file");
	}
    }

    ### send reports by mail.

    if ($MODE eq 'auto') {
	$prepend = "Hi, I am the fml Mail Error Analyzer Daemon (mead).\n";
	$prepend .= "I tried to remove the following mail unreachable addresses\n\n";

	$sep  = "\n--mead, fml\'s Mail Error Analyze Daemon\n";
	$sep .= "\n---------- makefml messages ---------\n";

	for $ml (keys %LogBuf) {
	    &Mail($ml, $MFSummary{$ml} . "$sep\n" . $LogBuf{$ml});
	}
    }
    elsif ($MODE eq 'report') {    
	if (%Template) {
	    for $ml (keys %Template) {
		$prepend = "Hi, I am the fml Mail Error Analyzer Daemon (mead).\n";
		$prepend .= "I think you should remove the following mail unreachable addresses\n\n";

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
    $Template{$ml} .= $buf."\n";
}


sub CacheHints
{
    for (reverse split(/\n/, $Received)) {
	&Debug("RECV>: <$_>");

	if (/from\s+([-A-Za-z0-9]+\.[-A-Za-z0-9\.]+)/i) {
	    $Hint{$1} = $1;
	}
	if (/by\s+([-A-Za-z0-9]+\.[-A-Za-z0-9\.]+)/i) {
	    $Hint{$1} = $1;
	}

	if (/for\s+<(\S+\@[A-Za-z0-9\.]+)>/) {
	    &Debug("--&CacheOn($1, $CurReason);");
	    &CacheOn($1, $CurReason);
	    &Log("cache.hint: <$1> reason=$CurReason");
	}
    }
}


sub Mail
{
    local($ml, $buf) = @_;
    local($maintainer) = $ml'MAA{$ml} ;#';
    local($sendmail);

    return unless $ml;

    if (! $maintainer) {
	&Debug("Mail: maintainer is not defined for ML <$ml>");
	&Log("error: maintainer for ml='$ml' not found");
	return $NULL;
    }

    $sendmail = $SENDMAIL || &SearchPath("sendmail") || 
	&SearchPath("qmail-smtpd", "/var/qmail/bin") ||
	    &SearchPath("exim", "/usr/local/exim/bin");

    if (! $sendmail) {
	&Log("error: cannot find sendmail=$sendmail");
	return $NULL;
    }

    open(MAIL, "| $sendmail -t") || &Die("cannot execute $sendmail");
    binmode(MAIL);

    print MAIL "From: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "Reply-To: ". $ml'CA{$ml} . "\n"; #';
    print MAIL "Subject: fml mail error analyzer (mead) report for ML <$ml>\n";
    print MAIL "To: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "X-MLServer: mead\n";
    print MAIL "\n";
    print MAIL $buf;

    close(MAIL);
}


sub SaveMail
{
    if ($NotSavedBuffer) {
	&Log("info: fml command mail (ignored)");
	return;
    }

    &Log("warn: unanalyzable error mail");

    if ($SAVE_UNANALYZABLE_ERROR_MAIL ||
	$Forced::SAVE_UNANALYZABLE_ERROR_MAIL) {

	&GetTime;
	
	# make working directory
	-d $VAR_DIR    || mkdir($VAR_DIR, 0755);
	-d $VARLOG_DIR || mkdir($VARLOG_DIR, 0755);
	my $f = $VARLOG_DIR."/mead.$$.".$PCurrentTime;
	&Append($SavedBuffer, $f);
	$f =~ s@$DIR/@@;
	&Log("warn: saved in $f");
    }
}


# mainly search e.g. "sendmail"
sub SearchPath
{
    local($prog, @path) = @_;
    for ("/usr/sbin", "/usr/lib", @path) {
	if (-e "$_/$prog" && -x "$_/$prog") { return "$_/$prog";}
    }
}


sub ValidAddressP
{
    my ($a) = @_;
    $a =~ /^[-a-z0-9\._]+\@[a-z0-9\.-]+$/i ? 1 : 0;
}

sub Action
{
    local($addr, $ml) = @_;
    my ($mode) = $MODE;

    ### makefml -> $LogBuf{$ml}
    ### report     $Template{$ml} (command template)
    ###            $MakeFmlTemplate{$ml} (e.g. "makefml bye $ml $addr");

    if (&ml::ValidMLP($ml)) {
	&Log("info: ml='$ml' is valid");
    }
    else{
	&Log("warn: ml='$ml' is invalid");
	return;
    }

    if (&ml::ValidMailListP($addr)) {
	&Log("warn: <$addr> is a mailing list name (ignored)");
	return;
    }

    if (&ValidAddressP($addr)) {
	&DeadCache($addr);

	if ($mode eq 'auto') {
	    &MakeFml("$ACTION $ml $addr", $addr, $ml);
	    &Log("action: makefml bye <$ml> $addr");
	}
	elsif ($mode eq 'report') {
	    $Template{$ml}            .= $CTK{$ml}."admin $ACTION $addr\n";
	    $MakeFmlTemplate{$ml}     .= "$MAKEFML $ACTION $ml $addr\n";
	    $MakeFmlTemplateAddr{$ml} .= $addr. "\t";
	}
	else {
	    &Debug("mode $mode is unknown");
	}
    }
    else {
	&Log("action: ignore $addr (invalid syntax)");

	$MFSummary{$ml} .= "\tignore invalid address <$addr>.\n";
	$MFSummary{$ml} .= "\tPlease remove <$addr> by hand.\n";
	$LogBuf{$ml} .= "\tignore invalid address <$addr>.\n";
	$LogBuf{$ml} .= "\tPlease remove <$addr> by hand.\n";
    }

    # record the addr irrespective of succeess or fail
    # to avoid a log of warning mails "remove ... but fails" ;-)
    &Log("info: remove <$addr>");
    &DoCacheOn("#remove $addr");
}


sub MakeFml
{
    local($buf, $addr, $ml) = @_;
    local($r, $ok, $logbuf);

    $ok = 0;

    $LogBuf{$ml} .= "mead> $ACTION $ml $addr\n";
    $MFSummary{$ml} .= "mead> $ACTION $ml $addr\n";

    require 'open2.pl';

    if (&open2(RS, S, "$MAKEFML -i stdin -u mead 2>&1")) { 
	select(S); $| = 1; select(STDOUT);
	print S $buf;
	close(S);
	while (<RS>) {
	    $logbuf .= $_;
	    if (/\#\#BYE\s*$addr/i) { $ok = 1;} # bye case (default)
	    if (/\#\s*$addr/i)     { $ok = 1;} # off case
	}
	close(RS);

	if ($ok) {
	    $LogBuf{$ml} .= "\tsucceeds.\n";
	    $MFSummary{$ml} .= "\tsucceeds.\n";
	}
	else {
	    $MFSummary{$ml} .= "\tfails.\n";
	    $MFSummary{$ml} .= "\tPlease remove $addr by hand.\n";

	    $LogBuf{$ml} .= "\tfails.\n";
	    $LogBuf{$ml} .= "\tPlease remove $addr by hand.\n";
	}

	$LogBuf{$ml} .= $logbuf;
    }
    else {
	print "Mead ERROR: cannot execute makefml [$MAKEFML]\n";
    }
}


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, 
			$isdst ? $TZONE_DST : $TZone);

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
    &Getopts("dD:e:S:hC:i:l:M:m:E:p:z:k:f:");
    $opt_h && die(&Usage);
    $debug = $opt_d ? 100 : 0;

    # program directory
    $EXEC_DIR = $opt_E;
    $ML_DIR   = $opt_S;
    if (! $EXEC_DIR) {
	$EXEC_DIR = $0;
	$EXEC_DIR =~ s#/libexec/mead.pl##;
    }

    # at the first stage, evaluate the configuration file
    # overwrite -m, -S, -D, -E ?
    if ($opt_f && -f $opt_f) {
	$ConfigFile = $opt_f;
    }
    # backward compatible ;-) but this is obsolete !!!
    elsif (-f "$ML_DIR/etc/mead/mead_config.ph") {
	$ConfigFile = "$ML_DIR/etc/mead/mead_config.ph";
    }

    # fml 4.0
    if ($opt_D) {
	if (-d $opt_D && -f "$opt_D/mead_init.ph") {
	    push(@INC, $opt_D);
	    eval require "$opt_D/mead_init.ph";
	}
    }

    &EvalCF($ConfigFile) if -f $ConfigFile;

    # fml 4.0
    if ($opt_D) {
	if (-d $opt_D && -f "$opt_D/mead_force.ph") {
	    push(@INC, $opt_D);
	    package Forced;
	    eval require "$main::opt_D/mead_force.ph";
	    package main;
	}
    }

    $MEAD_ERROR_ESTIMATION_METHOD = 'simple_sum_up_errors';
    $MEAD_INCOMING_MAIL_SIZE_LIMIT = 64*1024; # 64K bytes 

    $LIMIT  = $Forced::LIMIT  || $opt_l || $LIMIT  || 5;
    $EXPIRE = $Forced::EXPIRE || $opt_e || $EXPIRE || 14; # days
    $ACTION = $Forced::ACTION || $opt_k || $ACTION || 'bye';
    $MODE   = $Forced::MODE   || $opt_m || $MODE || 'report'; # mode

    # expire check interval
    $CHECK_INTERVAL = $Forced::CHECK_INTERVAL || $opt_i || 
	$CHECK_INTERVAL || 3*3600;

    # directories
    $ML_DIR     = $Forced::ML_DIR   || $opt_S || $ML_DIR;
    $EXEC_DIR   = $Forced::EXEC_DIR || $opt_E || $EXEC_DIR;
    $DIR        = $Forced::DIR      || $opt_D || $DIR; # working directory.
    $VAR_DIR    = "$DIR/var" if $DIR;
    $VARLOG_DIR = "$VAR_DIR/log" if $VAR_DIR;

    # log file
    $LOGFILE = "$DIR/log.mead";

    # cache
    $CACHE_FILE = $Forced::CACHE_FILE || $opt_C || $CACHE_FILE || 
	"$DIR/errormaillog";
    $ERROR_ADDR_HINT_FILE = $Forced::ERROR_ADDR_HINT_FILE || 
	$ERROR_ADDR_HINT_FILE || "$DIR/error_addr.hints";

    $DEAD_ADDR_HINT_FILE = $Forced::DEAD_ADDR_HINT_FILE || 
	$DEAD_ADDR_HINT_FILE || "$DIR/dead_addrs";

    # programs
    $MAKEFML  = $Forced::MAKEFML  || $opt_M || $MAKEFML || "$EXEC_DIR/makefml";
    $SENDMAIL = $Forced::SENDMAIL || $opt_z || $SENDMAIL;

    # priority; $opt_p
    $PRI{'uu'}      = 1;
    $PRI{'default'} = 0.25;
    for (split(/,/, $opt_p . $PRIORITY)) {
	if (/(\S+)=(\S+)/) {
	    $PRI{$1} = $2;
	    &Debug("--- \$PRI{$1} = $2") if $debug;
	}
    }

    # touch
    &Touch($CACHE_FILE);

    # diagnostics
    $DIR    || die("Please define -D \$DIR, mead.pl working directory\n");
    $ML_DIR || die("Please define -S ML_DIR e.g. -S /var/spool/ml\n");
}


sub EvalCF
{
    package mead;
    eval require $main'ConfigFile; #';
    package main;

    for ("debug", 
	 OVERWRITE_COMMAND_LINE_OPTIONS,
	 EXPIRE, ACTION, CHECK_INTERVAL, LIMIT, 
	 DIR, ML_DIR, CACHE_FILE, EXEC_DIR, MAKEFML, 
	 MODE, SENDMAIL, PRIORITY, MEAD_REPORT_HOOK) {
	eval("\$main::${_} = \$mead::${_};");

	if ($OVERWRITE_COMMAND_LINE_OPTIONS) {
	    eval("\$Force::${_} = \$mead::${_};");
	}
    }
}


sub Usage
{
"Usage: mead.pl [options]

Options:
    -h              help
    -d              debug mode on
    -m mode         mode; report or auto ('report' in default).

    -f configfile   load configuration from this file at the first
                    Other command line options can overwrite it.
    -e number       expire of error data cache (unit is 'day')
    -i number       check interval (unit is 'second')

    -C cachefile    mead data cache file
    -D directory    \$DIR (mead.pl working directory)
    -E directory    \$EXEC_DIR (e.g. /usr/local/fml)
    -S directory    \$ML_DIR (e.g. /var/spool/ml)
    -M path         makefml path

    -p priority     priority, e.g. -p uu=2,uh=0.5
                    (user unkwown == 2, host unkown == 0.5)
                    [KEYWORD]
                            uu: unknown user
                            uh: unknown host
                            ua: unknown address
                            us: service unavaiable 
                            default: default value for phrases not above

    -k action        'bye' is default,  off or bye.
                     change the action when mead detects a bad address.

    -l limit         limit whether we should do action defined by '-k action'

    -z sendmail      alternative sendmail path
"
}


sub Touch  { open(APP, ">>$_[0]"); close(APP); chown $<, $GID, $_[0] if $GID;}

sub Debug
{
    my ($s) = @_;

    return if $debug < 100;

    open(DEBUG, ">> $LOGFILE");
    print DEBUG $s, "\n";
    close(DEBUG);
    return unless $debug;
    print STDERR @_, "\n";
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


sub ValidMLP
{
    my ($mladdr) = @_;

    # compare 
    $mladdr =~ s/-admin@.*$//;

    $Valid{$mladdr} ? 1 : 0;
}


sub ValidMailListP
{
    my ($addr) = @_;
    $MAIL_LIST{$addr}; 
}

sub main'MLEntryOn #';
{
    local($spool) = @_;

    $ml_debug = $ml'debug = $main'debug;
    $ml'debug_ml = $main'debug_ml;

    opendir(DIRD, $spool) || die("cannot opendir $spool");
    for (readdir(DIRD)) {
	next if /^\./;
	next if /^etc/;
	next if /^fmlserv/;

	$ml = $_;

	$config = "$spool/$_/config.ph";

	if (-f $config) {
	    &Debug("eval $config") if $debug_ml;

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
	    &Debug("\$ML{$MAINTAINER} = $ml;") if $debug_ml;

	    $Valid{$ml} = 1;
	    $ML{$MAINTAINER} = $ml;
	    $MAA{$ml} = $MAINTAINER; # ML Admin Address
	    $CA{$ml}  = $CONTROL_ADDRESS || $MAINTAINER;
	    $CTK{$ml} = ($CONTROL_ADDRESS eq $MAIL_LIST) ? '# ' : '';

	    # valid ?
	    $MAIL_LIST{$MAIL_LIST} = 1;
	}

    }
    closedir(DIRD);

    if ($debug_ml) {
	while (($k, $v) = each %ML) { print "$k -> $v\n";}
    }
}

1;
