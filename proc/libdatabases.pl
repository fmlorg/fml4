#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# ### VARIABLES passed to database routines ###
#   \w+          control variables for database routines
#   _\w+         1. variables for database routines but from fml internal
#                   temporary
#                2. return value from database routines
#                3. in/out variable w/ database routines, may be rewritten
#                   in database routines
#   error        error messages from database routines
#
#   [-A-Z_]+     fml user defined varibales (defined in config.ph)
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
    ($mib->{'_ml_acct'}, $mib->{'_ml_domain'}) = split(/\@/, $MAIL_LIST);

    # set up action, method, ...
    # cached file which is the dumped data from database server.
    $mib->{'DATABASE_METHOD'} = $DATABASE_METHOD;
    $mib->{'DATABASE_LIB'}    = $DATABASE_LIB;
    $mib->{'_action'}         = $action;

    my ($suffix) = $DATABASE_CACHE_FILE_SUFFIX || ".dbcache";
    if ($action =~ /active/) {
	$mib->{'_cache_file'}     = $ACTIVE_LIST. $suffix;
    }
    elsif ($action =~ /member/) {
	$mib->{'_cache_file'}     = $MEMBER_LIST. $suffix;	
    }
    else {
	$mib->{'_cache_file'}     = $MEMBER_LIST. $suffix;
    }

    # LDAP by default (these are templates provided by fml).
    if ($mib->{'DATABASE_METHOD'} =~ /^LDAP$/i) {
	&_GenLDAPTemplate($mib);
    }
    elsif ($mib->{'DATABASE_METHOD'} =~ /^.*SQL$/i) {
	&_GenSQLTemplate($mib);
    }
    else {
	&Log("ERROR: DataBaseMIBPrepare: unknown METHOD $mib->{'DATABASE_METHOD'}");
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
	$mib->{'base'}     = $LDAP_SEARCH_BASE;
    }
    else {
	my($acct, $domain) = split(/\@/, $MAIL_LIST);
	my(@domain)        = split(/\./, $domain);
	$mib->{'base'}     = join(", ", $acct, @domain);
    }
}


# $SQL_SERVER_HOST      = "sql.fml.org";
# $SQL_SERVER_USER      = "fml";
# $SQL_SERVER_PASSWORD  = $NULL;
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
#
# return: NONE
sub main::DataBaseCtl
{
    local($e, $mib, $result, $misc) = @_;

    &Log("debug: DataBaseCtl($mib->{'_action'})");

    if ($mib->{'DATABASE_METHOD'} =~ /^LDAP$/i  ||
	$mib->{'DATABASE_METHOD'} =~ /^MySQL$/i ||
	$mib->{'DATABASE_METHOD'} =~ /^PostgreSQL$/i) {
	if ($mib->{'DATABASE_LIB'}) {
	    eval(" require \"$mib->{'DATABASE_LIB'}\"; ");
	    if ($@) {
		&Log($@);
		$mib->{'error'} = 'internal error';
		return;
	    }

	    eval(' &Execute($e, $mib, $result, $misc); ');
	    &Log($@) if $@;
	    if ($@) {
		&Log($@);
		$mib->{'error'} = 'internal error';
		return;
	    }
	}
	else {
	    &Log("ERROR: DataBaseCtl: \$DATABASE_LIB not defined");
	    $mib->{'error'} = 'internal error' if $@;
	}
    }
    else {
	$mib->{'error'} = 'internal error' if $@;
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
