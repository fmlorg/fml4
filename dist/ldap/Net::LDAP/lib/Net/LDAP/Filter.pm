
package Net::LDAP::Filter;

use Net::LDAP::BER ();
use strict;
use vars qw($VERSION);

$VERSION = "0.10";

# filter       = "(" filtercomp ")"
# filtercomp   = and / or / not / item
# and          = "&" filterlist
# or           = "|" filterlist
# not          = "!" filter
# filterlist   = 1*filter
# item         = simple / present / substring / extensible
# simple       = attr filtertype value
# filtertype   = equal / approx / greater / less
# equal        = "="
# approx       = "~="
# greater      = ">="
# less         = "<="
# extensible   = attr [":dn"] [":" matchingrule] ":=" value
#                / [":dn"] ":" matchingrule ":=" value
# present      = attr "=*"
# substring    = attr "=" [initial] any [final]
# initial      = value
# any          = "*" *(value "*")
# final        = value
# attr         = AttributeDescription from Section 4.1.5 of [1]
# matchingrule = MatchingRuleId from Section 4.1.9 of [1]
# value        = AttributeValue from Section 4.1.6 of [1]
# 
# Special Character encodings
# ---------------------------
#    *               \2a, \*
#    (               \28, \(
#    )               \29, \)
#    \               \5c, \\
#    NUL             \00

my $ErrStr;

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  
  my $me = bless [], $class;

  if (@_) {
    $me->parse(shift) or
      return undef;
  }
  $me;
}

my($Attr)  = qw{  [-;.:\d\w]*[-;\d\w] };
my($Op)    = qw{  [:~<>]?=            };
my($Value) = qw{  (?:\\.|[^\\()]+)*   };

my %Op = qw(
  &   FILTER_AND
  |   FILTER_OR
  !   FILTER_NOT
  =   FILTER_EQ
  ~=  FILTER_APPROX
  >=  FILTER_GE
  <=  FILTER_LE
  :=  FILTER_EXTENSIBLE
);

my %Rop = reverse %Op;

# Unescape
#   \xx where xx is a 2-digit hex number
#   \y  where y is one of ( ) \ *

sub errstr { $ErrStr }

sub _unescape {
  $_[0] =~ s/
	     \\([\da-fA-F]{2}|.)
	    /
	     length($1) == 1
	       ? $1
	       : chr(hex($1))
	    /soxeg;
  $_[0];
}

sub _escape { $_[0] =~ s/([\\\(\)\*\0])/sprintf("\\%02x",ord($1))/sge; }

sub _encode {
  my($attr,$op,$val) = @_;

  # An extensible match

  if ($op eq ':=') {

    # attr must be in the form type:dn:1.2.3.4
    unless ($attr =~ /^([-;\d\w]*)(:dn)?(:([.\d]+))?/) {
      $ErrStr = "Bad attribute $attr";
      return undef;
    }
    my($type,$dn,$rule) = ($1,$2,$4);

    return (
      FILTER_EXTENSIBLE => [
	OPTIONAL => [ EXTENSIBLE_RULE => $rule ],
	OPTIONAL => [ EXTENSIBLE_TYPE => $type ],
	EXTENSIBLE_VALUE => _unescape($val),
	EXTENSIBLE_DN    => $dn
      ]
    );
  }

  # If the op is = and contains one or more * not
  # preceeded by \ then do partial matches

  if ($op eq '=' && $val =~ /^(?:(?:\\\*|[^*])*)\*/o) {
    my $n = [];
    my $type = 'SUBSTR_INITIAL';

    while ($val =~ s/^((?:\\\*|[^*])*)\*+//) {
      push(@$n, $type, _unescape("$1"))         # $1 is readonly, copy it
	if length $1;

      $type = 'SUBSTR_ANY';
    }

    push(@$n, 'SUBSTR_FINAL', _unescape($val))
      if length $val;

    return (
      FILTER_SUBSTRS => [
	STRING   => $attr,
	SEQUENCE => $n
      ]
    );
  }

  # Well we must have an operator and no un-escaped *'s on the RHS

  return (
    $Op{$op} => [
      STRING => $attr,
      STRING => _unescape($val)
    ]
  );
}

