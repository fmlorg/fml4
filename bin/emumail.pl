#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

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
Date: $MailDate
From: $From
Message-Id: $MessageId
To: (list suppressed)
Subject: $Subject
#;

$_ .= $AddString if $AddString;
"$_\n\n";
}

sub Init
{
    require 'getopts.pl';
    &Getopts("dhg:f:s:");

    $USER  = $ENV{'USER'} || (getpwuid($<))[0];
    $Gecos = (getpwuid($<))[6] || $USER;

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

    if ($opt_g) {
	$From = "$From (\"$Gecos\")";
    }
    else {
	$From = "\"$Gecos\" <$From>";	
    }

    $AddString = shift @ARGV;
}

1;
