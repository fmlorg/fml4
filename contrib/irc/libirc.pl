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

### MAIN ###
local($pid, $dying);

if ($0 eq __FILE__) {
    &IrcParseArgv;

    if (($pid = fork) < 0) {
	die("cannot fork\n");
    }
    elsif (0 == $pid) {
	$NetIRC'LOGFILE = "$ENV{'PWD'}/log"; #';
	eval q#sub Log { &NetIRC'Log(@_);}#; #';

	# program name
	$Prog = $0;
	$Prog =~ s#.*/##;
	$Prog =~ s#\.pl$##;

	for (;;) {
	    ### configuration reset ###
	    # signal handling
	    $SIG{'HUP'} = $SIG{'INT'} = $SIG{'QUIT'} = 
		$SIG{'TERM'} = "irc'Exit";#';

	    ### (re)start Initialize ###
	    &IrcInit;
	    &IrcConnect;

	    # infinite loop (but it ends up if anything error occurs).
	    # stdin -> buffer <-> irc server
	    &IrcMainLoop($Prog);

	    ### end ###
	    close(S);
	    shutdown(S, 2);

	    sleep 3;
	    &Log("$Prog restarting ...");
	}
    }

    # In debug mode I do not detach the child process.
    # Wait for the child to terminate.
    if ($debug) {
	while (($dying = wait()) != -1 && ($dying != $pid)){ ;}
    }

    # parent end
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
    &Getopts("df:I:t:hL:H:");

    if ($opt_h) {
	$s = $0;
	$s =~ s#.*/##;
	$s = qq#USAGE:;
	$s [-dh] [-I INC] [-t title] [-L file] -f file;
	;
	-f file  perl configuration file (required);
	;
	-L file  log file;
	-I INC   add include path to \@INC;
	-t title setproctitle(title);
	-H a:b:c HOSTS to monitor (ircstat option)
	;
	-d       debug mode;
	-h       this message;
	;#;
	$s =~ s/;//g;
	print STDERR $s, "\n";
	exit 0;
    }

    # now 'irc' name space;
    $debug = $NetIRC'debug = $main'debug = $opt_d ? 1 : 0;

    $SetProcTitle = $opt_t;

    # load config.ph
    if (!-f $opt_f) { die("cannot load config file, stop.\n");}
    require $opt_f;

    # include path
    push(@INC, $opt_I);

    # import -> @irc::STAT_HOST
    if ($opt_H) {
	@STAT_HOST  = split(/:/, $opt_H);
	$STAT_UNIT  = $#STAT_HOST + 1;
    }
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
    local(@x);
    for ("USER $IRC_USER * * :$IRC_NAME",
	 "NICK $IRC_NICK",
	 "PING FML-IRC-FIRST",
	 "JOIN $IRC_CHANNEL"
	 ) {
	push(@x, $_);
    }

    unshift(@Queue, @x);
}


sub Exit
{
    local($sig) = @_; 
    &Log("Caught SIG${sig}, shutting down");
    &Log("Send QUIT To Server");
    &SendS("QUIT :$IRC_SIGNOFF_MSG");
    sleep 2;
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
    while ($status = &DoConnect(*IRC_SERVER, *error)) {
	print STDERR "status=$status\n" if $debug;
	&Log($status) if $status;
	sleep 2;
    }
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
	&Log("socket ok");
    } 
    else { 
	return ($error = "Irc::socket->Error[$!]");
    }
    
    if (connect(S, $target)) { 
	&Log("connect($host:$port) ok");
    } 
    else { 
	return ($error = "Irc::connect($host:$port)->Error[$!]");
    }

    ### need flush of sockect <S>;
    select(S); $| = 1; select(STDOUT);

    $error = "";
}


