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
#
local($MTI_DB, $MTIErrorString, %MTI, %HI);


# MTI: Mail Traffic Information
sub MTICache
{
    local(*e, $mode) = @_;
    local($time, $from, $rp, $sender, $db, $xsender);
    local($host, $date, $rdate, $buf, $status);
    local(%hostinfo, %addrinfo);

    ### 2.1B test ###
    $USE_MTI_TEST = 1;
    ### 2.1B test end ###

    ### Extract Header Fields
    $time    = time;
    $date    = &Date2UnixTime($e{'h:date:'});
    $from    = &Conv2mailbox($e{'h:from:'}, *e);
    $rp      = &Conv2mailbox($e{'h:return-path:'}, *e);
    $sender  = &Conv2mailbox($e{'h:sender:'}, *e);
    $xsender = &Conv2mailbox($e{'h:x-sender:'}, *e);

    ## Analizeing Received:
    $status = &MTI'GetHostInfo(*hostinfo, *e); #';
    if ($status) {
	&Log("MTI[$$]: $status"); # Information
    }

    ## additonal checks
    ## 1 check the consistency between Return-Path: and From:
    if ($rp && $From_address && !&AddressMatch($rp, $From_address)) {
	&Log("MTI[$$]: Warning; Return-Path:<$rp> != From:");
    }

    
    &MTIDBMOpen($mode) || return $NULL;

    ### CACHE ON
    ### cache on addresses with the current time; also, expire the addresses
    
    ## cache addresses info
    for ($from, $rp, $sender, $xsender) {
  	next unless $_;
	next if $addrinfo{$_};	# for uniqueness
	next if $MTI{$_} =~ /$time:/; # unique;
    
        &MTICleanUp(*MTI, $_, $time);
	$MTI{$_} .= " $time:$date";
	$addrinfo{$_} = $_;
    }

    ## UNDER CURRENT IMPLEMENTATION, HOST INFO IS JUST ADDITONAL FYI.
    ## cache host info with Date: or Received: 
    if (%hostinfo) {
	local($host, $rdate);
	while (($host, $rdate) = each %hostinfo) {
	    &MTICleanUp(*HI, $host, $rdate);
	    $HI{$host} .= " ${date}:$rdate";
	}
    }

    ### CLOSE HASH (save once anyway), AND RE-OPEN
    &MTIDBMClose;
    &MTIDBMOpen($mode) || return $NULL;


    ### GARBAGE COLLECTION FROM TIME TO TIME
    # Expire all caches (require to preserve the db size is small).
    # default is one week
    if ((time % 50) == 25) { # random, about once per 50;
	&MTIGabageCollect(*MTI, $time);
	&MTIGabageCollect(*HI, $time);
    }


    ### CHECK ROUTINES
    ## average traffic
    if (($mode eq 'distribute' && $MTI_DISTRIBUTE_TRAFFIC_MAX) || 
	($mode eq 'command' && $MTI_COMMAND_TRAFFIC_MAX)) {
	for (keys %addrinfo) {
	    &MTIProbe(*MTI, $_, "${mode}:max_traffic");	# open, close;
	}
    }

    ## speculate intermittent / burst traffic
    &MTIDBMClose;
    &MTIDBMOpen($mode) || return $NULL;

    local($fp) = $MTI_COST_EVAL_FUNCTION || 'MTISimpleBomberP';
    &$fp(*e, *MTI, *HI, *addrinfo, *hostinfo);

    ## EVAL HOOKS
    if ($MTI_COST_EVAL_HOOK) {
	eval($MTI_COST_EVAL_HOOK);
	&Log($@) if $@;
    }


    ### CLOSE
    &MTIDBMClose;
}

