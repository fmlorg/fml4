# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::BER;

use Convert::BER qw(/BER_/ /^\$/);

use strict;
use vars qw($VERSION @ISA);

@ISA = qw(Convert::BER);
$VERSION = "1.05";

Net::LDAP::BER->define(

  # Name		Type      Tag
  ########################################

  [ LDAPDN	      => $STRING,   undef ],

  [ REQ_BIND	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x00 ],
  [ REQ_UNBIND	      => $NULL,        BER_APPLICATION  		 | 0x02 ],
  [ REQ_SEARCH	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x03 ],
  [ REQ_MODIFY	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x06 ],
  [ REQ_ADD	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x08 ],
  [ REQ_DELETE	      => $STRING,      BER_APPLICATION  		 | 0x0A ],
  [ REQ_MODDN	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x0C ],
  [ REQ_COMPARE	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x0E ],
  [ REQ_ABANDON	      => $INTEGER,     BER_APPLICATION  		 | 0x10 ],
  [ REQ_EXTEND	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x17 ],

  [ RES_BIND	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x01 ],
  [ RES_SEARCH_ENTRY  => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x04 ],
  [ RES_SEARCH_RESULT => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x05 ],
  [ RES_SEARCH_REF    => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x13 ],
  [ RES_MODIFY	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x07 ],
  [ RES_ADD	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x09 ],
  [ RES_DELETE	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x0B ],
  [ RES_MODDN	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x0D ],
  [ RES_COMPARE	      => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x0F ],
  [ RES_EXTEND        => $SEQUENCE,    BER_APPLICATION | BER_CONSTRUCTOR | 0x18 ],

  [ AUTH_NONE	      => $STRING,      BER_CONTEXT			 | 0x00 ],
  [ AUTH_SIMPLE	      => $STRING,      BER_CONTEXT			 | 0x00 ],
  [ AUTH_KRBV41	      => $STRING,      BER_CONTEXT			 | 0x01 ],
  [ AUTH_KRBV42	      => $STRING,      BER_CONTEXT			 | 0x02 ],
  [ AUTH_SASL	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x03 ],

  [ SASL_CREDENTIALS  => $STRING,      BER_CONTEXT			 | 0x07 ],
  [ SASL_MECHANISM    => $STRING,      undef ],

  [ FILTER_AND	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x00 ],
  [ FILTER_OR	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x01 ],
  [ FILTER_NOT	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x02 ],
  [ FILTER_EQ	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x03 ],
  [ FILTER_SUBSTRS    => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x04 ],
  [ FILTER_GE	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x05 ],
  [ FILTER_LE	      => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x06 ],
  [ FILTER_PRESENT    => $STRING,      BER_CONTEXT			 | 0x07 ],
  [ FILTER_APPROX     => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x08 ],
  [ FILTER_EXTENSIBLE => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x09 ],

  [ SUBSTR_INITIAL    => $STRING,      BER_CONTEXT			 | 0x00 ],
  [ SUBSTR_ANY	      => $STRING,      BER_CONTEXT			 | 0x01 ],
  [ SUBSTR_FINAL      => $STRING,      BER_CONTEXT			 | 0x02 ],

  [ EXTENSIBLE_RULE   => $STRING,      BER_CONTEXT			 | 0x01 ],
  [ EXTENSIBLE_TYPE   => $STRING,      BER_CONTEXT			 | 0x02 ],
  [ EXTENSIBLE_VALUE  => $STRING,      BER_CONTEXT			 | 0x03 ],
  [ EXTENSIBLE_DN     => $BOOLEAN,     BER_CONTEXT			 | 0x04 ],

  [ LDAP_CONTROLS     => $SEQUENCE_OF, BER_CONTEXT     | BER_CONSTRUCTOR | 0x00 ],
  [ LDAP_REFERRAL     => $SEQUENCE,    BER_CONTEXT     | BER_CONSTRUCTOR | 0x03 ],

  [ EXTEND_REQ_NAME   => $STRING,      BER_CONTEXT                       | 0x00 ],
  [ EXTEND_REQ_VALUE  => $STRING,      BER_CONTEXT                       | 0x01 ],

  [ MOD_SUPERIOR      => $STRING,      BER_CONTEXT			 | 0x00 ],
);

1;
