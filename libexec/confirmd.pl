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
if ($CONFIRMD_EXPIRE_UNIT !~ /^\d+$/) {
    print "Error: confirmd invalid expire unit, exit\n";
}
elsif (-f "$DIR/config.ph") {
    &ConfirmRequest($CONFIRMD_EXPIRE_UNIT);
}
else {
    print "Error: confirmd cannot find \$DIR/config.ph, exit\n";
}

exit 0;


### Libraries


sub Init
{
    require 'getopts.pl';
    &Getopts("du:");

    # varialbes: argv[1] must be $DIR.
    $DIR  = shift @ARGV;
    $IAM  = $DIR;
    $IAM  =~ s#./(\S+)#$1#;

    # fix include path
    local($libdir) = $0;
    $libdir =~ s#/libexec/confirmd.pl##;
    push(@INC, $libdir);
    push(@INC, $DIR);
    push(@INC, @ARGV);

    # initialize
    require 'libsmtp.pl';
    require 'libkern.pl';
    &InitConfig;

    # I am
    $From_address = 'confirmd';
    $debug = $opt_d;

    $CONFIRMD_EXPIRE_UNIT = 
	&UnitCanonicalize($opt_u || $CONFIRMD_EXPIRE_UNIT || "1month");

    # acknowledge of continue
    $CONFIRMD_ACK_LOGFILE = 
	$CONFIRMD_ACK_LOGFILE || "$DIR/var/log/confirmd.ack";
    &Touch($CONFIRMD_ACK_LOGFILE) if ! -f $CONFIRMD_ACK_LOGFILE;
}


sub UnitCanonicalize
{
    local($_) = @_;

    if (/^(\d+)(month|months)$/) {
	$1 * (30 * 24 * 3600);
    }
    elsif (/^(\d+)(week|weeks)$/) {
	$1 * (7 * 24 * 3600);
    }
    elsif (/^(\d+)(day|days)$/) {
	$1 * (24 * 3600);
    }
    else {
	&Log("invalid expire unit");
    }
}


sub ConfirmRequest
{
    local($expire_unit) = @_;
    local(%uniq, $list, $addr);

    # debug
    if ($debug) { require 'libdebug.pl';}

    &GetAckLog(*ack);

    # scan member list
    for $list (@MEMBER_LIST, $MEMBER_LIST) {
	# touch
	&Touch($list) if ! -f $list;

	# unique
	next if $uniq{$list}; $uniq{$list} = $list;

	# scan member list and compare ack time and now
	&Scan(*addr, *ack, $expire_unit, $list);
    }

    # address
    if (%addr) {
	&Query(*addr);
    }
    else {
	&Log("no address to query");
    }
} 


sub GetAckLog
{
    local(*ack) = @_;
    local($addr, $time);

    if (! open(ACK, $CONFIRMD_ACK_LOGFILE)) {
	&Log("cannot open confirmd ack log [$CONFIRMD_ACK_LOGFILE]");
	return $NULL;
    }

    while (<ACK>) {
	next if /^\#/;
	next if /^\s*$/;

	($addr, $time) = split(/\s+/, $_);
	$ack{$addr} = $time;
    }
    close(ACK);
}


sub Scan
{
    local(*addr, *ack, $expire_unit, $list) = @_;
    local($time) = time;

    if (! open(LIST, $list)) {
	&Log("cannot open member list [$list]");
    }

    while (<LIST>) {
	next if /^\#\#/;
	next if /^\s*$/;

	# get and set $_ as an address part
	/^\#\s*(.*)/ && ($_ = $1);
	/^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

	# If latest ack is enough old, 
	# we query whether you continues to be in this list or not?
	# 
	if ($ack{$_}) {
	    # the previous ack is expired
	    if ($time - $ack{$_} > $expire_unit) {
		&Log("[".($time - $ack{$_})." > $expire_unit] sent to $_") if $debug;
		$addr{$_} = $_;
	    }
	    else {
		; # O.K. under acknowledge
	    }
	}
	# the first time
	else {
	    $addr{$_} = $_;
	}
    }
    close(LIST);
}


sub Query
{
    local(*addr) = @_;
    local($subject, $to, @to, $n);

    print STDERR "confirmd::Query($addr)\n" if $debug;

    @to      = keys %addr;
    $subject = "confirmation request $ML_FN";
    @files   = ($CONFIRMD_ACK_REQ_FILE || "$DIR/confirmd.ackreq");    
    $n       = $#to + 1;

    # substitute
    $Envelope{'mode:doc:repl'} = 1;
    $Envelope{'CtlAddr:'}      = &CtlAddr;

    &Log("send ack request to $n address".($n > 1 ? "es": ""));
    &DEFINE_FIELD_OF_REPORT_MAIL('Reply-To', $CONTROL_ADDRESS);
    &NeonSendFile(*to, *subject, *files);
}


### Section: fundamental
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
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}

### Section: IO
sub Log 
{ 
    local($str, $s) = @_;
    local($package, $filename, $line) = caller; # called from where?
    local($from) = $PeerAddr ? "$From_address[$PeerAddr]" : $From_address;
    local($error);

    &GetTime;

    $str =~ s/\015\012$//; # FIX for SMTP (cut \015(^M));

    if ($debug_smtp && ($str =~ /^5\d\d\s/)) {
	$error .= "Sendmail Error:\n";
	$error .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }

    $str = "$filename:$line% $str" if $debug_caller;

    # existence and append(open system call check)
    if (-f $LOGFILE && open(APP, ">> $LOGFILE")) {
	&Append2("$Now $str ($from)", $LOGFILE);
	&Append2("$Now    $filename:$line% $s", $LOGFILE) if $s;
    }
    else {
	print STDERR "$Now ($package, $filename, $line) $LOGFILE\n";
	print STDERR "$Now $str ($from)\n\t$s\n";
    }

    $Envelope{'error'} .= $error if $error;

    print STDERR "*** $str; $s;\n" if $debug;
}

# append $s >> $file
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2 
{ 
    &Write2(@_, 1) || do {
	local(@caller) = caller;
	print STDERR "Append2(@_)::Error caller=<@caller>\n";
    };
}

sub Write2
{
    local($s, $f, $o_append) = @_;

    if ($o_append && $s && open(APP, ">> $f")) { 
	select(APP); $| = 1; select(STDOUT);
	print APP "$s\n";
	close(APP);
    }
    elsif ($s && open(APP, "> $f")) { 
	select(APP); $| = 1; select(STDOUT);
	print APP "$s\n";
	close(APP);
    }
    else {
	local(@caller) = caller;
	print STDERR "Write2(@_)::Error caller=<@caller>\n";
	return 0;
    }

    1;
}

sub Touch  { open(APP, ">>$_[0]"); close(APP); chown $<, $GID, $_[0] if $GID;}

sub Debug { print STDERR @_;}

1;
