#!/usr/local/bin/perl
#
#

### MAIN ###
&Init;
&SocketInit;
&IrcConnect(*HOST, *error);
&SetUpSelect;

$timeout = 2;

for (;;) {
    ($nfound, $timeleft) =
	select($rout=$rin, $wout=$win, $eout=$ein, $timeout);

    if (vec($rout, $S_BITS, 1)) {
	sysread(S, $buffer, 4096) || &Log("Error:$!");
	for (split(/\n/, $buffer)) { print STDERR "--- $_\n";}
    }

    if (vec($rout, $I_BITS, 1)) {
	sysread(STDIN, $buffer, 4096) || &Log("Error:$!");

	for (split(/\n/, $buffer)) {
	    # print STDERR "PRIVMSG $CHANNEL :$_\n" if $debug;
	    push(@Queue, "PRIVMSG $CHANNEL :$_\n");
	}
    }

    sleep 1;
    $wbuf = shift @Queue;
    &SendS($wbuf) if $wbuf;
}

&SendS("AWAY :$IRC_SIGNOFF_MSG\n");

exit 0;

### MAIN ENDS ###


sub Log { print STDERR "LOG: @_\n";}


sub Init
{
    require 'getopts.pl';
    &Getopts("df:");

    $debug = $opt_d;
    if (!-f $opt_f) { die("cannot load config file, stop.\n");}

    require $opt_f;

    push(@INC, $PERL_LIB_PATH);
    require 'jcode.pl';

    open(SMTPLOG, ">/dev/stderr") || die($!);

    eval "&jcode'init;";
    &jcode'convert(*IRC_NAME, 'jis'); #';
    &jcode'convert(*CHANNEL, 'jis'); #';
    &jcode'convert(*IRC_USER, 'jis'); #';
    &jcode'convert(*IRC_NAME, 'jis'); #';
    &jcode'convert(*IRC_NICK, 'jis'); #';
    &jcode'convert(*IRC_SIGNOFF_MSG, 'jis'); #';

    @Queue = ("USER $IRC_USER * * :$IRC_NAME\n",
	      "NICK $IRC_NICK\n",
	      "PING FML-IRC-FIRST\n",
	      "JOIN $CHANNEL\n"
	      );

    # signal
    $SIG{'HUP'} = $SIG{'INT'} = $SIG{'QUIT'} = $SIG{'TERM'} = 'Exit';
}


sub Exit
{
    local($sig) = @_; 
    &Log("Caught SIG${sig}, shutting down");
    &Log("Send QUIT To Server");
    &SendS("QUIT :$IRC_SIGNOFF_MSG\n");
    sleep 1;
    exit(0);
}


sub SetUpSelect
{
    $S_BITS = fileno(S);
    $I_BITS = fileno(STDIN);

    $rin = $win = $ein = "";
    vec($rin,fileno(S),1) = 1;
    vec($rin,fileno(STDIN),1) = 1;
    $ein = $rin | $win;

    if ($debug_fileno) {
	print STDERR "----\n";
	print STDERR join(" ", split(//, unpack("b*", $rin))), "\n";
	print STDERR join(" ", split(//, unpack("b*", $win))), "\n";
	print STDERR join(" ", split(//, unpack("b*", $ein))), "\n";
	print STDERR "---------\n";
    }
}


sub SendS
{
    local($s) = @_;
    print S $s;
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


# Connect $host to SOCKET "S"
# RETURN *error
sub IrcConnect
{
    local(*host, *error) = @_;

    local($pat)    = $STRUCT_SOCKADDR;
    local($addrs)  = (gethostbyname($host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = $Port || $PORT || (getservbyname('irc', 'tcp'))[2];
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


1;
