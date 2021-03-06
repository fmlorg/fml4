#!/usr/local/bin/perl

# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.



local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

sub USAGE
{
    local($s);

    $s = q#;
    ntfml.pl [-user username] [-h host] [-fhd];
    ;
    -user username;			
    -pwfile password-file;
    -host host(pop server hostname);
    -f    config-file;
    -h    this message;
    -d    debug mode;#;
    $s =~ s/;//g;
    "$s\n\n";
}


sub PopGetopt 
{
    local(@ARGV) = @_;

    # getopts
    while(@ARGV) {
	$_ =  shift @ARGV;
	/^\-user/ && ($USER = shift @ARGV) && next; 
	/^\-pass/ && ($PASS = shift @ARGV) && next; 
	/^\-host/ && ($HOST = shift @ARGV) && next; 
	/^\-f/    && ($ConfigFile = shift @ARGV) && next; 
	/^\-h/    && do { print &USAGE; exit 0;};
	/^\-d/    && $debug++;
	/^\-D/    && $DUMPVAR++;

	/^\-pwfile/ && ($PW_FILE = shift @ARGV) && next; 

	$DIR = $_;
    }
}


sub PopInit
{
    $USER   = $USER || getlogin || (getpwuid($<))[0] || 
	die "USER not defined\n";

    $MAIL_SPOOL = $MAIL_SPOOL || 
	(-r "/var/mail/$USER"       && "/var/mail/$USER") ||
	    (-r "/var/spool/mail/$USER" && "/var/spool/mail/$USER") ||
		(-r "/usr/spool/mail/$USER" && "/usr/spool/mail/$USER");

    local($pipe) =  (-f '/dev/stderr') ? '>/dev/stderr' : '|cat 1>&2';
    open(POPLOG, $pipe) || &Log("cannot set output of error log");

    if ($POP_EXEC) {
	;			# Already defined. O.K.
    }
    elsif (-f "/usr/local/lib/mh/rcvstore") {
	$POP_EXEC = "|/usr/local/lib/mh/rcvstore";
    }
    elsif (-f "/usr/local/mh/lib/rcvstore") {
	$POP_EXEC = "|/usr/local/mh/lib/rcvstore";
    }
    else {
	$POP_EXEC = ">> $MAIL_SPOOL";
    }

    ##### PERL 5  
    eval "use Socket;", $perl5_p = $@ eq "";
    &Log(($perl5_p ? "O.K.": "fail.")." Perl 5, use Socket") if $debug;
    $perl5_p && return 1;

    ##### PERL 4
    $exist_socket_h_p = eval "require 'sys/socket.ph';", $@ eq "";
    &Log("sys/socket.ph is O.K.") if $exist_socket_h_p && $debug;

    if ((! $exist_socket_h_p) && $COMPAT_SOLARIS2) {
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
	undef $eval;
    }
    elsif (! $exist_socket_h_p) {	# 4.4BSD
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
	undef $eval;
    }
}


sub PopConnect # ($host, $headers, $body)
{
    local($host) = @_;

    local($pat)   = 'S n a4 x8';
    local($addrs) = (gethostbyname($host))[4];
    local($port)  = (getservbyname('pop3', 'tcp'))[2];
    $port = 110 unless defined($port); # default port
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    @addr = unpack('C4',$addr);

    print STDERR "addr=[@addr]";
    print STDERR " \n"; 
    print STDERR "pack($pat, &AF_INET, $port, $addrs); \n";

    # IPC open
    if (socket(S, &PF_INET, &SOCK_STREAM, $proto)) { 
	print STDERR  "socket ok\n";
    } 
    else { 
	return "Pop:sockect:$!";
    }

    if (connect(S, $target)) { 
	print STDERR  "connect ok\n"; 
    } 
    else { 
	return "Pop:connect:$!";
    }

    # need flush of sockect <S>;
    select(S);       $| = 1; select(STDOUT);
    select(STDERR);  $| = 1; select(STDOUT);

    # the first "OK.. session"
    print STDERR $_ = <S>; /^\-/o && &Log($_) && (return "$_");

    print S "USER $UserName\n";
    print STDERR "USER $UserName\n";
    print STDERR $_ = <S>; /^\-/o && &Log($_) && (return "$_");

    print S "PASS $Password\n";
    print STDERR "PASS \$Password\n";
    print STDERR $_ = <S>; /^\-/o && &Log($_) && (return "$_");

    &PopTalk2Server;

    print S "QUIT\n";
    print STDERR $_ = <S>; 

    close S; 
    close STDERR;

    0;#return status
}


sub PopTalk2Server
{
    umask(077);

    print STDERR "STAT\n";
    print S "STAT\n";
    print STDERR $_ = <S>; /^\-/o && &Log($_) && (return "$_");
    /^\+OK\s+(\d+)/ && ($n = $1);

    if (! $POP_EXEC) { die("\$POP_EXEC IS NOT DEFINED\n");}

    for ($i = 1; $i <= $n; $i++) {
	print S "RETR $i\n";
	print STDERR "RETR $i\n";
	print STDERR $_ = <S>; /^\-/o && last;

	### FILE RETRIEVE
	open(FILE, $POP_EXEC) || next;
	select(FILE); $| = 1; select(STDOUT);
	for( ; ; ) { 
	    $_ = <S>; 
	    s/\015$//;
	    last if /^\.$/;
	    print FILE $_;
	}
	close(FILE);

	### FILE REMOVE
	print S "DELE $i\n";
	print STDERR "DELE $i\n";
	print STDERR $_ = <S>; /^\-/o && last;
    }
}


sub NTFml
{
    print "--CHECK if (-f ./$ConfigFile) in ( @INC )\n\n" if $debug;
    if (-f $ConfigFile) { require ($ConfigFile);}

    # VARIABLES:
    $host       = $HOST || $host || 'localhost';

    $UserName = $USER;
    $Password = $PASS;

    if (! $Password) {
	open(PW, $PW_FILE) || &Log("Cannot open $PW_FILE");
	chop($Password = <PW>);
	$Password =~ s/\s*\015$//;
	$Password =~ s/\s*$//;
    }

    # Initialize
    &PopInit;			# sys/socket.ph

    $status = &PopConnect($HOST);
    &Log($status);
}


# eval and print error if error occurs.
sub eval
{
    local($exp, $s) = @_;

    eval($exp);
    &Log("$s:".$@) if $@;

    return 1 unless $@;
}



############################################################
if ($0 eq __FILE__) {
    print "ARGV\t@ARGV\n";

    &PopGetopt(@ARGV); 

    chop($PWD = `cd`);
    $EXEC_DIR =~ s/\\/\//g;
    print "exec_dir [$EXEC_DIR]\n";

    $POP_EXEC = "|perl fml.pl $PWD/$DIR $PWD . --HOST=$HOST";
    print STDERR "POP_EXEC\t$POP_EXEC\n";

    # "perl ntfml.pl -host $HOST -user $ML -pwfile $pwfile";
    &NTFml($HOST || $ARGV[0] || 'localhost');

    sub Log { print STDERR "LOG: ".join(" ", @_)."\n";}
}
############################################################

1;
