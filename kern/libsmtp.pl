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
	my ($org_smtp_log) = $SMTP_LOG;

	if ($USE_SMTP_LOG_ROTATE) {
	    eval { &use('modedef'); &RegistSmtpLogExpire; };

	    if ($USE_SMTP_LOG_ROTATE_TYPE eq 'day') {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime;
		$SMTP_LOG .= sprintf(".%04d%02d%02d", 
				    1900 + $year, $mon + 1, $mday);
	    }
	    else {
		my ($id) = &IncrementCounter("$VARLOG_DIR/.seq", 
					     $NUM_SMTP_LOG_ROTATE || 8);
		$SMTP_LOG .= ".$id" if $SMTP_LOG !~ /\.$id$/;

		# unlink $SMTP_LOG if first time in this process thread;
		if ($IncrementCounterCalled{"$VARLOG_DIR/.seq"} == 1) {
		    &Log("unlink $SMTP_LOG") if $debug_fml_org;
		    unlink $SMTP_LOG if -f $SMTP_LOG;
		    open($SMTP_LOG, ">$SMTP_LOG"); # XXX: prefer basic function
		    unlink $org_smtp_log if -f $org_smtp_log;
		    link($SMTP_LOG, $org_smtp_log)  if     $UNISTD;
		    &Copy($SMTP_LOG, $org_smtp_log) unless $UNISTD;
		}
	    }
	}
	else {
	    unlink $SMTP_LOG if -f $SMTP_LOG;
	}
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

    ## set up @RcptLists which has lists of recipients.
    ## Its purpose is to split lists to sub-organization but
    ## deliver to all of them. For example each admin maintains
    ## each labolatory. 
    ## @ACTIVE_LIST = (arrays of each laboratory actives).
    ## It is of no use if @ACTIVE_LIST == ($ACTIVE_LIST)
    ## which is true in almost cases.
    # We should sort here? But the order may be of mean ...
    @RcptLists = @ACTIVE_LIST;
    push(@RcptLists, $ACTIVE_LIST) 
	unless grep(/$ACTIVE_LIST/, @RcptLists);

    ## initialize "Recipient Lists Control Block"
    ## which saves the read pointer on the file.
    ## e.g. $RcptListsCB{"${file}:ptr"} => 999; (line number 999)
    undef %RcptListsCB;

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

    if ($USE_INET6) {
	my $mta = "$host:$Port" || 'localhost:25' || '[::1]:25';
	my $pkg = "Mail::Delivery";

	eval "use Socket6; require $pkg; $pkg->import();";
	unless ($@) {
	    my $service = new Mail::Delivery { 
		protocol     => 'SMTP', 
		log_function => \&Log,
	    };
	    &Log( $service->error() ) if $service->error();

	    if (defined $service) {
		$service->connect6( { _mta => $mta } );

		unless ( $service->error() ) {
		    if (defined $service->{ _socket }) {
			print SMTPLOG "socket ok (IPv6)\n";
			print SMTPLOG "connect ok (IPv6)\n";
			*S = $service->{ _socket };
			$error = "";
			return "";
		    }
		    else {
			&Log( $service->error() ) if $service->error();
			&Log("cannot connect $mta by IPv6");
		    }
		}
		else {
		    &Log( $service->error() );
		    &Log("cannot connect $mta by IPv6");
		}
	    }
	}
    }

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

    # Initialize, e.g. use Socket, sys/socket.ph ...
    &SmtpInit(*e, *smtp);
    
    # open LOG;
    open(SMTPLOG, ">> $SMTP_LOG") || (return "Cannot open $SMTP_LOG");
    select(SMTPLOG); $| = 1; select(STDOUT);

    ### cache Message-Id:
    if ($e{'h:Message-Id:'} || $e{'GH:Message-Id:'}) {
	&CacheMessageId(*e, $e{'h:Message-Id:'} || $e{'GH:Message-Id:'});
    }

    # main delivery routine:
    #    fml 3.0 does not use modulus type MCI.
    #    SmtpIO() handles recipient array window.
    $error = &SmtpIO(*e, *rcpt, *smtp, *files);
    return $error if $error;

    # close log
    close(SMTPLOG);
    0; # return status BAD FREE();
}

