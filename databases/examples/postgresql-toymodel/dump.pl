#!/usr/pkg/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");

use Pg;

$ENV{'PGHOST'} = 'postgres';
$conn = Pg::connectdb("dbname=fml");
if ($conn->status ne PGRES_CONNECTION_OK) {
    print "status: ", $conn->status, "\n";
    print $conn->errorMessage, "\n";
}


$result = $conn->exec("select * from ml");
print $conn->errorMessage, "\n" if $conn->errorMessage;
&ShowTable;


$result = $conn->exec("select distinct * from ml");
print $conn->errorMessage, "\n" if $conn->errorMessage;
&ShowTable;


exit 0;


sub ShowTable
{
    print "----- table -----\n";
    while (@row = $result->fetchrow()) {
	print join(" ", @row), "\n";
    }
    print "\n";
}


1;
