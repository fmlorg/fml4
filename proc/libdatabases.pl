#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


# DataBaseMIBPrepare( \$mib, action_strings, \%attr )
sub DataBaseMIBPrepare
{
    my ($mib, $action, $x) = @_;

    # canonicalize action to lower case
    $action =~ tr/A-Z/a-z/;

    # manipulate which address ?
    &Log("MIBPrepare.attr($x->{'address'} || $From_address)") if $debug;
    $mib->{'_address'} = &TrivialRewrite($x->{'address'} || $From_address);

    # fundamental information
    $mib->{'MAIL_LIST'}       = $MAIL_LIST;
    $mib->{'CONTROL_ADDRESS'} = $CONTROL_ADDRESS;
    $mib->{'MAINTAINER'}      = $MAINTAINER;
    $mib->{'DOMAINNAME'}      = $DOMAINNAME;
    $mib->{'FQDN'}            = $FQDN;

    # split $MAIL_LIST
    ($mib->{'ML_ACCT'}, $mib->{'ML_DOMAIN'}) = split(/\@/, $MAIL_LIST);

    # set up action, method, ...
    # cached file which is the dumped data from database server.
    $mib->{'METHOD'}          = $DATABASE_METHOD;
    $mib->{'ACTION'}          = $action;

    my ($suffix) = $DATABASE_CACHE_FILE_SUFFIX || ".dbcache";
    if ($action =~ /active/) {
	$mib->{'CACHE_FILE'}     = $ACTIVE_LIST.".dbcache";
    }
    elsif ($action =~ /member/) {
	$mib->{'CACHE_FILE'}     = $MEMBER_LIST.".dbcache";	
    }
    else {
	$mib->{'CACHE_FILE'}     = $MEMBER_LIST.".dbcache";
    }

    # LDAP by default (these are templates provided by fml).
    if ($mib->{'METHOD'} =~ /^LDAP$/i) {
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


sub _GenSQLTemplate
{
    my ($mib) = @_;

    $mib->{'host'}         = $SQL_SERVER_HOST;
    $mib->{'user'}         = $SQL_SERVER_USER;
    $mib->{'password'}     = $SQL_SERVER_PASSWORD;
}


package DataBases;


sub Log { &main::Log(@_);}


#  DataBaseCtl(\%Envelope, \%MIB, \%result, \%misc)
#     Envelope: Envelope Hash
#          MIB: Management Information Base
#       result: returned value or not used (*** reserved **)
#         misc: *** reserved **
sub main::DataBaseCtl
{
    local($e, $mib, $result, $misc) = @_;

    &Log("debug: DataBaseCtl($mib->{'ACTION'})");

    # Leightweight Directory Access Protocol
    if ($mib->{'METHOD'} =~ /^LDAP$/i) {
	if ($mydb) {
	    require $mib->{'mylib'};
	}
	else {
	    require 'databases/ldap/examples/libldap.pl'; # temporary
	    eval(' &Execute($e, $mib, $result, $misc); ');
	    &Log($@) if $@;
	}
    }
    # MySQL
    elsif ($mib->{'METHOD'} =~  /^MySQL$/i) {
	;
    }
    # PostgreSQL
    elsif ($mib->{'METHOD'} =~ /^PostgreSQL$/i) {
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