# for (MCIWindow loop (1 times in almost cases)) {
#    open one of smtp servers (one of @HOSTS)
#        for $list (recipient lists) { # at fixed smtp server
#            set up window for each $list (window==0..end in almost cases)
#            send "RCPT TO:<$rcpt>" to socket;
#            # that is "send N-th region assigned for N-th server"
#            # but the N-th region (window) size varies from files to files. 
#        }
#    close smtp server
# }
sub SmtpIO
{
    local(*e, *rcpt, *smtp, *files) = @_;
    local(%smtp_pcb);

    # for (@HOSTS) { try to connect SMTP server ... }
    push(@HOSTS, @HOST);    # [COMPATIBLITY]
    unshift(@HOSTS, $HOST); # ($HOSTS, @HOSTS, ...);

    if ($USE_SMTP_PROFILE) { $SmtpIOStart = time;}

    undef %MCIWindowCB; # initialize MCI Control Block;

    &ConvHdrCRLF(*e);

    $Total_Rcpt_Count = 0;

    if ($e{'mode:__deliver'}) { # consider mci in distribute() 
	local($n, $i);
	$n = $MCI_SMTP_HOSTS > 1 ? $MCI_SMTP_HOSTS : 1;

	for (1 .. $n) { # MCI window loop
	    undef %smtp_pcb;
	    $smtp_pcb{'mci'} = 1 if $n > 1;

	    &__SmtpIOConnect(*e, *smtp_pcb, *rcpt, *smtp, *files);
	    return $smtp_pcb{'fatal'} if $smtp_pcb{'fatal'}; # fatal return

	    # @RcptLists loop under "fixed smtp server"
	    &__SmtpIO(*e, *smtp_pcb, *rcpt, *smtp, *files);
            $Total_Rcpt_Count += $Current_Rcpt_Count;

	    &__SmtpIOClose(*e, $smtp_pcb{'ipc'});

	    push(@HOSTS, $HOST); # last resort for insurance :)
	}
    }
    else { # e.g. command, message by Notify(), ...
	undef %smtp_pcb;
	$smtp_pcb{'mci'} = 0; # not use mci

	&__SmtpIOConnect(*e, *smtp_pcb, *rcpt, *smtp, *files);
	return $smtp_pcb{'fatal'} if $smtp_pcb{'fatal'}; # fatal return

	&__SmtpIO(*e, *smtp_pcb, *rcpt, *smtp, *files);
        $Total_Rcpt_Count += $Current_Rcpt_Count;

	&__SmtpIOClose(*e, $smtp_pcb{'ipc'});
    }
    &RevConvHdrCRLF(*e);

    if ($USE_SMTP_PROFILE) { &Log("SMTPProf: ".(time-$SmtpIOStart)."sec.");}

    $NULL;
}


# FYI: programs which accpets SMTP from stdio.
#   sendmail: /usr/sbin/sendmail -bs
#   qmail: /var/qmail/bin/qmail-smtpd (-bs?)
#   exim: /usr/local/exim/bin/exim -bs
#
sub __SmtpIOConnect
{
    local(*e, *smtp_pcb, *rcpt, *smtp, *files) = @_;
    local($sendmail, $backoff);
    local($host, $error, $in_rcpt, $ipc, $try_prog, $retry);

    # set global variable
    $SocketTimeOut = 0; # against the call of &SocketTimeOut;
    # &SetEvent($TimeOut{'socket'} || 1800, 'SocketTimeOut') if $HAS_ALARM;

    # delay of retry 
    $backoff = 2;
    
    # IPC 
    if ($e{'mci:mailer'} eq 'ipc' || $e{'mci:mailer'} eq 'smtp') {
	$ipc = 1; # define [ipc]

	for ($host = shift @HOSTS; scalar(@HOSTS) >=0 ; $host = shift @HOSTS) {
	    undef $Port; # reset

	    if ($host =~ /(\S+):(\d+)/) {
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

	    sleep($backoff);	# sleep and try the secondaries

	    last unless @HOSTS;	# trial ends if no candidate of @HOSTS
	}
    }


    ###
    ### reaches here if mailer == prog or "smtp connection fails"
    ###

    # not IPC, try popen(sendmail) ... OR WHEN ALL CONNEVTION FAIL;
    # Only on UNIX
    if ($e{'mci:mailer'} eq 'prog' || $error) {
	undef $host;
	&Log("Try mci:prog since smtp connections not established") if $error;

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
		$smtp_pcb{'error'} = "SmtpIO: cannot exec $sendmail";
		return $NULL;
	    };

	    $ipc = 0;
	}
	else {
	    &Log("cannot open prog mailer not under UNIX");
	    $smtp_pcb{'error'} = "SmtpIO: cannot prog mailer on not unix";
	    return $NULL;
	}
    }

    if ($USE_SMTP_PROFILE) { &Log("SMTP::Prof:connect $host/$Port");}

    # receive "220 ... sendmail ..." greeting
    if ($ipc) {
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    $smtp_pcb{'ipc'}      = $ipc;
    $smtp_pcb{'sendmail'} = $sendmail;
}