sub parse {
  my $self   = shift;
  my $filter = shift;

  my @stack = ();   # stack
  my $cur   = $self;

  undef $ErrStr;
  @$cur = ();

  # Algorithm depends on /^\(/;
  $filter =~ s/^\s*//;

  $filter = "(" . $filter . ")"
    unless $filter =~ /^\(/;

  while (length($filter)) {

    # Process the start of  (& (...)(...))

    if ($filter =~ s/^\(\s*([&|!])\s*//) {
      my $n = [];                   # new list to hold filter elements

      push(@$cur, $Op{$1}, $n);
      push(@stack,$cur);            # push current list on the stack

      $cur = $n;
      next;
    }

    # Process the end of  (& (...)(...))

    if ($filter =~ s/^\)\s*//o) {
      $cur = pop @stack;
      last unless @stack;
      next;
    }
    
    # present is a special case (attr=*)

    if ($filter =~ s/^\(\s*($Attr)=\*\)\s*//o) {
      push(@$cur, FILTER_PRESENT => $1);
      next;
    }

    # process (attr op string)

    if ($filter =~ s/^\(\s*($Attr)\s*($Op)($Value)\)\s*//o) {
      push(@$cur, _encode($1,$2,$3));
      next;
    }

    # If we get here then there is an error in the filter string
    # so exit loop with data in $filter
    last;
  }

  if (length $filter) {
    # If we have anything left in the filter, then there is a problem
    $ErrStr = "Bad filter, error before " . substr($filter,0,20);
    return undef;
  }

  $self;
}

sub ber {
  my $self = shift;
  my $ber = new Net::LDAP::BER();

  return undef
    unless $ber->encode( @$self );

  $ber;
}

sub print {
  my $self = shift;
  no strict 'refs'; # select may return a GLOB name
  my $fh = @_ ? shift : select;

  print $fh $self->as_string,"\n";
}

sub as_string { _string(@{$_[0]}) }

sub _string {    # prints things of the form (<op> (<list>) ... )
  my @self = @_;
  my $i;
  my $str = "";

  for ($i=0; $i <= $#self; $i+=2) {  # List of ( operator, list ... )
    my $op = $Rop{$self[$i]} || '';
    if ($op =~ /^[&!|]$/) {  
      $str .= "($op" . _string(@{$self[$i+1]}) . ")";
    } else {
      $str .= _string_infix(@self[$i,$i+1],$op);
    }
  }
  $str;
}

sub _string_infix {    #  prints infix items of the form ( <attrib> <op> <val> )
  my($tag, $items, $op) = @_;

  # An EXTENSIBLE match

  if ($op eq ':=') {
    my($rule,$type,$val,$dn) = ($items->[1][1],$items->[3][1],$items->[5],$items->[7]);

    $val =~ s/([\\\(\)\*\0])/sprintf("\\%02x",ord($1))/sge;

    return join("",
         '(',
	   ($type ? ($type)     : ()),
	   ($dn   ? (':dn')     : ()),
	   ($rule ? (':',$rule) : ()),
	   ':=',
	   $val,
	 ')');

  }

  # ~= >= <= or simple =

  if (length $op) {
    my $val = $items->[3];

    $val =~ s/([\\\(\)\*\0])/sprintf("\\%02x",ord($1))/sge;

    return "($items->[1]$op$val)";
  }

  # PRESENT

  if ($tag eq 'FILTER_PRESENT') {
    return "($items=*)";
  }

  # SUBSTRS

  if ($tag eq 'FILTER_SUBSTRS') {
    my @bits = ( '(', $items->[1], '=');
    my $substrs = $items->[3];
    my $substr;

    push(@bits, '*')
        if $substrs->[0] ne 'SUBSTR_INITIAL';

    for( $substr=0; $substr < $#{$substrs}; $substr += 2) {
      my $val = $substrs->[$substr+1];

      $val =~ s/([\\\(\)\*\0])/sprintf("\\%02x",ord($1))/sge;

      push(@bits,
           $val,
	   $substrs->[$substr] ne 'SUBSTR_FINAL' ? '*' : ());
    }
    return join("",@bits,")");
  }

  return "";
}

1;
