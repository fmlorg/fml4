# Copyright (c) 1998 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# If we are to follow this approach, what should be in here

package Net::LDAP::Schema::oid7;

sub description { "Boolean" }

# encode a boolean value into what LDAP expects
sub encode {
  $_[1] ? "TRUE" : "FALSE";
}

# dencode a boolean value from LDAP into a usable value
sub decode {
  $_[1] eq "TRUE" ? 1 : 0;
}

# verify the data is legal and can be encoded
sub verify {
  1;
}

1;
