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
&Getopts("dhm:");

$|  = 1;
$ML = $opt_m || 'elena';

$regexp = shift @ARGV;

use Mozilla::LDAP::Conn;

$bind   = 'cn=root, dc=fml, dc=org';
$passwd = 'secret';
undef $bind;
undef $passwd;
undef $cert; 

$conn = new Mozilla::LDAP::Conn("elena", 389, $bind, $passwd, $cert);
$conn || die("cannot connect");

$base = "cn=$ML, dc=fml, dc=org";
$entry = $conn->search($base, "subtree", $regexp || "(objectclass=*)");

if (! $entry) {
    print "cannot find mailing list $ML\n";
    exit 0;
}

do {
    print "--- $base ---\n";

    $max   = $entry->size("maildrop");
    for my $i (0 .. $max) {
	if ($entry->{maildrop}[$i]) {
	    print $entry->{maildrop}[$i];
	    print "\n";
	}
    }

    if ($debug) {
	print "\n";
	$entry->printLDIF();
	print "\n";
    }

    $entry = $conn->nextEntry();
} while ($entry);

$conn->close();

exit 0;
