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
# $Id$

&Init;

# switch
if ($CONFIRMD_ACK_EXPIRE_UNIT !~ /^\d+$/) {
    print "Error: confirmd invalid expire unit, exit\n";
}
elsif (-f "$DIR/config.ph") {
    &ConfirmRequest(*e, *first_time, *mqueue, $CONFIRMD_ACK_EXPIRE_UNIT);

    # critical region
    &Lock;

    &CleanUpAckLog(*e, *first_time, *mqueue, *remove_addr, $CONFIRMD_ACK_EXPIRE_UNIT);
    &RemoveMembers(*e, *mqueue, *remove_addr);

    &Unlock;
    # critical region ends
}
else {
    print "Error: confirmd cannot find \$DIR/config.ph, exit\n";
}

exit 0;


### Libraries


sub Init
{
    require 'getopts.pl';
    &Getopts("du:w:");

    # varialbes: argv[1] must be $DIR.
    $DIR  = shift @ARGV;

    # fix include path
    local($libdir) = $0;
    $libdir =~ s#/libexec/confirmd.pl##;
    push(@INC, $libdir); push(@LIBDIR, $libdir);
    push(@INC, $DIR); push(@LIBDIR, $DIR);
    push(@INC, @ARGV); push(@LIBDIR, @ARGV);

    # initialize
    require 'libsmtp.pl';
    require 'libkern.pl';

    # chdir (required here before &InitConfig)
    chdir $DIR || die "Can't chdir to $DIR\n";

    &InitConfig;

    # I am
    $From_address = 'confirmd';
    $debug = $opt_d;

    $CONFIRMD_ACK_EXPIRE_UNIT = 
	&UnitCanonicalize($opt_u || $CONFIRMD_ACK_EXPIRE_UNIT || "2months");

    $CONFIRMD_ACK_WAIT_UNIT = 
	&UnitCanonicalize($opt_w || $CONFIRMD_ACK_WAIT_UNIT || "2weeks");
    
    # acknowledge of continue
    $CONFIRMD_ACK_LOGFILE = 
	$CONFIRMD_ACK_LOGFILE || "$DIR/var/log/confirmd.ack";
    &Touch($CONFIRMD_ACK_LOGFILE) if ! -f $CONFIRMD_ACK_LOGFILE;


    if ($USE_DATABASE) {
        &use('databases');

        # dump recipients
	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, 'dump_member_list');
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc);
	&Log("fail to dump active list") if $mib{'error'};
	exit 1 if $mib{'error'};
    }
}


sub UnitCanonicalize
{
    local($_) = @_;

    # seconds (direct representation)
    if (/^(\d+)$/) {
	$1;
    }
    elsif (/^(\d+)(month|months)$/) {
	$1 * (30 * 24 * 3600);
    }
    elsif (/^(\d+)(week|weeks)$/) {
	$1 * (7 * 24 * 3600);
    }
    elsif (/^(\d+)(day|days)$/) {
	$1 * (24 * 3600);
    }
    else {
	&Log("invalid expire unit [$_]");
    }
}


sub ConfirmRequest
{
    local(*e, *first_time, *mqueue, $expire_unit) = @_;
    local(%uniq, $list);

    # debug
    if ($debug) { require 'libdebug.pl';}

    &GetAckLog(*ack, *ack_req);

    # scan member list
    for $list (@MEMBER_LIST, $MEMBER_LIST) {
	# touch
	&Touch($list) if ! -f $list;

	# unique
	next if $uniq{$list}; $uniq{$list} = $list;

	# scan member list and compare ack time and now
	&Scan(*mqueue, *ack, *ack_req, *first_time, $expire_unit, $list);
    }

    # address
    if (%mqueue) {
	&Query(*mqueue);
    }
    else {
	&Log("no address to query") if $debug_confirmd;
    }
} 


