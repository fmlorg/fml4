# Copyright (c) 1998-1999 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::LDAP::Schema;

use strict;
use vars qw(%SyntaxDesc $VERSION);

$VERSION = "0.01";

# I have this table here, but I do not know why as I have not decided
# how to handle syntaxes. Is there any benefit from having a class
# per syntax which could provide some details like
#  * how to encode/decode the data
#  * the name (ie this table)
#  * verify the data

%SyntaxDesc = (
  "1.3.6.1.4.1.1466.115.121.1.1"  => "ACI Item",
  "1.3.6.1.4.1.1466.115.121.1.2"  => "Access Point",
  "1.3.6.1.4.1.1466.115.121.1.3"  => "Attribute Type Description",
  "1.3.6.1.4.1.1466.115.121.1.4"  => "Audio",
  "1.3.6.1.4.1.1466.115.121.1.5"  => "Binary",
  "1.3.6.1.4.1.1466.115.121.1.6"  => "Bit String",
  "1.3.6.1.4.1.1466.115.121.1.7"  => "Boolean",
  "1.3.6.1.4.1.1466.115.121.1.8"  => "Certificate",
  "1.3.6.1.4.1.1466.115.121.1.9"  => "Certificate List",
  "1.3.6.1.4.1.1466.115.121.1.10" => "Certificate Pair",
  "1.3.6.1.4.1.1466.115.121.1.11" => "Country String",
  "1.3.6.1.4.1.1466.115.121.1.12" => "DN",
  "1.3.6.1.4.1.1466.115.121.1.13" => "Data Quality Syntax",
  "1.3.6.1.4.1.1466.115.121.1.14" => "Delivery Method",
  "1.3.6.1.4.1.1466.115.121.1.15" => "Directory String",
  "1.3.6.1.4.1.1466.115.121.1.16" => "DIT Content Rule Description",
  "1.3.6.1.4.1.1466.115.121.1.17" => "DIT Structure Rule Description",
  "1.3.6.1.4.1.1466.115.121.1.18" => "DL Submit Permission",
  "1.3.6.1.4.1.1466.115.121.1.19" => "DSA Quality Syntax",
  "1.3.6.1.4.1.1466.115.121.1.20" => "DSE Type",
  "1.3.6.1.4.1.1466.115.121.1.21" => "Enhanced Guide",
  "1.3.6.1.4.1.1466.115.121.1.22" => "Facsimile Telephone Number",
  "1.3.6.1.4.1.1466.115.121.1.23" => "Fax",
  "1.3.6.1.4.1.1466.115.121.1.24" => "Generalized Time",
  "1.3.6.1.4.1.1466.115.121.1.25" => "Guide",
  "1.3.6.1.4.1.1466.115.121.1.26" => "IA5 String",
  "1.3.6.1.4.1.1466.115.121.1.27" => "INTEGER",
  "1.3.6.1.4.1.1466.115.121.1.28" => "JPEG",
  "1.3.6.1.4.1.1466.115.121.1.54" => "LDAP Syntax Description",
  "1.3.6.1.4.1.1466.115.121.1.56" => "LDAP Schema Definition",
  "1.3.6.1.4.1.1466.115.121.1.57" => "LDAP Schema Description",
  "1.3.6.1.4.1.1466.115.121.1.29" => "Master And Shadow Access Points",
  "1.3.6.1.4.1.1466.115.121.1.30" => "Matching Rule Description",
  "1.3.6.1.4.1.1466.115.121.1.31" => "Matching Rule Use Description",
  "1.3.6.1.4.1.1466.115.121.1.32" => "Mail Preference",
  "1.3.6.1.4.1.1466.115.121.1.33" => "MHS OR Address",
  "1.3.6.1.4.1.1466.115.121.1.55" => "Modify Rights",
  "1.3.6.1.4.1.1466.115.121.1.34" => "Name And Optional UID",
  "1.3.6.1.4.1.1466.115.121.1.35" => "Name Form Description",
  "1.3.6.1.4.1.1466.115.121.1.36" => "Numeric String",
  "1.3.6.1.4.1.1466.115.121.1.37" => "Object Class Description",
  "1.3.6.1.4.1.1466.115.121.1.40" => "Octet String",
  "1.3.6.1.4.1.1466.115.121.1.38" => "OID",
  "1.3.6.1.4.1.1466.115.121.1.39" => "Other Mailbox",
  "1.3.6.1.4.1.1466.115.121.1.41" => "Postal Address",
  "1.3.6.1.4.1.1466.115.121.1.42" => "Protocol Information",
  "1.3.6.1.4.1.1466.115.121.1.43" => "Presentation Address",
  "1.3.6.1.4.1.1466.115.121.1.44" => "Printable String",
  "1.3.6.1.4.1.1466.115.121.1.58" => "Substring Assertion",
  "1.3.6.1.4.1.1466.115.121.1.45" => "Subtree Specification",
  "1.3.6.1.4.1.1466.115.121.1.46" => "Supplier Information",
  "1.3.6.1.4.1.1466.115.121.1.47" => "Supplier Or Consumer",
  "1.3.6.1.4.1.1466.115.121.1.48" => "Supplier And Consumer",
  "1.3.6.1.4.1.1466.115.121.1.49" => "Supported Algorithm",
  "1.3.6.1.4.1.1466.115.121.1.50" => "Telephone Number",
  "1.3.6.1.4.1.1466.115.121.1.51" => "Teletex Terminal Identifier",
  "1.3.6.1.4.1.1466.115.121.1.52" => "Telex Number",
  "1.3.6.1.4.1.1466.115.121.1.53" => "UTC Time"
);

