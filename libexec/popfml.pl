#!/usr/local/bin/perl
#
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
#
# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#
$Rcsid   = 'popfml 4.0';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-h$/ && die (&USAGE);
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
$0 =~ m#(\S+)/(\S+)# && (unshift(@INC, $1)); #for lower task;
unshift(@INC, $DIR); #IMPORTANT @INC ORDER; $DIR, $1(above), $LIBDIR ...;


#################### MAIN ####################
require 'libkern.pl';
require 'libpop.pl';

&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&PopFmlInit;

### POPFML Win32 Version
if ($COMPAT_WIN32) {
    if ($Mode eq 'POP_ONLY') {
	### &PopFmlGobble; (without fork version)
	$status = &Pop'Gobble(*PopConf);#';
	if ($status) { die("Error: $status\n");}
	&PopFmlScan if $debug;
    }
    elsif ($Mode eq 'EXEC_ONLY_ONCE') {
	&PopFmlProg;
    }
    else {
	$status = &Pop'Gobble(*PopConf);#';
	if ($status) { die("Error: $status\n");}
	&PopFmlProg;
    }
}
### UNIX Version
else {
    local($evid);

    if ($HAS_ALARM) {
	# see libkern.pl (Global Jump)
	$Sigalrm = &SetEvent($TimeOut{'flock'} || 3600, 'TimeOut');

	# POP
	# anyway shutdown after 45 sec (60 sec. must be a unit).
	$evid = &SetEvent($TimeOut{'pop:flock'} || 45, "PopFmlProgShutdown");
    }

    # spool -POP3-> pop.queue
    &PopFmlGobble;
    &ClearEvent($evid) if $HAS_ALARM && $evid; # alarm(3) schduling reset;

    # scan pop.queue and fork() and exec()
    # the first &SetEvent 3600 governs sprog's timeout but 
    # this is incorrect if the child process execs "mget" ...
    &PopFmlProg;
}


&CheckQueueIsExpireP;

exit 0;


############################################################
sub PopFmlGetPasswd
{
    local($h, $config_file) = @_;
    my ($c) = 0;
    local($org_sep)  = $/;
    $/ = "\n\n";

    open(NETRC, $config_file) || die("Error: cannot open $config_file [$!]");
    if ($debug) { print STDERR "open password file: $config_file\n";}
    while(<NETRC>) {
	s/\n/ /;
	s/machine\s+(\S+)/$Host = $1/ei;
	if ($Host eq $h && /login\s+$USER/) {
	    $c++;
 	    s/password\s+(\S+)/$Password = $1/ei;
	}
    }
    close(NETRC);

    if ($debug) { if (! $c) { &Log("no such user $USER for Host $h");}}

    $/ =  $org_sep;
}


# getopts
sub PopFmlGetOpts
{
    while (@ARGV) {
	$_ = shift @ARGV;
	/^\-user/ && ($USER = $PopConf{'USER'} = shift @ARGV) && next; 
	/^\-host/ && ($PopConf{'SERVER'} = shift @ARGV) && next; 
	/^\-M/    && ($PopConf{'MAINTAINER'} = shift @ARGV) && next; 
	/^\-f/    && ($ConfigFile = shift @ARGV) && next; 
	/^\-h/    && do { print &USAGE; exit 0;};
	/^\-d/    && $debug++;
	/^\-D/    && $DUMPVAR++;

	# queue directory
	/^\-queue_dir/    && ($PopConf{'QUEUE_DIR'} = shift @ARGV) && next; 

	/^\-include_file/ && ($PopConf{'INCLUDE_FILE'} = shift @ARGV) && next;
	/^\-pwfile/       && ($PopConf{'NETRC'} = shift @ARGV) && next;
	/^\-pop_passwd/   && ($PopConf{'POP_PASSWD'} = shift @ARGV) && next;
	/^\-pop_port/     && ($PopConf{'PORT'} = shift @ARGV) && next;
	/^\-perl_prog/    && ($PerlProg = shift @ARGV) && next;

	/^\-arch/         && ($COMPAT_ARCH = shift @ARGV) && next;
	/^\-expire/       && ($POPFML_QUEUE_EXPIRE_LIMIT = shift @ARGV) && next;

	### mode
	/^\-mode/ && ($Mode = shift @ARGV) && next; 
    }

    if (0 && $debug) {
	while (($k, $v) = each %ENV) { print STDERR "$k\t=>\t$v\n";}
    }

    $MAINTAINER = $conf{'MAINTAINER'};
}