sub GetAckLog
{
    local(*ack, *ack_req) = @_;
    local($addr, $last_ack, $send_ack_req);

    if (! open(ACK, $CONFIRMD_ACK_LOGFILE)) {
	&Log("cannot open confirmd ack log [$CONFIRMD_ACK_LOGFILE]");
	return $NULL;
    }

    while (<ACK>) {
	next if /^\#/;
	next if /^\s*$/;

	($addr, $last_ack, $send_ack_req) = split(/\s+/, $_);
	$ack{$addr}     = $last_ack;
	$ack_req{$addr} = $send_ack_req;
    }
    close(ACK);
}


sub Scan
{
    local(*mqueue, *ack, *ack_req, *first_time, $expire_unit, $list) = @_;
    local($now) = time;

    if (! open(LIST, $list)) {
	&Log("cannot open member list [$list]");
    }

    while (<LIST>) {
	next if /^#\.FML/o .. /^\#\.endFML/o;
	next if /^\#\#/;
	next if /^\s*$/;

	# get and set $_ as an address part
	/^\#\s*(.*)/ && ($_ = $1);
	/^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

	# cache for unique
	next if $mqueue{$_};
	next if $first_time{$_};

	# not first time
	if ($ack{$_}) {
	    # we query whether you continues to be in this list or not?

	    # query and wait for reply
	    if ($ack{$_} < $ack_req{$_}) {
		&Log("wait for reply from [$_]") if $debug_confirmd;
		next;
	    }
	    else { ;}

	    &Debug(sprintf("%-30s   %10d > %-10d", 
			   $_, $now - $ack{$_}, $expire_unit)) if $debug;

	    # the previous ack is expired
	    if ($now > $ack{$_} + $expire_unit) {
		### add it to the address list to send ###
		$mqueue{$_} = $_;
	    }
	    else {
		; # O.K. under acknowledge
	    }
	}
	# Suppose he/she is "ack"ed state when the first time.
	# When the first time, just "entry in ack.log", "not send ack request".
	else {
	    $first_time{$_} = $_;
	}
    }
    close(LIST);
}


sub Query
{
    local(*mqueue) = @_;
    local($subject, $to, $arg0, $req_file, $draft);

    $subject  = "confirmation request $ML_FN";
    $req_file = ($CONFIRMD_ACK_REQ_FILE || "$DIR/confirmd.ackreq");    

    if (!-f $req_file) {
	$draft = $req_file; $draft =~ s#^.*/##;
	for (@LIBDIR) { 
	    # print STDERR "try -f $_/$draft\n" if $debug_confirmd;
	    $req_file = "$_/drafts/$draft" if -f "$_/drafts/$draft";
	    if (-f $req_file) {
		&Log("$req_file found") if $debug_confirmd;
	    }
	}
    }

    # unit
    $arg0 = $CONFIRMD_ACK_WAIT_UNIT;
    if ($LANGUAGE eq 'Japanese') {
	$arg0 = &Japanize($arg0);
    }
    else {
	$arg0 =~ s/^(\d+)(\S+)/$1 $2/;
    }

    # substitute
    $Envelope{'mode:doc:repl'} = 1;
    $Envelope{'CtlAddr:'}      = &CtlAddr;
    $Envelope{'doc:repl:arg0'} = $arg0;

    &DEFINE_FIELD_OF_REPORT_MAIL('Reply-To', &CtlAddr);

    for (keys %mqueue) {
	next unless $mqueue{$_};
	&Log("send ack request to [$_]");
	&SendFile($_, $subject, $req_file);
    }
}


