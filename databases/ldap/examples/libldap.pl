#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


package LDAP;


sub Log { &main::Log(@_);}


sub DataBases::Execute
{
    local(*Envelope, $mib, $result, $misc) = @_;

    if ($main::debug) {
	while (($k, $v) = each %$mib) { print "LDAP: $k => $v\n";}
    }

    if ($mib->{'ACTION'}) {
	# initialize
	&Init($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	&LDAP::Connect($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	&GetActiveList;
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	&Close;
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	# O.K.
	return 1;
    }
    else {
	&Log("ERROR: LDAP: no given action to do");
    }
}


sub Init
{
    my ($mib) = @_;

    use Mozilla::LDAP::Conn;
    $conn = 
	new Mozilla::LDAP::Conn($mib->{'host'} || 'elena',
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
    
    &Log(" search_base: $mib->{'base'}") if $main::debug_ldap;
    &Log("query_filter: $mib->{'query_filter'}") if $main::debug_ldap;

    $entry = $conn->search($mib->{'base'}, 
			   "subtree",
			   $mib->{'query_filter'} || '(objectclass=*)');

    if (! $entry) {
	$mib->{'error'} = "cannot find base $mib->{'base'}";
	return;
    }
}


sub GetActiveList
{
    my ($max, $orgf, $newf);

    $max  = $entry->size("maildrop");
    if ($main::debug_ldap) {
	$orgf = $newf = '/dev/stdout';
    }
    else {
	$orgf = $mib->{'CACHE_FILE'};
	$newf = $mib->{'CACHE_FILE'}.".new";
    }

    &main::Log("LDAP: maildrop max = $max") if $main::debug;

    if (open(OUT, "> $newf")) {
	for my $i (0 .. $max) {
	    if ($entry->{maildrop}[$i]) {
		print OUT $entry->{maildrop}[$i], "\n";
	    }
	}
	close(OUT);

	if ($main::debug_ldap) {
	    ;
	}
	elsif (! rename($newf, $orgf)) {
	    &Log("ERROR: LDAP: cannot rename $newf $orgf");
	}
    }
    else {
	&Log("ERROR: LDAP: cannot open $newf");
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


sub Dump
{
    while ($entry) {
	$entry->printLDIF();
	$entry = $conn->nextEntry();
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
    &Getopts("dhm:r:b:D");

    if ($opt_h) {
	print "$0: [options] [query_filter]\n";
	print "   -D       dump mode\n";
	print "   -m \$ml   mailing list\n";
	print "   -r \$addr recipient address\n";
	print "   -b \$base base\n";
	exit 0;
    }

    $|  = 1;
    $ML = $opt_m || 'elena';
    $r  = $opt_r;

    $debug_ldap = 1;

    my (%mib);
    $mib{'base'}         = $opt_b || "cn=$ML, dc=fml, dc=org";
    $mib{'query_filter'} = $ARGV[0] || '(objectclass=*)';

    if ($r) {
	# $mib{'password'} = 'secret';
    }

    &LDAP::Init(\%mib);
    if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}

    &LDAP::Connect(\%mib);
    if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}

    if ($r) {
	&LDAP::Add(\%mib, $r);
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
    elsif ($opt_D) {
	&Log("-- dump mode");	
	&LDAP::Dump();
    }
    else {
	&Log("-- get active list");

	&LDAP::GetActiveList;
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}

	&LDAP::Close;
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
}


1;
