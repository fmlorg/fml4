# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Search;

use strict;
use vars qw(@ISA $VERSION);
use Net::LDAP::Message;
use Net::LDAP::Entry;
use Net::LDAP::Filter;
use Net::LDAP::BER qw(RES_SEARCH_ENTRY RES_SEARCH_REF);
use Net::LDAP::Constant qw(LDAP_SUCCESS);

@ISA = qw(Net::LDAP::Message);
$VERSION = "0.02";

sub first_entry { # compat
  my $self = shift;
  $self->entry(0);
}

sub next_entry { # compat
  my $self = shift;
  $self->entry( defined $self->{'CurrentEntry'}
		? $self->{'CurrentEntry'} + 1
		: 0);
}

sub result_tag { 'RES_SEARCH_RESULT' }

sub decode {
  my $self = shift;
  my $data = shift;

  my $tag = $data->tag;
  my $seq;

  if ($tag == RES_SEARCH_ENTRY) {
    my $entry = Net::LDAP::Entry->new;

    $data->decode('RES_SEARCH_ENTRY' => \$seq);
    $entry->decode($seq);

    push(@{$self->{'Entries'} ||= []}, $entry);

    $self->{Callback}->($self,$entry)
      if (defined $self->{Callback});

    return $self;
  }
  elsif ($tag == RES_SEARCH_REF) {
    my $ref = Net::LDAP::Reference->new;

    $data->decode('RES_SEARCH_REF' => \$seq);
    $ref->decode($seq);

    push(@{$self->{'Reference'} ||= []}, $ref->references);

    $self->{Callback}->($self,$ref)
      if (defined $self->{Callback});

    return $self;
  }
  else {
    return $self->SUPER::decode($data);
  }
}

sub entry {
  my $self = shift;
  my $index = shift || 0; # avoid undef warning and default to first entry

  my $entries = $self->{'Entries'} ||= [];
  my $ldap = $self->parent;

  # There could be multiple response to a search request
  # but only the last will set {Code}
  until (exists $self->{Code} || (@{$entries} > $index)) {
    return
      unless $ldap->_recvresp($self->mesg_id) == LDAP_SUCCESS;
  }

  return
    unless (@{$entries} > $index);

  $self->{'CurrentEntry'} = $index; # compat

  return $entries->[$index];
}

sub all_entries { goto &entries } # compat

sub entries {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  @{$self->{'Entries'} || []}
}

sub count {
  my $self = shift;
  scalar entries($self);
}

sub shift_entry {
  my $self = shift;

  entry($self, 0) ? shift @{$self->{'Entries'}} : undef;
}

sub pop_entry {
  my $self = shift;

  entry($self, 0) ? pop @{$self->{'Entries'}} : undef;
}

sub sorted {
  my $self = shift;
  my @at;

  $self->sync unless exists $self->{Code};

  return unless exists $self->{'Entries'} && ref($self->{'Entries'});

  return @{$self->{'Entries'}} unless @{$self->{'Entries'}} > 1;

  if (@_) {
    my $attr = shift;

    @at = map {
      my $x = $_->get($attr);
      $x ? lc(join("\001",@$x)) : "";
    } @{$self->{'Entries'}};
  }
  else {
    # Sort by dn:
    @at = map {
      my $x = $_->dn;
      $x =~ s/(^|,)\s*\w+=/\001/sog;
      lc($x)
    } @{$self->{'Entries'}};
  }

  my @order = sort { $at[$a] cmp $at[$b] } 0..$#at;

  @{$self->{'Entries'}}[@order];
}

sub references {
  my $self = shift;

  $self->sync unless exists $self->{Code};

  return unless exists $self->{'Reference'} && ref($self->{'Reference'});

  @{$self->{'Reference'} || []}
}

sub as_struct {
  my $self = shift;
  my %result = map { ( $_->dn, $_->{'attrs'} ) } entries($self);
  return \%result;
}

package Net::LDAP::Reference;

sub new {
  my $pkg = shift;
  bless [],$pkg;
}

sub decode {
  my $self = shift;
  my $ber = shift;
  my @array;

  # Cannot just use $self here as Convert::BER does if(ref($arg) eq 'ARRAY')
  $ber->decode(
    STRING => \@array
  ) or return;

  @$self = @array;
  $self;
}

sub references {
  my $self = shift;

  @{$self}
}


1;
