#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;
$Rcsid   = 'fml 2.0 Exp #: Wed, 29 May 96 19:32:37  JST 1996';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);
$0 =~ m#(\S+)/(\S+)# && (unshift(@INC, $1)); #for lower task;

#################### MAIN ####################
# including libraries

&SraqInit;
&Log("$0 Started PORT=$PORT");
&SraqDeliver(@ARGV);

chdir $DIR || do {
    &Log("Can't chdir to $DIR");
    die "Can't chdir to $DIR\n";
};


eval alarm($TIMEOUT || 45); 
open(LOCK, $DIR); # spool is also a file!
flock(LOCK, $LOCK_EX);

opendir(DIR, $DIR) || die $!;

undef $TimeOutP;

foreach (readdir(DIR)) {
    last if $TimeOutP; # TIMEOUT;

    next if /^\s+$/;
    next if /^\./;
    next if /^\,/; # already delivered file ,\S+

    print STDERR "Delivery $DIR/$_ ... [$$]\n";

    &SraqDeliver($DIR, $_);
}

closedir(DIR);

&closelog; # syslog;

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####
sub Log
{
    &openlog('sraq2smtp', 'cons,pid', 'user');
    &syslog('notice', @_);
}


sub SraqInit
{
    # flock()
    $LOCK_SH = 1;
    $LOCK_EX = 2;
    $LOCK_NB = 4;
    $LOCK_UN = 8;

    # time
    &GetTime;

    # DNS
    chop($hostname = `hostname`);
    local($n, $a) = (gethostbyname($hostname))[0,1];
    foreach (split(/\s+/, "$n $a")) { /^$hostname\./ && ($FQDN = $_);}
    $FQDN       =~ s/\.$//; # for e.g. NWS3865
    $DOMAINNAME = $FQDN;
    $DOMAINNAME =~ s/^$hostname\.//;

    # config
    $MAINTAINER = "postmaster\@$FQDN";


    umask (077);			# rw-------
    &SetOpts;
    &GetTime;			        # Time

    # signal handling
    $SIG{'ALRM'} = 'TimeOut';

    require 'syslog.pl';
}


sub SraqDeliver
{
    local($dir, $q) = @_;
    local(@Rcpt, %e, $status);

    return unless -f  "$dir/$q";

    open(QUEUED_FILE, "$dir/$q") || &Log("cannot open $dir/$q");

    while (<QUEUED_FILE>) {
	chop;
	last if /^BODY/;
	next if /^FROM /;
	if (/^RCPT\s+(\S+)/) { unshift(@Rcpt, $1);}
    }

    while (<QUEUED_FILE>) { $e{'Body'} .= $_;}

    close(QUEUED_FILE);

    print STDERR "   ($dir/$q)::Deliver { @Rcpt } [$$]\n";

    # 
    return unless @Rcpt;

    $status = &Smtp(*e, *Rcpt);
    &Log($status) if $status;

    # O.K.
    if (! $status) { 
	&Log("$q delivered to @Rcpt");
	rename("$dir/$q", "$dir/,$q") || &Log($!);
    }
    else {
	&Log("$q FAILS to be delivered to @Rcpt");
   }
}



#######################################################

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
			$year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}



# Getopt
sub Opt { push(@SetOpts, @_);}
    
# Setting CommandLineOptions after include config.ph
sub SetOpts
{
    # should pararelly define ...
    for (@SetOpts) { /^\-\-MLADDR=(\S+)/i && (&use("mladdr"), &MLAddr($1));}
    for (@SetOpts) { /^\-\-([a-z0-9]+)$/  && (&use("modedef"), &ModeDef($1));}
    for (@SetOpts) {
	if (/^\-\-(force|fh):(\S+)=(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"fh:$h:"} = $3;
	}
	elsif (/^\-\-(original|org|oh):(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"oh:$h:"} = 1;
	}
	elsif (/^\-\-(\S+)=(\S+)/) {
	    eval("\$$1 = '$2';"); next;
	}
	elsif (/^\-\-(\S+)/) {
	    local($_) = $1;
	    /^[a-z0-9]+$/ ? ($Envelope{"mode:$_"} = 1) : eval("\$$_ = 1;"); 
	    /^permit:([a-z0-9:]+)$/ && ($Permit{$1} = 1); # set %Permit;
	    next;
	}

	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }
   
}


sub Funlock 
{
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}

sub TimeOut
{
    &Log("Caught ARLM Signal of TIMEOUT; Ending the current process ...");   
    $TimeOutP = 1;
    return;
}



######################################################################

# sys/socket.ph is O.K.?
sub Smtp
{
    local(*e, *rcpt) = @_;

    $eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
    $eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
    eval($eval);

    @smtp = ("HELO $FQDN", "MAIL FROM: $MAINTAINER");
    $host = $FQDN;

    open(SMTPLOG, "> /tmp/_smtplog") || &Log($!);

    local($pat)    = 'S n a4 x8'; # 'S n C4 x8'? which is correct? 
    local($addrs)  = (gethostbyname($host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = (getservbyname('smtp', 'tcp'))[2];
    $port          = 25 unless defined($port); # default port

    # sraq use a special port to communicate with the sendmail
    $port          = $PORT || $port;

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
	return ($error = "Smtp::socket->Error[$!]");
    }
    
    if (connect(S, $target)) { 
	print SMTPLOG "connect ok\n"; 
    } 
    else { 
	return ($error = "Smtp::connect($host)->Error[$!]");
    }

    ### need flush of sockect <S>;
    select(S); $| = 1; select(STDOUT);

    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    foreach $s (@smtp, 'm_RCPT', @rcpt, 'm_RCPT', 'DATA') {
	next if $s =~ /^\s*$/o;

	# RCPT TO:; trick for the less memory use;
	if ($s eq 'm_RCPT') { $in_rcpt = $in_rcpt ? 0 : 1; next;}
	$s = "RCPT TO: $s" if $in_rcpt;
	
	$0 = "-- $s <$FML $LOCKFILE>"; 

	print SMTPLOG ($s . "<INPUT\n");
	print S ($s . "\n");

	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    ### (HELO .. DATA) sequence ends

    if ($e{'Hdr'}) {
	print SMTPLOG $e{'Hdr'}."\n";
	print S $e{'Hdr'}."\n";
	$LastSmtpIOString = $e{'Hdr'};
    }

    if ($e{'Body'}) {
	$e{'Body'} =~ s/\n\./\n../g; # rfc821 4.5.2 TRANSPARENCY
	print SMTPLOG $e{'Body'};
	print S $e{'Body'};
	$LastSmtpIOString = $e{'Body'};
    }

    ### close smtp with '.'
    print S "\n" unless $LastSmtpIOString =~ /\n$/;	# fix the last 012
    print S ".\n";

    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    print S "QUIT\n";
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
}

1;
