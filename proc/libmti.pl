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
    local($time, $from, $rp, $sender, $db);

    $time   = time;
    $from   = &Conv2mailbox($e{'h:from:'}, *e);
    $rp     = &Conv2mailbox($e{'h:return-path:'}, *e);
    $sender = &Conv2mailbox($e{'h:sender:'}, *e);

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

    for ($from, $rp, $sender) {
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


1;
