#!/usr/local/bin/perl
#
# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $rcsid   = q$Id$;
# ($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");


@ARGV || die(&USAGE);
&Init;
require 'libkern.pl';
require 'libsmtp.pl';
&__GenerateHeader(*e);
&STDIN2Body(*e);
&Deliver(*e);
exit 0;


########## Section: pmail specific 
sub Init
{
    ### set defaults ###
    $DIR             = $ENV{'PWD'};
    $e{'mci:mailer'} = 'ipc';
    $debug           = 1;
    $debug_smtp      = 1;
    $SMTP_LOG        = -w "/dev/stderr" ? "/dev/stderr" : "/dev/null";
    $VAR_DIR         = "/tmp/var";
    $VARLOG_DIR      = "/tmp/var/log";

    # DNS
    &InitDNS;

    ### getopts() ###
    require 'getopts.pl';		# Getopt
    &Getopts('s:f:hvI:D:H:d');
    die(&USAGE) if $opt_h;

    # fix includes
    {
	local($dir) = $0;
	$dir =~ s@bin/.*@@;
	push(@INC, $dir);
	push(@INC, split(/:/,$opt_I)) if $opt_I;
    }

    # variables
    $user    = (split(/:/, getpwuid($<), 999))[0];
    $domain  = $opt_D || $DOMAINNAME;
    $verbose = ($opt_v || $opt_d) ? 1 : 0;
    $opt_d   = 0; # reset

    # From
    $From_address = $user;
    $MAINTAINER   = $opt_f || "$user\@$domain";
    $from         = $MAINTAINER;

    # To and SMTP
    foreach (@ARGV) {
	$to .= $to ? ", $_" : $_;
	push(@Rcpt, $_);
    }

    # SMTP
    $HOST  = $opt_H || $FQDN;
    @HOSTS = $opt_H ? ($opt_H) : ($HOST);
}


# DNS AutoConfigure to set FQDN and DOMAINNAME; 
sub InitDNS
{ 
    local(@n, $hostname, $list);
    chop($hostname = `hostname`); # beth or beth.domain may be possible
    $FQDN = $hostname;
    @n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";
    @n    = split(/\./, $hostname); $hostname = $n[0]; # beth.dom -> beth
    @n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";

    for (split(/\s+/, $list)) { /^$hostname\.\w+/ && ($FQDN = $_);}
    $FQDN       =~ s/\.$//; # for e.g. NWS3865
    $DOMAINNAME = $FQDN;
    $DOMAINNAME =~ s/^$hostname\.//;
}


sub __GenerateHeader
{
    local(*e) = @_;

    $e{'Hdr'} .= "From: $from\n";
    $e{'Hdr'} .= "Subject: $opt_s\n";
    $e{'Hdr'} .= "To: $to\n";
    $e{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
}


sub STDIN2Body
{
    local(*e) = @_;

    # Get Body
    while(<STDIN>) { $e{'Body'} .= $_;}
}


sub Deliver
{
    local(*e) = @_;
    local(@inc);

    for (@INC) { push(@inc, $_) unless /usr\/local/;}

    print STDERR qq#

CAUTION: In verbose mode, SMTP does not connect $HOST:25

    INC: @inc

=== variables
Recipients => @Rcpt
\$SMTP_LOG  => $SMTP_LOG
\$HOST      => $HOST
\@HOSTS     => @HOSTS

=== Envelope
#;

   if ($verbose) {
	while(($k, $v) = each %e) {
	    print STDERR '-' x 30, "\n";
	    printf STDERR "[%s]\n%s\n", $k, $v;
	}
    }
    else {
	&Smtp(*e, *Rcpt);
    }
}



########## Section: misc
# Alias but delete \015 and \012 for seedmail return values
sub __Log
{ 
    local($str) = @_;
    $str =~ s/\015\012$//;

    print STDERR ">>> $str\n";
}


sub USAGE
{
local($prog) = $0;
$prog =~ s#.*/##;

qq#
$prog [-vdh] [-s subject] [-f from] [-I include] [-H host] [-D domain] addr

  options:

\t-h this help
\t-v verbose
\t-d debug/verbose

\t-I directory      includes
\t-I dir1:dir2      includes dir1, dir2, .. 

\t-D domain         \@domain part
\t-H smtp-server    SMTP Server
\t-s subject        subject
\t-f Envelope-From  UNIX from
#;
}


1;
