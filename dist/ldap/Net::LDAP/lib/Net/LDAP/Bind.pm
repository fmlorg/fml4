# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Bind;

use strict;
use Net::LDAP qw(LDAP_SASL_BIND_IN_PROGRESS);
use Net::LDAP::Message;
use vars qw(@ISA);

@ISA = qw(Net::LDAP::Message);

sub _sasl_info {
  my $self = shift;
  $self->{DN} = shift;
  $self->{SaslCtrl} = shift;
  $self->{Sasl} = shift;
  
}

sub decode {
  my $self = shift;
  my $ber = shift;

  my($code,$dn,$error, $referral, $saslref, $count);

  $ber->decode(
    $self->result_tag => [
      ENUM   => \$code,
      STRING => \$dn,
      STRING => \$error,
      OPTIONAL => [ 
        LDAP_REFERRAL => [
          STRING => $referral = []
        ]
      ],
      OPTIONAL => [ SASL_CREDENTIALS => \$saslref ],
    ]
  ) or
    return;

  # it is the setting of the Code entry that tells the rest
  # of the code that we have a response for this message

  # tell out LDAP client to forget us as this message has now completed
  # all communications with the server
  $self->parent->_forgetmesg($self);

  if ($code == LDAP_SASL_BIND_IN_PROGRESS) {
    
    # This is where we fake it a bit. If the server has
    # sent us a challenge, use the sasl object to get the
    # response and send it
    #
    # But if we are running async the user already has a ref to $self
    # so we must re-use $self so it will contain the results of the
    # last response on the sequence

    $self->{Ber}    = Net::LDAP::BER->new;
    $self->{MesgID} = $self->NewMesgID(); # Get a new message ID

    my $sasl = $self->{Sasl};
    my $ldap = $self->parent;
    my $resp = $sasl->challenge($saslref);

    $self->ber->encode(
      SEQUENCE => [
        INTEGER  => $self->mesg_id,
        REQ_BIND => [
          INTEGER    => $ldap->version,
          LDAPDN     => $self->{DN},
          AUTH_SASL  => [
            SASL_MECHANISM => $sasl->name,
            STRING         => $resp,
          ]
        ],
        BER => $self->{SaslCtrl}
      ]
    );
    $ldap->_sendmesg($self);
  }
  else {
    $self->{Code}  = $code;
    $self->{DN}    = $dn;
    $self->{Error} = $error;
    $self->{Referral} = $referral;
    $self->{Sasl} = $saslref;

    # free up memory as we have a result so we will not need to re-send it
    $self->{Ber} = undef;

    $self->{Callback}->($self)
      if (defined $self->{Callback});
  }

  $self;
}

1;