sub MTIDBMOpen
{
    local($mode) = @_;
    local($error);

    ### OPEN HASH TABLES (SWITCH)
    if ($mode eq 'distribute') {
	$MTI_DB    = $MTI_DIST_DB    || "$FP_VARDB_DIR/mti.dist";
	$MTI_HI_DB = $MTI_HI_DIST_DB || "$FP_VARDB_DIR/mti.hi.dist";
    }
    elsif ($mode eq 'command') {
	$MTI_DB    = $MTI_COMMAND_DB    || "$FP_VARDB_DIR/mti.command";
	$MTI_HI_DB = $MTI_HI_COMMAND_DB || "$FP_VARDB_DIR/mti.hi.command";
    }
    else {
	&Log("MTI[$$] Error: MTICache called under an unknown mode");
	return $NULL;
    }

    # force the permission
    if ($USE_FML_WITH_FMLSERV) {
	chmod 0660, $MTI_DB, $MTI_HI_DB;
    }
    else {
	chmod 0600, $MTI_DB, $MTI_HI_DB;
    }

    ### DBM OPEN ###
    # perl 5 tie
    if ($MTI_TIE_TYPE) {
	eval "use $MTI_TIE_TYPE;"; 
	&Log($@) if $@;

	local($_) =  q#;
	tie(%MTI, $MTI_TIE_TYPE, $MTI_DB) || 
	    ($error++, &Log("MTI[$$]: cannot tie \%MTI as $MTI_TIE_TYPE"));
	tie(%HI, $MTI_TIE_TYPE, $MTI_HI_DB) || 
	    ($error++, &Log("MTI[$$]: cannot tie \%HI as $MTI_TIE_TYPE"));
	#;

	eval($_);
	&Log($@) if $@;
    }
    # perl 4 (default)
    else {
	if ($USE_FML_WITH_FMLSERV) {
	    dbmopen(%MTI, $MTI_DB, 0660) || 
		($error++, &Log("MTI[$$]: cannot bind \%MTI"));
	    dbmopen(%HI,  $MTI_HI_DB, 0660) || 
		($error++, &Log("MTI[$$]: cannot bind \%HI"));
	}
	else {
	    dbmopen(%MTI, $MTI_DB, 0600) || 
		($error++, &Log("MTI[$$]: cannot bind \%MTI"));
	    dbmopen(%HI,  $MTI_HI_DB, 0600) || 
		($error++, &Log("MTI[$$]: cannot bind \%HI"));
	}
    }

    $error ? 0 : 1;
}


sub MTIDBMClose
{
    dbmclose(%MTI);
    dbmclose(%HI);
}


sub MTIProbe
{
    local(*MTI, $addr, $mode) = @_;
    local(@c, $c, $s, $ss);

    &MTIDBMOpen($mode =~ /^(\w+):/ && $1) || return $NULL;

    if ($mode eq "distribute:max_traffic") {
	# count irrespective of contents
	@c = split(/\s+/, $MTI{$addr});
	$c = $#c + 1;

	if ($c > $MTI_DISTRIBUTE_TRAFFIC_MAX) {
	    $s  = "Distribute traffic ($c mails/$MTI_EXPIRE_UNIT s) ";
	    $s .= "exceeds \$MTI_DISTRIBUTE_TRAFFIC_MAX.";
	    $ss = "Reject post from $From_address for a while.";
	    &Log("MTI[$$]: $s");
	    &Log("MTI[$$]: $ss");
	    &MTIHintOut(*e, $addr) if $MTI_APPEND_TO_REJECT_ADDR_LIST;
	}
    }
    elsif ($mode eq "command:max_traffic") {
	# count irrespective of contents
	@c = split(/\s+/, $MTI{$addr});
	$c = $#c + 1;

	if ($c > $MTI_COMMAND_TRAFFIC_MAX) {
	    $s  = "Command traffic ($c mails/$MTI_EXPIRE_UNIT s) ";
	    $s .= "exceeds \$MTI_COMMAND_TRAFFIC_MAX.";
	    $ss = "Reject command from $From_address for a while.";
	    &Log("MTI[$$]: $s");
	    &Log("MTI[$$]: $ss");
	    &MTIHintOut(*e, $addr) if $MTI_APPEND_TO_REJECT_ADDR_LIST;
	}
    }

    &MTIDBMClose;

    $s ? ($MTIErrorString = "$s\n$ss") : $NULL; # return;
}

sub MTIGabageCollect
{
    local(*MTI, $time) = @_;
    local($k, $v);
    while (($k, $v) = each %MTI) { 
	&MTICleanUp(*MTI, $k, $time);
	undef $MTI{$k} unless $MTI{$k}; 
    }
}

