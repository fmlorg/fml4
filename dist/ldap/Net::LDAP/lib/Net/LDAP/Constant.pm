# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Constant;

use Exporter ();

@ISA         = qw(Exporter);
@EXPORT_OK   = ( grep /^LDAP_/, keys %{'Net::LDAP::Constant::'} );
%EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

##
## The constants
##

sub LDAP_SUCCESS                   () { 0x00 }
sub LDAP_OPERATIONS_ERROR          () { 0x01 }
sub LDAP_PROTOCOL_ERROR            () { 0x02 }
sub LDAP_TIMELIMIT_EXCEEDED        () { 0x03 }
sub LDAP_SIZELIMIT_EXCEEDED        () { 0x04 }
sub LDAP_COMPARE_FALSE             () { 0x05 }
sub LDAP_COMPARE_TRUE              () { 0x06 }
sub LDAP_STRONG_AUTH_NOT_SUPPORTED () { 0x07 }
sub LDAP_AUTH_METHOD_NOT_SUPPORTED () { 0x07 }
sub LDAP_STRONG_AUTH_REQUIRED      () { 0x08 }
sub LDAP_PARTIAL_RESULTS           () { 0x09 }

sub LDAP_REFERRAL                  () { 0x0a } # V3
sub LDAP_ADMIN_LIMIT_EXCEEDED      () { 0x0b } # V3
sub LDAP_UNAVAILABLE_CRITICAL_EXT  () { 0x0c } # V3
sub LDAP_CONFIDENTIALITY_REQUIRED  () { 0x0d } # V3
sub LDAP_SASL_BIND_IN_PROGRESS     () { 0x0e } # V3

sub LDAP_NO_SUCH_ATTRIBUTE         () { 0x10 }
sub LDAP_UNDEFINED_TYPE            () { 0x11 }
sub LDAP_INAPPROPRIATE_MATCHING    () { 0x12 }
sub LDAP_CONSTRAINT_VIOLATION      () { 0x13 }
sub LDAP_TYPE_OR_VALUE_EXISTS      () { 0x14 }
sub LDAP_INVALID_SYNTAX            () { 0x15 }

sub LDAP_NO_SUCH_OBJECT            () { 0x20 }
sub LDAP_ALIAS_PROBLEM             () { 0x21 }
sub LDAP_INVALID_DN_SYNTAX         () { 0x22 }
sub LDAP_IS_LEAF                   () { 0x23 }
sub LDAP_ALIAS_DEREF_PROBLEM       () { 0x24 }

sub LDAP_INAPPROPRIATE_AUTH        () { 0x30 }
sub LDAP_INVALID_CREDENTIALS       () { 0x31 }
sub LDAP_INSUFFICIENT_ACCESS       () { 0x32 }
sub LDAP_BUSY                      () { 0x33 }
sub LDAP_UNAVAILABLE               () { 0x34 }
sub LDAP_UNWILLING_TO_PERFORM      () { 0x35 }
sub LDAP_LOOP_DETECT               () { 0x36 }

sub LDAP_NAMING_VIOLATION          () { 0x40 }
sub LDAP_OBJECT_CLASS_VIOLATION    () { 0x41 }
sub LDAP_NOT_ALLOWED_ON_NONLEAF    () { 0x42 }
sub LDAP_NOT_ALLOWED_ON_RDN        () { 0x43 }
sub LDAP_ALREADY_EXISTS            () { 0x44 }
sub LDAP_NO_OBJECT_CLASS_MODS      () { 0x45 }
sub LDAP_RESULTS_TOO_LARGE         () { 0x46 }

sub LDAP_AFFECTS_MULTIPLE_DSAS     () { 0x47 } # V3

sub LDAP_OTHER                     () { 0x50 }
sub LDAP_SERVER_DOWN               () { 0x51 }
sub LDAP_LOCAL_ERROR               () { 0x52 }
sub LDAP_ENCODING_ERROR            () { 0x53 }
sub LDAP_DECODING_ERROR            () { 0x54 }
sub LDAP_TIMEOUT                   () { 0x55 }
sub LDAP_AUTH_UNKNOWN              () { 0x56 }
sub LDAP_FILTER_ERROR              () { 0x57 }
sub LDAP_USER_CANCELED             () { 0x58 }
sub LDAP_PARAM_ERROR               () { 0x59 }
sub LDAP_NO_MEMORY                 () { 0x5a }

1;
