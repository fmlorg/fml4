#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


sub DataBaseMIBPrapare
{
    my ($mib) = @_;

    # fundamental information
    $mib->{'MAIL_LIST'}       = $MAIL_LIST;
    $mib->{'CONTROL_ADDRESS'} = $CONTROL_ADDRESS;
    $mib->{'MAINTAINER'}      = $MAINTAINER;
    $mib->{'DOMAINNAME'}      = $DOMAINNAME;
    $mib->{'FQDN'}            = $FQDN;

    # split $MAIL_LIST
    ($mib->{'ML_ACCT'}, $mib->{'ML_DOMAIN'}) = split(/\@/, $MAIL_LIST);

    # custom
    $mib->{'method'} = 'LDAP';

    # LDAP by default (these are templates provided by fml).
    if ($mib->{'method'} =~ /^LDAP$/i) {
	&_GenLDAPTemplate($mib);
    }
}


# $LDAP_SERVER_HOST      = "ldap.fml.org";
# $LDAP_SEARCH_BASE      = "dc=fml, dc=org";
# $LDAP_SEARCH_BIND      = "cn=root, dc=fml, dc=org";
# $LDAP_SEARCH_PASSWORD  = $NULL;
# $LDAP_SEARCH_CERT_FILE = $NULL;
# $LDAP_QUERY_FILTER     = "(objectclass=*)";
sub _GenLDAPTemplate
{
    my ($mib) = @_;

    $mib->{'host'}         = $LDAP_SERVER_HOST;
    $mib->{'bind'}         = $LDAP_SERVER_BIND;
    $mib->{'password'}     = $LDAP_SERVER_PASSWORD;
    $mib->{'query_filter'} = $LDAP_QUERY_FILTER || '(objectclass=*)';

    if ($LDAP_SEARCH_BASE) {
	$mib->{'base'} = $LDAP_SEARCH_BASE;
    }
    else {
	my($acct, $domain) = split(/\@/, $MAIL_LIST);
	my(@domain)        = split(/\./, $domain);
	$mib->{'base'}     = join(", ", $acct, @domain);
    }
}


package DataBases;


sub Log { &main::Log(@_);}


#  DataBaseCtl(*Envelope, *MIB, *result, *misc)
#     Envelope: Envelope Hash
#          MIB: Management Information Base
#       result: returned value or not used (*** reserved **)
#         misc: *** reserved **
sub main::DataBaseCtl
{
    local(*Envelope, $mib, $result, $misc) = @_;

    # Leightweight Directory Access Protocol
    if ($mib->{'method'} =~ /^LDAP$/i) {
	if ($mydb) {
	    require $mib->{'mylib'};
	}
	else {
	    require 'databases/ldap/examples/libldap.pl'; # temporary
	    eval(' &Execute(*Envelope, $mib, $result, $misc); ');
	    &Log($@) if $@;
	}
    }
    # MySQL
    elsif ($mib->{'method'} =~  /^MySQL$/i) {
	;
    }
    # PostgreSQL
    elsif ($mib->{'method'} =~ /^PostgreSQL$/i) {
	;
    }
    else {
	$NULL;
    }
}


### debug ###
package main;
if ($0 eq __FILE__) {
    # getopt()
    require 'getopts.pl';
    &Getopts("dh");


}


1;
