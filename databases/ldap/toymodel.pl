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

    if ($mib->{'_action'}) {
	# initialize
	&Init($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	&LDAP::Connect($mib);
	if ($mib->{'error'}) { &Log("ERROR: LDAP: $mib->{'error'}"); return 0;}

	if ($mib->{'_action'} eq 'get_status') {
	    &Log("$mib->{'_action'} not yet implemented");
	}
	elsif ($mib->{'_action'} eq 'num_active') {
	    &Log("$mib->{'_action'} not yet implemented");
	}
	elsif ($mib->{'_action'} eq 'num_member') {
	    &Log("$mib->{'_action'} not yet implemented");
	}
	elsif ($mib->{'_action'} eq 'get_active_list' ||
	    $mib->{'_action'} eq 'dump_active_list') {
	    &GetActiveList($mib);
	}
	elsif ($mib->{'_action'} eq 'get_member_list' ||
	       $mib->{'_action'} eq 'dump_member_list') {
	    &GetMemberList($mib);
	}
	elsif ($mib->{'_action'} eq 'active_p') {
	    $mib->{'_result'} = &ActiveP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'member_p') {
	    $mib->{'_result'} = &MemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'admin_member_p') {
	    $mib->{'_result'} = &AdminMemberP($mib, $mib->{'_address'});
	}
	elsif ($mib->{'_action'} eq 'add' ||
	       $mib->{'_action'} eq 'bye' ||
	       $mib->{'_action'} eq 'subscribe'   ||
	       $mib->{'_action'} eq 'unsubscribe' ||
	       $mib->{'_action'} eq 'on'     ||
	       $mib->{'_action'} eq 'off'    ||
	       $mib->{'_action'} eq 'chaddr' ||
	       $mib->{'_action'} eq 'digest' ||
	       $mib->{'_action'} eq 'matome' ||
	       $mib->{'_action'} eq 'addmembers' ||
	       $mib->{'_action'} eq 'addactives' ||
	       $mib->{'_action'} eq 'addadmin' ||
	       $mib->{'_action'} eq 'byeadmin' ) {
	    &__ListCtl($mib);
	}
	elsif ($mib->{'_action'} eq 'store_article') {
	    # &Distribute() calls this function after saving article
	    # at spool/$ID
	    # If you store ML articles to DB, please write the code here.
	    ;
	}
	elsif ($mib->{'_action'} eq 'store_subscribe_mail') {
	    # &AutoRegist() calls this function after subscribe the address
	    # If you store the request mail to DB, please write the code here.
	    ;
	}
	else {
	    &Log("ERROR: LDAP: unkown ACTION $mib->{'_action'}");
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

    $addr = &main::LowerDomain($addr);
    &Log("\$entry->hasValue(admin, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(admin, $addr)");
    $entry->hasValue("admin", $addr);
}


sub MemberP
{
    my ($mib, $addr) = @_;

    $addr = &main::LowerDomain($addr);
    &Log("\$entry->hasValue(member, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(member, $addr)");
    $entry->hasValue("member", $addr);
}


sub ActiveP
{
    my ($mib, $addr) = @_;

    $addr = &main::LowerDomain($addr);
    &Log("\$entry->hasValue(member, $addr)") if $main::debug_ldap;
    &Log("\$entry->hasValue(member, $addr)");
    $entry->hasValue("member", $addr);
}


sub GetActiveList { my($mib) = @_; &__DumpList($mib, 'active');}
sub GetMemberList { my($mib) = @_; &__DumpList($mib, 'member');}
sub __DumpList
{
    my ($mib, $mode) = @_;
    my ($max, $orgf, $newf);

    $max = $entry->size($mode);

    if ($max == 0) {
	&Log("fail to get size");
	$mib->{'error'} = "fail to get size";
	return $NULL;
    }

    if ($main::debug_ldap) {
	$orgf = $newf = '/dev/stdout';
    }
    else {
	$orgf = $mib->{'_cache_file'};
	$newf = $mib->{'_cache_file'}.".new.$$";
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
    my ($status);

    $addr = $addr || $mib->{'_address'};
    $addr = &main::LowerDomain($addr);

    &main::Log("$mib->{'_action'} $addr");

    $conn->simpleAuth( $entry->getDN(), $mib->{'password'});

    if ($mib->{'_action'} eq 'subscribe' ||
	$mib->{'_action'} eq 'add') {
	$entry->addValue("member", $addr) ||
	    &__Error("fail to add $addr to member");
	$entry->addValue("active", $addr) ||
	    &__Error("fail to add $addr to active");
    }
    elsif ($mib->{'_action'} eq 'add2actives' ||
	   $mib->{'_action'} eq 'addactives') {
	$entry->addValue("active", $addr) ||
	    &__Error("fail to add $addr to active");
    }
    elsif ($mib->{'_action'} eq 'add2members' ||
	   $mib->{'_action'} eq 'addmembers') {
	$entry->addValue("member", $addr) ||
	    &__Error("fail to add $addr to active");
    }
    elsif ($mib->{'_action'} eq 'unsubscribe' ||
	   $mib->{'_action'} eq 'bye') {
	$entry->removeValue("member", $addr) ||
	    &__Error("fail to remove $addr from member");
	$entry->removeValue("active", $addr) ||
	    &__Error("fail to remove $addr from active");
    }
    elsif ($mib->{'_action'} eq 'off') {
	$entry->removeValue("active", $addr) ||
	    &__Error("fail to remove $addr from active");
    }
    elsif ($mib->{'_action'} eq 'on') {
	$entry->addValue("active", $addr) ||
	    &__Error("fail to add $addr to active");
    }
    elsif ($mib->{'_action'} eq 'chaddr') {
	my $new_addr = $mib->{'_value'};
	$new_addr = &main::LowerDomain($new_addr);

	$entry->removeValue("member", $addr) ||
	    &__Error("fail to remove $addr");
	$entry->addValue("member",    $new_addr) ||
	    &__Error("fail to add $new_addr");

	$entry->removeValue("active", $addr) ||
	    &__Error("fail to remove $addr");
	$entry->addValue("active",    $new_addr) ||
	    &__Error("fail to add $new_addr");
    }
    elsif ($mib->{'_action'} eq 'digest' ||
	   $mib->{'_action'} eq 'matome') {
	&Log("$mib->{'_action'} not yet implemented");
    }
    elsif ($mib->{'_action'} eq 'addadmin') {
	$entry->addValue("admin", $addr) ||
	    &__Error("fail to addadmin $addr");
    }
    elsif ($mib->{'_action'} eq 'byeadmin') {
	$entry->removeValue("admin", $addr) ||
	    &__Error("fail to byeadmin $addr");
    }
    else {
	&Log("ERROR: LDAP: unknown ACTION $mib->{'_action'}");
    }

    if ($mib->{'error'}) { return $NULL;}

    # try to update db
    $conn->update($entry);

    my ($status) = $conn->getErrorString();
    if ($status ne 'Success') {
	$mib->{'error'} = $conn->getErrorString();
    }
}


sub __Error
{
    my ($s) = @_;
    $mib->{'error'} = $s;
}

### for debug ###
sub RemoveAll
{
    $max = $entry->remove("maildrop");
    $max = $entry->remove("off");
    $max = $entry->remove("member");
    $max = $entry->remove("active");

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


package main;
### debug mode ###
if ($0 eq __FILE__) {
    # debug routines
    eval "sub Log { print \@_, \"\\n\";}";

    # getopt()
    require 'getopts.pl';
    &Getopts("a:dhm:r:b:Dk:RA:");

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
	$mib{'_action'} = $opt_A || 'subscribe';
	&LDAP::__ListCtl(\%mib, $r);
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
    elsif ($opt_a) {
	$mib{'_action'} = 'addadmin';
	&LDAP::__ListCtl(\%mib, $opt_a);
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
	&LDAP::GetActiveList($mib);
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}

	&LDAP::Close;
	if ($mib{'error'}) { &Log("ERROR: LDAP: $mib{'error'}"); exit 1;}
    }
}


1;
