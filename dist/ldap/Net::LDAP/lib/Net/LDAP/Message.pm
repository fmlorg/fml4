# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Message;

use Net::LDAP::BER;
use Net::LDAP::Constant qw(LDAP_SUCCESS);
use strict;
use vars qw($VERSION);

$VERSION = "1.01";

my $MsgID = 0;

# We do this here so when we add threading we can lock it
sub NewMesgID {
  $MsgID = 1 if ++$MsgID > 65535;
  $MsgID;
}

sub new {
  my $self = shift;
  my $type = ref($self) || $self;
  my $parent = shift;
  my $arg = shift;

  bless {
    Parent   => $parent,
    MesgID   => $self->NewMesgID(),
    Callback => $arg->{'callback'} || undef,
    Ber      => Net::LDAP::BER->new
  }, $type;
}

sub callback {
  shift->{Callback};
}

sub ber {
  shift->{Ber};
}

sub parent {
  shift->{Parent};
}

sub mesg_id {
  shift->{MesgID};
}

sub code {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{Code}
    ? $self->{Code}
    : undef
}

sub done {
  my $self = shift;

  exists $self->{Code};
}

sub dn {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{DN}
    ? $self->{DN}
    : undef
}

sub referrals {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{Referral}
    ? @{$self->{Referral}}
    : ();
}

sub error {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{Error}
    ? $self->{Error}
    : undef
}

sub set_error {
  my $self = shift;
  ($self->{Code},$self->{Error}) = ($_[0]+0, "$_[1]");
  $self;
}

sub sync {
  my $self = shift;
  my $ldap = $self->{Parent};
  my $err;

  until(exists $self->{Code}) {
    $err = $ldap->sync($self->mesg_id) or next;
    $self->set_error($err,"Protocol Error")
      unless exists $self->{Code};
    return $err;
  }

  LDAP_SUCCESS;
}

sub decode {
  my $self = shift;
  my $ber = shift;

  my($code,$dn,$error, $count, $referral);

  $ber->decode(
    $self->result_tag => [
      ENUM     => \$code,
      STRING   => \$dn,
      STRING   => \$error,
      OPTIONAL => [ 
        LDAP_REFERRAL => [
          STRING => $referral = []
        ]
      ]
    ]
  ) or return;

  # it is the setting of the Code entry that tells the rest
  # of the code that we have a response for this message

  $self->{Code}  = $code;
  $self->{DN}    = $dn;
  $self->{Error} = $error;
  $self->{Referral} = $referral;

  # free up memory as we have a result so we will not need to re-send it
  $self->{Ber} = undef;

  # tell out LDAP client to forget us as this message has now completed
  # all communications with the server
  $self->parent->_forgetmesg($self);

#    if (@{$ldapurl}) {
#       my $ldap = $self->parent;
#       # We have been refered to another host
#    }

  $self->{Callback}->($self)
    if (defined $self->{Callback});

  $self;
}

sub abandon {
  my $self = shift;

  return if exists $self->{Code}; # already complete

  my $ldap = $self->{Parent};

  $ldap->abandon(
    ID => $self->{MesgID}
  );
}

sub saslref {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  exists $self->{Sasl}
    ? $self->{Sasl}
    : undef
}


##
##
##

{
  package Net::LDAP::Bind;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_BIND' }
}
{
  package Net::LDAP::Add;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_ADD' }
}
{
  package Net::LDAP::Delete;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_DELETE' }
}
{
  package Net::LDAP::Modify;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_MODIFY' }
}
{
  package Net::LDAP::ModDN;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_MODDN' }
}
{
  package Net::LDAP::Compare;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);
  sub result_tag { 'RES_COMPARE' }
}
{
  package Net::LDAP::Message::Dummy;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message);

  sub result_tag { undef } # there is no response

  sub sync    { shift }
  sub decode  { shift }
  sub abandon { shift }
  sub code { 0 }
  sub error { "" }
  sub dn { "" }
  sub done { 1 }
}
{
  package Net::LDAP::Unbind;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message::Dummy);
  sub result_tag { undef }
}
{
  package Net::LDAP::Abandon;
  use vars qw(@ISA);
  @ISA = qw(Net::LDAP::Message::Dummy);
  sub result_tag { undef }
}

1;