# expire history logs beyond $MTI_EXPIRE_UNIT
sub MTICleanUp
{
    local(*MTI, $addr, $time) = @_;
    local($mti, $t);

    $MTI_EXPIRE_UNIT = $MTI_EXPIRE_UNIT || 3600;
    
    for (split(/\s+/, $MTI{$addr})) {
	next unless $_;
	($t) = (split(/:/, $_))[0];
	next if ($time - $t) > $MTI_EXPIRE_UNIT;
	$mti .= $mti ? " $_" : $_;
    }

    $MTI{$addr} = $mti;
}

sub MTIError
{
    local(*e) = @_;

    if ($MTIErrorString) {
	&MTIWarn(*e, $MTIErrorString);
	1;
    }
    else {
	0;
    }
}

sub MTIWarn
{
    local(*e, $s) = @_;
    local($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	  $atime,$mtime,$ctime,$blksize,$blocks);
    local($cont, $s);

    $MTI_WARN_LOG_FILE = $MTI_WARN_LOG_FILE || "$FP_VARLOG_DIR/mti.lastwarn";
    $MTI_WARN_INTERVAL = $MTI_WARN_INTERVAL || 3600;

    # already exists (some errors occured in the past)
    if (-f $MTI_WARN_LOG_FILE) {
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	 $atime,$mtime,$ctime,$blksize,$blocks)
	    = stat($MTI_WARN_LOG_FILE);

	# ignore until the next waning time.
	if ((time - $mtime) < $MTI_WARN_INTERVAL) { 
	    return 0;
	}
	elsif ((time - $mtime) < 2*$MTI_WARN_INTERVAL) { 
	    $cont = 1;
	    &Append2(time, $MTI_WARN_LOG_FILE);
	}
    }
    # the first time
    else {
	&Append2(time, $MTI_WARN_LOG_FILE);
    }

    $s = "FML Mail Traffic Monitor System:\n\n".
	"I detect a burst traffic (mail bomb?) occurs now.\n";
    if ($cont) {
	$s .= "Fml MTI rejects submission of articles continuously.\n";
    }
    else {
	$s .= "Fml MTI rejects submission of articles hereafter.\n";
    }
    $s .= "The current rejected article:\n\n$MTIErrorString\n".
	&WholeMail;

    &Warn("FML Mail Traffic Monitor System Report $ML_FN", $s);
}

