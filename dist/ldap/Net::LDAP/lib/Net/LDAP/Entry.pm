# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Entry;

use Net::LDAP::BER;
use strict;

#@Net::LDAP::Filter::Error::ISA = qw(Error);

sub new {
  my $self = shift;
  my $type = ref($self) || $self;

  my $entry = bless { 'changetype' => 'add' }, $type;

  $entry;
}

sub decode {
  my $self = shift;
  my $ber = shift;
  my $count = 0;
  my $cur_attr;
  my @order;
  my %attrs;

  %{$self} = (
    'dn'    => undef,
    'order' => \@order,
    'attrs' => \%attrs,
    'changetype' => 'modify'
  );

  $ber->decode(
    STRING   => \$self->{'dn'},
    SEQUENCE_OF => [ \$count,
      SEQUENCE => [
        STRING  => sub { \$cur_attr },
        SET     => [
          STRING => sub {
			my $la = lc $cur_attr;
			push(@order, $cur_attr) unless exists $attrs{$la};
			$attrs{$la} ||= []
		    }
        ]
      ]
    ]
  ) or return;

  $self;
}

sub carp {
  require Carp;
  goto &Carp::carp;
}

sub attributes {
  my $self = shift;
  carp("attributes called with arguments") if @_;
  @{$self->{'order'}};
}

sub get_attribute {
  carp("->get_attribute depricated, use ->get") if $^W;
  goto &get;
}

sub get {
  my $self = shift;
  my $attr  = lc(shift);

  return unless exists $self->{'attrs'}{$attr};

  wantarray
    ? @{$self->{'attrs'}{$attr}}
    : $self->{'attrs'}{$attr};
}

sub dn {
  my $self = shift;
  @_ ? ($self->{'dn'} = shift) : $self->{'dn'};
}

# Just for debugging

sub dump {
  my $self = shift;

  print "-" x 72,"\n";
  print "dn:",$self->{'dn'},"\n\n";

  my($attr,$val);
  my $l = 0;

  map { $l = length if length > $l } $self->attributes;
  my $spc = "\n  " . " " x $l;

  foreach $attr ($self->attributes) {
    $val = $self->{'attrs'}{lc($attr)};
    printf "%${l}s: ", $attr;
    my($i,$v);
    $i = 0;
    foreach $v (@$val) {
      print $spc if $i++;
      print $v;
    }
    print "\n";
  }
}

my $lonce = 0;

sub ldif {
  my $self = shift;
  my $dn = "dn: " . $self->{'dn'} . "\n";

  carp('depricated use of $entry->ldif, use Net::LDAP::LDIF')
    unless ($lonce++);

  $dn =~ s/(.{78})(?=.)/$1\n /g;

  my @ldif = ($dn);
  my($attr,$val);

  foreach $attr ($self->attributes) {
    $val = $self->{'attrs'}{$attr};
    push(@ldif, map {
      my $ln = $attr;
      if (/(^[ :]|[\x00-\x1f\x7f-\xff])/) {
        require MIME::Base64;
        $ln .= ":: " . MIME::Base64::encode($_);
        $ln =~ s/\n//sog;
        $ln .= "\n";
      }
      else {
        $ln .= ": " . $_ . "\n";
      }
      my @ln = ();
      if (length($ln) > 79) {
        push @ln, $1 . "\n"
          while ($ln =~ s/^(.{78})(?=.)/ /);
      }
      (@ln,$ln);
    } @$val);
  }

  push @ldif, "\n";
  wantarray ? @ldif : \@ldif;
}

my $ronce = 0;
sub ldif_read {
  my $self = shift;
  my $fh = shift;

  carp('depricated use of $entry->ldif_read, use Net::LDAP::LDIF')
    unless ($ronce++);

  %{$self} = (
    'dn'    => undef,
    'order' => [],
    'attrs' => {},
    'changetype' => 'modify'
  );

  my $ln = "";
  my $buf;
  
  while (defined($buf = <$fh>)) {
    chomp $buf;
    last if length $buf;
  }

  while (defined($buf)) {
    $ln = $buf;
    last unless length $ln;
    while (defined($buf = <$fh>)) {
      chomp $buf;
      last unless $buf =~ /^[ \t]./;
      $ln .= substr($buf,1);
    }

    return # "Bad LDIF format near, " . substr($ln,0,15)
      if ($ln =~ /^\s/);

    next if (!defined($self->{'dn'}) && $ln =~ /^\d+$/);

    return # "Bad LDIF format near, " . substr($ln,0,15)
      unless ($ln =~ /^([^:]+)(::?)[ \t]/);

    my $attr = $1;
    my $val = $';

    if ($2 eq "::") {
      require MIME::Base64;
      $val = MIME::Base64::decode($val);
    }

    if ($attr eq 'dn') {
      return # "Bad LDIF format"
        if (defined($self->{'dn'}));

      $self->{'dn'} = $val;
    }
    else {
      return # "Bad LDIF format"
        unless (defined($self->{'dn'}));

      push( @{$self->{'order'}},$attr)
	unless exists $self->{'attrs'}{$attr};
      my $array = $self->{'attrs'}{$attr} ||= [];

      push @$array, $val;
    }
  }

  return  # "No LDIF found"
    unless defined( $self->{'dn'} );

  $self;
}

