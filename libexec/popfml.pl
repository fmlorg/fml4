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

if ($COMPAT_WIN32) {
    # require 'arch/Win32/libwin32.pl';
    require 'libwin32.pl';

    ### &PopFmlGabble; (without fork version)
    $status = &Pop'Gabble(*PopConf);#';
    if ($status) { die("Error: $status\n");}

    ### &PopFmlProg;

}
# UNIX
else {
    &PopFmlGabble;
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

	/^\-conf/   && ($PopConf{'POPFML_RC'} = shift @ARGV) && next; 
	/^\-pwfile/ && ($PopConf{'NETRC'}     = shift @ARGV) && next; 
    }

    if ($debug) {
	while (($k, $v) = each %ENV) {
	    print STDERR "$k\t=>\t$v\n";
	}
    }
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

    # search config file
    for ($PopConf{'POPFML_RC'}, 
	 "$ENV{'HOME'}/.popfmlrc", "$ENV{'HOME'}/.popexecrc") { 
	if (-f $_) { $ConfigFile = $_;}
    }

    &PopFmlGetOpts;

    ### NTFML ###
    if ($ENV{'OS'} =~ /Windows_NT/) {
	$HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 0;
	$COMPAT_WIN32 = 1;
    }
    ### NTFML ENDS ###

    # debug 
    # for (keys %PopConf) { print STDERR "$_\t$PopConf{$_}\n" if $debug;}

    # get password for the host;
    &PopFmlGetPasswd($PopConf{'SERVER'}, 
		     $PopConf{'NETRC'} || "$ENV{'HOME'}/.netrc");
    $PopConf{"PASSWORD"}  = $Password;


    if (! $PopConf{'USER'}) {
	$PopConf{'USER'} = getlogin || (getpwuid($<))[0];
    }

    for ("/var/mail/$USER", "/var/spool/mail/$USER", "/usr/spool/mail/$USER") {
	if (-r $_) {
	    $PopConf{'MAIL_SPOOL'} = $_;
	    last;
	}
    }

    if (-f $ConfigFile) { 
	package popcf;
	require $main'ConfigFile; #';
	$POPFML_PROG = $POP_EXEC if $POP_EXEC;
	package main;

	$PopConf{"PROG"} = $popcf'POPFML_PROG; #';
    }
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

    print STDERR "--caught signal $sig ($$)\n";
    print STDERR "--alarm PopFmlProgShutdown ($$)\n";
    exit(0);
}

sub PopFmlLock
{
    local($queue_dir) = $PopConf{'QUEUE_DIR'};

    print STDERR "--try lock ... ($$)\n" if $debug;

    # anyway shutdown after 45 sec (60 sec. must be a unit).
    $SIG{'ALRM'} = "PopFmlProgShutdown";
    alarm($TimeOut{"pop:flock"} || 45) if $HAS_ALARM;

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

    print STDERR "--PopFmlProg (queue_dir=$queue_dir prog=$prog)\n" if $debug;

    &PopFmlLock;

    opendir(DIRD, $queue_dir) || &Log("Cannot opendir $queue_dir");
    for $qf (sort {$a <=> $b} readdir(DIRD)) {
	next if $qf =~ /^\./;
	next if $qf =~ /\.prog$/;

	last if $ForkCount >= $POPFML_MAX_CHILDREN;
	last if $PopFmlProgExitP;

	$queue = "$queue_dir/$qf";

	print STDERR "===queue $queue\n" if $debug;

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
	}

	### FORKED, CHILDREN IS THE MAIN PROG ###
	if (($pid = fork) < 0) {
	    &Log("Cannot fork");
	}
	elsif (0 == $pid) {
	    print STDERR "--PopFmlProg [$qf] ... ($$)\n" if $debug;
	    print STDERR "   $prog" if $debug;

	    if (! open(QUEUE_IN, $queue)) {
		&Log("Cannot open $queue");
		exit 0;
	    }

	    if (! open(PROG_IN, "|$prog")) {
		&Log("Cannot exec [$prog] for $queue");
		exit 0;
	    }

	    while (<QUEUE_IN>) { print PROG_IN $_;}

	    close(PROG_IN);
	    close(QUEUE_IN);

	    unlink $queue || &Log("PopFmlProg: fails to remove the queue $qf");

	    exit 0;
	}

	$ForkCount++; # parent;

    }
    
    # O.K. Setup the prog of the queue; GO!
    undef $SIG{'ALRM'};
    alarm(0) if $HAS_ALARM;

    &PopFmlUnLock;
    closedir(DIRD);

    # &Log("fork $ForkCount childrens") if $ForkCount;

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}


### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

1;
