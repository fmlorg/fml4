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
# $Id$

print "DNS Check Program: Starting the check ... \n\n";

# extracted from fml.pl
# DNS AutoConfigure to set FQDN and DOMAINNAME; 
{

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

    print "HOST     $hostname\n";
    print "\ngethostbyname = ( $list )\n\n"; 
    print "FQDN     $FQDN\n";
    print "DOMAIN   $DOMAINNAME\n";

    $acct = (getpwuid($<))[0];
    $from = "$acct\@$FQDN";

    print "\nYou are now\n\t$from\nO.K.?\n\n";

}

exit 0;
