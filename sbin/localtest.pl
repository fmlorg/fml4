#!/usr/local/bin/perl

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


$FROM            = "$acct\@$FQDN";
$MAINTAINER      =~ s/domain\.uja/$FQDN/;
$MAIL_LIST       =~ s/domain\.uja/$FQDN/;
$CONTROL_ADDRESS =~ s/domain\.uja/$FQDN/;


$HEADER_INFO = qq#MAIL:  $FROM -> $MAIL_LIST
#;
$HEADER = qq#From $FROM
From: $FROM
    (uja)
To: $MAIL_LIST
Subject: make localtest 
Message-Id: <0403.1218.CAA$$Elena.Lolobrigita\@Baycity.or.jp>
MIME-Version: 1.0
Content-type: multipart/mixed; boundary="simple      boundary"
#;

$BODY = "test\n";

##############################
print $HEADER;
print "\n";

# BODY
print $BODY;

1;
