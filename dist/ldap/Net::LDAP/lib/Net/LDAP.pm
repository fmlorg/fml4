# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP;

use IO::Socket;
use IO::Select;
use strict;
use Net::LDAP::BER;
use Net::LDAP::Message;
use vars qw($VERSION $LDAP_VERSION);
use UNIVERSAL qw(isa);
use Net::LDAP::Constant qw(LDAP_SUCCESS
			   LDAP_OPERATIONS_ERROR
			   LDAP_DECODING_ERROR
			   LDAP_PROTOCOL_ERROR
			   LDAP_ENCODING_ERROR
			   LDAP_FILTER_ERROR
			   LDAP_LOCAL_ERROR
			);

$VERSION = "0.13";

$LDAP_VERSION = 2;      # default LDAP protocol version

sub import {
    shift;
    unshift @_, 'Net::LDAP::Constant';
    require Net::LDAP::Constant;
    goto &{Net::LDAP::Constant->can('import')};
}

sub _options {
  my %ret = ();
  my $once = 1;
  while (@_) {
    my($k,$v) = splice(@_,0,2);
    if ($k =~ s/^-// && $once && $^W) {
      $once = 0;
      require Carp;
      Carp::carp("depricated use of leading - for options");
    }
    $ret{$k} = $v;
  }
  \%ret;
}

# make up an LDAP Controls option
sub _controls {
  my ($ctrl) = @_;

  $ctrl = [ $ctrl ] if ref($ctrl) eq 'HASH';

  return undef unless ref($ctrl) eq 'ARRAY';

  my $ber = Net::LDAP::BER->new(
    LDAP_CONTROLS => [ $ctrl,
      SEQUENCE => [
        STRING   => sub { $_[0]->{'type'} },
        BOOLEAN  => sub { $_[0]->{'critical'} ? 1 : 0 },
        OPTIONAL => [
          STRING => sub { $_[0]->{'value'} }
        ],
      ]
    ]
  );
  
  $ber;
}

sub new {
  my $self = shift;
  my $type = ref($self) || $self;
  my $host = shift if @_ % 2;
  my $arg  = &_options;
  my $obj  = bless {}, $type;

  my $sock = IO::Socket::INET->new(
               PeerAddr => $host,
               PeerPort => $arg->{'port'} || '389',
               Proto    => 'tcp',
               Timeout  => defined $arg->{'timeout'}
                             ? $arg->{'timeout'}
                             : 120
             ) or return;

  $sock->autoflush(1);

  $obj->{'net_ldap_socket'}  = $sock;
  $obj->{'net_ldap_host'}    = $host;
  $obj->{'net_ldap_resp'}    = {};
  $obj->{'net_ldap_debug'}   = $arg->{'debug'} || 0;
  $obj->{'net_ldap_version'} = $arg->{'version'} || $LDAP_VERSION;
  $obj->{'net_ldap_async'}   = $arg->{'async'} ? 1 : 0;

#    my $opt = $obj->{'net_ldap_options'}  = {};
#
#    $opt->{'async'} = $arg->{'async'} ? 1 : 0;
#
#    my $option;
#    foreach $option (qw(timelimit sizelimit)) {
#       $opt->{$option} = $arg->{$option}
#           if exists $arg->{$option};
#    }

  $obj;
}

sub async {
  $_[0]->{'net_ldap_async'};
}

sub debug {
  my $ldap = shift;

  @_
    ? ($ldap->{'net_ldap_debug'},$ldap->{'net_ldap_debug'} = shift)[0]
    : $ldap->{'net_ldap_debug'};
}

sub socket {
  $_[0]->{'net_ldap_socket'};
}

# what version are we talking?
sub version {
  my $ldap = shift;

  @_
    ? ($ldap->{'net_ldap_version'},$ldap->{'net_ldap_version'} = shift)[0]
    : $ldap->{'net_ldap_version'};
}

