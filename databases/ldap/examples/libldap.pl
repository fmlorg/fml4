#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


package LDAP;


sub Init
{
    my ($mib) = @_;

    use Mozilla::LDAP::Conn;
    $conn = new Mozilla::LDAP::Conn($mib->{'host'} || 'elena',
				    $mib->{'port'} || 389,
				    $mib->{'bind'}, 
				    $mib->{'password'}, 
				    $mib->{'cert'});

    if (! $conn) { 
	$mib->{'error'} = "cannot connect host $mib->{'host'}";
	return;
    }
}


sub Connect
{
    my ($mib) = @_;

    $entry = $conn->search($mib->{'base'}, "subtree", "(objectclass=*)");
    if (! $entry) {
	$mib->{'error'} = "cannot find base $mib->{'base'}";
	return;
    }
}


sub GetActiveList
{
    $max = $entry->size("maildrop");
    &main::Log("maildrop max = $max");

    for my $i (0 .. $max) {
	if ($entry->{maildrop}[$i]) {
	    print $entry->{maildrop}[$i];
	    print "\n";
	}
    }
}

sub Add
{
    my ($mib, $addr) = @_;

    &main::Log("add $addr");

    $conn->simpleAuth( $entry->getDN(), $mib->{'password'});

    $entry->addValue("maildrop", $addr);

    $conn->update($entry);
    my ($status) = $conn->getErrorString();
    if ($status ne 'Success') {
	$mib->{'error'} = $conn->getErrorString();
    }
}


sub Close
{
    $conn->close();
}



package main;
### debug mode ###
if ($0 eq __FILE__) {
    # debug routines
    eval "sub Log { print \@_, \"\\n\";}";

    # getopt()
    require 'getopts.pl';
    &Getopts("dhm:r:");

    $|  = 1;
    $ML = $opt_m || 'elena';
    $r  = $opt_r;

    my (%mib);
    $mib{'base'} = "cn=$ML, dc=fml, dc=org";
    if ($r) {
	# $mib{'password'} = 'secret';
    }

    &LDAP::Init(\%mib);
    if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}");}

    &LDAP::Connect(\%mib);
    if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}");}

    if ($r) {
	&LDAP::Add(\%mib, $r);
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}");}
    }
    else {
	&Log("get active list");
	&LDAP::GetActiveList;
	&LDAP::Close;
    }
}


1;