sub USAGE
{
    local($n) = $0;
    $n =~ s#.*/(\S+)#$1#;

qq#
   $n [options] \$DIR [options] \$LIBDIR [options]

   \$DIR     popfml's directory (log, queue, tmp, etc..)
   \$LIBDIR  FML system library

   options:
   -h      this help
   -user   user
   -host   pop server
   -pwfile password file      (.netrc style)
   -f      configuration file (alternative of .popfmlrc)
   -d      debug mode
   -D      dumpvar

   -include_file  include file
   -pwfile        .netrc style 
   -pop_passwd    password
   -perl_prog     perl program path

   -arch          architecture
   -mode          mode
#;
}


sub PopFmlInit
{
    &InitConfig;	# Load config.ph, initialize conf, date,...

    # for logging 
    $From_address = "popfml";

    # flock parameters (/usr/include/sys/file.h)
    $LOCK_SH                       = 1;
    $LOCK_EX                       = 2;
    $LOCK_NB                       = 4;
    $LOCK_UN                       = 8;

    # Defualt Value
    $POPFML_MAX_CHILDREN  = 3;

    $PopConf{'TIMEOUT'}   = 30;
    $PopConf{'QUEUE_DIR'} = "$DIR/var/pop.queue";
    $PopConf{'LOGFILE'}   = "$DIR/var/log/_poplog";
    $PopConf{"PROG"}      = "/usr/local/mh/lib/rcvstore";

    # log file of popfml proceess
    $LOGFILE              = "$DIR/log";

    # search config file
    for ("$ENV{'HOME'}/.popfmlrc", "$ENV{'HOME'}/.popexecrc") { 
	if (-f $_) { $ConfigFile = $_;}
    }

    &PopFmlGetOpts;

    ### NTFML ###
    # load architecture dependent default 
    # here for command line options --COMPAT_ARCH
    if ($ENV{'OS'} =~ /Windows_NT/) {
	$HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 0;
	$COMPAT_ARCH  = "WINDOWS_NT4";
	$COMPAT_WIN32 = 1;

	require "sys/$COMPAT_ARCH/depend.pl";
    }
    ### NTFML ENDS ###

    # debug 
    # for (keys %PopConf) { print STDERR "$_\t$PopConf{$_}\n";}

    # get password for the host;
    if (-f $PopConf{'POP_PASSWD'}) {
	&Debug("popfml: $PopConf{'POP_PASSWD'} 'usr passwd' format file")
	    if $debug;

	$PopConf{"PASSWORD"} = &GetPopPasswd($USER, $PopConf{'POP_PASSWD'});
    }
    else {
	&Debug("popfml: .netrc format file") if $debug;

	&PopFmlGetPasswd($PopConf{'SERVER'}, 
			 $PopConf{'NETRC'} || "$ENV{'HOME'}/.netrc");
	$PopConf{"PASSWORD"} = $Password;
    }

    if (! $PopConf{'USER'}) {
	$PopConf{'USER'} = getlogin || (getpwuid($<))[0];
    }

    for ("/var/mail/$USER", "/var/spool/mail/$USER", "/usr/spool/mail/$USER") {
	if (-r $_) {
	    $PopConf{'MAIL_SPOOL'} = $_;
	    last;
	}
    }

    local($if);
    if ($if = $PopConf{'INCLUDE_FILE'}) {
	if (-f $if) {
	    $PopConf{"PROG"} = &EvalIncludeFile($if);
	}
	else {
	    die("Error: include_file[$if] is defined but not exists.\n");
	}
    }
    elsif (-f $ConfigFile) { 
	package popcf;
	require $main'ConfigFile; #';
	$POPFML_PROG = $POP_EXEC if $POP_EXEC;
	package main;

	$PopConf{"PROG"} = $popcf'POPFML_PROG; #';
    }
    else {
	&Log("not found $ConfigFile");
    }

    # make directories
    for ($VAR_DIR, $PopConf{'QUEUE_DIR'}) {
	-d $_ || &Mkdir($_, 0755) || die("popfml: cannot mkdir $_\n");
    }

    if ($debug) {
	for (keys %PopConf) {
	    if ($_ eq 'PASSWORD') {
		printf STDERR "---PopConf: %-15s => %s\n", $_, '********';
		if (! $PopConf{'PASSWORD'}) {
		    &Log("ERROR: password for user '$USER' is empty");
		    &Log("no more action, exit now");
		    exit 1;
		}
	    }
	    else {
		printf STDERR "---PopConf: %-15s => %s\n", $_, $PopConf{$_};
	    }
	}
    }
}


sub EvalIncludeFile
{
    local($if) = @_;
    local($s);
    
    open(IF, $if) || die("Error: cannot read $if [$!]");
    while (<IF>) {
	chop;
	next if /^\s*$/;
	next if /^\#/;
	
	s/\"//g;

	$s = $_ if /^|/;
    }
    close(IF);
    
    $s =~ s/\|//g;
    $s =~ s#\\#/#g;
    $s = "$PerlProg $s" if $PerlProg;
    $s .= " --COMPAT_ARCH=$COMPAT_ARCH" if $COMPAT_ARCH;
    print STDERR "include[$s]\n" if $debug;

    $s;
}


