#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

package Databases;

sub Log { &main::Log(@_);}


#  &DataBaseAccessInitialize(*Envelope, *MIB, *result, *misc);
#     Envelope: Envelope Hash
#          MIB: Management Information Base
#       result: returned value or not used (*** reserved **)
#         misc: *** reserved **
sub main::DataBaseAccessInitialize
{
    local(*e, *mib, *result, *misc) = @_;

    # import configuration
    my ($mydb) = $main::MY_DATABASE;

    # Leightweight Directory Access Protocol
    if ($mib{'method'} =~ /^LDAP$/i) {
	if ($mydb) {
	    require $mydb;
	}
	else {
	    require 'libldap.pl'; # ???
	}
    }
    # MySQL
    elsif ($mib{'method'} =~  /^MySQL$/i) {
	;
    }
    # PostgreSQL
    elsif ($mib{'method'} =~ /^PostgreSQL$/i) {
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
