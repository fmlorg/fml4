#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

&Init;
&GetTime;
$MessageId = "<$CurrentTime/$$.$USER\@$DOMAINNAME>";
print &EmuHeader;

exit 0;


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, 
		   $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 1900 + $year, 
			   $mon + 1, $mday, $hour, $min);
}

sub EmuHeader
{
$_ = qq#From $USER\@$DOMAINNAME $MailDate
Return-Path: $From _RECEIVED_
Date: $MailDate +0900 (JST)
From: $From
Message-Id: $MessageId
To: $To
Subject: $Subject
#;

$_ .= "\n" unless $opt_H; 

if ($opt_r) {
    s/_RECEIVED_/\nReceived: received at .../;
}
else {
    s/_RECEIVED_//;
}


$_ .= $AddString if $AddString;
$_;
}

sub Init
{
    require 'getopts.pl';
    &Getopts("dhg:f:s:t:h:Hr");

    $USER  = $ENV{'USER'} || (getpwuid($<))[0];
    $Gecos = (getpwuid($<))[6] || $USER;

    # HELP Message
    if ($opt_h) { 
	print <<"EOF";
	$0 [options]

	    -f\tFrom:
	    -s\tSubject:
	    -t\tTo:
	    -g\tGecos Field

EOF

	exit 0;
    }



    # DNS AutoConfigure to set FQDN and DOMAINNAME; 
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

    # From: Field 
    $From    = $opt_f || "$USER\@$DOMAINNAME";
    $Subject = $opt_s || "test mail";
    $To      = $opt_t || "(list suppressed)";

    if ($opt_g) {
	$From = "$From (\"$Gecos\")";
    }
    else {
	$From = "\"$Gecos\" <$From>";	
    }

    $AddString = shift @ARGV;
}

1;
