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

$| = 1;

use DBI;
use DBD::mysql;

$driver   = "mysql";
$database = shift || "fml";
$server   = 'elena';
$dsn      = "DBI:$driver:$database:$server";

print "DSN: ", $dsn, "\n\n";
$dbh = DBI->connect($dsn, 'fukachan', 'uja');

if (1) {
    @db = $dbh->func( '_ListDBs' );
    print "Databases: ";
    for $db ( @db ) { print $db, " ";}
    print "\n";
}

@tables = $dbh->func( '_ListTables' );
for $table ( @tables ) { 

    print "\n"; print "-" x 80; print "\n";
    printf "%8s: %s\n", "Table", $table;

    $p = $dbh->prepare("select * from $table");
    $p->execute;

    if ($p) {
	my @f = @{ $p->{NAME} };
	printf "%3d   %-10s %-30s %-10s %-10s\n", @f;
	while ( my (@data) = $p->fetchrow_array ) {
	printf "%3d   %-10s %-30s %-10s %-10s\n", @data;
	}
    }
    else {
	print "failed\n";
    }
}

print "\n\n";

exit 0;

sub Update
{
    my ($sql) = @_;
    my($p) = $dbh->prepare($sql);
    print "> ", $sql, "\n";
    $p->execute;
    if (! $p) { print "fail\n";}
}

1;
