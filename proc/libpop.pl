# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

# signal handler (should be in "main" space)
package main;

sub Shutdown
{
    local($sig) = @_; 
    local($tmpf);

    &Log("Caught Signal[$sig], shutting down");
    &Log("Pop Connection Timeout") if $sig eq 'ALRM';

    # unlink temporaroy files
    $tmpf = $Pop'CurTmpFile; #';

    if (-f $tmpf) {
	&Log("unlink $tmpf");
	unlink $tmpf;
    }

    exit 0;
}


package Pop;

sub Log { &main'Log(@_);} #';


sub Init
{
    for (HAS_ALARM, HAS_GETPWUID, HAS_GETPWGID) {
	eval("\$POP'$_ = \$main'$_;");	
    }

    for (SERVER, PORT, USER, PASSWORD, TIMEOUT, 
	 PROG, MAIL_SPOOL, QUEUE_DIR, RECVSTORE, LOGFILE) {
	eval("\$POP_${_} = \$PopConf{\"${_}\"};");
    }

    # pop queue should be "only you can read and write".
    -d $POP_QUEUE_DIR || mkdir($POP_QUEUE_DIR, 0700);
    $POP_LOGFILE = $POP_LOGFILE || '/dev/null';

    open(POPLOG, "> $POP_LOGFILE") || 
	&Log("cannot open poplog[$POP_LOGFILE]");
    select(POPLOG); $| = 1; select(STDOUT);

    &main'SocketInit;#'; # smtp;
}


sub MakeConnection # ($host, $headers, $body)
{
    local(*conf) = @_;

    $host    = $conf{'SERVER'};
    %PopConf = %conf;

    # Initialize
    &Init;			# sys/socket.ph

    local($pat)    = $main'STRUCT_SOCKADDR; #';
    local($addrs)  = (gethostbyname($host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = $POP_PORT || (getservbyname('pop3', 'tcp'))[2];
    $port          = 110 unless defined($port); # default port

    local($target) = pack($pat, &main'AF_INET, $port, $addrs);

    # IPC open
    if (socket(S, &main'PF_INET, &main'SOCK_STREAM, $proto)) { 
	print POPLOG  "socket ok\n";
    } 
    else { 
	return "Pop:sockect:$!";
    }
			  
    if (connect(S, $target)) { 
	print POPLOG  "connect ok\n"; 
    } 
    else { 
	return "Pop:connect:$!";
    }
			  
    # need flush of sockect <S>;
    select(S);       $| = 1; select(STDOUT);
    select(POPLOG);  $| = 1; select(STDOUT);

    # the first "OK.. session";
    print POPLOG $_ = <S>; /^\-/o && &Log($_) && (return "$_");

    &PopPut2Socket("USER $POP_USER");
    &PopPut2Socket("PASS $POP_PASSWORD");
}


sub CloseConnection
{
    &PopPut2Socket("QUIT");
    close(S);
    close(POPLOG);
    0;#return status
}


sub PopPut2Socket
{
    local($s) = @_;

    return if $s =~ /^\s*$/; # return if null;

    if ($s =~ /^PASS/) {
	$0 = "-- Put2Socket PASS <$FML $LOCKFILE>"; 
	print POPLOG "PASS ********<INPUT\n";
    }
    else {
	$0 = "-- Put2Socket $s <$FML $LOCKFILE>"; 
	print POPLOG "$s<INPUT\n";
    }

    print S "$s\r\n";
    print POPLOG $_ = <S>; 

    if (/^\-/o) { &Log($_); print STDERR "POP3: $_";}

    $_;
}


sub Gabble
{
    local(*conf) = @_;
    local($i, $tmpf, $queue);

    # only you can read since the mail is your mail;
    umask(077);

    &MakeConnection(*conf);

    $_ =  &PopPut2Socket("STAT");

    if (/^\+OK\s+(\d+)/) {
	$n = $1;
	# &Log("Pop::Gabble STAT $n") if $n > 0;
    }
    else {
	&Log("Pop::fails to STAT the pop server[$POP_SERVER].");
	return 'ERROR of POP SERVER';
    }

    for ($i = 1; $i <= $n; $i++) {
	print S "RETR $i\r\n";
	print POPLOG "RETR $i\n";
	print POPLOG $_ = <S>; /^\-/o && last;

	$tmpf       = "$POP_QUEUE_DIR/in.pop$$.$i";
	$queue      = "$POP_QUEUE_DIR/pq$$.$i";
	$CurTmpFile = $tmpf;

	# If occurs, we regard it as a critical error 
	# to close all the connection.
	# We expect the future try. 
	$SIG{'ALRM'} = 'Shutdown';
	$SIG{'INT'}  = $SIG{'QUIT'} = $SIG{'TERM'} = 'Shutdown';
	alarm($POP_TIMEOUT || 30) if $HAS_ALARM;

	### FILE RETRIEVE
	open(FILE, "> $tmpf") || next;
	select(FILE); $| = 1; select(STDOUT);
	for (;;) { 
	    $_ = <S>; 
	    s/\015$//;
	    last if /^\.$/;
	    print FILE $_;
	}
	close(FILE);

	### FILE REMOVE
	print S "DELE $i\r\n";
	print POPLOG "DELE $i\n";
	print POPLOG $_ = <S>; 

	# when an error occurs;
	if (/^\-/o) {
	    unlink $tmpf;
	    last; # ending ... expect the future;
	}
	else {
	    if (rename($tmpf, $queue)) {
		unlink $tmpf;
	    }
	    else {
		&Log("fails to rename $tmpf $queue");
	    }
	}
    }

    &CloseConnection;
}


1;