# This is one way we could put each syntax into a class

sub syntax {
  my $self = shift; # ignore;
  my $oid = shift;
  my($p,$n) = ($oid =~ /^(.+\.)?(\d+)$/);
  my $pkg = __PACKAGE__ . "::oid$n" if $n;

  return undef
    unless ((!length($p) || $p eq "1.3.6.1.4.1.1466.115.121.1")
            && $n && eval "require $pkg");

  bless \$oid, $pkg;
}

# Get schema from the server and parse it into my data structure

sub new {
  my $self = shift;
  my $type = ref($self) || $self;
  my $mesg = shift;
  my $entry = $mesg->entry or return;

  my %schema;
  _parse_schema($entry,\%schema);
  $schema{'entry'} = $entry;

  bless \%schema, $type;
}

sub entry {
  $_[0]->{'entry'};
}

sub dump {
  my $self = shift;
  my $fh = @_ ? shift : \*STDOUT;
  my $entry = $self->{'entry'} or return;
  require Net::LDAP::LDIF;
  Net::LDAP::LDIF->new($fh,"w", wrap => 0)->write($entry);
  1;
}

my %flags = map { ($_,1) } qw(
  SINGLE-VALUE
  OBSOLETE
  COLLECTIVE
  NO-USER-MODIFICATION
  ABSTRACT
  STRUCTURAL
  AUXILIARY
);

# Parse the data, this is crude as it assumes the data from the server
# is syntactically correct

