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

$error_code_pat = '55\d|5\.\d\.\d';
$TrapWord       = 'unknown \S+|\S+ unknown|\S+ not known';
$new_block = 1;
$gabble = 0;
$curf = $NULL;
$first_header_part = 1;

while (<>) {
    chop;

    # ignore the first header
    # we should ignore header for <maintainer>
    $first_header_part = 0 if /^$/;

    # save excursion
    $PrevLine = $CurLine;
    $CurLine  = $_;

    # check the current block
    if (/^Content-Type:\s*(.*)/i) { 
	print STDERR "<<< $_ >>>\n";
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

    if (/^From:.*mailer-daemon/i ||
	/^From:.*postmaster/) {
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
		&Debug("$new_block, $gabble> rset \%return_addr\n") if $debug;
		undef %return_addr;
	    }

	    $new_block = 0;
	    $gabbble = 1;

	    &ExtractAddr($_);
	    next;
	}
	# 822 folding
	elsif (/^\s+/ && $gabble) {
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

    #####
    ##### MTA szpecific
    #####
    # exim || qmail
    if ($MTA eq 'exim' || $MTA eq 'qmail') {
	/^\s*(\S+\@\S+):\s*$/ && ($CurAddr = $1);
	$CurAddr =~ s/[\<\>]//g;
	$CurAddr =~ s/\s*//g;
	&Debug("CurAddr => $CurAddr") if $debug && $CurAddr;
    }

    $gabble = 0;

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

    if (/($error_code_pat)/ && $MTA eq 'exim') { 
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
    local($addr) = $ENV{'RECIPIENT'};
    if ($addr =~ /=/) {
	$addr =~ s/\@\S+$//;
	$addr =~ s/=/\@/;
	$addr =~ s/^\S+\-admin\-//; # fml specific 
	&CacheOn($addr, " ");
    }
}

&CacheHints;
&CacheOut;

&DeadOrAlive;

&Report;

exit 0;


sub BareAddr
{
    local($s) = @_;
    $s =~ s/<//g;
    $s =~ s/>//g;
    $s;
}


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


sub AnalWord
{
    local($reason);

    &Debug("AnalWord: @_") if $debug;

    $_ = $_[0];

    if (/user unknown|unknown user|user not known/i) { $reason = 'uu';}
    if (/host unknown|unknown host/i) { $reason = 'uh';}
    if (/service unavailable/i)       { $reason = 'us';}
    if (/address\w+ unknown|unknown address/i) { $reason = 'ua';}

    # qmail
    if (/couldn\'t find any host/) { $reason = 'uh';}
    if (/can\'t accept addresses/) { $reason = 'ua';}

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

	if (/^($error_code_pat)|\D($error_code_pat)\D/) {
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
    return if $Cached{"$addr:$reason"};
    $Cached{"$addr:$reason"} = 1;

    for (keys %return_addr) {
	next if /^\s*$/;
	next if $_ eq $addr;

print STDERR " 
	&AddrCache(time, $addr, $_, $reason);
";

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

    &Debug("AddrCache => $AddrCache{$k}, \"r=$reason\"") if $debug;

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
    local($s);
    &Debug("--- CacheOut") if $debug;

    for (keys %AddrCache) {
	$s = $_.$AddrCache{$_};
	&Append($s, $CACHE);
	&Debug($s) if $debug;
    }
    &Debug("--- CacheOut End.") if $debug;
} 	


sub DoCacheOn
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


sub Die
{
    &GetTime;
    &Append("$Now $_[0]", "$DIR/meadlog");
    exit 0;
}


sub DeadOrAlive
{
    local($buf, $now, $last, $prev);

    $now = time;

    ### check time arrival?

    open(CACHE, $CACHE) || &Die("CacheOn: cannot read CACHE $CACHE\n");
    while (<CACHE>) { 
	$buf = $_ if /^\#check/;
    }
    close(CACHE);

    ($last) = (split(/\s+/, $buf))[1];

    if ($now - $last > $CHECK_INTERVAL) {
	&MLEntryOn($ML_DIR);	# set %ml'ML
	&Debug("check time comes") if $debug;
    }
    else {
	&Debug("check time comes not yet") if $debug;
	return;
    }


    ### check whether a user is dead or alive
    ### expire old entries 
    local($time, $addr, $ml, $expire_range);
    local($new) = "$CACHE.".$$."new";
    local($expire_time) = $now - int($EXPIRE*24*3600);

    &Debug("expire time is " . ($EXPIRE*24*3600)/3600 ." hour(s)") if $debug;

    open(CACHE, $CACHE) || &Die("CacheOn: cannot read CACHE $CACHE\n");
    open(NEW, "> $new") || &Die("CacheOn: cannot open $new\n");
    select(NEW); $| = 1; select(STDOUT);

    while (<CACHE>) {
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

	    print STDERR "$addr : $addr{\"$addr $ml\"}\t" if $debug;
	    $addr{"$addr $ml"} += $PRI{$pri} != 0 ? $PRI{$pri} : $PRI{'default'};
	    print STDERR "=>\t$addr{\"$addr $ml\"} (pri=$pri)\n" if $debug;
	}
    }

    print NEW "#check $now\n";
    close(CACHE);

    rename($new, $CACHE) || &Die("CacheOn: cannot rename $new $CACHE");

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
		&Debug("dead($addr{$_}/$LIMIT):\t$_ <$ml>") if $debug;
		&Action($addr, $ml);
	    }
	    else {
		&Debug("$ml for <$admin> is not found, ignore <$_>") if $debug;
	    }
	}
	# alive
	else {
	    &Debug("alive($addr{$_}/$LIMIT):\t$_") if $debug;
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
	print STDERR "--report MODE=$MODE\n{";
	print STDERR join(" ", %MakeFmlTemplate);
	print STDERR "}\n";
	# print STDERR "HOOK={$MEAD_REPORT_HOOK}\n";
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
	    # $MakeFmlTemplate{$ml} .= "$MAKEFML $KILL $ml $addr\n";
	    for $ml (keys %MakeFmlTemplate) {
		@addr = split(/\s+/, $MakeFmlTemplateAddr{$ml});
		$addr = $addr[0];

		if ($MEAD_REPORT_HOOK) {
		    eval($MEAD_REPORT_HOOK);
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
	}
    }

    ### send reports by mail.

    if ($MODE eq 'auto') {
	$prepend = "Hi, I am fml Mail Error Analyzer Daemon (mead).\n";
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
		$prepend = "Hi, I am fml Mail Error Analyzer Daemon (mead).\n";
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
    $Template{$ml} .= "$buf\n";
}


sub CacheHints
{
    for (reverse split(/\n/, $Received)) {
	print STDERR "RECV>: <$_>\n";

	if (/from\s+([-A-Za-z0-9]+\.[-A-Za-z0-9\.]+)/i) {
	    $Hint{$1} = $1;
	}
	if (/by\s+([-A-Za-z0-9]+\.[-A-Za-z0-9\.]+)/i) {
	    $Hint{$1} = $1;
	}

	if (/for\s+<(\S+\@[A-Za-z0-9\.]+)>/) {
	    print STDERR "--&CacheOn($1, $CurReason);\n";
	    &CacheOn($1, $CurReason);
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
	return $NULL;
    }

    $sendmail = $SENDMAIL || &SearchPath("sendmail") || 
	&SearchPath("qmail-smtpd", "/var/qmail/bin") ||
	    &SearchPath("exim", "/usr/local/exim/bin");

    if (! $sendmail) {
	&Die("cannot find $sendmail");
    }

    open(MAIL, "| $sendmail -t") || &Die("cannot execute $sendmail");
    binmode(MAIL);

    print MAIL "From: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "Reply-To: ". $ml'CA{$ml} . "\n"; #';
    print MAIL "Subject: fml mail error analyzer (mead) report for ML <$ml>\n";
    print MAIL "To: ". $ml'MAA{$ml} . "\n"; #';
    print MAIL "\n";
    print MAIL $buf;

    close(MAIL);
}


# mainly search e.g. "sendmail"
sub SearchPath
{
    local($prog, @path) = @_;
    for ("/usr/sbin", "/usr/lib", @path) {
	if (-e "$_/$prog" && -x "$_/$prog") { return "$_/$prog";}
    }
}


sub Action
{
    local($addr, $ml) = @_;

    ### makefml -> $LogBuf{$ml}
    ### report     $Template{$ml} (command template)
    ###            $MakeFmlTemplate{$ml} (e.g. "makefml bye $ml $addr");

    if ($MODE eq 'auto') {
	&MakeFml("$KILL $ml $addr", $addr, $ml);
    }
    elsif ($MODE eq 'report') {
	$Template{$ml}            .= $CTK{$ml}."admin $KILL $addr\n";
	$MakeFmlTemplate{$ml}     .= "$MAKEFML $KILL $ml $addr\n";
	$MakeFmlTemplateAddr{$ml} .= $addr. "\t";
    }
    else {
	&Debug("mode $MODE is unknown");
    }

    # record the addr irrespective of succeess or fail
    # to avoid a log of warning mails "remove ... but fails" ;-)
    &DoCacheOn("#remove $addr");
}


sub MakeFml
{
    local($buf, $addr, $ml) = @_;
    local($r, $ok, $logbuf);

    $ok = 0;

    $LogBuf{$ml} .= "mead> $KILL $ml $addr\n";
    $MFSummary{$ml} .= "mead> $KILL $ml $addr\n";

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
	print "Mead error: cannot execute makefml [$MAKEFML]\n";
    }
}


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   $year % 100, $mon + 1, $mday, $hour, $min, $sec);
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
    &Getopts("dD:e:S:hC:i:l:M:m:E:p:z:k:f:");
    $opt_h && die(&Usage);
    $debug = $opt_d ? 1 : 0;


    ### at the first stage, evaluate the configuration file ###
    if ($opt_f && -f $opt_f) {
	&EvalCF($opt_f);
    }

    $EXPIRE = $opt_e || $EXPIRE || 14; # days
    $KILL   = $opt_k || $KILL || 'bye';

    # expire check interval
    $CHECK_INTERVAL = $opt_i || $CHECK_INTERVAL || 3*3600;

    $LIMIT  = $opt_l || $LIMIT || 5;

    $DIR    = $opt_D || $DIR ||
	die("Please define -D \$DIR, mead.pl working directory\n");
    $ML_DIR = $opt_S || $ML_DIR ||
	die("Please define -S ML_DIR e.g. -S /var/spool/ml\n");
    $CACHE  = $opt_C || $CACHE || "$DIR/errormaillog";

    # program
    if (! $EXEC_DIR) {
	$EXEC_DIR = $0;
	$EXEC_DIR =~ s#/libexec/mead.pl##;
    }
    $EXEC_DIR = $opt_E || $EXEC_DIR;
    $MAKEFML  = $opt_M || $MAKEFML || "$EXEC_DIR/makefml";

    # mode
    $MODE = $opt_m || $MODE || 'report';

    # MTA
    $SENDMAIL = $opt_z || $SENDMAIL;

    # touch
    &Touch($CACHE);

    # priority; $opt_p
    $PRI{'uu'} = 1;
    $PRI{'default'} = 0.25;
    for (split(/,/, $opt_p . $PRIORITY)) {
	if (/(\S+)=(\S+)/) {
	    $PRI{$1} = $2;
	    &Debug("--- \$PRI{$1} = $2") if $debug;
	}
    }

    # Regular Expression
    $RE_SJIS_C = '[\201-\237\340-\374][\100-\176\200-\374]';
    $RE_SJIS_S = "($RE_SJIS_C)+";
    $RE_EUC_C  = '[\241-\376][\241-\376]';
    $RE_EUC_S  = "($RE_EUC_C)+";
    $RE_JIN    = '\033\$[\@B]';
    $RE_JOUT   = '\033\([BJ]';
}


sub EvalCF
{
    package mead;
    require $main'opt_f; #';
    package main;

    for ("debug", 
	 EXPIRE, KILL, CHECK_INTERVAL, LIMIT, 
	 DIR, ML_DIR, CACHE, EXEC_DIR, MAKEFML, 
	 MODE, SENDMAIL, PRIORITY, MEAD_REPORT_HOOK) {
	eval("\$main'${_} = \$mead'${_};"); 
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

	    $ML{$MAINTAINER} = $ml;
	    $MAA{$ml} = $MAINTAINER; # ML Admin Address
	    $CA{$ml}  = $CONTROL_ADDRESS || $MAINTAINER;
	    $CTK{$ml} = ($CONTROL_ADDRESS eq $MAIL_LIST) ? '# ' : '';
	}

    }
    closedir(DIRD);

    if ($debug_ml) {
	while (($k, $v) = each %ML) { print "$k -> $v\n";}
    }
}

1;
