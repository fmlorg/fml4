#!/usr/local/bin/perl
#
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
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
# $Id$;
$Rcsid   = 'fmlserv #: Wed, 29 May 96 19:32:37  JST 1996';

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
    # require 'arch/Win32/libwin32.pl';
    # require 'libwin32.pl';

    ### &PopFmlGabble; (without fork version)
    $status = &Pop'Gabble(*PopConf);#';
    if ($status) { die("Error: $status\n");}

    ### &PopFmlProg;
    &PopFmlProg;
}
### UNIX Version
else {
    # anyway shutdown after 45 sec (60 sec. must be a unit).
    $SIG{'ALRM'} = "PopFmlProgShutdown";
    alarm($TimeOut{"pop:flock"} || 45) if $HAS_ALARM;

    # spool -POP3-> pop.queue
    &PopFmlGabble;

    # scan pop.queue and fork() and exec()
    &PopFmlProg;
}

exit 0;


############################################################
sub PopFmlGetPasswd
{
    local($h, $config_file) = @_;
    local($org_sep)  = $/;
    $/ = "\n\n";

    open(NETRC, $config_file) || die("Error::Open $config_file [$!]");
    while(<NETRC>) {
	s/\n/ /;
	s/machine\s+(\S+)/$Host = $1/ei;
	if ($Host eq $h && /login\s+$USER/) {
 	    s/password\s+(\S+)/$Password = $1/ei;
	}
    }
    close(NETRC);

    $/ =  $org_sep;
}


# getopts
sub PopFmlGetOpts
{
    while (@ARGV) {
	$_ = shift @ARGV;
	/^\-user/ && ($USER = $PopConf{'USER'} = shift @ARGV) && next; 
	/^\-host/ && ($PopConf{'SERVER'} = shift @ARGV) && next; 
	/^\-f/    && ($ConfigFile = shift @ARGV) && next; 
	/^\-h/    && do { print &USAGE; exit 0;};
	/^\-d/    && $debug++;
	/^\-D/    && $DUMPVAR++;

	/^\-include_file/ && ($PopConf{'INCLUDE_FILE'} = shift @ARGV) && next;
	/^\-pwfile/       && ($PopConf{'NETRC'} = shift @ARGV) && next;
	/^\-pop_passwd/   && ($PopConf{'POP_PASSWD'} = shift @ARGV) && next;
	/^\-perl_prog/    && ($PerlProg = shift @ARGV) && next;

	/^\-arch/         && ($COMPAT_ARCH = shift @ARGV) && next;
    }

    if (0 && $debug) {
	while (($k, $v) = each %ENV) { print STDERR "$k\t=>\t$v\n";}
    }
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

	require "arch/$COMPAT_ARCH/depend.pl";
    }
    ### NTFML ENDS ###

    # debug 
    # for (keys %PopConf) { print STDERR "$_\t$PopConf{$_}\n";}

    # get password for the host;
    if (-f $PopConf{'POP_PASSWD'}) {
	print STDERR "POP3: user passwd format file\n" if $debug;
	$PopConf{"PASSWORD"} = &GetPopPasswd($USER, $PopConf{'POP_PASSWD'});
    }
    else {
	print STDERR "POP3: .netrc format file\n" if $debug;
	&PopFmlGetPasswd($PopConf{'SERVER'}, 
			 $PopConf{'NETRC'} || "$ENV{'HOME'}/.netrc");
	$PopConf{"PASSWORD"}  = $Password;
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


sub PopFmlGabble
{
    $! = "";
    &PopFmlLock;

    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	# go !
	$status = &Pop'Gabble(*PopConf);#';
	if ($status) { die "Error: $status\n";}
	exit 0;
    }

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }

    &Log("Gabble Error: $!") if $!;


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
    local($queue_dir) = $PopConf{'QUEUE_DIR'};

    print STDERR "--try lock ... ($$)\n" if $debug;

    open(LOCK, $queue_dir);
    flock(LOCK, $LOCK_EX);

    print STDERR "--locked ... ($$)\n" if $debug;
}

sub PopFmlUnLock
{
    close(LOCK);
    flock(LOCK, $LOCK_UN);

    print STDERR "--unlocked ($$)\n" if $debug;
}

sub PopFmlProgFreeLock
{
    $PopFmlProgExitP = 1;
    &PopFmlUnLock;
}

sub PopFmlProg
{
    local($queue, $queue_dir, $prog, $qf);

    $queue_dir = $PopConf{'QUEUE_DIR'};
    $prog  = $PopConf{'PROG'};
    $prog =~ s/^\|+//;

    print STDERR "--PopFmlProg (\n\tqueue_dir=$queue_dir\n\tprog=$prog\n)\n"
	if $debug;

    &PopFmlLock;

    opendir(DIRD, $queue_dir) || &Log("Cannot opendir $queue_dir");
    for $qf (sort {$a <=> $b} readdir(DIRD)) {
	print STDERR "   scan: $qf\n" if $debug;

	next if $qf =~ /^\./;
	next if $qf =~ /\.prog$/;

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
    }
    
    # O.K. Setup the prog of the queue; GO!
    undef $SIG{'ALRM'};
    alarm(0) if $HAS_ALARM;

    &PopFmlUnLock;
    closedir(DIRD);

    &Log("fork $ForkCount childrens") if $ForkCount;

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
    local($pid);

    print STDERR "--PopFmlDoExec [$qf] ... ($$)\n" if $debug;
    print STDERR "   $prog\n\n" if $debug;

    if (! open(QUEUE_IN, $queue)) {
	&Log("Cannot open $queue");
	exit 0;
    }
    else {
	&Debug("open $queue") if $debug;
    }

    if (! open(PROG_IN, "|$prog")) {
	&Log("Cannot exec [$prog] for $queue");
	exit 0;
    }
    else {
	&Debug("open |$prog") if $debug;
    }

    while (<QUEUE_IN>) { 
	s/^From /From /;
	print PROG_IN $_;
    }

    close(PROG_IN);
    close(QUEUE_IN);

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
    $buf =~ s/^[\r\n]+$//g;
    (split(/\s+/, $buf, 2))[1];
}


### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

1;
