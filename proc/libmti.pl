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
    local($host, $date, $rdate, $buf);
    local(%uniq);

    ### Extract Header Fields
    $time    = time;
    $date    = &Date2UnixTime($e{'h:date:'});
    $from    = &Conv2mailbox($e{'h:from:'}, *e);
    $rp      = &Conv2mailbox($e{'h:return-path:'}, *e);
    $sender  = &Conv2mailbox($e{'h:sender:'}, *e);
    $xsender = &Conv2mailbox($e{'h:x-sender:'}, *e);

    ## Received:
    if ($e{"sh:received:"}) {
	($host, $rdate) = &ExtractInfoFromReceived($e{"sh:received:"});
    }

    ### OPEN HASH TABLES (SWITCH)
    if ($mode eq 'distribute') {
	$MTI_DB    = $db = $MTI_DIST_DB || "$FP_VARDB_DIR/mti.dist";
	$MTI_HI_DB = $MTI_HI_DIST_DB || "$FP_VARDB_DIR/mti.hi.dist";
    }
    elsif ($mode eq 'command') {
	$MTI_DB    = $db = $MTI_COMMAND_DB || "$FP_VARDB_DIR/mti.command";
	$MTI_HI_DB = $MTI_HI_COMMAND_DB || "$FP_VARDB_DIR/mti.hi.command";
    }
    else {
	&Log("Error: MTICache called under an unknown mode");
	return $NULL;
    }

    &MTIDBMOpen;

    ### CACHE ON
    ### cache on addresses with the current time; also, expire the addresses

    ## cache addresses info
    for ($from, $rp, $sender, $xsender) {
	next unless $_;
	next if $uniq{$_};
	next if $MTI{$_} =~ /${time}:/; # uniq

	&MTICleanUp(*MTI, $_, $time);
	$MTI{$_} .= " $time:$date";
	$uniq{$_} = $_;
    }

    ## cache host info with Date: or Received: 
    # Under the in-coming mail date CORRELATION CHECKS,
    # if a host sent queued mails when UUCP or DIP wakes up,
    # we cannot determine whether he is a real bomber
    # or to be a bomber by a mistake.
    # Here we record time estimated as when the mail left the host.
    if ($host && ($date || $rdate)) {
	&MTICleanUp(*HI, $host, $rdate);
	$HI{$host} .= " ". &ValidateDate($date, $rdate);
    }

    ### CLOSE HASH (save once anyway), AND RE-OPEN
    &MTIDBMClose;
    &MTIDBMOpen;

    ### GARBAGE COLLECTION FROM TIME TO TIME
    # Expire all caches (require to preserve the db size is small.)
    # default is one week
    if ((time % 50) == 25) { # random, about once per 50;
	&MTIGabageCollect(*MTI, $time);
	&MTIGabageCollect(*HI, $time);
    }


    #######################################################
    ### CHECK ROUTINES
    ## BUILT_IN 
    if (($mode eq 'distribute' && $MTI_DISTRIBUTE_TRAFFIC_MAX) || 
	($mode eq 'command' && $MTI_COMMAND_TRAFFIC_MAX)) {
	for ($from, $rp, $sender) {
	    next unless $_;
	    &MTIProbe(*MTI, $_, "${mode}:max_traffic");
	}
    }

    ## SPECULATE BOMBERS
    for (keys %uniq) { &BomberP('addr', $_, $MTI{$_});}
    &BomberP('host', $host, $HI{$host});

    ## EVAL HOOKS
    if ($MTI_CHECK_FUNCTION_HOOK) {
	eval($MTI_CHECK_FUNCTION_HOOK);
	&Log($@) if $@;
    }


    ### CLOSE
    &MTIDBMClose;
}

