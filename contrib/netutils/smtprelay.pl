#!/usr/local/bin/perl
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

#########################################
### SMTP RELAY ###
###
### Usage:
### open(SENDMAIL, "|smtprelay.pl ") 
###   direct connection to the mail server without fork() in this machine
###   must be better then using open(SENDMAIL, "|/usr/sbin/sendmail ... ");


if ($0 eq __FILE__) {
    $HOST       = 'hikari.sapporo.iij.ad.jp';
    $MAINTAINER = 'fml-admin@sapporo.iij.ad.jp';
$debug++;
    push(@Rcpt, @ARGV);

    $DIR = '/var/tmp/smtprelay';
    $SMTP_LOG = "/dev/stderr";

    -d $DIR || mkdir($DIR, 0755);

    &GetTime;
    &SetDefaults;
    &Parse;
    &Relay(*Envelope);

    exit 0;
}


sub Log { print STDERR @_;}


sub Relay
{
    local(*e) = @_;
    $e{'Hdr'} = $e{'Header'};
    $status = &Smtp(*e, *Rcpt);
    &Log("Smtp:$status") if $status;
}

##############################################


#:include: fml.pl
#:sub SetDefaults GetTime Parse eval
#:~sub
#:replace
#:replace
sub SetDefaults
{
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)
    $Envelope{'mode:uip'}   = '';    # default UserInterfaceProgram is nil.;
    $Envelope{'mode:req:guide'} = 0; # not member && guide request only

    { # DNS AutoConfigure to set FQDN and DOMAINNAME; 
	local(@n, $hostname, $list);
	chop($hostname = `hostname`); # beth or beth.domain may be possible
	$FQDN = $hostname;
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";
	@n    = split(/\./, $hostname); $hostname = $n[0]; # beth.dom -> beth
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";

	foreach (split(/\s+/, $list)) { /^$hostname\.\w+/ && ($FQDN = $_);}
	$FQDN       =~ s/\.$//; # for e.g. NWS3865
	$DOMAINNAME = $FQDN;
	$DOMAINNAME =~ s/^$hostname\.//;
    }

    # Architecture Dependence;
    $HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 1;

    # REQUIRED AS DEFAULTS
    %SEVERE_ADDR_CHECK_DOMAINS = ('or.jp', +1, 'ne.jp', +1);
    $REJECT_ADDR = 'root|postmaster|MAILER-DAEMON|msgs|nobody';
    $SKIP_FIELDS = 'Received|Return-Receipt-To';
    $MAIL_LIST   = "dev.null\@$DOMAINNAME";
    $MAINTAINER  = "dev.null-admin\@$DOMAINNAME";
    $ML_MEMBER_CHECK  = $CHECK_MESSAGE_ID = 1;

    # default security level
    $SECURITY_LEVEL = 2; undef %Permit;
    
    @DenyProcedure = ('library');
    @HdrFieldsOrder =	# rfc822; fields = ...; Resent-* are ignored;
	('Return-Path', 'Date', 'Posted', 
	 'From', 'Reply-To', 'Subject', 'Sender', 
	 'To', 'Cc', 'Errors-To', 'Message-Id', 'In-Reply-To', 
	 'References', 'Keywords', 'Comments', 'Encrypted',
	 ':XMLNAME:', ':XMLCOUNT:', 'X-MLServer', 
	 'XRef', 'X-Stardate', 'X-ML-Info', ':body:', ':any:', 
	 'Mime-Version', 'Content-Type', 'Content-Transfer-Encoding',
	 'Precedence', 'Lines');
}


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}


# one pass to cut out the header and the body
sub Parsing { &Parse;}
sub Parse
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($nlines, $nclines);

    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    $Envelope{'Header'} .= $_ unless /^$/o;
	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:req:guide'} = 1 if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	    }

	    # Command or not is checked within the first 3 lines.
	    # '# help\s*' is OK. '# guide"JAPANESE"' & '# JAPANESE' is NOT!
	    # BUT CANNOT JUDGE '# guide "JAPANESE CHARS"' SYNTAX;-);
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:uip'} = 'on'    if /^\#\s*\w+\s|^\#\s*\w+$/;
		$Envelope{'mode:uip:chaddr'}=$_ if /^\#\s*($CHADDR_KEYWORD)\s+/i;
	    }

	    $Envelope{'Body'} .= $_; # save the body
	    $nlines++;               # the number of bodylines
	    $nclines++ if /^\#/o;    # the number of command lines
	}
    }# END OF WHILE LOOP;

    $Envelope{'nlines'}  = $nlines;
    $Envelope{'nclines'} = $nclines;
}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}



1;
