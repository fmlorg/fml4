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
    if (($pid = fork) < 0) {
	die("cannot fork\n");
    }
    elsif (0 == $pid) {
	$stdin2irc'LOGFILE = "$ENV{'PWD'}/log"; #';
	eval q#sub Log { &stdin2irc'Log(@_);}#; #';
	
	for (;;) {
	    # signal handling
	    $SIG{'HUP'} = $SIG{'INT'} = $SIG{'QUIT'} = 
		$SIG{'TERM'} = "irc'Exit";#';

	    &IrcParseArgv;
	    &IrcInit;

	    &IrcConnect;
	    &IrcMainLoop; # infinite loop

	    close(S);
	    sleep 3;
	}
    }

    # parent
    exit 0;
}
else {
    &IrcImport;
    &IrcInit;
    &IrcConnect;
}


### MAIN ENDS ###

package irc;

sub Log { main'Log(@_);}

sub GetTime
{
    local($time) = @_;

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime($time||time))[0..6];
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);

    $MailDate;
}


sub main'IrcParseArgv #'
{
    ### getopts
    require 'getopts.pl';
    &Getopts("df:I:t:");

    $debug = $opt_d;
    $SetProcTitle = $opt_t;

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
    
    ($my_user, $my_name, $HOME) = (getpwuid($<))[0,6,7];
    $my_name =~ s/,.*$//;
    $IRC_USER = $my_user;
    $IRC_NAME = $IRC_NAME || $my_user;
    $IRC_NICK = $IRC_NICK || $my_user;

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
    &GetTime(time);
    print STDERR "SendS $Now> $s\n" if $debug;
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

    # server timeout
    $IRC_SERVER_TIMEOUT = $IRC_SERVER_TIMEOUT || 1800;

    $BITS{'S'}     = fileno(S);
    $BITS{'STDIN'} = fileno(STDIN);

    $rin = $win = $ein = "";
    vec($rin,fileno(S),1) = 1;
    vec($rin,fileno(STDIN),1) = 1;
    $ein = $rin | $win;

    $lasttime_input = time;
    for (;;) {
	$0 = "--stdin2irc $SetProcTitle";
    
	($nfound, $timeleft) =
	    select($rout=$rin, $wout=$win, $eout=$ein, $IRC_TIMEOUT);

	# logs time
	if ($nfound != 0) { 
	    $lasttime_input = time;
	}
	elsif (time - $lasttime_input > $IRC_SERVER_TIMEOUT) {
	    &SendS("QUIT :$IRC_SIGNOFF_MSG");
	    &Log("no input time lasts over $IRC_SERVER_TIMEOUT sec.");
	    last;
	}

	if (vec($rout, $BITS{'S'}, 1)) {
	    sysread(S, $buf, 4096) || &Log("Error:$!");
	    if ($debug) {
	        &GetTime(time);
		for (split(/\n/, $buf)) { print STDERR "----- $Now> $_\n";}
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
	sleep int(length(@Queue)/3);
	$wbuf = shift @Queue;
	&SendS($wbuf) if $wbuf;

	# counter
	$count = @Queue ? 0 : ($count+1);

	# ping, pong
	if ($count % 10 == 0) { 
	    &SendS("PING $IRC_SERVER");
	}
    }
}



########## Library
sub main'IrcImport #'
{
    $irc'debug = $main'debug;

    for (IRC_SERVER, IRC_PORT, IRC_CHANNEL, IRC_USER, IRC_NAME, IRC_NICK, 
	 IRC_SIGNOFF_MSG) {
	eval "\$irc'$_ = \$main'$_;";
    }
}


sub main'Write2Irc #'
{
    local($buf) = @_;
    local($rin, $win, $ein);
    local($rout, $wout, $eout);
    local($wbuf);

    ### Set up buffer
    for (split(/\n/, $buf)) {
	print STDERR ">>> $_\n" if $debug;
	$_ = /^\s*$/ ? " " : $_; # effective null line for irc.
	push(@Queue, "PRIVMSG $IRC_CHANNEL :$_") if $_;
    }
    push(@Queue, "QUIT :$IRC_SIGNOFF_MSG");

    $BITS{'S'} = fileno(S);

    $rin = $win = $ein = "";
    vec($rin,fileno(S),1) = 1;
    $ein = $rin | $win;

    for (@Queue) {
	&SendS($_) if $_;

	($nfound, $timeleft) =
	    select($rout=$rin, $wout=$win, $eout=$ein, $IRC_TIMEOUT);

	if (vec($rout, $BITS{'S'}, 1)) {
	    sysread(S, $buf, 4096) || &Log("Error:$!");
	    if ($debug) {
		for (split(/\n/, $buf)) { print STDERR "--- $_\n";}
	    }
	}
    }
}


package stdin2irc;

sub GetTime
{
    local($time) = @_;

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime($time||time))[0..6];
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);

    $MailDate;
}


sub Log 
{ 
    local($str, $s) = @_;
    local($from) = $USER;
    local(@c)    = caller;

    &GetTime(time);

    # existence and append(open system call check)
    if (-f $LOGFILE && open(APP, ">> $LOGFILE")) {
	&Append2("$Now $str", $LOGFILE);
	&Append2("$Now    $filename:$line% $s", $LOGFILE) if $s;
    }
    else {
	print STDERR "$Now $str\n\t$s\n";
    }
}


# append $s >> $file
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2 { &Write2(@_, 1);}
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
	print STDERR "Append2(@_)::Error [@caller] \n";
    }

    1;
}


1;
