# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


##### local scope in Calss:Smtp #####
local($SmtpTime, $FixTransparency, $LastSmtpIOString, $CurModulus, $Port);
local($SoErrBuf, $RetVal);

# sys/socket.ph is O.K.?
sub SmtpInit
{
    local(*e, *smtp) = @_;

    # IF NOT SPECIFIED, [IPC]
    $e{'mci:mailer'} = $e{'mci:mailer'} || 'ipc';
    $e{'macro:s'}    = $e{'macro:s'}    || $FQDN;

    # Pipelining waiting receive queue length
    $PipeLineMaxRcvQueue = 100;

    # Set Defaults (must be "in $DIR" NOW)
    $SmtpTime  = time() if $TRACE_SMTP_DELAY;

    # LOG: on IPC and "Recovery for the universal use"
    if ($NOT_TRACE_SMTP || (!$VAR_DIR) || (!$VARLOG_DIR)) {
	$SMTP_LOG = '/dev/null';
    }
    else {
	(-d $VAR_DIR)    || &Mkdir($VAR_DIR);
	(-d $VARLOG_DIR) || &Mkdir($VARLOG_DIR);
	$SMTP_LOG = $SMTP_LOG || "$VARLOG_DIR/_smtplog";
    }

    ### FIX: . -> .. 
    ### rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
    if (! $FixTransparency) {
	$FixTransparency = 1;	# Fixing is done once!

	undef $e{'preamble'} if $e{'mode:dist'};
	undef $e{'trailer'}  if $e{'mode:dist'};

	if ($e{'preamble'}) { 
	    $e{'preamble'} =~ s/\n\./\n../g; $e{'preamble'} =~ s/\.\.$/./g;
	}

	if ($e{'trailer'})  { 
	    $e{'trailer'} =~ s/\n\./\n../g;  $e{'trailer'} =~ s/\.\.$/./g;
	}
    }

    return 1 if $SocketOK;
    return ($SocketOK = &SocketInit);
}


sub SocketInit
{
    local($eval, $exist_socket_ph);

    ### XXX: Set up @RcptLists ###
    @RcptLists = @ACTIVE_LIST;
    push(@RcptLists, $ACTIVE_LIST) 
	unless grep(/$ACTIVE_LIST/, @RcptLists);

    # SMTP HACK
    if ($USE_OUTGOING_ADDRESS) { 
	require 'libsmtphack.pl'; &SmtpHackInit;
    }

    for (@INC) { if (-r "$_/sys/socket.ph") { $ExistSocketPH = 1;}}

    $STRUCT_SOCKADDR = $STRUCT_SOCKADDR || 'n n a4 x8';

    ### PERL 5  
    if ($] =~ /^5\./) {
	eval("use Socket;");
	if ($@ eq '') {
	    &Log("Set Perl 5::Socket O.K.") if $debug;
	    return 1;
	}
    }

    ### PERL 4
    if ($ExistSocketPH) {
	eval("require 'sys/socket.ph';");
	$exist_socket_ph = $@ eq '' ? 1 : 0;
	&Log("\"eval sys/socket.ph\" O.K.") if $exist_socket_ph && $debug;
	return 1 if $exist_socket_ph; 
    }

    # COMPAT_SOLARIS2 is for backward compatibility.
    if ((! $exist_socket_ph) && 
	($COMPAT_SOLARIS2 || $CPU_TYPE_MANUFACTURER_OS =~ /solaris2|sysv4/i)) {
	eval "sub AF_INET {2;}; sub PF_INET { 2;};";
	eval "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&Log("Set socket [Solaris2]") if $debug;
    }
    elsif (! $exist_socket_ph) { # 4.4BSD (and 4.x BSD's)
	eval "sub AF_INET {2;}; sub PF_INET { 2;};";
	eval "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&Log("Set socket [4.4BSD]") if $debug;
    }

    1;
}