sub encode {
  my $self = shift;
  my $ber = new Net::LDAP::BER;

  $ber->encode(
    STRING   => $self->{'dn'},
    SEQUENCE_OF => [ $self->{'order'},
      SEQUENCE => [
        STRING  => sub { $_[0] },
        SET     => [
          STRING => sub { $self->{'attrs'}{$_[0]} }
        ]
      ]
    ]
  ) or return;

  $ber;
}

sub add {
  my $self = shift;
  my $cmd = $self->{'changetype'} eq 'modify' ? [] : undef;

  while (@_) {
    my $attr = lc(shift);
    my $val = shift;

    if ($cmd) {
      push @$cmd, $attr;
      push @$cmd, [ ref($val) ? @$val : $val ];
    }

    push( @{$self->{'order'}},$attr)
      unless exists $self->{'attrs'}{$attr};

    my $arr = $self->{'attrs'}{$attr} ||= [];

    push(@$arr, ref($val) ? @$val : $val);
  }
  push(@{$self->{'changes'}}, 'add', $cmd) if $cmd;
}

sub replace {
  my $self = shift;
  my $cmd = $self->{'changetype'} eq 'modify' ? [] : undef;

  while(@_) {
    my $attr = lc(shift);
    my $val = shift;
    if (defined($val) && @$val) {
      push( @{$self->{'order'}},$attr)
	unless exists $self->{'attrs'}{$attr};
      $self->{'attrs'}{$attr} = [ ref($val) ? @$val : $val ];
      if ($cmd) {
	push @$cmd, $attr, [ ref($val) ? @$val : $val ];
      }
    }
    else {
      delete $self->{'attrs'}{$attr};
      if ($cmd) {
	push @$cmd, $attr, [];
      }
    }
  }
  push(@{$self->{'changes'}}, 'replace', $cmd) if $cmd;
}

sub delete {
  my $self = shift;

  unless (@_) {
    $self->changetype('delete');
    return;
  }

  my $cmd = $self->{'changetype'} eq 'modify' ? [] : undef;

  while(@_) {
    my $attr = lc(shift);
    my $val = shift;

    if (defined($val) && @$val) {
      my %values;
      @values{@$val} = ();

      $self->{'attrs'}{$attr} = [
	  grep { !exists $values{$_} } @{$self->{'attrs'}{$attr}}
      ];
      if ($cmd) {
	push @$cmd, $attr, [ ref($val) ? @$val : $val ];
      }
    }
    else {
      delete $self->{'attrs'}{$attr};
      @{$self->{'order'}} = grep { $_ ne $attr } @{$self->{'order'}};
      if ($cmd) {
	push @$cmd, $attr, [];
      }
    }
  }

  push(@{$self->{'changes'}}, 'delete', $cmd) if $cmd;
}

sub changetype {
  my $self = shift;
  return $self->{'changetype'} unless @_;
  $self->{'changes'} = [];
  $self->{'changetype'} = shift;
}

sub changes {
  my $self = shift;
  @{$self->{'changes'}}
}

# If add/replace/delete remembered the changes they make the we
# can automatically submit $ldap->modify

sub update {
  my $self = shift;
  my $ldap = shift;
  my $mesg;
  my $cb = sub { $self->changetype('modify') unless $_[0]->code };

  if ($self->{'changetype'} eq 'add') {
    $mesg = $ldap->add($self, 'callback' => $cb);
  }
  elsif ($self->{'changetype'} eq 'delete') {
    $mesg = $ldap->delete($self, 'callback' => $cb);
  }
  else {
    $mesg = $ldap->modify($self, 'changes' => $self->{'changes'}, 'callback' => $cb);
  }

  return $mesg;
}

1;
