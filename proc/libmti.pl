# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#
local($MTI_DB, $MTIErrorString);


# MTI: Mail Traffic Information
sub MTICache
{
    local(*e, $mode) = @_;
    local($time, $from, $rp, $sender, $db, $host);

    $time   = time;
    $from   = &Conv2mailbox($e{'h:from:'}, *e);
    $rp     = &Conv2mailbox($e{'h:return-path:'}, *e);
    $sender = &Conv2mailbox($e{'h:sender:'}, *e);

    $e{"sh:received:"} =~ s/\n\s/ /g;
    if ($e{"sh:received:"} =~ /by\s+(\S+).*;(.*)/) { 
	$host = $1;
	$date = $2;
	&Log("MTI: host=$host [$date]") if $debug_mti;
	$date = &Date2UnixTime($date);
    }

    if ($mode eq 'distribute') {
	$MTI_DB = $db = $MTI_DIST_DB || "$FP_VARDB_DIR/mti.dist";
    }
    elsif ($mode eq 'command') {
	$MTI_DB = $db = $MTI_COMMAND_DB || "$FP_VARDB_DIR/mti.command";
    }
    else {
	&Log("Error: MTICache called under an unknown mode");
	return $NULL;
    }

    ### cache on addresses with the current time
    ### also, expire the addresses
    dbmopen(%MTI, $db, 0600);

    for ($from, $rp, $sender, $host) {
	next unless $_;
	next if $MTI{$_} =~ /$time/; # uniq

	&MTICleanUp(*MTI, $_, $time);
	$MTI{$_} .= " $time";
    }

    dbmclose(%MTI);

    # Expire all caches (require to preserve the db size is small.)
    # default is one week
    if ((time % 50) == 25) { # random, once perl 50;
	dbmopen(%MTI, $db, 0600);
	&MTIGabageCollect(*MTI, $time);
	dbmclose(%MTI);
    }

    ### BUILT_IN CHECK ROUTINES
    if (($mode eq 'distribute' && $MTI_DISTRIBUTE_TRAFFIC_MAX) || 
	($mode eq 'command' && $MTI_COMMAND_TRAFFIC_MAX)) {
	dbmopen(%MTI, $db, 0600);

	for ($from, $rp, $sender) {
	    next unless $_;
	    &MTIProbe(*MTI, $_, "${mode}:max_traffic");
	}

	dbmclose(%MTI);
    }

    ### CHECK FUNCTION HOOK
    if ($MTI_CHECK_FUNCTION_HOOK) {
	dbmopen(%MTI, $db, 0600);
	eval($MTI_CHECK_FUNCTION_HOOK);
	&Log($@) if $@;
	dbmclose(%MTI);
    }
}

sub MTIProbe
{
    local(*MTI, $addr, $mode, $db) = @_;
    local($c, $s, $ss);

    if ($mode eq "distribute:max_traffic") {
	$c = split(/\s+/, $MTI{$addr});

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
	$c = split(/\s+/, $MTI{$addr});

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
    local($mti);

    $MTI_EXPIRE_UNIT = $MTI_EXPIRE_UNIT || 3600;
    
    for (split(/\s+/, $MTI{$addr})) {
	next unless $_;
	next if ($time - $_) > $MTI_EXPIRE_UNIT;
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
	&Mesg(*e, "FML Warning:\n$MTIErrorString");
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


1;