sub main'IrcMainLoop  #'
{
    local($mode) = @_;
    local($rin, $win, $ein);
    local($rout, $wout, $eout);
    local($buf, $wbuf, $reset, $count);

    # server not recognize me!
    $TrapPattern = 'not registered';

    ### ircstat
    if ($mode eq 'ircstat') {
	$RecvYes   = 1;
	$StatQuery = 0;
	$StatCount = 0;
	$LastRecv  = time;

	$STAT_UNIT || die("$mode: -H host is required\n");

	# host to monitor
	$NextStatHost = $STAT_HOST = $STAT_HOST[$StatCount++ % $STAT_UNIT];
    }

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
	if ($reset) {
	    $GlobalErrorCount++;
	    last;
	}

	$0 = "--$mode $SetProcTitle";

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

	# Server Socket
	if (vec($rout, $BITS{'S'}, 1)) {
	    sysread(S, $buf, 4096) || do { 
		if ($!) { &Log("S sysread: $!");} 
		$reset = 1;
	    };

	    if ($debug) {
	        &GetTime(time);
		for (split(/\n/, $buf)) {
		    if (/$TrapPattern/) { $reset = 1;}
		    print STDERR "----- $Now> $_\n";
		}
	    }
	}

	# input channel
	if (($mode eq 'stdin2irc') && vec($rout, $BITS{'STDIN'}, 1)) {
	    sysread(STDIN, $buf, 4096) || do { 
		if ($!) { &Log("STDIN sysread: $!");}
		$reset = 1;
	    };

	    for (split(/\n/, $buf)) {
		print STDERR ">>> $_\n" if $debug;
		push(@Queue, "PRIVMSG $IRC_CHANNEL :$_");
	    }
	}


	### analyze buffer
	# ircstat
	if ($mode eq 'ircstat' && $StatQuery) {
	    # wait for reply we expect
	    if ($buf) {
		$RecvYes = &NetIRC'StatLog(*buf); #';
	    }

	    if ((time - $LastRecv) > 60) {
		&Log("ircstat: wait reply for ".(time - $LastRecv)." secs.");
	    }
	    
	    if ($RecvYes) {
		$StatQuery = 0;
		$LastRecv  = time;

		# host to monitor
		$STAT_HOST = $STAT_HOST[$StatCount++ % $STAT_UNIT];
		$StatCount = $StatCount % $STAT_UNIT;
		undef $NextStatHost;

		# debug :-)
		push(@Queue, "PRIVMSG $IRC_CHANNEL :$RecvYes");
	    }
	    else {
		# next;
	    }
	}


	### reset flag, not continue ### 
	next if $reset;
	# O.K. We can write to IRC server. Trun off error flag.
	$GlobalErrorCount = 0 if $count > 5;

	# wait
	sleep 2; # RFC1459 defines "1 message per 2 secs". (theory)
	sleep int(log(length(@Queue) + 3)); # experimental (3 for 'e').

	# write the buffer to server
	$wbuf = &GetNextBuffer($mode);
	&GetTime(time);
	print STDERR "--wbuf <$wbuf> ($Now)\n" if $debug;
	&SendS($wbuf) if $wbuf;

	# counter
	$count++;

	# ping, pong
	if ($count % 10 == 0) { 
	    &SendS("PING $IRC_SERVER");
	    $count = 0;
	}
    }

    &Log("anyway wait for $GlobalErrorCount sec;");
    sleep($GlobalErrorCount % 16); # max 15 sec.
}


########## SWITCH

# stdin2irc
sub GetNextBuffer
{
    local($m) = @_;

    if ($m eq 'stdin2irc') {
	shift @Queue;
    }
    elsif ($m eq 'ircstat') {
	if (@Queue) {
	    shift @Queue;
	}
	else {
	    &GetTime(time);
	    # 59,58,57
	    if (((59 - $sec) % 30) < 3*$IRC_TIMEOUT) {
		sleep(((59 - $sec) % 30) + 1); # align at 0 sec:-)
		$StatQuery = 1;
		"LUSERS $STAT_HOST";
	    }
	    else {
		$NULL;
	    }
	}
    }
    elsif ($m eq 'q2irc') {
	&QueueToIrc;
    }
    else {
	shift @Queue;
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
	    sysread(S, $buf, 4096) || do { 
		if ($!) { &Log("sysread: $!");} 
	    };
	    if ($debug) {
		for (split(/\n/, $buf)) { print STDERR "--- $_\n";}
	    }
	}
    }
}


package NetIRC;

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
	print STDERR "$Now $str\n" if $debug;
	print STDERR "\t$s\n"  if $debug && $s;
    }
    else {
	print STDERR "$Now $str\n";
	print STDERR "\t$s\n" if $s;
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


### ircstat
sub StatLog
{
    local(*buf) = @_;
    local(@x) = split(/\n/, $buf);

    for (@x) {
	if (/.*:.*\s+(\d+\s+user\w+)/) {
	    &Log($_ = "$irc'STAT_HOST: $1"); #';
	    return($_ ? $_ : 1);
	}
    }

    0;
}

1;
