#!/usr/local/bin/perl
# 
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

### MAIN ###
if ($0 eq __FILE__) {
    # signal handling
    $SIG{'HUP'} = $SIG{'INT'} = $SIG{'QUIT'} = $SIG{'TERM'} = "irc'Exit";#';

    &IrcParseArgv;
    &IrcInit;
    &IrcConnect;
    &IrcMainLoop;

    exit 0;
}
else {
    &IrcImport;
    &IrcInit;
    &IrcConnect;
}


### MAIN ENDS ###

package irc;

sub main'IrcParseArgv #'
{
    eval "sub Log { print STDERR \"LOG: \@_\\n\";}";


    ### getopts
    require 'getopts.pl';
    &Getopts("df:I:");

    $debug = $opt_d;

    # load config.ph
    if (!-f $opt_f) { die("cannot load config file, stop.\n");}
    require $opt_f;

    # log
    if (-w "/dev/stderr") {
	open(SMTPLOG, ">/dev/stderr") || die($!);
    }

    # include path
    push(@INC, $opt_I);
}


sub main'IrcInit  #'
{
    ### defaults 
    # default
    $IRC_TIMEOUT = $IRC_TIMEOUT || 2;
    $IRC_SIGNOFF_MSG = $IRC_SIGNOFF_MSG || "Seeing you";

    ### fix Japanese code of configurable variables
    require 'jcode.pl';
    eval "&jcode'init; #';";
    for (IRC_CHANNEL, IRC_USER, IRC_NAME, IRC_NICK, IRC_SIGNOFF_MSG) {
	eval "&jcode'convert(*$_, 'jis'); #';";
    }
    
    ### Declare the first connection phase
    # stack on @Queue
    &InitConnection;

    ### set up socket
    &SocketInit;
}


sub InitConnection
{
    for ("USER $IRC_USER * * :$IRC_NAME",
	 "NICK $IRC_NICK",
	 "PING FML-IRC-FIRST",
	 "JOIN $IRC_CHANNEL"
	 ) {
	push(@Queue, $_);
    }
}


sub Exit
{
    local($sig) = @_; 
    &Log("Caught SIG${sig}, shutting down");
    &Log("Send QUIT To Server");
    &SendS("QUIT :$IRC_SIGNOFF_MSG");
    sleep 1;
    exit(0);
}


sub SendS
{
    local($s) = @_;
    print S "$s\r\n";
    print STDERR "SendS:[$s]\n" if $debug;
}


sub SocketInit
{
    local($eval, $exist_socket_ph);

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
	($COMPAT_SOLARIS2 || $CPU_TYPE_MANUFACTURER_OS =~ /solaris2/i)) {
	$eval  = "sub AF_INET {2;}; sub PF_INET { 2;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
    }
    elsif (! $exist_socket_ph) { # 4.4BSD (and 4.x BSD's)
	$eval  = "sub AF_INET {2;}; sub PF_INET { 2;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
    }

    1;
}


sub main'IrcConnect #'
{
    $status = &DoConnect(*IRC_SERVER, *error);
    &Log($status) if $status;
}


# Connect $IRC_SERVER to SOCKET "S"
# RETURN *error
sub DoConnect
{
    local(*host, *error) = @_;

    local($pat)    = $STRUCT_SOCKADDR;
    local($addrs)  = (gethostbyname($host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = $IRC_PORT || (getservbyname('irc', 'tcp'))[2];
    $port          = 6667 unless defined($port); # default port

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
	return ($error = "Irc::socket->Error[$!]");
    }
    
    if (connect(S, $target)) { 
	print SMTPLOG "connect ok\n"; 
    } 
    else { 
	return ($error = "Irc::connect($host)->Error[$!]");
    }

    ### need flush of sockect <S>;
    select(S); $| = 1; select(STDOUT);

    $error = "";
}


sub main'IrcMainLoop  #'
{
    local($rin, $win, $ein);
    local($rout, $wout, $eout);
    local($buf, $wbuf);

    $BITS{'S'}     = fileno(S);
    $BITS{'STDIN'} = fileno(STDIN);

    $rin = $win = $ein = "";
    vec($rin,fileno(S),1) = 1;
    vec($rin,fileno(STDIN),1) = 1;
    $ein = $rin | $win;

    for (;;) {
	($nfound, $timeleft) =
	    select($rout=$rin, $wout=$win, $eout=$ein, $IRC_TIMEOUT);

	if (vec($rout, $BITS{'S'}, 1)) {
	    sysread(S, $buf, 4096) || &Log("Error:$!");
	    if ($debug) {
		for (split(/\n/, $buf)) { print STDERR "--- $_\n";}
	    }
	}

	if (vec($rout, $BITS{'STDIN'}, 1)) {
	    sysread(STDIN, $buf, 4096) || &Log("Error:$!");

	    for (split(/\n/, $buf)) {
		print STDERR ">>> $_\n" if $debug;
		push(@Queue, "PRIVMSG $IRC_CHANNEL :$_");
	    }
	}

	sleep 1;
	$wbuf = shift @Queue;
	&SendS($wbuf) if $wbuf;
    }
}


1;