sub PopFmlGobble
{
    &PopFmlLock;

    undef $!;
    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	# go !
	$status = &Pop'Gobble(*PopConf);#';
	if ($status) { die "Error: $status\n";}
	exit 0;
    }

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }

    &Log("ERROR: PopFmlGobble: $!") if $!;

    &PopFmlUnLock;
}


sub PopFmlProgShutdown
{
    local($sig) = @_;

    print STDERR "--caught SIG$sig ($$)\n";
    print STDERR "--alarm PopFmlProgShutdown ($$)\n";
    exit(0);
}

sub PopFmlLock
{
    # lock this file to ensure only I read/write QUEUE_DIR.
    $PopFmlLockFile = "$PopConf{'QUEUE_DIR'}/lockfile";
    unless (-f $PopFmlLockFile) {
	open(TOUCH, ">> $PopFmlLockFile"); close(TOUCH);
    }

    print STDERR "--try lock ... ($$)\n" if $debug;

    if (open(FML_LOCK, $PopFmlLockFile)) {
	flock(FML_LOCK, $LOCK_EX);
    }
    else {
	&Log("cannot open $PopFmlLockFile");
    }

    print STDERR "--locked ... ($$)\n" if $debug;
}

sub PopFmlUnLock
{
    close(FML_LOCK);
    flock(FML_LOCK, $LOCK_UN);

    print STDERR "--unlocked ($$)\n" if $debug;
}

sub PopFmlProgFreeLock
{
    $PopFmlProgExitP = 1;
    &PopFmlUnLock;
}

sub PopFmlScan
{
    local($queue, $queue_dir, $prog, $qf);
    $queue_dir = $PopConf{'QUEUE_DIR'};

    opendir(DIRD, $queue_dir) || &Log("Cannot opendir $queue_dir");
    for $qf (sort {$a <=> $b} readdir(DIRD)) {
	next if $qf =~ /^\./;

	print STDERR "   debug scan: $qf\n" if $debug;

	if ($qf =~ /prog$/) {
	    ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
             $atime,$mtime,$ctime,$blksize,$blocks) = stat("$queue_dir/$qf");
	    
	    $Queue{$qf} = $ctime;
	    print STDERR "   debug scan: $qf ($ctime)\n" if $debug;
	}
    }
    closedir(DIRD);
}


sub CheckQueueIsExpireP
{
    local($buf, $cur_time, $queue, $queue_dir, $qel);
 
    ### Initialize
    ### InitConfig defines $DOMAINNAME;
    local($m);
    $m = $HAS_GETPWUID ? (getpwuid($<))[0] : 
	($ENV{'USER '}|| $ENV{'USERNAME'});
    $MAINTAINER = "$m\@$DOMAINNAME";

    $HOST = $PopConf{'SERVER'};
    ### Initialize ends

    # scan
    &PopFmlScan;

    # 3 hours
    $POPFML_QUEUE_EXPIRE_LIMIT = $POPFML_QUEUE_EXPIRE_LIMIT || 3*3600;

    # current time
    $cur_time  = time;
    $queue_dir = $PopConf{'QUEUE_DIR'};

    &Log("check queue $queue_dir") if $debug;

    if ($POPFML_QUEUE_EXPIRE_LIMIT > 3600) {
	$qel = sprintf("%.1f hours", $POPFML_QUEUE_EXPIRE_LIMIT/3600);
    }
    elsif ($POPFML_QUEUE_EXPIRE_LIMIT == 3600) {
	$qel = "1 hour";
    }
    else {
	$qel = "$POPFML_QUEUE_EXPIRE_LIMIT secs";
    }

    # check the current queue
    for $qf (keys %Queue) {
	$uiq   = "$queue_dir/$qf.ui";
	$queue = "$queue_dir/$qf";

	&Log("check queue $qf") if $debug;

	# created time is 3 hours before.
	if (($cur_time - $Queue{$qf}) > $POPFML_QUEUE_EXPIRE_LIMIT) {
	    &Log("queue $qf is timed out.");

	    eval("require \"$uiq\";") if -f $uiq;
	    &Log($@) if $@;

	    undef $buf;
	    $buf  = "Popfml:\n";
	    $buf .= "Queue $qf is created before $qel but not processed.\n";
	    $buf .= "Queue $qf is timed out.\n";
	    $buf .= "\n------- Forwarded Message\n\n";
	    open(F, $queue) || &Log("cannot open $queue");
	    while (<F>) { $buf .= $_;}
	    close(F);
	    $buf .= "\n\n------- End of Forwarded Message\n";

	    # XXX malloc()
	    &Sendmail($MAINTAINER, "popfml: timeout queue $qf", $buf);

	    $status = unlink $queue;

	    if ($status) {
		&Log("unlink $queue for timeout");
	    }
	    else {
		&Log("cannot unlink $queue");
	    }
	    
	    unlink $uiq if -f $uiq;
	}
    }
}