sub unbind {
  my $ldap = shift;
  my $arg = &_options;

  my $mesg = Net::LDAP::Unbind->new($ldap,$arg);

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER    => $mesg->mesg_id,
      REQ_UNBIND => 1                 # dummy arg to keep even args :-)
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub ldapbind {
  require Carp;
  Carp::carp("->ldapbind depricated, use ->bind") if $^W;
  goto &bind;
}

sub bind {
  my $ldap = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg  = &_options;

  $dn = $arg->{'dn'} || "" unless defined($dn); # compat

  require Net::LDAP::Bind;

  $ldap->version($arg->{'version'}) if exists $arg->{'version'};

  my $mesg = Net::LDAP::Bind->new($ldap,$arg);
  my $version = $ldap->version;

  my %ptype = qw(
    noauth          AUTH_NONE
    password        AUTH_SIMPLE
    krb41password   AUTH_KRBV41
    krb42password   AUTH_KRBV42
    kerberos41      AUTH_KRBV41
    kerberos42      AUTH_KRBV42
    sasl            AUTH_SASL
  );

  my($auth_type,$passwd) = ( AUTH_NONE => "");
  my $ctrl = _controls($arg->{'control'}) if ($version > 2);

  $dn = $dn->dn
    if (ref($dn) && isa($dn,'Net::LDAP::Entry'));

  my $ptype;
  foreach $ptype (keys %ptype) {
    if (exists $arg->{$ptype}) {
      ($auth_type,$passwd) = ($ptype{$ptype},$arg->{$ptype});
      last;
    }
  }

  $passwd = "" if ($auth_type  eq 'AUTH_NONE');

  if ($auth_type eq 'AUTH_SASL') {
    if ($version < 3) {
      # FIXME: Need V3 for SASL
    }
    my $sasl = $passwd;

    # Tell the SASL object our user identifier
    $sasl->user("dn: $dn");

    $passwd = [
        SASL_MECHANISM => $sasl->name,
        OPTIONAL => [ STRING => $sasl->initial ]
    ];

    # Save data, we will need it later
    $mesg->_sasl_info($dn,$ctrl,$sasl);
  }

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER  => $mesg->mesg_id,
      REQ_BIND => [
        INTEGER     => $version,
        LDAPDN      => $dn || "",
        $auth_type  => $passwd
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

my %scope = qw(base  0 one    1 single 1 sub    2 subtree 2);
my %deref = qw(never 0 search 1 find   2 always 3);

sub search {
  my $ldap = shift;
  my $arg = &_options;

  require Net::LDAP::Search;

  my $mesg = Net::LDAP::Search->new($ldap,$arg);

  my $base      = $arg->{'base'} || "";
  my $scope     = 2;
  my $deref     = 2;
  my $sizeLimit = $arg->{'sizelimit'} || 0;
  my $timeLimit = $arg->{'timelimit'} || 0;
  my $typesOnly = $arg->{'typesonly'} || $arg->{'attrsonly'} || 0;
  my $filter    = $arg->{'filter'};
  my $attribs   = $arg->{'attrs'} || [];

  if (exists $arg->{'scope'}) {
    my $sc = lc $arg->{'scope'};
    $scope = 0 + (exists $scope{$sc} ? $scope{$sc} : $sc);
  }

  if (exists $arg->{'deref'}) {
    my $dr = lc $arg->{'deref'};
    $deref = 0 + (exists $deref{$dr} ? $deref{$dr} : $dr);
  }

  unless (ref($filter)) {
    require Net::LDAP::Filter;
    $filter = Net::LDAP::Filter->new($filter)
      or return $mesg->set_error(LDAP_FILTER_ERROR,"$@");
  }

  my $ctrl = _controls($arg->{'control'});

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER    => $mesg->mesg_id,
      REQ_SEARCH => [
        LDAPDN   => $base,
        ENUM     => $scope,
        ENUM     => $deref,
        INTEGER  => $sizeLimit,
        INTEGER  => $timeLimit,
        BOOLEAN  => $typesOnly,
        BER      => $filter->isa('Convert::BER')
                      ? $filter
                      : $filter->ber,
        SEQUENCE => [
          STRING => $attribs  # sequence of STRINGs
        ]
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}


sub add {
  my $ldap = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg  = &_options;

  my $mesg = Net::LDAP::Add->new($ldap,$arg);

  my $entry;

  $dn ||= $arg->{'dn'} || undef;

  if (ref($dn) && isa($dn,'Net::LDAP::Entry')) {
    $entry = $dn;
  }
  else {
    require Net::LDAP::Entry;
    $entry = Net::LDAP::Entry->new();
    $entry->dn($dn);
    $entry->add(@{$arg->{'attrs'} || $arg->{'attr'} || []});
  }

  my $ctrl = _controls($arg->{'control'});
  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER => $mesg->mesg_id,
      REQ_ADD => [
        BER => $entry->encode,
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

my %opcode = ( 'add' => 0, 'delete' => 1, 'replace' => 2);

sub modify {
  my $ldap = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg  = &_options;

  $dn = $arg->{'dn'} unless defined($dn); # compat

  $dn = $dn->dn if (ref($dn) && isa($dn,'Net::LDAP::Entry'));

  my @ops;
  my $opcode;
  my $op;

  if (exists $arg->{'changes'}) {
    my $chg;
    my $opcode;
    my $j = 0;
    while($j < @{$arg->{'changes'}}) {
      $opcode = $opcode{$arg->{'changes'}[$j++]};
      $chg = $arg->{'changes'}[$j++];
      if (ref($chg)) {
	my $i = 0;
	while ($i < @$chg) {
          push @ops, [ $opcode, $chg->[$i], $chg->[$i+1] ];
	  $i += 2;
	}
      }
    }
  }
  else {
    foreach $op (qw(add delete replace)) {
      next unless exists $arg->{$op};
      my $opt = $arg->{$op};
      my $opcode = $opcode{$op};
      my($k,$v);

      if (ref($opt) eq 'HASH') {
	while (($k,$v) = each %$opt) {
          push @ops, [ $opcode, $k, $v ];
	}
      }
      elsif (ref($opt) eq 'ARRAY') {
	$k = 0;
	while ($k < @{$opt}) {
          my $attr = ${$opt}[$k++];
          my $val = $opcode == 1 ? [] : ${$opt}[$k++];
          push @ops, [ $opcode, $attr, $val ];
	}
      }
      else {
	push @ops, [ $opcode, "$opt", [] ];
      }
    }
  }

  my $mesg = Net::LDAP::Modify->new($ldap,$arg);

  my $ctrl = _controls($arg->{'control'});
  $mesg->ber->encode(
    SEQUENCE    => [
      INTEGER     => $mesg->mesg_id,
      REQ_MODIFY  => [
        LDAPDN      => $dn,
        SEQUENCE_OF => [ \@ops,
          SEQUENCE    => [
            ENUM      => sub { $_[0]->[0] },
            SEQUENCE  => [
              STRING    => sub { $_[0]->[1] },
              SET       => [
                STRING    => sub { $_[0]->[2] }
              ]
            ]
          ]
        ]
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub delete {
  my $ldap = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg  = &_options;

  $dn = $arg->{'dn'} unless defined($dn); # compat

  my $mesg = Net::LDAP::Delete->new($ldap,$arg);

  $dn = $dn->dn
    if (ref($dn) && isa($dn,'Net::LDAP::Entry'));

  my $ctrl = _controls($arg->{'control'});

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER    => $mesg->mesg_id,
      REQ_DELETE => $dn,
      OPTIONAL => [
        BER => $ctrl
      ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub moddn {
  my $ldap = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg  = &_options;
  my $new  = $arg->{'newrdn'} || $arg->{'new'};
  my $del  = $arg->{'deleteoldrdn'} || $arg->{'delete'} || 0;

  $dn = $arg->{'dn'} unless defined($dn); # compat

  my $mesg = Net::LDAP::ModDN->new($ldap,$arg);

  $dn = $dn->dn
    if (ref($dn) && isa($dn,'Net::LDAP::Entry'));

  $new = $new->dn
    if (ref($new) && isa($new,'Net::LDAP::Entry'));

  my $newsup = $arg->{'newsuperior'};

  $newsup = $newsup->dn
    if (ref($newsup) && isa($newsup,'Net::LDAP::Entry'));

  my $ctrl = _controls($arg->{'control'});

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER   => $mesg->mesg_id,
      REQ_MODDN => [
        LDAPDN    => $dn,
        LDAPDN    => $new,
        BOOLEAN   => $del,
        OPTIONAL  => [
          MOD_SUPERIOR => $newsup
        ]
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

# now maps to the V3/X.500(93) modifydn map
sub modrdn { goto &moddn }

sub compare {
  my $ldap  = shift;
  my $dn   = @_ & 1 ? shift : undef;
  my $arg   = &_options;

  $dn = $arg->{'dn'} unless defined($dn); # compat

  my $attr = exists $arg->{'attr'}
		? $arg->{'attr'}
		: exists $arg->{'attrs'} #compat
		   ? $arg->{'attrs'}[0]
		   : "";

  my $value = exists $arg->{'value'}
		? $arg->{'value'}
		: exists $arg->{'attrs'} #compat
		   ? $arg->{'attrs'}[1]
		   : "";

  my $mesg = Net::LDAP::Compare->new($ldap,$arg);
  my $ctrl = _controls($arg->{'control'});

  $dn = $dn->dn if (ref($dn) && isa($dn,'Net::LDAP::Entry'));

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER     => $mesg->mesg_id,
      REQ_COMPARE => [
        LDAPDN      => $dn,
        SEQUENCE    => [
          STRING => $attr,
          STRING => $value,
        ]
      ],
      OPTIONAL => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub abandon {
  my $ldap = shift;
  my $mesg_id = @_ & 1 ? shift : undef;
  my $arg = &_options;

  $mesg_id ||= $arg->{'id'};

  $mesg_id = $mesg_id->mesg_id
    if (ref($mesg_id) && UNIVERSAL::isa($mesg_id, 'Net::LDAP::Message'));

  my $mesg = Net::LDAP::Abandon->new($ldap,$arg);
  my $ctrl = _controls($arg->{'control'});

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER     => $mesg->mesg_id,
      REQ_ABANDON => $mesg_id
    ],
    OPTIONAL => [ BER => $ctrl ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub extension {
  my $ldap = shift;
  my $arg  = &_options;
  my $oid  = $arg->{'name'};
  my $string = $arg->{'value'};

  return if ($ldap->version < 3);

  require Net::LDAP::Extension;

  my $mesg = Net::LDAP::Extension->new($ldap, $arg);
  my $ctrl = _controls($arg->{'control'});
  my $ref  = defined ($string)
	       ? [ EXTEND_REQ_NAME => $oid, EXTEND_REQ_VALUE => $string ]
	       : [ EXTEND_REQ_NAME => $oid ];

  $mesg->ber->encode(
    SEQUENCE => [
      INTEGER    => $mesg->mesg_id,
      REQ_EXTEND => $ref,
      OPTIONAL   => [ BER => $ctrl ]
    ]
  ) or return $mesg->set_error(LDAP_ENCODING_ERROR,"$@");

  $ldap->_sendmesg($mesg);
}

sub sync {
  my $ldap = shift;
  my $mid  = shift;
  my $table = $ldap->{'net_ldap_mesg'};
  my $err = LDAP_SUCCESS;
  $mid = $mid->mesg_id if ref($mid);
  while (defined($mid) ? exists $table->{$mid} : %$table) {
    last if $err = $ldap->_recvresp($mid);
  }

  $err;
}

sub _sendmesg {
  my $ldap = shift;
  my $mesg = shift;
  my $ber = $mesg->ber;

  if ($ldap->debug & 1) {
    print STDERR "$ldap sending:\n";
    $ber->hexdump(\*STDERR);
  }

  $ber->write($ldap->socket)
    or return $mesg->set_error(LDAP_LOCAL_ERROR,"$!");

  # for CLDAP, here we need to recode when we were sent
  # so that we can perform timeouts and resends

  my $mid = $mesg->mesg_id;

  unless ($mesg->done) { # may not have a responce

    $ldap->{'net_ldap_mesg'}->{$mid} = $mesg;

    unless ($ldap->async) {
      my $err = $ldap->sync($mid);
      $mesg->set_error($err,$@) if $err;
    }
  }
  $mesg;
}

sub _recvresp {
  my $ldap = shift;
  my $what = shift;
  my $sock = $ldap->socket;
  my $sel = IO::Select->new($sock);
  my $ready;

  for( $ready = 1 ; $ready ; $ready = $sel->can_read(0)) {
    my $ber = Net::LDAP::BER->new();

    $ber->read($sock) or
      return LDAP_OPERATIONS_ERROR;

    if ($ldap->debug & 2) {
      print STDERR "$ldap received:\n";
      $ber->hexdump(\*STDERR);
    }

    my($mid,$data);

    $ber->decode(
      SEQUENCE => [
        INTEGER => \$mid,
        BER     => \$data
      ]
    ) or
      return LDAP_DECODING_ERROR;

    my $mesg = $ldap->{'net_ldap_mesg'}->{$mid} or
      return LDAP_PROTOCOL_ERROR;

    $mesg->decode($data) or
      return $mesg->code;

    last if defined $what && $what == $mid;
  }

  # FIXME: in CLDAP here we need to check if any message has timed out
  # and if so do we resend it or what

  return LDAP_SUCCESS;
}

sub _forgetmesg {
  my $ldap = shift;
  my $mesg = shift;

  my $mid = $mesg->mesg_id;

  delete $ldap->{'net_ldap_mesg'}->{$mid};
}

sub schema {
  require Net::LDAP::Schema;
  my $self = shift;
  my $mesg;

  unless ($self->{'net_ldap_schema'}) {
    my($m,$root) = $self->root_dse;

    return ($m, undef) unless $root;

    my $base = ($root->get('subschemasubentry'))[0] || 'cn=schema';

    $mesg = $self->search(
      base     => $base,
      scope    => 'base',
      filter   => '(objectClass=*)',
    );

    $self->{'net_ldap_schema'} = Net::LDAP::Schema->new($mesg)
      unless $mesg->code;
  }

  return ( $mesg, $self->{'net_ldap_schema'} );
}

sub root_dse {
  my $self = shift;
  my $mesg;
  
  unless ($self->{'net_ldap_rootdse'}) {
    $mesg = $self->search(
      base   => "",
      scope  => 'base',
      filter => "(objectClass=*)",
    );
    $self->{'net_ldap_rootdse'} = $mesg->entry;
  }

  return ($mesg, $self->{'net_ldap_rootdse'});
}

1;

