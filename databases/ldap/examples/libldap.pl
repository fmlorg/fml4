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
    local($e, $mib, $result, $misc) = @_;

    if ($main::debug) {
	while (($k, $v) = each %$mib) { print "LDAP: $k => $v\n";}
    }

    if ($mib->{'ACTION'}) {
	# initialize
	&Init($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	&LDAP::Connect($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	if ($mib->{'ACTION'} eq 'get_active_list' ||
	    $mib->{'ACTION'} eq 'dump_active_list') {
	    &GetActiveList;
	}
	elsif ($mib->{'ACTION'} eq 'get_member_list' ||
	       $mib->{'ACTION'} eq 'dump_member_list') {
	    &GetMemberList;
	}
	elsif ($mib->{'ACTION'} eq 'active_p') {
	    $mib->{'_result'} = &ActiveP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'ACTION'} eq 'member_p') {
	    $mib->{'_result'} = &MemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'ACTION'} eq 'admin_member_p') {
	    $mib->{'_result'} = &AdminMemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'ACTION'} eq 'add' ||
	       $mib->{'ACTION'} eq 'bye' ||
	       $mib->{'ACTION'} eq 'subscribe'   ||
	       $mib->{'ACTION'} eq 'unsubscribe' ||
	       $mib->{'ACTION'} eq 'on'     ||
	       $mib->{'ACTION'} eq 'off'    ||
	       $mib->{'ACTION'} eq 'digest' ||
	       $mib->{'ACTION'} eq 'matome') {
	    &__ListCtl($mib);
	}
	else {
	    &Log("ERROR: LDAP: unkown ACTION $mib->{'ACTION'}");
	}

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


sub Close
{
    $conn->close();
}


### ***-predicate() ###


sub AdminMemberP
{
    my ($mib, $addr) = @_;

    &Log("\$entry->hasValue(admin, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(admin, $addr)");
    $entry->hasValue("admin", $addr);
}


sub MemberP
{
    my ($mib, $addr) = @_;

    &Log("\$entry->hasValue(member, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(member, $addr)");
    $entry->hasValue("member", $addr);
}


sub ActiveP
{
    my ($mib, $addr) = @_;

    &Log("\$entry->hasValue(member, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(member, $addr)");
    $entry->hasValue("member", $addr);
}


sub GetActiveList { &__DumpList('active');}
sub GetMemberList { &__DumpList('member');}
sub __DumpList
{
    my ($mode) = @_;
    my ($max, $orgf, $newf);

    $max = $entry->size($mode);
    if ($main::debug_ldap) {
	$orgf = $newf = '/dev/stdout';
    }
    else {
	$orgf = $mib->{'CACHE_FILE'};
	$newf = $mib->{'CACHE_FILE'}.".new.$$";
    }

    &main::Log("LDAP: member max = $max") if $main::debug;

    if (open(OUT, "> $newf")) {
	for my $i (0 .. $max) {
	    if ($entry->{member}[$i]) {
		print OUT $entry->{member}[$i], "\n";
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


### amctl ###
# subscribe unsubscribe 
sub __ListCtl
{
    my ($mib, $addr) = @_;

    $addr = $addr || $mib->{'_address'};

    &main::Log("$mib->{'ACTION'} $addr");

    $conn->simpleAuth( $entry->getDN(), $mib->{'password'});

    if ($mib->{'ACTION'} eq 'subscribe' ||
	$mib->{'ACTION'} eq 'add') {
	$entry->addValue("member", $addr);
	$entry->addValue("active", $addr);
    }
    elsif ($mib->{'ACTION'} eq 'unsubscribe' ||
	   $mib->{'ACTION'} eq 'bye') {
	$entry->removeValue("member", $addr);
	$entry->removeValue("active", $addr);
    }
    elsif ($mib->{'ACTION'} eq 'off') {
	$entry->removeValue("active", $addr);
    }
    elsif ($mib->{'ACTION'} eq 'on') {
	$entry->addValue("active", $addr);
    }
    elsif ($mib->{'ACTION'} eq 'chaddr') {
	$entry->removeValue("member", $mib->{'_old_address'});
	$entry->addValue("member",    $mib->{'_new_address'});
	$entry->removeValue("active", $mib->{'_old_address'});
	$entry->addValue("active",    $mib->{'_new_address'});
    }
    elsif ($mib->{'ACTION'} eq 'digest') {
	&Log("not yet implemented");
    }

    $conn->update($entry);

    my ($status) = $conn->getErrorString();
    if ($status ne 'Success') {
	$mib->{'error'} = $conn->getErrorString();
    }
}


### for debug ###
sub RemoveAll
{
    $max = $entry->remove("maildrop");
    $max = $entry->remove("off");
    $max = $entry->remove("member");
    $max = $entry->remove("active");
    $conn->update($entry);
}


sub Dump
{
    while ($entry) {
	$entry->printLDIF();
	$entry = $conn->nextEntry();
    }
}


package main;
### debug mode ###
if ($0 eq __FILE__) {
    # debug routines
    eval "sub Log { print \@_, \"\\n\";}";

    # getopt()
    require 'getopts.pl';
    &Getopts("dhm:r:b:Dk:RA:");

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

    if ($opt_R) {
	&LDAP::RemoveAll();
    }
    elsif ($r) {
	$mib{'ACTION'} = $opt_A || 'subscribe';
	&LDAP::__ListCtl(\%mib, $r);
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
    elsif ($opt_D) {
	&Log("-- dump mode");	
	&LDAP::Dump();
    }
    else {
	if ($opt_k) {
	    my ($x) = $opt_k;
	    my ($x) = &LDAP::MemberP(\%mib, $x);
	    print "\t$opt_k is a member\n"   if $x; 
	    print "\t$opt_k is not member\n" unless $x; 
	    exit 1 unless $x;
	}

	&Log("-- get active list");
	&LDAP::GetActiveList;
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}

	&LDAP::Close;
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
}


1;