sub __SmtpIOClose
{
    local(*e, $ipc) = @_;

    ### SMTP Section: QUIT
    # Closing Phase;
    &SmtpPut2Socket('QUIT', $ipc);

    close(S);
}

sub ConvHdrCRLF
{
    local(*e) = @_;

    $e{'Hdr'} =~ s/\n/\r\n/g; 
    $e{'Hdr'} =~ s/\r\r\n/\r\n/g; # twice reading;

    $NULL;
}

sub RevConvHdrCRLF
{
    local(*e) = @_;

    ### SMTP Section: save-excursion(?)
    # reverse \r\n -> \n
    $e{'Hdr'} =~ s/\r\n/\n/g;

    $NULL;
}

sub __SmtpIO
{
    local(*e, *smtp_pcb, *rcpt, *smtp, *files) = @_;
    local($sendmail, $host, $error, $in_rcpt, $ipc, $try_prog, $retry);

    # SMTP PCB
    $ipc      = $smtp_pcb{'ipc'};
    $sendmail = $smtp_pcb{'sendmail'};
    

    ### SMTP Section: HELO/EHLO
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


    ### SMTP Section: MAIL FROM:

    # [VERPs]
    # XXX MAIL FROM:<mailing-list-maintainer@domain>
    # XXX If USE_VERP (e.g. under qmail), you can use VERPs
    # XXX "VERPs == Variable Envelope Return-Path's".
    {
	my ($mail_from);
	if ($USE_VERP) {
	    $mail_from = $SMTP_SENDER || $MAINTAINER;
	    $mail_from =~ s/\@/-\@/;
	    $mail_from .= '-@[]';
	} else {
	    $mail_from = $SMTP_SENDER || $MAINTAINER;
	}
	&SmtpPut2Socket("MAIL FROM:<$mail_from>", $ipc);
    }
    
    if ($SoErrBuf =~ /^[45]/) {
	&Log("SmtpIO ERROR: smtp session stop and NOT SEND ANYTHING!");
	&Log("reason: $SoErrBuf");
	return $NULL;
    }


    ### SMTP Section: RCPT TO:

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

	local(%a, $a);
	for $a (@RcptLists) { # plural active lists
	    next if $a{$a}; $a{$a} = 1; # uniq;
	    &SmtpPutActiveList2Socket(*smtp_pcb, $ipc, $a);
	}

	if ($SMTP_SORT_DOMAIN) { &SDFin(*RcptLists);}
    }
    elsif ($e{'mode:delivery:list'}) { 
	&SmtpPutActiveList2Socket(*smtp_pcb, $ipc, $e{'mode:delivery:list'});
    }
    else { # [COMPATIBILITY] not-DLA is possible;
	local($lc_rcpt);
	for (@rcpt) { 
	    $Current_Rcpt_Count++ if $_;

	    $lc_rcpt = $_;
	    $lc_rcpt =~ tr/A-Z/a-z/;

	    # Relay Hack; always enable %RelayRcpt
	    $_ = $RelayRcpt{$lc_rcpt} if $RelayRcpt{$lc_rcpt};

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


    ### SMTP Section: DATA

    if ($e{'mci:pipelining'}) {
	&SmtpPut2Socket_NoWait('DATA', $ipc);
	&WaitFor354($ipc);
    }
    else {
	&SmtpPut2Socket('DATA', $ipc, 1);
    }

    # "DATA" Session BEGIN; no reply via socket
    # BODY INPUT ; putheader()
    print SMTPLOG ('-' x 30), "\n";
    $0 = "${FML}:  BODY <$LOCKFILE>";

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

    ## close smtp with '.'
    print S "\r\n" unless $LastSmtpIOString =~ /\n$/;	# fix the last 012
    print SMTPLOG ('-' x 30), "\n";

    ## "DATA" Session ENDS; ##
    &SmtpPut2Socket("\r\n.", $ipc);

    $NULL;
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
    local($buf);

    if ($ipc) {
	do { 
	    print SMTPLOG ($buf = <S>); 
	    $RetVal .= $buf if $getretval;
	    $SoErrBuf = $buf if $buf =~ /^[45]/o;
	    &Log($buf) if $buf =~ /^[45]/o && (!$ignore_error);
	} while ($buf =~ /^\d+\-/o);
    }
    else {
	do { 
	    print SMTPLOG $_ = <RS>; 
	    $RetVal .= $_ if $getretval;
	    $SoErrBuf = $_  if /^[45]/o;
	    &Log($_) if /^[45]/o && (!$ignore_error);
	} while (/^\d+\-/o);
    }
}


sub SmtpPut2Socket
{
    local($s, $ipc, $getretval, $ignore_error, $no_wait) = @_;

    # return if $s =~ /^\s*$/; # return if null;

    $0 = "${FML}:  $s <$LOCKFILE>"; 
    print SMTPLOG $s, "<INPUT\n";
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
    local(*smtp_pcb, $ipc, $file) = @_;
    local($rcpt, $lc_rcpt, $gw_pat, $ngw_pat, $relay);
    local($mci_count, $count, $time, $filename, $xtime);
    local($size, $mci_window_start, $mci_window_end);

    $filename = $file; $filename =~ s#$DIR/##;

    # Relay Hack
    if ($CF_DEF && $RELAY_HACK) { require 'librelayhack.pl'; &RelayHack;}
    if (%RELAY_GW)  { $gw_pat  = join("|", sort keys %RELAY_GW);}
    if (%RELAY_NGW) { $ngw_pat = join("|", sort keys %RELAY_NGW);}

    if ($debug_relay) { 
	local($k, $v);
	print STDERR "gw_pat=$gw_pat\nngw_pat=$ngw_pat\n";
	while (($k,$v) = each %RELAY_GW) { 
	    print STDERR " RELAY_GW: $k => $v\n";
	}
	while (($k,$v) = each %RELAY_NGW) { 
	    print STDERR "RELAY_NGW: $k => $v\n";
	}
    }

    $MCIType = 'window'; # no more modulus
    if ($smtp_pcb{'mci'}) {
	require 'libsmtpsubr2.pl';
	($size, $mci_window_start, $mci_window_end) = &GetMCIWindow($file);
	print STDERR "window $file:($start, $end)\n" if $debug_mci;
	&Log("window size=$size $mci_window_start/$mci_window_end")
	    if $debug_fml_org;
	if ($debug_mci_window2) {
	    local($fn) = $file;
	    $fn =~ s#$DIR/##;
	    &Log("mci_window $fn:($mci_window_start, $mci_window_end)");
	}
    }

    # when crosspost, delivery info is saved in crosspost.db;
    if ($USE_CROSSPOST) { 
	dbmopen(%WMD, "$FP_VARDB_DIR/crosspost", 0400);
	$myml = $MAIL_LIST;
	$myml =~ tr/A-Z/a-z/;
    }


    ##                                                          ##
    ## MAIN IO from recipients list to Socket (SMTP Connection) ##
    ##                                                          ##
    if ($debug_smtp) { &Log("--SmtpPutActiveList2Socket:open $file");}
    $time = time;
    $mci_count = $count = 0;

    open(ACTIVE_LIST, $file) || do {
	&Log("SmtpPutActiveList2Socket: cannot open $file");
	return 0;
    };

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
	# &Debug("  $mci_count % $MCI_SMTP_HOSTS != $CurModulus") if $debug_mci;


	### Window Control ###
	# PLURAL SMTP SERVERS
	if ($smtp_pcb{'mci'}) {
	    if ($MCIType eq 'window') {
		# $mci_count++ before but $count++ after here.
		# Suppose (first, last) = (0, 100), (100, 200), ...
		# we pass throught 0-99, 100-199, ...
		next if $mci_count <= $mci_window_start; #   0 100 200
		last if $mci_count >  $mci_window_end;   # 100 200 300
	    }
	    # else { # modulus
	    #    next if ($mci_count % $MCI_SMTP_HOSTS != $CurModulus);
	    # }
	}
	# SINGLE SMTP SERVER
	else {
	    ;
	}
	### Window Control ends ###


	$count++; # real delivery count;
	&Debug("Delivered[$count]\t$rcpt") if $debug_mci;
	&Debug("RCPT TO[$count]:\t$rcpt") if $debug_smtp || $debug_dla;

	if ($debug_mci) {
	    print STDERR 
		$mci_count, 
		":$file:($mci_window_start, $mci_window_end)> $rcpt\n";
	}

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