sub Date2UnixTime
{
    local($in) = @_;
    local($input) = $in;
    local($c, $day, $month, $year, $hour, $min, $sec, $pm, $shift_t, $shift_m);
    local(%zone);

    require 'timelocal.pl';

    # Hints
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    $c = 0; for (@Month) { $c++; $Month{$_} = $c;}
    
    # TIME ZONES: RFC822 except for "JST"
    %zone = ("JST", "+0900",
	     "UT",  "+0000",
	     "GMT", "+0000",
	     "EST", "-0500",
	     "EDT", "-0400",
	     "CST", "-0600",
	     "CDT", "-0500",
	     "MST", "-0700",
	     "MDT", "-0600",	     
	     "PST", "-0800",
	     "PDT", "-0700",	     
	     "Z",   "+0000",	     
	     );

    if ($in =~ /([A-Z]+)\s*$/) {
	$zone = $1;
	if ($zone{$zone} ne "") { 
	    $in =~ s/$zone/$zone{$zone}/;
	}
    }

    # RFC822
    # date        =  1*2DIGIT month 2DIGIT        ; day month year
    #                                             ;  e.g. 20 Jun 82
    # date-time   =  [ day "," ] date time        ; dd mm yy
    #                                             ;  hh:mm:ss zzz
    # hour        =  2DIGIT ":" 2DIGIT [":" 2DIGIT]
    # time        =  hour zone                    ; ANSI and Military
    # 
    # RFC1123
    # date = 1*2DIGIT month 2*4DIGIT
    # 
    # 
    # 
    if ($in =~ 
	/(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+([\+\-])(\d\d)(\d\d)/) {
	$day   = $1;
	$month = ($Month{$2} || $month) - 1;
	$year  = $3 > 1900 ? $3 - 1900 : $3;
	$hour  = $4;
	$min   = $5;
	$sec   = $6;	    

	# time zone
	$pm    = $7;
	$shift_t = $8;
	$shift_m = $9;
    }
    elsif ($in =~ 
	/(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+)\s+([\+\-])(\d\d)(\d\d)/) {
	$day   = $1;
	$month = ($Month{$2} || $month) - 1;
	$year  = $3 > 1900 ? $3 - 1900 : $3;
	$hour  = $4;
	$min   = $5;
	$sec   = 0;

	# time zone
	$pm    = $6;
	$shift_t = $7;
	$shift_m = $8;
    }
    # INVALID BUT MANY Only in Japan ???
    elsif ($in =~ /(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d{4})\s*/) {
	$month = ($Month{$1} || $month) - 1;
	$day   = $2;
	$hour  = $3;
	$min   = $4;
	$sec   = $5;
	$year  = $6 > 1900 ? $6 - 1900 : $6;

	# time zone
	$pm    = '+';
	$shift_t = '09';
	$shift_m = '00';	   
    }
    elsif ($in =~ /\;\s*(\d{9,})\s*$/) {
	if (&ABS($1 - time) < 7*24*3600) { 
	    return $1;
	}
	elsif ($debug_mti) {
	    local(@caller) = caller;
	    &Log("MTI[$$]::Date2UnixTime: invalid [$input]");
	    &Log("MIT[$$]: callded from @caller");
	}
    }
    else {
	if ($debug_mti) {
	    local(@caller) = caller;
	    &Log("MTI[$$]::Date2UnixTime: invalid [$input]");
	    &Log("MIT[$$]: callded from @caller");
	}
	return 0;
    }

    # get gmtime
    $shift_t =~ s/^0*//; 
    $shift_m =~ s/^0*//;

    $shift = $shift_t + ($shift_m/60);
    $shift = ($pm eq '+' ? -1 : +1) * $shift;

    &timegm($sec,$min,$hour,$day,$month,$year) + $shift*3600;
}


sub MTILog
{
    local(*e, $s) = @_;
    local($buf, $x, $h);

    $buf .= "We reject the following mail:\n\n";
    for ('return-path', 'date', 'from', 'sender', 'x-sender') {
	$h = $_;
	$h =~ s/^(\w)/ $x = $1, $x =~ tr%a-z%A-Z%, $x/e; # capitlalize
	$h =~ s/(\-\w)/$x = $1, $x =~ tr%a-z%A-Z%, $x/eg; # capitlalize
	$buf .= sprintf("%15s %s\n", "$h:", $e{"h:$_:"}) if $e{"h:$_:"};
    }
    $buf .= "\nsince\n$s\n";

    # IN TEST PHASE, please set $USE_MTI_TEST to reject mails automatically.
    # removed $USE_MTI_TEST in the future;
    $MTIErrorString .= $buf if $USE_MTI_TEST && $s;
}


sub MTIHintOut
{
    local(*e, $addr) = @_;
    local($rp, $hint);

    $hint = $MTI_MAIL_FROM_HINT_LIST || "$DIR/mti_mailfrom.hints";
    &Touch($hint) if ! -f $hint;

    # logs Erturn-Path: (hints for MTA e.g. sendmail)
    if ($e{'h:return-path:'}) {
	$rp = &Conv2mailbox($e{'h:return-path:'});

	if (! &CheckMember($rp, $hint)) {
	    &Append2(&Conv2mailbox($e{'h:return-path:'}, *e), $hint);
	}
    }

    # logs $addr to $DIR/spamlist (FML level)
    if ($addr && $MTI_APPEND_TO_REJECT_ADDR_LIST) {
	&Append2($addr, $REJECT_ADDR_LIST); 
    }
}


######################################################################
package MTI;

sub Log { &main'Log(@_);} #';
sub ABS { $_[0] < 0 ? - $_[0] : $_[0];}

# should we try ?
#    if ($buf =~ /\@localhost.*by\s+(\S+).*;(.*)/) { 
#    elsif ($buf =~ /from\s+(\S+).*;(.*)/) { 
#    elsif ($buf =~ /^\s*by\s+(\S+).*;(.*)/) { 
sub GetHostInfo
{
    local(*hostinfo, *e) = @_;
    local($host, $rdate, $p_rdate, @chain, $threshold);
    local($buf) = "\n$e{'h:received:'}\n";
    local($host_pat) = '[A-Za-z0-9\-]+\.[A-Za-z0-9\-\.]+';

    # We trace Received: chain to detect network error (may be UUCP?)
    # where the threshold is 15 min.
    # NOT USED NOW
    $threshold = $main'MTI_CACHE_HI_THRESHOLD || 15*60; #'; 15 min.

    for (split(/\n\w+:/, $buf)) {
	undef $host; undef $rdate;
	
	s/\n/ /g;
	s/\(/ \(/g;
	s/by\s+($host_pat).*(\;.*)/$host = $1, $rdate = $2/e;

	if ($rdate) {
	    $rdate = &main'Date2UnixTime($rdate); #';
	    $rdate || next;	# skip if invalid Date:
	    $hostinfo{$host} = $rdate;

	    push(@chain, &ABS($rdate - $p_rdate)) if $p_rdate;
	    $p_rdate = $rdate;
	}
    }

    for (@chain) {
	if ($_ > $threshold) {
	    return "network error? @chain";
	}
    }

    $NULL;
}


sub main'MTISimpleBomberP #';
{
    local(*e, *MTI, *HI, *addrinfo, *hostinfo) = @_;
    local($sum, $soft_limit, $hard_limit, $es, $addr);
    local($cr, $scr);

    # BOMBER OR NOT: the limit is 
    # "traffic over sequential 5 mails with 1 mail for each 5s".
    $soft_limit = $main'MTI_BURST_SOFT_LIMIT || (5/5);   #';
    $hard_limit = $main'MTI_BURST_HARD_LIMIT || (2*5/5); #';

    # GLOBAL in this Name Space; against divergence
    $Threshold = $main'MTI_BURST_MINIMUM || 3; #': 

    # addresses
    for $addr (keys %addrinfo) {
	($cr, $scr)  = &SumUp($MTI{$addr});	# CorRelation 

	if (($cr > 0) && $main'debug_mti) { #';
	    &Log("MTI[$$]: SumUp ". 
		 sprintf("src_cr=%2.4f dst_cr=%2.4f", $scr, $cr));
	}

	# soft limit: scr > cr : busrt in src host not dst host
	# hard limit: cf > hard_limit or scr > hard_limit
	if ((&MTI_GE($scr, $cr) && ($scr > $soft_limit)) ||
	    ($scr > $hard_limit) || 
	    ($cr  > $hard_limit)) {
	    &Log("MTI[$$]: <$addr> must be a bomber;");
	    &Log("MTI[$$]:".
		 sprintf("src_cr=%2.4f >= dst_cr=%2.4f", $scr, $cr));
	    $es .= "   MTI[$$]: <$addr> must be a bomber,\n";
	    $es .= "   since the evaled costs are ".
		sprintf("src_cr=%2.4f >= dst_cr=%2.4f\n", $scr, $cr);
	    &main'MTIHintOut(*e); #';
	}
    }

    &main'MTILog(*e, $es) if $es; #';
}


sub MTI_GE
{
    if ($_[0] >= $_[1]) { 
	return 1;
    }
    # within 3 %
    elsif (&ABS($_[0] - $_[1]) < $MTI_BURST_SOFT_LIMIT * 0.03) {
	return 1;
    }

    0;
}

sub COST 
{
    &ABS($_[0]) < $Threshold ? $Threshold : &ABS($_[0]);
}


sub SumUp
{
    local($buf) = @_;
    local($cr, $d_cr, $time, $date, $p_time, $p_date);

    # reset
    $cr = $d_cr = 0;

    for (split(/\s+/, $buf)) {
	next unless $_;
	($time, $date) = split(/:/, $_);

	if ($p_time) { # $p_date may be invalid, so not check it.
	    $cr   += 1 / &COST($time - $p_time);
	    $d_cr += 1 / &COST($date - $p_date);
	}

	# cache on previous values
	($p_time, $p_date) = ($time, $date);
    }

    ($cr, $d_cr);
}


1;
