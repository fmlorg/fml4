#!/usr/local/bin/perl
#
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
require 'proc/libkern.pl';
require 'proc/libpop.pl';


&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# Load config.ph, initialize conf, date,...

&PopFmlInit;
&PopFmlGabble;
&PopFmlProg;

exit 0;


############################################################
sub PopFmlReadCF
{
    local($h) = @_;
    local($org_sep)  = $/;
    $/ = "\n\n";

    open(NETRC, "$ENV{'HOME'}/.netrc") || die $!;
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


sub PopFmlGetopt 
{
    local(@ARGV) = @_;

    # getopts
    while(@ARGV) {
	$_ =  shift @ARGV;
	/^\-user/ && ($USER = $PopConf{'USER'} = shift @ARGV) && next; 
	/^\-host/ && ($PopConf{'SERVER'} = shift @ARGV) && next; 
	/^\-f/    && ($ConfigFile = shift @ARGV) && next; 
	/^\-h/    && do { print &USAGE; exit 0;};
	/^\-d/    && $debug++;
	/^\-D/    && $DUMPVAR++;
    }
}


sub PopFmlInit
{
    # for logging 
    $From_address = "popfml";

    &PopFmlGetopt(@ARGV); 
    &PopFmlReadCF($PopConf{'SERVER'});

    if (! $PopConf{'USER'}) {
	$PopConf{'USER'} = getlogin || (getpwuid($<))[0];
    }

    for ("/var/mail/$USER", "/var/spool/mail/$USER", "/usr/spool/mail/$USER") {
	if (-r $_) {
	    $PopConf{'MAIL_SPOOL'} = $_;
	    last;
	}
    }

    $PopConf{'TIMEOUT'}   = 30;
    $PopConf{'QUEUE_DIR'} = 'var/pop.queue';
    $PopConf{'LOGFILE'}   = 'var/log/_poplog';
    $PopConf{"PASSWORD"}  = $Password;
    $PopConf{"PROG"}      = "/usr/local/mh/lib/rcvstore";

    if (-f $ConfigFile) { require ($ConfigFile);}
}


sub PopFmlGabble
{
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
}


sub PopFmlProg
{
    local($queue, $prog, $qf);

    $queue = $PopConf{'QUEUE_DIR'};
    $prog  = $PopConf{'PROG'};
    $prog =~ s/^\|+//;

    print STDERR "--PopFmlProg (queue=$queue prog=$prog)\n" if $debug;

    opendir(DIRD, $queue) || &Log("Cannot opendir $queue");
    for $qf (readdir(DIRD)) {
	next if $qf =~ /^\./;

	print STDERR "--PopFmlProg [$qf] ...\n" if $debug;

	if (! open(QUEUE_IN, "$queue/$qf")) {
	    &Log("Cannot open $queue/$qf");
	    next;
	}

	if (! open(PROG_IN, "|$prog")) {
	    &Log("Cannot exec [$prog]");
	    next;
	}

	while (<QUEUE_IN>) { print PROG_IN $_;}

	close(PROG_IN);
	close(QUEUE_IN);

	unlink "$queue/$qf" || 
	    &Log("PopFmlProg: fails to remove the queue $qf");
    }
    closedir(DIRD);
}


### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

1;
