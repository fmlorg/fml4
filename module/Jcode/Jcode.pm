#
# $Id: Jcode.pm,v 1.1.1.1 2000/09/26 04:01:59 fukachan Exp $
#

=head1 NAME

Jcode - Japanese Charset Handler

=head1 SYNOPSIS

 use Jcode;
 
 # traditional
 Jcode::convert(\$str, $ocode, $icode, "z");
 # or OOP!
 print Jcode->new($str)->h2z->tr($from, $to)->utf8;

=cut

=head1 DESCRIPTION

Jcode.pm supports both object and traditional approach.  
With object approach, you can go like;

$iso_2022_jp = Jcode::new($str)->h2z->jis;

Which is more elegant than;

$iso_2022_jp = &jcode::convert(\$str,'jis',jcode::getcode(\str), "z");

For those unfamiliar with objects, Jcode.pm still supports getcode()
and convert(). 

=cut

package Jcode;
require 5.004;

use strict;
use vars qw($RCSID $VERSION);

$RCSID = q$Id: Jcode.pm,v 1.1.1.1 2000/09/26 04:01:59 fukachan Exp $;
$VERSION = do { my @r = (q$Revision: 1.1.1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use Carp;

BEGIN {
    use Exporter;
    use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    @ISA         = qw(Exporter);
    @EXPORT      = qw(jcode getcode);
    @EXPORT_OK   = qw($RCSID $VERSION $DEBUG $USE_CACHE);
    %EXPORT_TAGS = ( all => [ @EXPORT_OK, @EXPORT ] );
}

use vars @EXPORT_OK;

$DEBUG = 0;
$USE_CACHE = 1;

print $RCSID, "\n" if $DEBUG;

use Jcode::Constants qw(:all);

=head1 Methods

Methods mentioned here all return Jcode object unless otherwise mentioned.

=over 4

=cut

use overload 
    '""' => sub { ${$_[0]->[0]} },
    '==' => sub {overload::StrVal($_[0]) eq overload::StrVal($_[1])},
    fallback => 1,
    ;

=item $j = Jcode->new($str [, $icode]);

Creates Jcode object $j from $str.  Input code is automatically checked 
unless you explicitly set $icode. For available charset, see L<getcode()>
below.

The object keeps the string in EUC format enternaly.  When the object 
itself is evaluated, it returns the EUC-converted string so you can 
"print $j;" without calling access method if you are using EUC 
(thanks to function overload).

=item Passing Reference

Instead of scalar value, You can use reference as

Jcode->new(\$str);

This saves time a little bit.  In exchange of the value of $str being 
converted. (In a way, $str is now "tied" to jcode object).

=cut

sub new {
    my $class = shift;
    my ($thingy, $icode) = @_;
    my $r_str = _mkbuf($thingy);
    my $nmatch;
    ($icode, $nmatch) = getcode($r_str) unless $icode;
    convert($r_str, 'euc', $icode);
    my $self = [
	$r_str,
	$icode,
	$nmatch,
    ];
    carp "Object of class $class created" if $DEBUG >= 2;
    bless $self, $class;
}

sub r_str  { $_[0]->[0] }
sub icode  { $_[0]->[1] }
sub nmatch { $_[0]->[2] }

=item $j->set($str [, $icode]);

Sets $j's internal string to $str.  Handy when you use Jcode object repeatedly 
(saves time and memory to create object). 

 # converts mailbox to SJIS format
 my $jconv = new Jcode;
 while(&lt;&gt;){
     print $jconv->set(\$_)->mime_decode->sjis;
 }

=cut

sub set {
    my $self = shift;
    my ($thingy, $icode) = @_;
    my $r_str = _mkbuf($thingy);
    my $nmatch;
    ($icode, $nmatch) = getcode($r_str) unless $icode;
    convert($r_str, 'euc', $icode);
    $self->[0] = $r_str;
    $self->[1] = $icode;
    $self->[2] = $nmatch;
    return $self;
}

=item $j->append($str [, $icode]);

Appends $str to $j's internal string.

=cut

sub append {
    my $self = shift;
    my ($thingy, $icode) = @_;
    my $r_str = _mkbuf($thingy);
    my $nmatch;
    ($icode, $nmatch) = getcode($r_str) unless $icode;
    convert($r_str, 'euc', $icode);
    ${$self->[0]} .= $$r_str;
    $self->[1] = $icode;
    $self->[2] = $nmatch;
    return $self;
}


=item $j = jcode($str [, $icode]);

shortcut for Jcode->new() so you can go like;

$sjis = jcode($str)->sjis;

=item $euc = $j->euc;

=item $jis = $j->jis;

=item $sjis = $j->sjis;

What you code is what you get :)

=cut

sub jcode { return Jcode->new(@_) }
sub euc   { return ${$_[0]->[0]} }
sub jis   { return  &euc_jis(${$_[0]->[0]})}
sub sjis  { return &euc_sjis(${$_[0]->[0]})}


=item $iso_2022_jp = $j->iso_2022_jp

Same as $j->z2h->jis.  
Hankaku Kanas are forcibly converted to Zenkaku.

=cut

sub iso_2022_jp{return $_[0]->h2z->jis}

=head2 Methods that use MIME::Base64

To use methods below, you need MIME::Base64.  To install, simply

   perl -MCPAN -e 'CPAN::Shell->install("MIME::Base64")'

=item $mime_header = $j->mime_encode;

Converts $str to MIME-Header documented in RFC1522.

=cut

sub mime_encode{
    require MIME::Base64; # not use
    my $self = shift;
    my $jis = $self->iso_2022_jp;
    my $base64 = MIME::Base64::encode_base64($jis, "");
    return '=?ISO-2022-JP?B?' . $base64 .  '?=';
}

=item $j->mime_decode;

Decodes MIME-Header in Jcode object.

You can retrieve the number of matches via $j->nmatch;

=cut

sub mime_decode{
    require MIME::Base64; # not use
    my $self = shift;
    my $r_str = $self->[0];
    $self->[2] = 
	(
	 $$r_str =~ s(
		      =\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?
		      ([A-Za-z0-9\+\/]+=*)
		      \?=
		      )
	 {
	     jis_euc(MIME::Base64::decode_base64($1));
	 }ogex
	 );
    $self;
}

=head2 Methods implemented by Jcode::H2Z

Methods below are actually implemented in Jcode::H2Z.

=item $j->h2z([$keep_dakuten]);

Converts X201 kana (Hankaku) to X208 kana (Zenkaku).  
When $keep_dakuten is set, it leaves dakuten as is
(That is, "ka + dakuten" is left as is instead of
being converted to "ga")

You can retrieve the number of matches via $j->nmatch;

=cut

sub h2z {
    require Jcode::H2Z; # not use
    my $self = shift;
    $self->[2] = Jcode::H2Z::h2z($self->[0], @_);
    return $self;
}

=item $j->z2h;

Converts X208 kana (Zenkaku) to X201 kana (Hankazu).

You can retrieve the number of matches via $j->nmatch;

=cut

sub z2h {
    require Jcode::H2Z; # not use
    my $self = shift;
    $self->[2] =  &Jcode::H2Z::z2h($self->[0], @_);
    return $self;
}

=head2 Methods implemented in Jcode::Tr

Methods here are actually implemented in Jcode::Tr.

=item  $j->tr($from, $to);

Applies tr on Jcode object. $from and $to can contain EUC Japanese.

You can retrieve the number of matches via $j->nmatch;

=cut

sub tr{
    require Jcode::Tr; # not use
    my $self = shift;
    $self->[2] = Jcode::Tr::tr($self->[0], @_);
    return $self;
}

#
# load needed module depending on the configuration just once!
#

use vars qw(%PKG_LOADED);
sub load_module{
    my $pkg = shift;
    return $pkg if $PKG_LOADED{$pkg}++;
    eval qq( require $pkg; );
    unless ($@){
	carp "$pkg loaded." if $DEBUG;
    }else{
	$pkg .= "::NoXS";
	eval qq( require $pkg; );
	unless ($@){
	    carp "$pkg loaded" if $DEBUG;
	}else{
	    croak "Loading $pkg failed!";
	}
    }
    $pkg;
}

=head2 Methods implemented in Jcode::Unicode

If your perl does not support XS (or you can't C<perl Makefile.PL>,
Jcode::Unicode::NoXS will be used.

See L<Jcode::Unicode> and L<Jcode::Unicode::NoXS> for details

=item $ucs2 = $j->ucs2;

Returns UCS2 (Raw Unicode) string.

=cut

sub ucs2{
    load_module("Jcode::Unicode");
    euc_ucs2(${$_[0]->[0]});
}

=item $ucs2 = $j->utf8;

Returns utf8 String.

=cut

sub utf8{
    load_module("Jcode::Unicode");
    euc_utf8(${$_[0]->[0]});
}

=head2 Instance Variables

If you need to access instance variables of Jcode object, use access
methods below instead of directly accessing them (That's what OOP
is all about)

FYI, Jcode uses a ref to array instead of ref to hash (common way) to
optimize speed (Actually you don't have to know as long as you use
access methods instead;  Once again, that's OOP)

=item $j->r_str

Reference to the EUC-coded String.

=item $j->icode

Input charcode in recent operation.

=item $j->nmatch

Number of matches (Used in $j->tr, etc.)

=cut

=head1 Subroutines

=item ($code, [$nmatch]) = getcode($str);

Returns char code of $str. Return codes are as follows

 ascii   Ascii (Contains no Japanese Code)
 binary  Binary (Not Text File)
 euc     EUC-JP
 sjis    SHIFT_JIS
 jis     JIS (ISO-2022-JP)
 ucs2    UCS2 (Raw Unicode)
 utf8    UTF8

When array context is used instead of scaler, it also returns how many
character codes are found.  As mentioned above, $str can be \$str
instead.

=item jcode.pl Users:

This function is 100% upper-conpatible with jcode::getcode() -- well, almost;

 * When its return value is an array, the order is the opposite;
   jcode::getcode() returns $nmatch first.

 * jcode::getcode() returns 'undef' when the number of EUC characters
   is equal to that of SJIS.  Jcode::getcode() returns EUC.  for
   Jcode.pm is no in-betweens. 

=cut

sub getcode {
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    my ($code, $nmatch, $sjis, $euc, $utf8) = ("", 0, 0, 0, 0);
    
    if ($$r_str =~ /$RE{BIN}/o) {	# 'binary'
	my $ucs2;
	$ucs2 += length($1)
	    while $$r_str =~ /(\x00$RE{ASCII})+/go;
	if ($ucs2){      # smells like raw unicode 
	    ($code, $nmatch) = ('ucs2', $ucs2);
	}else{
	    ($code, $nmatch) = ('binary', 0);
	 }
    }
    elsif ($$r_str !~ /[\e\x80-\xff]/o) {	# not Japanese
	($code, $nmatch) = ('ascii', 1);
    }				# 'jis'
    elsif ($$r_str =~ 
	   m[
	     $RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA}
	   ]ox)
    {
	($code, $nmatch) = ('jis', 1);
    } 
    else { # should be euc|sjis|utf8
	# use of (?:) by Hiroki Ohzaki <ohzaki@iod.ricoh.co.jp>
	$sjis += length($1) 
	    while $$r_str =~ /((?:$RE{SJIS_C})+)/go;
	$euc  += length($1) 
	    while $$r_str =~ /((?:$RE{EUC_C}|$RE{EUC_KANA}|$RE{EUC_0212})+)/go;
	$utf8  += length($1) 
	    while $$r_str =~ /((?:$RE{UTF8})+)/go;
	$nmatch = _max($utf8, $sjis, $euc);
	carp ">DEBUG:sjis = $sjis, euc = $euc, utf8 = $utf8" if $DEBUG >= 3;
	$code = 
	    ($euc > $sjis and $euc > $utf8) ? 'euc' :
		($sjis > $euc and $sjis > $utf8) ? 'sjis' :
		    ($utf8 > $euc and $utf8 > $sjis) ? 'utf8' : undef;
    }
    return wantarray ? ($code, $nmatch) : $code;
}

=item Jcode::convert($str, [$ocode, $icode, $opt]);

Converts $str to char code specified by $ocode.  When $icode is specified
also, it assumes $icode for input string instead of the one checked by
getcode(). As mentioned above, $str can be \$str instead.

=item jcode.pl Users:

This function is 100% upper-conpatible with jcode::convert() !

=cut

sub convert{
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    my ($ocode, $icode, $opt) = @_;

    my $nmatch;
    ($icode, $nmatch) = getcode($r_str) unless $icode;

    return $$r_str if $icode eq $ocode; # do nothin'

    no strict qw(refs);
    my $method;

    # convert to EUC

    load_module("Jcode::Unicode") if $icode =~ /ucs2|utf8/o;
    if ($icode and defined &{$method = $icode . "_euc"}){
	carp "Dispatching \&$method" if $DEBUG >= 2;
	&{$method}($r_str) ;
    }

    # h2z or z2h

    if ($opt){
	my $cmd = ($opt =~ /^z/o) ? "h2z" : ($opt =~ /^h/o) ? "z2h" : undef;
	if ($cmd){
	    require Jcode::H2Z;
	    &{'Jcode::H2Z::' . $cmd}($r_str);
	}
    }
    
    # convert to $ocode

    load_module("Jcode::Unicode") if $ocode =~ /ucs2|utf8/o;
    if ($ocode and defined &{$method = "euc_" . $ocode}){
	carp "Dispatching \&$method" if $DEBUG >= 2;
	&{$method}($r_str) ;
    }
    $$r_str;
}

# JIS<->EUC

sub jis_euc {
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    $$r_str =~ s(
		 ($RE{JIS_0212}|$RE{JIS_0208}|$RE{JIS_ASC}|$RE{JIS_KANA})
		 ([^\e]*)
		 )
    {
	my ($esc, $str) = ($1, $2);
	if ($esc !~ /$RE{JIS_ASC}/o) {
	    $str =~ tr/\x21-\x7e/\xa1-\xfe/;
	    if ($esc =~ /$RE{JIS_KANA}/o) {
		$str =~ s/([\xa1-\xdf])/\x8e$1/og;
	    }
	    elsif ($esc =~ /$RE{JIS_0212}/o) {
		$str =~ s/([\xa1-\xfe][\xa1-\xfe])/\x8f$1/og;
	    }
	}
	$str;
    }geox;
    $$r_str;
}

#
sub euc_jis {
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    $$r_str =~ s{
	(($RE{EUC_C}|$RE{EUC_KANA}|$RE{EUC_0212})+)
	}
    {
	my $str = $1;
	my $esc = ($str =~ tr/\x8e//d) ?	$ESC{KANA} : 
	    ($str =~ tr/\x8f//d) ? $ESC{JIS_0212} : $ESC{JIS_0208};
	$str =~ tr/\xa1-\xfe/\x21-\x7e/;
	$esc . $str . $ESC{ASC}
    }geox;
    $$r_str;
}

# EUC<->SJIS

my %_S2E = ();
my %_E2S = ();

sub sjis_euc {
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    $$r_str =~ s(
		 ($RE{SJIS_C}|$RE{SJIS_KANA})
	     )
    {
	my $str = $1;
	unless ($_S2E{$1}){
	    my ($c1, $c2) = unpack('CC', $str);
	    if (0xa1 <= $c1 && $c1 <= 0xdf) {
		$c2 = $c1;
		$c1 = 0x8e;
	    } elsif (0x9f <= $c2) {
		$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
		$c2 += 2;
	    } else {
		$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
		$c2 += 0x60 + ($c2 < 0x7f);
	    }
	    $_S2E{$str} = pack('CC', $c1, $c2);
	}
	$_S2E{$str};
    }geox;
    $$r_str;
}

#

sub euc_sjis {
    my $thingy = shift;
    my $r_str = _mkbuf($thingy);
    $$r_str =~ s(
		 ($RE{EUC_C}|$RE{EUC_KANA}|$RE{EUC_0212})
		 )
    {
	my $str = $1;
	unless ($_E2S{$str}){
	    my ($c1, $c2) = unpack('CC', $str);
	    if ($c1 == 0x8e) {          # SS2
		$_E2S{$str} = chr($c2);
	    } elsif ($c1 == 0x8f) {     # SS3
		$_E2S{$str} = $CHARCODE{UNDEF_SJIS};
	    }else { #SS1 or X0208
		if ($c1 % 2) {
		    $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
		    $c2 -= 0x60 + ($c2 < 0xe0);
		} else {
		    $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
		    $c2 -= 2;
		}
		$_E2S{$str} = pack('CC', $c1, $c2);
	    }
	}
	$_E2S{$str};
    }geox;
    $$r_str;
}

#

1;

__END__

=head1 BUGS

=item Unicode support by Jcode is far from efficient!

=head1 ACKNOWLEDGEMENTS

This package owes a lot in motivation, design, and code, to the jcode.pl 
for Perl4 by Kazumasa Utashiro <utashiro@iij.ad.jp>.

Hiroki Ohzaki <ohzaki@iod.ricoh.co.jp> has helped me polish regexp from the 
very first stage of development.

And folks at Jcode Mailing list <jcode5@ring.gr.jp>.  Without them, I
couldn't have coded this far.

=head1 SEE ALSO

=item L<Jcode::Unicode>

=item L<Jcode::Unicode::NoXS>

=head1 COPYRIGHT

Copyright 1999 Dan Kogai <dankogai@dan.co.jp>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