### Section: Clean up
sub CleanUpAckLog
{
    local(*e, *first_time, *mqueue, *remove_addr, $expire_unit) = @_;
    local($too_old, $now, $new, $bak);
    local($last_ack, $send_ack_req);

    ## TIME
    # threshold: 2month(expired) + 2 weeks(ack wait)
    $now     = time;
    $too_old = $expire_unit + &UnitCanonicalize($CONFIRMD_ACK_WAIT_UNIT);

    if ($too_old !~ /^\d+$/) {
	&Log("CleanUpAckLog: invalid threshold [$CONFIRMD_ACK_EXPIRE_UNIT + $CONFIRMD_ACK_WAIT_UNIT], stop");
	return $NULL;
    }

    ## FILES
    $bak = "$CONFIRMD_ACK_LOGFILE.bak";
    $new = "$CONFIRMD_ACK_LOGFILE.new";

    ## IO
    if (! open(ACK, $CONFIRMD_ACK_LOGFILE)) {
	&Log("cannot open confirmd ack log [$bak]");
	return $NULL;
    }
    if (! open(NEW, "> $new")) {
	select(NEW); $| = 1; select(STDOUT);
	&Log("cannot open new confirmd ack log [$new]");
	return $NULL;
    }

    ## HERE WE GO 
    while (<ACK>) {
	$line = $_;
	next if /^\#/;
	next if /^\s*$/;

	($addr, $last_ack, $send_ack_req) = split(/\s+/, $_);

	# for overwrite
	if ($remove_addr{$addr}) {
	    &Log("remove remove_queue [$addr]") if $debug_confirmd;
	    undef $remove_addr{$addr};
	}

	# set addresses to remove; The threshold is after 
	# "$CONFIRMD_ACK_EXPIRE_UNIT + $CONFIRMD_ACK_WAIT_UNIT";
	if ($now - $last_ack > $too_old) {
	    if (&MailListMemberP($addr)) {
		&Log("add_remove_queue [$addr]") if $debug_confirmd;
		$remove_addr{$addr} = $addr;
	    }
	}

	# remove entries from $CONFIRMD_ACK_LOGFILE if the ack is too old.
	# The threshold is 2 times threshold of %remove_addr.
	# Operspec is for safety.
	if ($now - $last_ack > 2*$too_old) {
	    &Log("acklog::remove [$addr]") if $debug_confirmd;
	    next;
	}
	else {
	    # sent this time
	    if ($mqueue{$addr}) {
		printf NEW "%-30s   %-10d   %-10d\n", $addr, $last_ack, $now;
	    }
	    else {
		print NEW $line;
	    }
	}
    }

    # logs first time enties
    for (keys %first_time) {
	next unless $first_time{$_};
	&Log("acklog::add [$_]");
	printf NEW "%-30s   %-10d   %-10d\n", $_, $now if $_;
    }

    close(NEW);
    close(ACK);

    # turn over;
    if (! rename($CONFIRMD_ACK_LOGFILE, $bak)) {
	&Log("cannot rename $CONFIRMD_ACK_LOGFILE -> $bak");
	return $NULL;
    }

    if (! rename($new, $CONFIRMD_ACK_LOGFILE)) {
	&Log("cannot rename $new -> $CONFIRMD_ACK_LOGFILE");
	return $NULL;
    }

    &use('newsyslog');
    &NewSyslog($bak);
}


sub RemoveMembers
{
    local(*e, *mqueue, *remove_addr) = @_;

    &use('amctl');

    # administration mode
    $e{'mode:admin'} = 1;
    $_PCB{'mode:addr:multiple'} = 1;

    for (keys %remove_addr) {
	next unless $remove_addr{$_};
	next unless &MailListMemberP($_);
	&Log("member::remove $_");
	$Fld[2] = $_;
	&SaveACL;
	&DoSetMemberList('BYE', *Fld, *e, *misc);
	&RetACL;
    }
    
    $e{'mode:admin'} = 0;
}


sub Japanize
{
    local($_) = @_;
    local($s);

    if (/^(\d+)$/) {
	$s = "${1}ÉÃ";
    }
    elsif (/^(\d+)(month|months)$/) {
	$s = "${1}¤«·î";
    }
    elsif (/^(\d+)(week|weeks)$/) {
	$s = "${1}½µ´Ö";
    }
    elsif (/^(\d+)(day|days)$/) {
	$s = "${1}Æü";
    }
    else {
	&Log("invalid expire unit [$_]");
    }

    &JSTR($s);
}


1;
