#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
require 'getopts.pl';
&Getopts("dhs:");

use Net::DNS::Resolver;
$res = new Net::DNS::Resolver;

$res->nameservers($opt_s || '127.0.0.1');
$res->retry(2);
$res->debug(1);
print $res->string;

if (@ARGV) {
    for (@ARGV) { 
	print $res->query($_), "\n";	
    }

    if ($res->errorstring ne 'NOERROR') {
	print "ERROR: ";
	print $res->errorstring;
	print "\n";
    }
}

exit 0;