# Connect $host to SOCKET "S"
# RETURN *error
sub SmtpConnect
{
    local(*host, *error) = @_;

    local($pat)    = $STRUCT_SOCKADDR;
    local($addrs)  = (gethostbyname($host = $host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = $Port || $PORT || (getservbyname('smtp', 'tcp'))[2];
    $port          = 25 unless defined($port); # default port

    # Check the possibilities of Errors
    return ($error = "Cannot resolve the IP address[$host]") unless $addrs;
    return ($error = "Cannot resolve proto")                 unless $proto;

    # O.K. pack parameters to a struct;
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC open
    if (socket(S, &PF_INET, &SOCK_STREAM, $proto)) { 
	print SMTPLOG "socket ok\n";
    } 
    else { 
	return ($error = "SmtpConnect: socket() error [$!]");
    }
    
    if (connect(S, $target)) { 
	print SMTPLOG "connect ok\n"; 
    } 
    else { 
	return ($error = "SmtpConnect: connect($host/$port) error[$!]");
    }

    ### need flush of sockect <S>;
    select(S); $| = 1; select(STDOUT);

    $error = "";
}


# delete logging errlog file and return error strings.
sub Smtp 
{
    local(*e, *rcpt, *files) = @_;
    local(@smtp, $error, %cache, $nh, $nm, $i);

    ### Initialize, e.g. use Socket, sys/socket.ph ...
    &SmtpInit(*e, *smtp);
    
    ### open LOG;
    open(SMTPLOG, "> $SMTP_LOG") || (return "Cannot open $SMTP_LOG");
    select(SMTPLOG); $| = 1; select(STDOUT);

    # primary, secondary -> @HOSTS (ATTENTION! THE PLURAL NAME)
    push(@HOSTS, @HOST); # the name of the variable should be plural
    unshift(@HOSTS, $HOST);

    ### cache Message-Id:
    if ($e{'h:Message-Id:'} || $e{'GH:Message-Id:'}) {
	&CacheMessageId(*e, $e{'h:Message-Id:'} || $e{'GH:Message-Id:'});
    }

    # when @rcpt is non-zero, !mode:DirectListAcess
    if ($MCI_SMTP_HOSTS > 1) {
	require 'libsmtpmci.pl';
	if ($error = &SmtpMCIDeliver(*e, *rcpt, *smtp, *files)) {
	    return $error;
	}
    }
    else { # not use pararell hosts to deliver;
	$error = &SmtpIO(*e, *rcpt, *smtp, *files);
	return $error if $error;
    }

    ### SMTP CLOSE
    close(SMTPLOG);
    0; # return status BAD FREE();
}

# 
# SMTP chat with given channel <S>; from HELO to QUIT
#
# Deliver using one of $HOSTS or prog mailer
# This routine ignore the contents of a set of recipients,
# which is controlled by the parent routine calling this routine.
# In default, no control. In MCI_SMTP_HOSTS > 1, $CurModulus controlls 
# the set of recipients (SmtpIO not concern this set).
#
# FYI: programs which accpets SMTP from stdio.
#   sendmail: /usr/sbin/sendmail -bs
#   qmail: /var/qmail/bin/qmail-smtpd (-bs?)
#   exim: /usr/local/exim/bin/exim -bs
#
# FYI2:
#   Already given $CurModulus by SmtpDLAMCIDeliver
#     SmtpDLAMCIDeliver 
#        for (@HOSTS) { 
#             set $CurModulus (global variable)
#             => SmtpIO
#             <=
#        }
#
sub SmtpIO
{
    local(*e, *rcpt, *smtp, *files) = @_;
    local($sendmail);
    local($host, $error, $in_rcpt, $ipc, $try_prog, $retry, $backoff);

    if ($USE_SMTP_PROFILE) { $SmtpIOStart = time;}

    ### set global variable
    $SmtpFeedMode  = 0; # reset;
    $SocketTimeOut = 0; # against the call of &SocketTimeOut;
    # &SetEvent($TimeOut{'socket'} || 1800, 'SocketTimeOut') if $HAS_ALARM;

    # delay of retry 
    $backoff = 2;

    ### IPC 
    if ($e{'mci:mailer'} eq 'smtpfeed' || $HOSTS[0] =~ /(\S+):\#smtpfeed/) {
	# calling smtpfeed in the last
	require 'liblmtp.pl';
	&SetupSmtpFeed;
	$SmtpFeedMode = 1;
	$ipc = 0;	
    }
    elsif ($e{'mci:mailer'} eq 'ipc' || $e{'mci:mailer'} eq 'smtp') {
	$ipc = 1;		# define [ipc]

	# (PROBE AND) MAKE A CONNECTTION;
	# primary, secondary, ...;already unshift(@HOSTS, $HOST);
	for ($host = shift @HOSTS; scalar(@HOSTS) >= 0; $host = shift @HOSTS) {
	    undef $Port; # reset

	    if ($host =~ /(\S+):\#smtpfeed/) { # anyway skip here
		next;
	    }
	    elsif ($host =~ /(\S+):(\d+)/) {
		$host = $1;
		$Port = $2 || $PORT || 25;
	    }
	    else {
		$Port = $PORT || 25;
	    }

	    print STDERR "---SmtpIO::try smtp->host($host:$Port)\n"
		if $debug_smtp;

	    undef $error;
	    &SmtpConnect(*host, *error);  # if host is null, localhost
	    print STDERR "$error\n" if $error;

	    if ($error) {
		&Log($error); # error log BAD FREE();

		# but maximum is 30 sec.
		$backoff = 2 * $backoff;
		$backoff = $backoff > 30 ? 30 : $backoff;
		&Log("fml[$$] retry after $backoff sec.");
		$retry = 1; 
	    }
	    else { # O.K.
		&Log("fml[$$] send after $backoff sec.") if $retry;
		last;
	    }

	    sleep($backoff);              # sleep and try the secondaries

	    last         unless @HOSTS;	  # trial ends if no candidate
	}
    }

    ### not IPC, try popen(sendmail) ... OR WHEN ALL CONNEVTION FAIL;
    ### Only on UNIX
    if ($e{'mci:mailer'} eq 'prog' || $error) {
	$host = '';
	&Log("Try mci:prog since smtp connections cannot be opened") if $error;

	if ($UNISTD) {
	    $sendmail = $SENDMAIL || &SearchPath("sendmail") || 
		&SearchPath("qmail-smtpd", "/var/qmail/bin") ||
		    &SearchPath("exim", "/usr/local/exim/bin");
	    # fix argv options
	    if ($sendmail !~ /\-bs/) { $sendmail .= " -bs ";}

	    require 'open2.pl';
	    if (&open2(RS, S, $sendmail)) { 
		&Log("open2(RS, S, $sendmail)") if $debug;
	    }
	    else {
		&Log("SmtpIO: cannot exec $sendmail");
		return "SmtpIO: cannot exec $sendmail";
	    };

	    $ipc = 0;
	}
	else {
	    &Log("delivery fails since cannot open prog mailer");
	    return 0;
	}
    }

    if ($USE_SMTP_PROFILE) {
	&Log("SMTP::Prof:connect $host/$Port");
    }

    ### Do talk with sendmail via smtp connection
    # interacts smtp port, see the detail in $SMTPLOG
    if ($ipc) {
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    ##### SMTP CONNECTION
    ##### THE MOST HEAVY LOOP IS HERE;
    #####
    $Current_Rcpt_Count = 0;
    $e{'mci:pipelining'} = 0; # reset EHLO information

    if ($e{'mci:mailer'} eq 'smtpfeed' || $SmtpFeedMode) {
	&SmtpPut2Socket("LHLO $e{'macro:s'}", $ipc);
    }
    else {
	&SmtpPut2Socket("EHLO $e{'macro:s'}", $ipc, 1, 1); # error ignore mode 

	# EHLO fails (smap returns 500 ;_;, may not 554)
	if ($SoErrBuf =~ /^5/) {
	    &SmtpPut2Socket("HELO $e{'macro:s'}", $ipc);
	}
	elsif ($RetVal =~ /250.PIPELINING/) {
	    $e{'mci:pipelining'} = 1;
	}

	undef $SoErrBuf;
    }

    $e{'mci:pipelining'} = 0 if $NOT_USE_ESMTP_PIPELINING;
    
    # XXX MAIL FROM:<mailing-list-maintainer@domain>
    # XXX If USE_VERP (e.g. under qmail), you can use VERPs
    # XXX "VERPs == Variable Envelope Return-Path's".
    {
	local($mail_from);
	if ($USE_VERP) {
	    $mail_from = $MAINTAINER;
	    $mail_from =~ s/\@/-\@/;
	    $mail_from .= '-@[]';
	} else {
	    $mail_from = $MAINTAINER;
	}
	&SmtpPut2Socket("MAIL FROM:<$mail_from>", $ipc);
    }
    
    if ($SoErrBuf =~ /^[45]/) {
	&Log("SmtpIO error: smtp session stop and NOT SEND ANYTHING!");
	&Log("reason: $SoErrBuf");
	return $NULL;
    }

    # DLA is effective in processing deliver();
    local(%a, $a);

    if ($USE_SMTP_PROFILE) { &GetTime; print SMTPLOG "RCPT  IN>$MailDate\n";}

    if ($e{'mode:__deliver'} && $USE_OUTGOING_ADDRESS) { 
	if ($e{'mci:pipelining'}){
	    &SmtpPut2Socket_NoWait("RCPT TO:<$OUTGOING_ADDRESS>", $ipc);
	}
	else {
	    &SmtpPut2Socket("RCPT TO:<$OUTGOING_ADDRESS>", $ipc);
	}
	    
	$Current_Rcpt_Count = 1;
    }
    elsif ($e{'mode:__deliver'}) { 
	if ($SMTP_SORT_DOMAIN) { &use('smtpsd'); &SDInit(*RcptLists);}

	for $a (@RcptLists) { # plural active lists
	    next if $a{$a}; $a{$a} = 1; # uniq;
	    &SmtpPutActiveList2Socket($ipc, $a);
	}

	if ($SMTP_SORT_DOMAIN) { &SDFin(*RcptLists);}
    }
    elsif ($e{'mode:delivery:list'}) { 
	&SmtpPutActiveList2Socket($ipc, $e{'mode:delivery:list'});
    }
    else { # not-DLA is possible;
	for (@rcpt) { 
	    $Current_Rcpt_Count++ if $_;
	    if ($e{'mci:pipelining'}){
		&SmtpPut2Socket_NoWait("RCPT TO:<$_>", $ipc) if $_;
	    }
	    else {
		&SmtpPut2Socket("RCPT TO:<$_>", $ipc) if $_;
	    }
	}
    }

    if ($USE_SMTP_PROFILE) { &GetTime; print SMTPLOG "RCPT OUT>$MailDate\n";}

    # if no rcpt (e.g. MCI_SMTP_HOSTS > 1,  crosspost and compination of them)
    # "DATA" without "RCPT" must be error;
    if ($Current_Rcpt_Count == 0) {
	&Log("SmtpIO: no recipients but O.K.?");
	&SmtpPut2Socket('QUIT', $ipc);
	return;
    }

    # check critical error: comment out (99/01/25)
    # XXX this condition is too restrict since this traps
    # XXX direct local delivery errors ;D
    # if ($SoErrBuf =~ /^[45]/) {
    # &Log("SmtpIO error: smtp session stop and NOT SEND ANYTHING!");
    # &Log("reason: $SoErrBuf");
    # return $NULL;
    # }

    if ($e{'mci:pipelining'}) {
	&SmtpPut2Socket_NoWait('DATA', $ipc);
	&WaitFor354($ipc);
    }
    else {
	&SmtpPut2Socket('DATA', $ipc, 1);
    }

    print SMTPLOG ('-' x 30), "\n";

    ### (HELO .. DATA) sequence ends

    ##### "DATA" Session BEGIN; no reply via socket ######
    ###
    ### BODY INPUT
    ### putheader()
    $0 = "$FML:  BODY <$LOCKFILE>";
    $e{'Hdr'} =~ s/\n/\r\n/g; 
    $e{'Hdr'} =~ s/\r\r\n/\r\n/g; # twice reading;
    print SMTPLOG $e{'Hdr'};
    print S $e{'Hdr'};	# "\n" == separator between body and header;
    print SMTPLOG "\r\n";
    print S "\r\n";

    # Preamble
    if ($e{'preamble'}) { 
	$e{'preamble'} =~ s/\n/\r\n/g; 
	$e{'preamble'} =~ s/\r\r\n/\r\n/g; # twice reading;
	print SMTPLOG $e{'preamble'}; 
	print S $e{'preamble'};
    }

    # Put files as a body
    if (@files) { 
	&SmtpFiles2Socket(*files, *e);
    }
    # BODY ON MEMORY
    else { 
	# Essentially we request here only "s/\n/\r\n/ && print"!
	# We should not reference body itself by s///; since
	# it leads to big memory allocation.
	{
	    local($pp, $p, $maxlen, $len, $buf, $pbuf);

	    $pp     = 0;
	    $maxlen = length($e{'Body'});

	    # write each line in buffer
	  smtp_io:
	    while (1) {
		$p   = index($e{'Body'}, "\n", $pp);
		$len = $p  - $pp + 1;
		$buf = substr($e{'Body'}, $pp, ($p < 0 ? $maxlen-$pp : $len));
		if ($buf !~ /\r\n$/) { $buf =~ s/\n$/\r\n/;}

		# ^. -> ..
		$buf =~ s/^\./../;

		print SMTPLOG $buf;
		print S $buf;
		$LastSmtpIOString = $buf;

		last smtp_io if $p < 0;
		$pp = $p + 1;
	    }
	}

	# global interrupt;
	if ($Envelope{'ctl:smtp:stdin2socket'}) {
	    undef $buf; # reset $buf to use
	    undef $pbuf;

	    while (sysread(STDIN, $buf, 1024)) {
		$buf =~ s/\n/\r\n/g;
		$buf =~ s/\r\r\n/\r\n/g; # twice reading;

		# ^. -> .. 
		$buf =~ s/\n\./\n../g;

		# XXX: 1. "xyz\n.abc" => "xyz\n" + ".abc"
		# XXX: 2. "xyz..abc" => "xyz." + ".abc"
		if ($pbuf =~ /\n$/) { $buf =~ s/^\./../g;}
		if ($pbuf eq '') { $buf =~ s/^\./../g;} # the first time

		print S $buf;
		$pbuf = substr($buf, -4); # the last buffer
	    }

	    print SMTPLOG "\n\n... truncated in log for file system ...\n";
	    $LastSmtpIOString = substr($_, -16);
	}
	else {
	    $LastSmtpIOString = substr($e{'Body'}, -16);
	}
    }

    # special exceptions;
    if ($e{'Body:append:files'}) {
	local(@append) = split($;, $e{'Body:append:files'});
	&SmtpFiles2Socket(*append, *e);
	undef $e{'Body:append:files'};
    }

    # special control: direct buffer copy from %Envelope.
    if ($Envelope{'ctl:smtp:ebuf2socket'}) {
	require 'libsmtpsubr.pl';

	if ($Envelope{'ctl:smtp:forw:ebuf2socket'}) {
	    print S &ForwardSeparatorBegin;
	    print SMTPLOG &ForwardSeparatorBegin;
	}

	&Copy2SocketFromHash('Header');

	# Separator between Header and Body
	print SMTPLOG "\r\n";
	print S "\r\n";

	&Copy2SocketFromHash('Body');

	if ($Envelope{'ctl:smtp:forw:ebuf2socket'}) {
	    print S &ForwardSeparatorEnd;
	    print SMTPLOG &ForwardSeparatorEnd;
	}
    }

    # Trailer
    if ($e{'trailer'}) { 
	$e{'trailer'} =~ s/\n/\r\n/g; 
	$e{'trailer'} =~ s/\r\r\n/\r\n/g; # twice reading;
	$LastSmtpIOString =  $e{'trailer'}; 
	print SMTPLOG $e{'trailer'}; 
	print S $e{'trailer'};
    }

    ### close smtp with '.'
    print S "\r\n" unless $LastSmtpIOString =~ /\n$/;	# fix the last 012
    print SMTPLOG ('-' x 30), "\n";

    ##### "DATA" Session ENDS; ######
    ### Closing Phase;
    &SmtpPut2Socket('.', $ipc);
    &SmtpPut2Socket('QUIT', $ipc);

    close(S);

    # reverse \r\n -> \n
    $e{'Hdr'}  =~ s/\r\n/\n/g;
    # $e{'Body'} =~ s/\r\n/\n/g; # XXX 2.2D no more reference of $e{'Body'}

    # 
    if ($USE_SMTP_PROFILE) { 
	&Log("SMTP::Prof::IO: ". (time - $SmtpIOStart)." secs.");
    }

    0;
}


sub SocketTimeOut
{
    $SocketTimeOut = 1;
    close(S);
}


sub SmtpPut2Socket_NoWait
{
    $PipeLineCount++; # the number of wait after 'DATA' request.
    &SmtpPut2Socket(@_, 0, 0, 1);
}


sub GetPipeLineReply
{
    local($ipc) = @_;    
    local($wc)  = int($PipeLineCount/2);
    while ($wc-- > 0) {
	&WaitForSmtpReply($ipc, 1, 0);
	$PipeLineCount--;
    }
}


# XXX If $Current_Rcpt_Count is no longer used, 
# XXX remove it! (must be true in the future. logged on 1999/06/21).
sub WaitFor354
{
    local($ipc) = @_;
    local($wc) = $PipeLineCount + 1; 

    while ($wc-- > 0) {
	undef $RetVal;
	&WaitForSmtpReply($ipc, 1, 0);
	last if $RetVal =~ /^354/;
    }

    $PipeLineCount = 0;
}


sub WaitForSmtpReply
{
    local($ipc, $getretval, $ignore_error) = @_;

    if ($ipc) {
	do { 
	    print SMTPLOG $_ = <S>; 
	    $RetVal .= $_ if $getretval;
	    $SoErrBuf = $_  if /^[45]/o;
	    &Log($_) if /^[45]/o && (!$ignore_error);
	} while(/^\d+\-/o);
    }
    else {
	do { 
	    print SMTPLOG $_ = <RS>; 
	    $RetVal .= $_ if $getretval;
	    $SoErrBuf = $_  if /^[45]/o;
	    &Log($_) if /^[45]/o && (!$ignore_error);
	} while(/^\d+\-/o);
    }
}


sub SmtpPut2Socket
{
    local($s, $ipc, $getretval, $ignore_error, $no_wait) = @_;

    # return if $s =~ /^\s*$/; # return if null;

    $0 = "$FML:  $s <$LOCKFILE>"; 
    print SMTPLOG "$s<INPUT\n";
    print S $s, "\r\n";

    # no wait
    return $NULL if $no_wait;

    # wait for SMTP Reply
    &WaitForSmtpReply($ipc, $getretval, $ignore_error);

    # Approximately correct :-)
    if ($TRACE_SMTP_DELAY) {
	$time = time() - $SmtpTime;
	$SmtpTime = time();
	&Log("SMTP DELAY[$time sec.]:$s") if $time > $TRACE_SMTP_DELAY;
    }

    $RetVal;
}


# %RELAY_SERVER = ('ac.jp', 'relay-server', 'ad.jp', 'relay-server');
sub SmtpPutActiveList2Socket
{
    local($ipc, $file) = @_;
    local($rcpt, $lc_rcpt, $gw_pat, $ngw_pat, $relay);
    local($mci_count, $count, $time, $filename, $xtime);

    $filename = $file; $filename =~ s#$DIR/##;

    # Relay Hack
    if ($CF_DEF && $RELAY_HACK) { require 'librelayhack.pl'; &RelayHack;}
    if (%RELAY_GW)  { $gw_pat  = join("|", sort keys %RELAY_GW);}
    if (%RELAY_NGW) { $ngw_pat = join("|", sort keys %RELAY_NGW);}

    $time  = time;
    $mci_count = $count = 0;

    if ($SMTP_SORT_DOMAIN && $MCI_SMTP_HOSTS) {
	$MCIType = 'window';
	&GetMCIWindow;
	print STDERR "new:($MCIWindowStart, $MCIWindowEnd)\n" if $debug_mci;
    }

    # when crosspost, delivery info is saved in crosspost.db;
    if ($USE_CROSSPOST) { 
	dbmopen(%WMD, "$FP_VARDB_DIR/crosspost", 0400);
	$myml = $MAIL_LIST;
	$myml =~ tr/A-Z/a-z/;
    }

    if ($debug_smtp) {
	&Log("SmtpPutActiveList2Socket:open $file");
	print STDERR "SmtpPutActiveList2Socket::open $file\n";
    }

    &Open(ACTIVE_LIST, $file) || return 0;
    while (<ACTIVE_LIST>) {
	chop;

	print STDERR "\nRCPT ENTRY\t$_\n" if ($debug_smtp || $debug_dla);

	next if /^\#/o;	 # skip comment and off member
	next if /^\s*$/o; # skip null line
	next if /\s[ms]=/o;

	# O.K. Checking delivery and addrs to skip;
	($rcpt) = split(/\s+/, $_);

	# Address Representation Range Check
	# local-part is /^\S+$/ && /^[^\@]$/ is enough effective, is'nt it?
	&ValidAddrSpecP($rcpt) || ($rcpt =~ /^[^\@]+$/) || do {
	    &Log("$filename:$. <$rcpt> is invalid");
	    next;
	};

	$lc_rcpt = $rcpt;
	$lc_rcpt =~ tr/A-Z/a-z/; # lower case;

	# skip case, already loop-check-code-in %SKIP;
	next if $SKIP{$lc_rcpt}; 

	# skip if crosspost and the ml to deliver != $MAIL_LIST;
	if ($USE_CROSSPOST) {
	    if ($WMD{$lc_rcpt} && ($WMD{$lc_rcpt} ne $myml)) {
		print STDERR "SKIP FOR CROSSPOST [$WMD{$lc_rcpt} ne $myml]\n"
		    if $debug_smtp;
		next;
	    }
	}

	# Relay Hack;
	$rcpt = $RelayRcpt{$lc_rcpt} if $RelayRcpt{$lc_rcpt};

	# %RELAY_GW 
	# attention! $gw_pat is "largest match";
	if ($gw_pat && $rcpt =~ /^\@/ && $rcpt =~ /($gw_pat)[,:]/i) {
	    if ($relay = $RELAY_GW{$1}) { $rcpt = "\@${relay},${rcpt}";}
	}
	elsif ($gw_pat && $rcpt =~ /($gw_pat)$/i) {
	    if ($relay = $RELAY_GW{$1}) { $rcpt = "\@${relay}:${rcpt}";}
	}

	if ($debug_smtp) {
	    $ok = $rcpt !~ /($ngw_pat)/i ? 1 : 0;
	    &Debug("$rcpt !~ /($ngw_pat)[,:]/i rewrite=$ok") if $debug_relay;
	}

	# %RELAY_NGW (negative relay gataway)
	# attention! $ngw_pat is "largest match";
	if ($ngw_pat) {
	    if ($rcpt =~ /^\@/ && ($rcpt !~ /($ngw_pat)[,:]/i)) {
		$relay = &SearchNegativeGw($rcpt, 1);
		$rcpt = "\@${relay},${rcpt}" if $relay;
	    }
	    elsif ($rcpt !~ /($ngw_pat)$/i) {
		$relay = &SearchNegativeGw($rcpt);
		$rcpt = "\@${relay}:${rcpt}" if $relay;
	    }
	}

	# count and do delivery for each modulus sets;
	$mci_count++;

	&Debug("  [$mci_count]  \t$rcpt") if $debug_mci;
	&Debug("  $mci_count % $MCI_SMTP_HOSTS != $CurModulus") if $debug_mci;

	if ($MCIType eq 'window' && $MCI_SMTP_HOSTS) {
	    # $mci_count++ before but $count++ after here.
	    # Suppose (first, last) = (0, 100), (100, 200), ...
	    # we pass throught 0-99, 100-199, ...
	    next if $mci_count <= $MCIWindowStart; #   0 100 200
	    last if $mci_count >  $MCIWindowEnd;   # 100 200 300
	}
	elsif (($MCIType eq 'modulus') || $MCI_SMTP_HOSTS) {
	    next if ($mci_count % $MCI_SMTP_HOSTS != $CurModulus);
	}

	$count++; # real delivery count;
	&Debug("Delivered[$count]\t$rcpt") if $debug_mci;
	&Debug("RCPT TO[$count]:\t$rcpt") if $debug_smtp || $debug_dla;

	print STDERR "$mci_count:($MCIWindowStart, $MCIWindowEnd)> $rcpt\n"
	    if $debug_mci;

	if ($USE_SMTP_PROFILE) { $xtime = time;}

	if ($e{'mci:pipelining'}){
	    &SmtpPut2Socket_NoWait("RCPT TO:<$rcpt>", $ipc);
	}
	else {
	    &SmtpPut2Socket("RCPT TO:<$rcpt>", $ipc);
	}

	if ($USE_SMTP_PROFILE && (time - $xtime > 1)) { 
	    &Log("SMTP::Prof $rcpt slow");
	}

	if ($e{'mci:pipelining'} && ($PipeLineCount > $PipeLineMaxRcvQueue)) {
	    &GetPipeLineReply($ipc);
	}

	$Current_Rcpt_Count++;
    }

    close(ACTIVE_LIST);
    dbmclose(%WMD);

    &Log("Smtp: ".(time - $time)." sec. for $count rcpts.") if $debug_smtp;
    if ($USE_SMTP_PROFILE && ((time - $time) > 0)) {
	&Log("SMTP::Prof:RCPT ".(time - $time)." sec. for $count rcpts.");
    }
}

###FI: NOT EXPORTS IN FIX-INCLUDE
# SMTP UTILS;
sub SmtpFiles2Socket { require 'libsmtpsubr.pl'; &DoSmtpFiles2Socket(@_);}
sub NeonSendFile     { require 'libsmtputils.pl'; &DoNeonSendFile(@_);}
sub SendFile         { require 'libsmtputils.pl'; &DoSendFile(@_);}
sub SendFile2        { require 'libsmtputils.pl'; &DoSendFile2(@_);}
sub SendFile3        { require 'libsmtputils.pl'; &DoSendFile3(@_);}
sub SendPluralFiles  { require 'libsmtputils.pl'; &DoSendPluralFiles(@_);}
sub Sendmail         { require 'libsmtputils.pl'; &DoSendmail(@_);}
sub GenerateMail     { &GenerateHeaders(@_);}
sub GenerateHeaders  { &GenerateHeader(@_);}
sub GenerateHeader   { require 'libsmtputils.pl'; &DoGenerateHeader(@_);}

1;