sub PopFmlProg
{
    local($queue, $queue_dir, $prog, $qf);

    $queue_dir = $PopConf{'QUEUE_DIR'};
    $prog  = $PopConf{'PROG'};
    $prog =~ s/^\|+//;

    &Debug("--PopFmlProg (\n\tqueue_dir=$queue_dir\n\tprog=$prog\n)")
	if $debug;

    &PopFmlLock;

    opendir(DIRD, $queue_dir) || &Log("Cannot opendir $queue_dir");
    for $qf (sort {$a <=> $b} readdir(DIRD)) {
	print STDERR "   scan: $qf\n" if $debug;

	next if $qf =~ /^\./;
	next if $qf =~ /\.prog$/;
	next if $qf =~ /\.ui$/; # user credential

	last if $ForkCount >= $POPFML_MAX_CHILDREN;
	last if $PopFmlProgExitP;

	$queue = "$queue_dir/$qf";

	print STDERR "   queue: $queue\n" if $debug;

	# checks the current progs (if exists, fatal error since unlocked);
	# againt another context doing the processing...;
	next if -f "${queue}.prog";


	if (-f "${queue}.prog") {
	    # NOT MATCH THIE CONDISION, but should do the error handling;
	    &Log("PopFmlProg Fatal Error ${queue}.prog exists!");
	}
	# anyway touch; (here flocked state);
	elsif (-f $queue) {
	    open(TOUCH, ">> ${queue}.prog"); close(TOUCH);

	    # setup the prog
	    if (! rename($queue, "${queue}.prog")) {
		unlink "${queue}.prog";
		&Log("Cannot setup the prog for $queue, exit");
		exit(1);
	    }

	    # change the queue file name after setup;
	    $queue = "${queue}.prog";

	    print STDERR "   exec: $queue\n" if $debug;
	}


	# fork and exec
	if ($COMPAT_WIN32) { 
	    &PopFmlDoExec($qf, $queue, $prog);
	}
	else {
	    ### FORKED, CHILDREN IS THE MAIN PROG ###
	    if (($pid = fork) < 0) {
		&Log("Cannot fork");
	    }
	    elsif (0 == $pid) {	# child;
		&PopFmlDoExec($qf, $queue, $prog);
		exit 0;
	    }
	}

	$ForkCount++; # parent;

	if ($Mode eq 'EXEC_ONLY_ONCE') {
	    &Log("ends for EXEC_ONLY_ONCE");
	}
    }
    
    # O.K. Setup the prog of the queue; GO!
    undef $SIG{'ALRM'};
    alarm(0) if $HAS_ALARM;

    &PopFmlUnLock;
    closedir(DIRD);

    &Log("fork $ForkCount child")    if $ForkCount == 1;
    &Log("fork $ForkCount children") if $ForkCount > 1;

    print STDERR "---PopFmlProg Ends\n" if $debug;

    # NTPERL has no wait(), fork(), ...
    if ($COMPAT_WIN32) { return 1;}

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}


sub PopFmlDoExec
{
    local($qf, $queue, $prog) = @_;
    local($pid, $uiq);

    # log info
    $uiq = "${queue}.ui";

    if ($debug) {
	print STDERR "--PopFmlDoExec [$qf] ... ($$)\n";
	print STDERR "   $prog\n\n";
    }

    if (open(QUEUE_IN, $queue)) {
	&Debug("open $queue") if $debug;
    }
    else {
	&Log("cannot open $queue");
	return 0;
    }

    if (open(PROG_IN, "|$prog")) {
	&Debug("open |$prog") if $debug;
    }
    else {
	&Log("cannot exec [$prog] for $queue");
	return 0;
    }

    while (<QUEUE_IN>) { 
	s/^From /From /; # ???
	print PROG_IN $_;
    }

    close(PROG_IN);
    close(QUEUE_IN);

    unlink $uiq   || &Log("PopFmlProg: fails to remove the queue $uiq");
    unlink $queue || &Log("PopFmlProg: fails to remove the queue $qf");
}


sub Grep
{
    local($key, $file) = @_;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/i;}
    close(IN);

    $NULL;
}


sub GetPopPasswd
{
    local($ml, $f) = @_;
    local($buf, @buf);

    $buf = &Grep("^$ml", $f);
    $buf =~ s/[\r\n]+$//g;
    (split(/\s+/, $buf, 2))[1];
}


### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

1;
