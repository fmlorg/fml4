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
# $Id$

require 'getopts.pl';
&Getopts("I:");

push(@INC, $opt_I);
push(@INC, @ARGV);

require 'libkern.pl';
require 'config.ph';
require 'libcompat_cf1.pl';

# DNS
chop($HOSTNAME = `hostname`);
local($n, $a) = (gethostbyname($HOSTNAME))[0,1];
foreach (split(/\s+/, "$n $a")) { /^$HOSTNAME\./ && ($FQDN = $_);}

$FQDN       =~ s/\.$//; # for e.g. NWS3865
$FQDN       =  $FQDN || $HOSTNAME;

$DOMAINNAME =  $FQDN;
$DOMAINNAME =~ s/^$HOSTNAME\.//;

$acct = (getpwuid($<))[0];

if ($MAINTAINER !~ /domain\.uja/) {
    print STDERR "MAINTAINER\t$MAINTAINER\n";
    local($acct, $fqdn) = split(/@/, $MAINTAINER, 2);
    $acct = (getpwuid($<))[0];
    $FQDN = $fqdn || $FQDN;
}


$From            = "$acct\@$FQDN";
$MAINTAINER      =~ s/domain\.uja/$FQDN/;
$MAIL_LIST       =~ s/domain\.uja/$FQDN/;
$CONTROL_ADDRESS =~ s/domain\.uja/$FQDN/;


$header = qq#From $From
From: $From
    (uja)
To: $MAIL_LIST
Subject: make localtest 
Message-Id: <0403.1218.CAA${$}Elena.Lolobrigita\@Baycity.or.jp>
MIME-Version: 1.0
Content-type: multipart/mixed; boundary="simple      boundary"
#;

$body = "test\n";

##############################
print "$header\n$body";

1;