sub _parse_schema {
  my($entry,$result) = @_;
  return unless defined($entry);

  my $what;
  foreach $what (qw(attributetypes objectclasses)) {
    my $attrs = $entry->get_attribute($what);
    next unless $attrs;
    $result->{$what} ||= {};
    my $attr;
    foreach $attr (@$attrs) {
      my($data,$name);
      ($data = $attr) =~ s/(^s*\(\s*|\s*\)\s*$)//g;
      $data .= " ";
      $data =~ s/^(\d+(\.\d+)+|[a-zA-Z][-a-zA-Z0-9;]+)\s+//
        or die "Bad schema";
      $name = $1;
      my $hash = {};
      while (length($data)) {
        $data =~ s/^([-A-Z]+)\s+// or die "Bad schema";
        my $key = $1;
        if (exists $flags{$key}) {
          $hash->{$key} = 1;
          next;
        }
        my $list = 1;
        my $value;
        if ($data =~ s/^\(\s*//) {
          $list = -1;
          $value = [];
        }
        while ($list--) {
          $data =~ s/^(([^']\S*)|'([^']+)')\s+//;
          if ($list) {
            if ( $+ eq ')' ) {
              last;
            }
            elsif ( $+ eq '$') {
              next;
            }
            else {
              push @$value, $+;
            }
          }
          else {
            $value = $+;
            last;
          }
        }
        $hash->{$key} = $value;
      }
      $result->{$what}->{$name} = $hash;
    }
  }
}

# The names of all the attributes

sub attributetypes {
  my $self = shift;
  keys %{$self->{'attributetypes'}}
}

# The names of all the object classes

sub objectclasses {
  my $self = shift;
  keys %{$self->{'objectclasses'}}
}

# We also have two ways to get details about the schema, one
# creates a class for each attribute/class the other does not

# return the object for an attribute, methods on this will get the data

sub attribute {
  my($self,$attr) = @_;
  my $at = $self->{'attributetypes'};
  $attr = lc $attr;

  exists $at->{$attr}
    ? bless $at->{$attr}, 'Net::LDAP::Schema::attribute'
    : undef;
}

# return the object for a class, methods on this will get the data

sub class {
  my($self,$attr) = @_;
  my $at = $self->{'objectclasses'};

  $attr = lc $attr;

  exists $at->{$attr}
    ? bless $at->{$attr}, 'Net::LDAP::Schema::class'
    : undef;
}

# Given an attribute name, return the syntax object
# but if we dump this, then the at_syntax_oid method will be renamed
# as at_syntax

sub at_syntax {
  my $self = shift;
  my $name = shift;
  my $oid = $self->at_syntax_oid($name) or return;
  $self->syntax($oid);
}

# This is the other method for getting at data here we use AUTOLOAD to
# generate methods to access the data
# methods starting at_ access teh elements of attributes
# methods starting oc_ access teh elements of attributes
# eg at_description will return the DESC data from teh given attribute
#
# Is this method better than the class method ? Do we need/want both ?

use vars qw($AUTOLOAD);

my %map = qw(
  name            NAME
  description     DESC
  obsolete        OBSOLETE
  superior        SUP

  oc_single_value SINGLE-VALUE

  at_syntax_oid   SYNTAX
  at_must         MUST
  at_may          MAY
  at_readonly     NO-USER-MODIFICATION
);

my %list = qw(
  at_must       MUST
  at_may        MAY
);

my %type = qw(
  at            attributetypes
  oc            objectclasses
);

sub DESTROY {} # prevent calling AUTOLOAD

sub AUTOLOAD {
  my $sub; ($sub = $AUTOLOAD) =~ s/.*:://;
  my $prefix = ($sub =~ /(at|oc)_/)[0];
  my $elem   = $map{$sub} || $map{ substr($sub,3) } || undef;

  unless (defined($prefix) && defined($elem)) {
    use Carp;
    my($p,$m);
    ($p,$m) = ($AUTOLOAD =~ /^(.*)::([^:]+)$/);
    Carp::croak(qq!Can't locate object method "$m" via package "$p"!);
  }

  my $type = $type{$prefix};

  no strict 'refs';

  *$AUTOLOAD = sub {
    return unless exists $_[0]->{$type}{$_[1]}
                && exists $_[0]->{$type}{$_[1]}{$elem};

    my $entry = $_[0]->{$type}{$_[1]}{$elem};
    ref($entry)
      ? wantarray
        ? @{$entry}
        : $entry->[0]
      : $entry;
  };

  goto &$AUTOLOAD;
}

package Net::LDAP::Schema::class;

# The routine that dets the data
#
# if the element does not exists returns undef or ()
#
# if in an array context return all data elements in list
# if in scalar return the data element or the first if there is a list

sub _get_value {
  return unless exists $_[0]->{$_[1]};

  my $entry = $_[0]->{$_[1]};

  ref($entry)
    ? wantarray
      ? @{$entry}
      : $entry->[0]
    : $entry;
}

sub name         { scalar(_get_value($_[0],'NAME')) }
sub description  { scalar(_get_value($_[0],'DESC')) }
sub single_value { scalar(_get_value($_[0],'SINGLE-VALUE')) }

sub must        { _get_value($_[0],'MUST') }
sub may         { _get_value($_[0],'MAY') }

package Net::LDAP::Schema::attribute;

BEGIN {
  *_get_value = \&Net::LDAP::Schema::class::_get_value;
}

sub name        { scalar(_get_value($_[0],'NAME')) }
sub syntax_oid  { scalar(_get_value($_[0],'SYNTAX')) }
sub description { scalar(_get_value($_[0],'DESC')) }
sub superior    { scalar(_get_value($_[0],'SUP')) }

sub syntax {
    my $oid = _get_value($_[0],'SYNTAX') or return;
    Net::LDAP::Schema->syntax($oid);
}

@schema2asn = (
  'SYNTAX'		=> "WITH SYNTAX",
  'OBSOLETE'		=> "OBSOLETE",
  'SUP'			=> "SUBTYPE OF",
  'EQUALITY'		=> "EQUALITY MATCHING RULE",
  'ORDERING'		=> "ORDERING MATCHING RULE",
  'SUBSTR'		=> "SUBSTRINGS MATCHING RULE",
  'NOUSERMODIFICATION'	=> "NO USER MODIFICATION",
  'USAGE'		=> "USAGE",
  'COLLECTIVE'		=> "COLLECTIVE",
  'SINGLE-VALUE'	=> "SINGLE VALUE"
);

sub asn {
  my $self = shift;
  my $asn =  exists $self->{'NAME'} ? $self->{'NAME'} : "noname";
  $asn .= " ATTRIBUTE ::= {\n";
  $asn .= "}\n";
}

1;