sub ExtractInfoFromReceived
{
    local($buf) = @_;
    local($host, $rdate);

    $buf =~ s/\n\s/ /g;
    $buf =~ s/\(/ \(/g;

    if ($buf =~ /\@localhost.*by\s+(\S+).*;(.*)/) { 
	$host = $1;
	$rdate = $2;
    }
    elsif ($buf =~ /from\s+(\S+).*;(.*)/) { 
	$host = $1;
	$rdate = $2;
    }
    elsif ($buf =~ /^\s*by\s+(\S+).*;(.*)/) { 
	$host = $1;
	$rdate = $2;
    }
    else {
	&Log("MTI: not match Received: [$buf]");
    }

    # Received: date
    &Log("MTI: Received info: host=$host [$rdate]") if $debug_mti;
    $rdate = &Date2UnixTime($rdate) if $rdate;

    ($host, $rdate);
}

sub ValidateDate
{
    local($date, $rdate) = @_;

    # both errors
    if (!$date && !$rdate) {
	$NULL;
    }
    else {
	$rdate < $date ? $rdate : $date;
    }
}

sub MTIDBMOpen
{
    dbmopen(%MTI, $db, 0600);
    dbmopen(%HI, $MTI_HI_DB, 0600);
}

sub MTIDBMClose
{
    dbmclose(%MTI);
    dbmclose(%HI);
}

sub MTIProbe
{
    local(*MTI, $addr, $mode, $db) = @_;
    local($c, $s, $ss);

    if ($mode eq "distribute:max_traffic") {
	$c = split(/\s+/, $MTI{$addr});	# count irrespective of contents

	if ($c > $MTI_DISTRIBUTE_TRAFFIC_MAX) {
	    $s  = "Distribute traffic ($c mails/$MTI_EXPIRE_UNIT s) ";
	    $s .= "exceeds \$MTI_DISTRIBUTE_TRAFFIC_MAX.";
	    $ss = "Reject post from $From_address for a while.";
	    &Log("MTI: $s");
	    &Log($ss);
	    &Append2($addr, $REJECT_ADDR_LIST) if $MTI_APPEND_TO_REJECT_LIST;
	}
    }
    elsif ($mode eq "command:max_traffic") {
	$c = split(/\s+/, $MTI{$addr});	# count irrespective of contents

	if ($c > $MTI_COMMAND_TRAFFIC_MAX) {
	    $s  = "Command traffic ($c mails/$MTI_EXPIRE_UNIT s) ";
	    $s .= "exceeds \$MTI_COMMAND_TRAFFIC_MAX.";
	    $ss = "Reject command from $From_address for a while.";
	    &Log("MTI: $s");
	    &Log($ss);
	    &Append2($addr, $REJECT_ADDR_LIST) if $MTI_APPEND_TO_REJECT_LIST;
	}
    }

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
	&Warn("MTI Error $ML_FN",
	      "FML Warning:\n$MTIErrorString\n".
	      &WholeMail);
	1;
    }
    else {
	0;
    }
}

sub TrafficInfoEval
{
    $TrafficInfoFP = $TrafficInfoFP || 'TrafficInfoFP';
    1;
}

sub TrafficInfoFP { 30/(30 + $_[0]);}

sub Date2UnixTime
{
    local($in) = @_;
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
	$shift_t =~ s/^0*//; 
	$shift_m =~ s/^0*//;

	$shift = $shift_t + ($shift_m/60);
	$shift = ($pm eq '+' ? -1 : +1) * $shift;

	&timegm($sec,$min,$hour,$day,$month,$year) + $shift*3600;
    }
    else {
	&Log("Error Date2UnixTime: cannot resolve [$in]");
	0;
    }
}


######################################################################
sub BomberP
{
    local($tag, $addr, $buf) = @_;
    local($fp) = $MTI_COST_FUNCTION || 'MTICost';
    local($sum, $limit);

    # BOMBER OR NOT: the limit is 
    # "traffic over sequential 5 mails with 1 mail for each 10s".
    $limit = $MTI_BURST_HARD_LIMIT || (5/10);
    $sum   = &$fp($buf);

    if ($sum > $limit) {
	&Log("MTI::${tag}_cache: [$addr] must be a bomber; ".
	     sprintf("sum=%1.2f > %1.2f", $sum, $limit));

	$MTIErrorString .= "\nFML Mail Traffic Monitor System:\n";
	$MTIErrorString .= "We detect address[$addr] must be a bomber, so\n";
	$MTIErrorString .= "reject mails with address[$addr] in the header.\n";
	$MTIErrorString .= "FYI: evaled as ".
	    sprintf("sum=%1.2f > limit=%1.2f\n", $sum, $limit);
    }

    &Log("MTI::${tag}_cache: [$addr] ".sprintf("sum=%1.2f", $sum));
}


sub MTICost
{
    local($s) = @_;
    local($prev, $sum, $epsilon, $time, $date, $p_date, $cr);
    local($x, $cx);

    # against divergence
    $epsilon = $MTI_EPSILON || 0.1; 

    for (split(/\s+/, $s)) {
	next unless $_;
	($time, $date) = split(/:/, $_);
	if ($prev) { $sum += 1 / &ABS($time - $prev + $epsilon);}

	printf STDERR "=== %d\t%d\t%d\t%d\n",  $time, $prev, $date, $p_date;

	if ($p_date) { 
	    printf STDERR "--- %1.3f\t%1.3f\n", 
	    &ABS($time - $prev + $epsilon),
	    &ABS($date - $p_date + $epsilon);

	    $cr += 1 / &ABS($date - $p_date + $epsilon);

	    $x += 
1 / (&ABS($time - $prev + $epsilon) * &ABS($date - $p_date + $epsilon));

	    $cx += 
(&ABS($time - $prev + $epsilon) * &ABS($date - $p_date + $epsilon));
	}

	$prev   = $time;
	$p_date = $date;
    }

    $sum;

    &Log( sprintf("sum=%1.2f cr=%1.2f", $sum, $cr) ) if $sum && $cr;
    &Log("x=$x") if $x;
    &Log("cx=$cx") if $cx;
}


1;
