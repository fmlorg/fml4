# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Extension;

use vars qw(@ISA $VERSION);

@ISA = qw(Net::LDAP::Message);
$VERSION = "1.01";

sub result_tag { 'RES_EXTEND' }

sub decode {
  my $self = shift;
  my $ber  = shift;

  my($code,$dn,$error, $referral, $respname, $resp, $count);

  $ber->decode(
    RES_EXTEND => [
      ENUM   => \$code,
      STRING => \$dn,
      STRING => \$error,
      OPTIONAL => [ 
        LDAP_REFERRAL => [
          STRING => $referral = []
        ]
      ],
      OPTIONAL => [ EXT_RESP_NAME => \$respname ],
      OPTIONAL => [ EXT_RESP => \$resp ],
    ]
   ) or
     return;

  # it is the setting of the Code entry that tells the rest
  # of the code that we have a response for this message

  $self->{Code}  = $code;
  $self->{DN}    = $dn;
  $self->{Error} = $error;
  $self->{Referral} = $referral;
  $self->{ResponseName} = $respname;
  $self->{Response} = $resp;

  # free up memory as we have a result so we will not need to re-send it
  $self->{Ber} = undef;

  # tell out LDAP client to forget us as this message has now completed
  # all communications with the server
  $self->parent->_forgetmesg($self);

  $self->{Callback}->($self)
    if (defined $self->{Callback});

  $self;
}

#fetch the response name
sub response_name { 
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{ResponseName}
    ? $self->{ResponseName}
    : undef;
}

# fetch the response.
sub response {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{Response}
    ? $self->{Response}
    : undef;
}

1;
