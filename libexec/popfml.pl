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

$DIR   =  $ENV{'PWD'};
$debug = 1;



require 'libsmtp.pl';
require 'proc/libkern.pl';
require 'proc/libpop.pl';

&PopFmlInit;

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

print STDERR "O.K. Go! Delivery.. \n";


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
    $PopConf{'QUEUE_DIR'} = './tmp/pop.queue';
    $PopConf{'LOGFILE'}   = '/dev/stderr';
    $PopConf{"PASSWORD"}  = $Password;
    $PopConf{"PROG"}      = "/usr/local/mh/lib/rcvstore";

    if (-f $ConfigFile) { require ($ConfigFile);}
}


1;
