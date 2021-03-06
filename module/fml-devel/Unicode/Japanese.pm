package Unicode::Japanese;
# $Id: Japanese_stub.pm,v 1.25 2002/06/30 23:20:17 hio Exp $

use strict;
use vars qw($VERSION $PurePerl $xs_loaderror);
$VERSION = '0.09';

sub import
{
  my $pkg = shift;
  my @na = grep{ !/^PurePerl$/i }@_;
  if( @na != @_ )
  {
    $PurePerl = 1;
  }
  if( @na )
  {
    use Carp;
    croak("invalid parameter (".join(',',@na).")");
  }
}

sub DESTROY
{
}

sub load_xs
{
  #print STDERR "load_xs\n";
  if( $PurePerl )
  {
    #print STDERR "PurePerl mode\n";
    $xs_loaderror = 'disabled';
    return;
  }
  #print STDERR "XS mode\n";
  
  my $use_xs;
  LoadXS:
  {
    
    #print STDERR "* * bootstrap...\n";
    eval q
    {
      use strict;
      require DynaLoader;
      use vars qw(@ISA);
      @ISA = qw(DynaLoader);
      local($SIG{__DIE__}) = 'DEFAULT';
      Unicode::Japanese->bootstrap($VERSION);
    };
    #print STDERR "* * try done.\n";
    #undef @ISA;
    if( $@ )
    {
      #print STDERR "failed.\n";
      #print STDERR "$@\n";
      $use_xs = 0;
      $xs_loaderror = $@;
      undef $@;
      last LoadXS;
    }
    #print STDERR "succeeded.\n";
    $use_xs = 1;
    eval q
    {
      #print STDERR "over riding _s2u,_u2s\n";
      do_memmap();
      #print STDERR "memmap done\n";
      END{ do_memunmap(); }
      #print STDERR "binding xsubs done.\n";
    };
    if( $@ )
    {
      #print STDERR "error on last part of load XS.\n";
      $xs_loaderror = $@;
      CORE::die($@);
    }

    #print STDERR "done.\n";
  }

  if( $@ )
  {
    $xs_loaderror = $@;
    CORE::die("Cannot Load Unicode::Japanese either XS nor PurePerl\n$@");
  }
  if( !$use_xs )
  {
    #print STDERR "no xs.\n";
    eval q
    {
      sub do_memmap($){}
      sub do_memunmap($){}
    };
  }
  $xs_loaderror = '' if( !defined($xs_loaderror) );
  #print STDERR "load_xs done.\n";
}

use vars qw($FH $TABLE $HEADLEN $PROGLEN);

sub gensym {
  package Unicode::Japanese::Symbol;
  no strict;
  $genpkg = "Unicode::Japanese::Symbol::";
  $genseq = 0;
  my $name = "GEN" . $genseq++;
  my $ref = \*{$genpkg . $name};
  delete $$genpkg{$name};
  $ref;
}

sub _init_table {
  
  if(!defined($HEADLEN))
    {
      $FH = gensym;
      
      my $file = "Unicode/Japanese.pm";
    OPEN:
      {
	foreach my $path (@INC)
	  {
	    my $mypath = $path;
	    $mypath =~ s#/$##;
	    if (-f "$mypath/$file")
	      {
		open($FH,"$mypath/$file")	|| CORE::die;
		binmode($FH);
		last OPEN;
	      }
	  }
	CORE::die "Can't find Japanese.pm in \@INC\n";
      }

      local($/) = "\n";
      my $line;
      while($line = <$FH>)
	{
	  last if($line =~ m/^__DATA__/);
	}
      $PROGLEN = tell($FH);
      
      read($FH, $HEADLEN, 4)
	or die "Can't read table. [$!]\n";
      $HEADLEN = unpack('N', $HEADLEN);
      read($FH, $TABLE, $HEADLEN)
	or die "Can't seek table. [$!]\n";
      $TABLE = eval $TABLE;
      if($@)
	{
	  die "Internal Error. [$@]\n";
	}
      if(!defined($TABLE))
	{
	  die "Internal Error.\n";
	}
      $HEADLEN += 4;

      # load xs.
      load_xs();
    }
}

sub _getFile {
  my $this = shift;

  my $file = shift;

#  print STDERR "_getFile($file, $TABLE->{$file}{offset}, $TABLE->{$file}{length})\n";
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$file}{offset}, 0)
    or die "Can't seek $file. [$!]\n";
  
  my $data;
  read($FH, $data, $TABLE->{$file}{length})
    or die "Can't read $file. [$!]\n";
  
  $data;
}

sub new
{
  my $pkg = shift;
  my $this = {};

  if( defined($pkg) )
  {
    bless $this, $pkg;
  $this->_init_table;
  }else
  {
    bless $this;
  }
  
  if(defined($_[0]))
    {
      $this->set(@_);
    }

  $this;
}



use vars qw(%CHARCODE %ESC %RE);
use vars qw(@J2S @S2J @S2E @E2S @U2T %T2U %S2U %U2S);

%CHARCODE = (
	     UNDEF_EUC  =>     "\xa2\xae",
	     UNDEF_SJIS =>     "\x81\xac",
	     UNDEF_JIS  =>     "\xa2\xf7",
	     UNDEF_UNICODE  => "\x20\x20",
	 );

%ESC =  (
	 JIS_0208      => "\e\$B",
	 JIS_0212      => "\e\$(D",
	 ASC           => "\e\(B",
	 KANA          => "\e\(I",
	 E_JSKY_START  => "\e\$",
	 E_JSKY_END    => "\x0f",
	 );

%RE =
    (
     ASCII     => '[\x00-\x7f]',
     EUC_0212  => '\x8f[\xa1-\xfe][\xa1-\xfe]',
     EUC_C     => '[\xa1-\xfe][\xa1-\xfe]',
     EUC_KANA  => '\x8e[\xa1-\xdf]',
     JIS_0208  => '\e\$\@|\e\$B|\e&\@\e\$B',
     JIS_0212  => "\e" . '\$\(D',
     JIS_ASC   => "\e" . '\([BJ]',
     JIS_KANA  => "\e" . '\(I',
     SJIS_DBCS => '[\x81-\x9f\xe0-\xef\xfa-\xfc][\x40-\x7e\x80-\xfc]',
     SJIS_KANA => '[\xa1-\xdf]',
     UTF8      => '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}',
     BOM2_BE    => '\xfe\xff',
     BOM2_LE    => '\xff\xfe',
     BOM4_BE    => '\x00\x00\xfe\xff',
     BOM4_LE    => '\xff\xfe\x00\x00',
     UTF32_BE   => '\x00[\x00-\x10][\x00-\xff]{2}',
     UTF32_LE   => '[\x00-\xff]{2}[\x00-\x10]\x00',
     E_IMODE    => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x72-\x7e\x80-\xb0]',
     E_JSKY1    => '[EFG]',
     E_JSKY2    => '[\!-z]',
     E_DOTI     => '\xf0[\x40-\x7e\x80-\xfc]|\xf1[\x40-\x7e\x80-\xd6]|\xf2[\x40-\x7e\x80-\xab\xb0-\xd5\xdf-\xfc]|\xf3[\x40-\x7e\x80-\xfa]|\xf4[\x40-\x4f\x80\x84-\x8a\x8c-\x8e\x90\x94-\x96\x98-\x9c\xa0-\xa4\xa8-\xaf\xb4\xb5\xbc-\xbe\xc4\xc5\xc8\xcc]',
     E_JSKY_START => quotemeta($ESC{E_JSKY_START}),
     E_JSKY_END   => quotemeta($ESC{E_JSKY_END}),
     );

$RE{E_JSKY}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};

use vars qw($s2u_table $u2s_table);
use vars qw($ei2u $ed2u $ej2u $eu2i $eu2d $eu2j);

# encode/decode

use vars qw(%_h2zNum %_z2hNum %_h2zAlpha %_z2hAlpha %_h2zSym %_z2hSym %_h2zKanaK %_z2hKanaK %_h2zKanaD %_z2hKanaD %_hira2kata %_kata2hira);



AUTOLOAD
{
  use strict;
  use vars qw($AUTOLOAD);

  #print STDERR "AUTOLOAD... $AUTOLOAD\n";
  
  my $save = $@;
  my @BAK = @_;
  
  my $subname = $AUTOLOAD;
  $subname =~ s/^Unicode\:\:Japanese\:\://;

  #print "subs..\n",join("\n",keys %$TABLE,'');
  
  # check
  if(!defined($TABLE->{$subname}{offset}))
    {
      if (substr($AUTOLOAD,-9) eq '::DESTROY')
	{
	  {
	    no strict;
	    *$AUTOLOAD = sub {};
	  }
	  $@ = $save;
	  @_ = @BAK;
	  goto &$AUTOLOAD;
	}
      
      CORE::die "Undefined subroutine \&$AUTOLOAD called.\n";
    }
  if($TABLE->{$subname}{offset} == -1)
    {
      CORE::die "Double loaded \&$AUTOLOAD. It has some error.\n";
    }
  
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$subname}{offset}, 0)
    or die "Can't seek $subname. [$!]\n";
  
  my $sub;
  read($FH, $sub, $TABLE->{$subname}{length})
    or die "Can't read $subname. [$!]\n";

  CORE::eval($sub);
  if ($@)
    {
      CORE::die $@;
    }
  $DB::sub = $AUTOLOAD;	# Now debugger know where we are.
  
  # evaled
  $TABLE->{$subname}{offset} = -1;

  $@ = $save;
  @_ = @BAK;
  goto &$AUTOLOAD;
}


1;

=head1 NAME

Unicode::Japanese - Japanese Character Encoding Handler

=head1 SYNOPSIS

use Unicode::Japanese;

# convert utf8 -> sjis

print Unicode::Japanese->new($str)->sjis;

# convert sjis -> utf8

print Unicode::Japanese->new($str,'sjis')->get;

# convert sjis (imode_EMOJI) -> utf8

print Unicode::Japanese->new($str,'sjis-imode')->get;

# convert ZENKAKU (utf8) -> HANKAKU (utf8)

print Unicode::Japanese->new($str)->z2h->get;

=head1 DESCRIPTION

Module for conversion among Japanese character encodings.

=head2 FEATURES

=over 2

=item *

The instance stores internal strings in UTF-8.

=item *

Supports both XS and Non-XS.
Use XS for high performance,
or No-XS for ease to use (only by copying Japanese.pm).

=item *

Supports conversion between ZENKAKU and HANKAKU.

=item *

Safely handles "EMOJI" of the mobile phones (DoCoMo i-mode, ASTEL dot-i
and J-PHONE J-Sky) by mapping them on Unicode Private Use Area.

=item *

Supports conversion of the same image of EMOJI
between different mobile phone's standard mutually.

=item *

Considers Shift_JIS(SJIS) as MS-CP932.
(Shift_JIS on MS-Windows (MS-SJIS/MS-CP932) differ from
generic Shift_JIS encodings.)

=item *

On converting Unicode to SJIS (and EUC-JP/JIS), those encodings that cannot
be converted to SJIS (except "EMOJI") are escaped in "&#dddd;" format.
"EMOJI" on Unicode Private Use Area is going to be '?'.
When converting strings from Unicode to SJIS of mobile phones,
any characters not up to their standard is going to be '?'

=back

=head1 METHODS

=over 4

=item $s = Unicode::Japanese->new($str [, $icode [, $encode]])

Creates a new instance of Unicode::Japanese.

If arguments are specified, passes through to set method.

=item $s->set($str [, $icode [, $encode]])

=over 2

=item $str: string

=item $icode: character encodings, may be omitted (default = 'utf8')

=item $encode: ASCII encoding, may be omitted.

=back

Set a string in the instance.
If '$icode' is omitted, string is considered as UTF-8.

To specify a encodings, choose from the following;
'jis', 'sjis', 'euc', 'utf8',
'ucs2', 'ucs4', 'utf16', 'utf16-ge', 'utf16-le',
'utf32', 'utf32-ge', 'utf32-le', 'ascii', 'binary',
'sjis-imode', 'sjis-doti', 'sjis-jsky'.

'&#dddd' will be converted to "EMOJI", when specified 'sjis-imode'
or 'sjis-doti'.

For auto encoding detection, you MUST specify 'auto'
so as to call getcode() method automatically.

For ASCII encoding, only 'base64' may be specified.
With it, the string will be decoded before storing.

To decode binary, specify 'binary' as the encoding.

=item $str = $s->get

=over 2

=item $str: string (UTF-8)

=back

Gets a string with UTF-8.

=item $code = $s->getcode($str)

=over 2

=item $str: string

=item $code: character encoding name

=back

Detects the character encodings of I<$str>.

Notice: This method detects B<NOT> encoding of the string in the instance
but I<$str>.

Character encodings are distinguished by the following algorithm:

(In case of PurePerl)

=over 4

=item 1

If BOM of UTF-32 is found, the encoding is utf32.

=item 2

If BOM of UTF-16 is found, the encoding is utf16.

=item 3

If it is in proper UTF-32BE, the encoding is utf32-be.

=item 4

If it is in proper UTF-32LE, the encoding is utf32-le.

=item 5

Without NON-ASCII characters, the encoding is ascii.
(control codes except escape sequences has been included in ASCII)

=item 6

If it includes ISO-2022-JP(JIS) escape sequences, the encoding is jis.

=item 7

If it includes "J-PHONE EMOJI", the encoding is sjis-sky.

=item 8

If it is in proper EUC-JP, the encoding is euc.

=item 9

If it is in proper SJIS, the encoding is sjis.

=item 10

If it is in proper SJIS and "EMOJI" of i-mode, the encoding is sjis-imode.

=item 11

If it is in proper SJIS and "EMOJI" of dot-i,the encoding is sjis-doti.

=item 12

If it is in proper UTF-8, the encoding is utf8.

=item 13

If none above is true, the encoding is unknown.

=back

(In case of XS)

=over 4

=item 1

If BOM of UTF-32 is found, the encoding is utf32.

=item 2

If BOM of UTF-16 is found, the encoding is utf16.

=item 3

String is checked by State Transition if it is applicable
for any listed encodings below. 

ascii / euc-jp / sjis / jis / utf8 / utf32-be / utf32-le / sjis-jsky /
sjis-imode / sjis-doti

=item 4

The listed order below is applied for a final determination.

utf32-be / utf32-le / ascii / jis / euc-jp / sjis / sjis-jsky / sjis-imode /
sjis-doti / utf8

=item 5

If none above is true, the encoding is unknown.


=back

Regarding the algorithm, pay attention to the following:

=over 2

=item *

UTF-8 is occasionally detected as SJIS.

=item *

Can NOT detect UCS2 automatically.

=item *

Can detect UTF-16 only when the string has BOM.

=item *

Can detect "EMOJI" when it is stored in binary, not in "&#dddd;"
format. (If only stored in "&#dddd;" format, getcode() will
return incorrect result. In that case, "EMOJI" will be crashed.)

=back

Because each of XS and PurePerl has a different algorithm, A result of
the detection would be possibly different.  In case that the string is
SJIS with escape characters, it would be considered as SJIS on
PurePerl.  However, it can't be detected as S-JIS on XS. This is
because by using Algorithm, the string can't be distinguished between
SJIS and SJIS-Jsky.  This exclusion of escape characters on XS from
the detection is suppose to be the same for EUC-JP.
  
=item $str = $s->conv($ocode, $encode)

=over 2

=item $ocode: output character encoding (Choose from 'jis', 'sjis', 'euc', 'utf8', 'ucs2', 'ucs4', 'utf16', 'binary')

=item $encode: ASCII encoding, may be omitted.

=item $str: string

=back

Gets a string converted to I<$ocode>.

For ASCII encoding, only 'base64' may be specified. With it, the string
encoded in base64 will be returned.

=item $s->tag2bin

Replaces the substrings "&#dddd;" in the string with the binary entity
they mean.

=item $s->z2h

Converts ZENKAKU to HANKAKU.

=item $s->h2z

Converts HANKAKU to ZENKAKU.

=item $s->hira2kata

Converts HIRAGANA to KATAKANA.

=item $s->kata2hira

Converts KATAKANA to HIRAGANA.

=item $str = $s->jis

$str: string (JIS)

Gets the string converted to ISO-2022-JP(JIS).

=item $str = $s->euc

$str: string (EUC-JP)

Gets the string converted to EUC-JP.

=item $str = $s->utf8

$str: string (UTF-8)

Gets the string converted to UTF-8.

=item $str = $s->ucs2

$str: string (UCS2)

Gets the string converted to UCS2.

=item $str = $s->ucs4

$str: string (UCS4)

Gets the string converted to UCS4.

=item $str = $s->utf16

$str: string (UTF-16)

Gets the string converted to UTF-16(big-endian).
BOM is not added.

=item $str = $s->sjis

$str: string (SJIS)

Gets the string converted to Shift_JIS(MS-SJIS/MS-CP932).

=item $str = $s->sjis_imode

$str: string (SJIS/imode_EMOJI)

Gets the string converted to SJIS for i-mode.

=item $str = $s->sjis_doti

$str: string (SJIS/dot-i_EMOJI)

Gets the string converted to SJIS for dot-i.

=item $str = $s->sjis_sky

$str: string (SJIS/J-SKY_EMOJI)

Gets the string converted to SJIS for j-sky.

=item @str = $s->strcut($len)

=over 2

=item $len: number of characters

=item @str: strings

=back

Splits the string by length(I<$len>).

=item $len = $s->strlen

$len: `visual width' of the string

Gets the length of the string. This method has been offered to
substitute for perl build-in length(). ZENKAKU characters are
assumed to have lengths of 2, regardless of the coding being
SJIS or UTF-8.

=item $s->join_csv(@values);

@values: data array

Converts the array to a string in CSV format, then stores into the instance.
In the meantime, adds a newline("\n") at the end of string.

=item @values = $s->split_csv;

@values: data array

Splits the string, accounting it is in CSV format.
Each newline("\n") is removed before split.

=back


=head1 DESCRIPTION OF UNICODE MAPPING

=over 2

=item SJIS

Mapped as MS-CP932. Mapping table in the following URL is used.

ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP932.TXT

If a character cannot be mapped to SJIS from Unicode,
it will be converted to &#dddd; format.

Also, any unmapped character will be converted into "?" when converting
to SJIS for mobile phones.

=item EUC-JP/JIS

Converted to SJIS and then mapped to Unicode. Any non-SJIS character
in the string will not be mapped correctly.

=item DoCoMo i-mode

Portion of involving "EMOJI" in F800 - F9FF is maapped
 to U+0FF800 - U+0FF9FF.

=item ASTEL dot-i

Portion of involving "EMOJI" in F000 - F4FF is mapped
 to U+0FF000 - U+0FF4FF.

=item J-PHONE J-SKY

"J-SKY EMOJI" are mapped down as follows: "\e\$"(\x1b\x24) escape
sequences, the first byte, the second byte and "\x0f".
With sequential "EMOJI"s of identical first bytes,
it may be compressed by arranging only the second bytes.

4500 - 47FF is mapped to U+0FFB00 - U+0FFDFF, accounting the first
and the second bytes make one EMOJI character.

Unicode::Japanese will compress "J-SKY_EMOJI" automatically when
the first bytes of a sequence of "EMOJI" are identical.

=back

=head1 PurePerl mode

   use Unicode::Japanese qw(PurePerl);

If module was loaded with 'PurePerl' keyword,
it works on Non-XS mode.

=head1 BUGS

=over 2

=item *

EUC-JP, JIS strings cannot be converted correctly when they include
non-SJIS characters because they are converted to SJIS before
being converted to UTF-8.

=item *

Some characters of CP932 not in standard Shift_JIS
(ex; not in Joyo Kanji) will not be detected and converted. 

When string include such non-standard Shift_JIS,
they will not detected as SJIS.
Also, getcode() and all convert method will not work correctly.

=item *

When using XS, character encoding detection of EUC-JP and
SJIS(included all EMOJI) strings when they include "\e" will
fail. Also, getcode() and all convert method will not work.

=item *

The Japanese.pm file will collapse if sent via ASCII mode of FTP,
as it has a trailing binary data.

=back

=head1 AUTHOR INFORMATION

Copyright 2001-2002
SANO Taku (SAWATARI Mikage) and YAMASHINA Hio.
All right reserved.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

Bug reports and comments to: mikage@cpan.org.
Thank you.

=head1 CREDITS

Thanks very much to:

NAKAYAMA Nao

SUGIURA Tatsuki & Debian JP Project

=cut



__DATA__
  #{'_loadConvTable'=>{'length'=>17905,'offset'=>'0'},'euc'=>{'length'=>60,'offset'=>'18079'},'h2zNum'=>{'length'=>174,'offset'=>'17905'},'z2hKana'=>{'length'=>89,'offset'=>'18139'},'splitCsv'=>{'length'=>349,'offset'=>'18228'},'jcode/emoji/ej2u.dat'=>{'length'=>3072,'offset'=>'197994'},'strlen'=>{'length'=>360,'offset'=>'18577'},'join_csv'=>{'length'=>60,'offset'=>'18937'},'utf16'=>{'length'=>70,'offset'=>'18997'},'_utf16_utf8'=>{'length'=>769,'offset'=>'19067'},'_u2s'=>{'length'=>2104,'offset'=>'19836'},'_j2s2'=>{'length'=>382,'offset'=>'21940'},'z2hKanaD'=>{'length'=>498,'offset'=>'22322'},'_j2s3'=>{'length'=>337,'offset'=>'22820'},'joinCsv'=>{'length'=>413,'offset'=>'23157'},'jcode/emoji/ed2u.dat'=>{'length'=>5120,'offset'=>'192874'},'jcode/emoji/eu2d.dat'=>{'length'=>8192,'offset'=>'209258'},'_utf32be_ucs4'=>{'length'=>70,'offset'=>'23570'},'_s2e2'=>{'length'=>446,'offset'=>'23640'},'z2hKanaK'=>{'length'=>979,'offset'=>'24086'},'h2zKana'=>{'length'=>87,'offset'=>'25065'},'_ucs2_utf8'=>{'length'=>444,'offset'=>'25152'},'z2hAlpha'=>{'length'=>836,'offset'=>'25596'},'_utf32le_ucs4'=>{'length'=>178,'offset'=>'26432'},'_utf8_utf16'=>{'length'=>950,'offset'=>'26610'},'getcode'=>{'length'=>1591,'offset'=>'27560'},'_decodeBase64'=>{'length'=>609,'offset'=>'29151'},'sjis_doti'=>{'length'=>68,'offset'=>'29760'},'jcode/u2s.dat'=>{'length'=>85504,'offset'=>'56749'},'sjis_jsky'=>{'length'=>68,'offset'=>'29828'},'tag2bin'=>{'length'=>236,'offset'=>'29896'},'strcut'=>{'length'=>771,'offset'=>'30132'},'h2zKanaD'=>{'length'=>810,'offset'=>'30903'},'_utf8_ucs2'=>{'length'=>672,'offset'=>'31713'},'sjis_imode'=>{'length'=>69,'offset'=>'32385'},'_utf8_ucs4'=>{'length'=>1424,'offset'=>'32454'},'_u2sd'=>{'length'=>1615,'offset'=>'33878'},'get'=>{'length'=>48,'offset'=>'35493'},'utf8'=>{'length'=>49,'offset'=>'35541'},'hira2kata'=>{'length'=>1242,'offset'=>'35590'},'z2h'=>{'length'=>114,'offset'=>'36832'},'_encodeBase64'=>{'length'=>645,'offset'=>'36946'},'h2zKanaK'=>{'length'=>979,'offset'=>'37591'},'jcode/emoji/eu2j.dat'=>{'length'=>20480,'offset'=>'217450'},'_u2si'=>{'length'=>1615,'offset'=>'38570'},'_u2sj'=>{'length'=>1768,'offset'=>'40185'},'h2zAlpha'=>{'length'=>264,'offset'=>'41953'},'_s2e'=>{'length'=>188,'offset'=>'42217'},'_e2s2'=>{'length'=>535,'offset'=>'42405'},'_utf16le_utf16'=>{'length'=>179,'offset'=>'42940'},'_sj2u'=>{'length'=>1135,'offset'=>'43119'},'_s2j'=>{'length'=>157,'offset'=>'44254'},'_s2j2'=>{'length'=>376,'offset'=>'44411'},'_s2j3'=>{'length'=>355,'offset'=>'44787'},'conv'=>{'length'=>1132,'offset'=>'45142'},'_s2u'=>{'length'=>883,'offset'=>'46274'},'_j2s'=>{'length'=>177,'offset'=>'47157'},'h2z'=>{'length'=>114,'offset'=>'47334'},'ucs2'=>{'length'=>68,'offset'=>'47448'},'z2hSym'=>{'length'=>557,'offset'=>'47516'},'set'=>{'length'=>2322,'offset'=>'48073'},'ucs4'=>{'length'=>68,'offset'=>'50395'},'jcode/emoji/ei2u.dat'=>{'length'=>2048,'offset'=>'190826'},'z2hNum'=>{'length'=>284,'offset'=>'50463'},'_si2u'=>{'length'=>1221,'offset'=>'50747'},'_e2s'=>{'length'=>202,'offset'=>'51968'},'jis'=>{'length'=>60,'offset'=>'52170'},'_utf32_ucs4'=>{'length'=>312,'offset'=>'52230'},'jcode/s2u.dat'=>{'length'=>48573,'offset'=>'142253'},'kata2hira'=>{'length'=>1242,'offset'=>'52542'},'_ucs4_utf8'=>{'length'=>936,'offset'=>'53784'},'split_csv'=>{'length'=>62,'offset'=>'54720'},'_utf16_utf16'=>{'length'=>300,'offset'=>'54782'},'_sd2u'=>{'length'=>1220,'offset'=>'55082'},'h2zSym'=>{'length'=>314,'offset'=>'56435'},'_utf16be_utf16'=>{'length'=>71,'offset'=>'56364'},'sjis'=>{'length'=>62,'offset'=>'56302'},'jcode/emoji/eu2i.dat'=>{'length'=>8192,'offset'=>'201066'}}sub _loadConvTable {


%_h2zNum = (
		"0" => "\xef\xbc\x90", "1" => "\xef\xbc\x91", 
		"2" => "\xef\xbc\x92", "3" => "\xef\xbc\x93", 
		"4" => "\xef\xbc\x94", "5" => "\xef\xbc\x95", 
		"6" => "\xef\xbc\x96", "7" => "\xef\xbc\x97", 
		"8" => "\xef\xbc\x98", "9" => "\xef\xbc\x99", 
		
);



%_z2hNum = (
		"\xef\xbc\x90" => "0", "\xef\xbc\x91" => "1", 
		"\xef\xbc\x92" => "2", "\xef\xbc\x93" => "3", 
		"\xef\xbc\x94" => "4", "\xef\xbc\x95" => "5", 
		"\xef\xbc\x96" => "6", "\xef\xbc\x97" => "7", 
		"\xef\xbc\x98" => "8", "\xef\xbc\x99" => "9", 
		
);



%_h2zAlpha = (
		"A" => "\xef\xbc\xa1", "B" => "\xef\xbc\xa2", 
		"C" => "\xef\xbc\xa3", "D" => "\xef\xbc\xa4", 
		"E" => "\xef\xbc\xa5", "F" => "\xef\xbc\xa6", 
		"G" => "\xef\xbc\xa7", "H" => "\xef\xbc\xa8", 
		"I" => "\xef\xbc\xa9", "J" => "\xef\xbc\xaa", 
		"K" => "\xef\xbc\xab", "L" => "\xef\xbc\xac", 
		"M" => "\xef\xbc\xad", "N" => "\xef\xbc\xae", 
		"O" => "\xef\xbc\xaf", "P" => "\xef\xbc\xb0", 
		"Q" => "\xef\xbc\xb1", "R" => "\xef\xbc\xb2", 
		"S" => "\xef\xbc\xb3", "T" => "\xef\xbc\xb4", 
		"U" => "\xef\xbc\xb5", "V" => "\xef\xbc\xb6", 
		"W" => "\xef\xbc\xb7", "X" => "\xef\xbc\xb8", 
		"Y" => "\xef\xbc\xb9", "Z" => "\xef\xbc\xba", 
		"a" => "\xef\xbd\x81", "b" => "\xef\xbd\x82", 
		"c" => "\xef\xbd\x83", "d" => "\xef\xbd\x84", 
		"e" => "\xef\xbd\x85", "f" => "\xef\xbd\x86", 
		"g" => "\xef\xbd\x87", "h" => "\xef\xbd\x88", 
		"i" => "\xef\xbd\x89", "j" => "\xef\xbd\x8a", 
		"k" => "\xef\xbd\x8b", "l" => "\xef\xbd\x8c", 
		"m" => "\xef\xbd\x8d", "n" => "\xef\xbd\x8e", 
		"o" => "\xef\xbd\x8f", "p" => "\xef\xbd\x90", 
		"q" => "\xef\xbd\x91", "r" => "\xef\xbd\x92", 
		"s" => "\xef\xbd\x93", "t" => "\xef\xbd\x94", 
		"u" => "\xef\xbd\x95", "v" => "\xef\xbd\x96", 
		"w" => "\xef\xbd\x97", "x" => "\xef\xbd\x98", 
		"y" => "\xef\xbd\x99", "z" => "\xef\xbd\x9a", 
		
);



%_z2hAlpha = (
		"\xef\xbc\xa1" => "A", "\xef\xbc\xa2" => "B", 
		"\xef\xbc\xa3" => "C", "\xef\xbc\xa4" => "D", 
		"\xef\xbc\xa5" => "E", "\xef\xbc\xa6" => "F", 
		"\xef\xbc\xa7" => "G", "\xef\xbc\xa8" => "H", 
		"\xef\xbc\xa9" => "I", "\xef\xbc\xaa" => "J", 
		"\xef\xbc\xab" => "K", "\xef\xbc\xac" => "L", 
		"\xef\xbc\xad" => "M", "\xef\xbc\xae" => "N", 
		"\xef\xbc\xaf" => "O", "\xef\xbc\xb0" => "P", 
		"\xef\xbc\xb1" => "Q", "\xef\xbc\xb2" => "R", 
		"\xef\xbc\xb3" => "S", "\xef\xbc\xb4" => "T", 
		"\xef\xbc\xb5" => "U", "\xef\xbc\xb6" => "V", 
		"\xef\xbc\xb7" => "W", "\xef\xbc\xb8" => "X", 
		"\xef\xbc\xb9" => "Y", "\xef\xbc\xba" => "Z", 
		"\xef\xbd\x81" => "a", "\xef\xbd\x82" => "b", 
		"\xef\xbd\x83" => "c", "\xef\xbd\x84" => "d", 
		"\xef\xbd\x85" => "e", "\xef\xbd\x86" => "f", 
		"\xef\xbd\x87" => "g", "\xef\xbd\x88" => "h", 
		"\xef\xbd\x89" => "i", "\xef\xbd\x8a" => "j", 
		"\xef\xbd\x8b" => "k", "\xef\xbd\x8c" => "l", 
		"\xef\xbd\x8d" => "m", "\xef\xbd\x8e" => "n", 
		"\xef\xbd\x8f" => "o", "\xef\xbd\x90" => "p", 
		"\xef\xbd\x91" => "q", "\xef\xbd\x92" => "r", 
		"\xef\xbd\x93" => "s", "\xef\xbd\x94" => "t", 
		"\xef\xbd\x95" => "u", "\xef\xbd\x96" => "v", 
		"\xef\xbd\x97" => "w", "\xef\xbd\x98" => "x", 
		"\xef\xbd\x99" => "y", "\xef\xbd\x9a" => "z", 
		
);



%_h2zSym = (
		"\x20" => "\xe3\x80\x80", "\x21" => "\xef\xbc\x81", 
		"\x22" => "\xe2\x80\x9d", "\x23" => "\xef\xbc\x83", 
		"\x24" => "\xef\xbc\x84", "\x25" => "\xef\xbc\x85", 
		"\x26" => "\xef\xbc\x86", "\x27" => "\xef\xbf\xa5", 
		"\x28" => "\xef\xbc\x88", "\x29" => "\xef\xbc\x89", 
		"\x2a" => "\xef\xbc\x8a", "\x2b" => "\xef\xbc\x8b", 
		"\x2c" => "\xef\xbc\x8c", "\x2d" => "\xe2\x88\x92", 
		"\x2e" => "\xef\xbc\x8e", "\x2f" => "\xef\xbc\x8f", 
		"\x3a" => "\xef\xbc\x9a", "\x3b" => "\xef\xbc\x9b", 
		"\x3c" => "\xef\xbc\x9c", "\x3d" => "\xef\xbc\x9d", 
		"\x3e" => "\xef\xbc\x9e", "\x3f" => "\xef\xbc\x9f", 
		"\x40" => "\xef\xbc\xa0", "\x5b" => "\xef\xbc\xbb", 
		"\x5c" => "\xef\xbf\xa5", "\x5d" => "\xef\xbc\xbd", 
		"\x5e" => "\xef\xbc\xbe", "\x60" => "\xef\xbd\x80", 
		"\x7b" => "\xef\xbd\x9b", "\x7c" => "\xef\xbd\x9c", 
		"\x7d" => "\xef\xbd\x9d", "\x7e" => "\xe3\x80\x9c", 
		
);



%_z2hSym = (
		"\xe3\x80\x80" => "\x20", "\xef\xbc\x8c" => "\x2c", 
		"\xef\xbc\x8e" => "\x2e", "\xef\xbc\x9a" => "\x3a", 
		"\xef\xbc\x9b" => "\x3b", "\xef\xbc\x9f" => "\x3f", 
		"\xef\xbc\x81" => "\x21", "\xef\xbd\x80" => "\x60", 
		"\xef\xbc\xbe" => "\x5e", "\xef\xbc\x8f" => "\x2f", 
		"\xe3\x80\x9c" => "\x7e", "\xef\xbd\x9c" => "\x7c", 
		"\xe2\x80\x9d" => "\x22", "\xef\xbc\x88" => "\x28", 
		"\xef\xbc\x89" => "\x29", "\xef\xbc\xbb" => "\x5b", 
		"\xef\xbc\xbd" => "\x5d", "\xef\xbd\x9b" => "\x7b", 
		"\xef\xbd\x9d" => "\x7d", "\xef\xbc\x8b" => "\x2b", 
		"\xe2\x88\x92" => "\x2d", "\xef\xbc\x9d" => "\x3d", 
		"\xef\xbc\x9c" => "\x3c", "\xef\xbc\x9e" => "\x3e", 
		"\xef\xbf\xa5" => "\x27", "\xef\xbc\x84" => "\x24", 
		"\xef\xbc\x85" => "\x25", "\xef\xbc\x83" => "\x23", 
		"\xef\xbc\x86" => "\x26", "\xef\xbc\x8a" => "\x2a", 
		"\xef\xbc\xa0" => "\x40", 
);



%_h2zKanaK = (
		"\xef\xbd\xa1" => "\xe3\x80\x82", "\xef\xbd\xa2" => "\xe3\x80\x8c", 
		"\xef\xbd\xa3" => "\xe3\x80\x8d", "\xef\xbd\xa4" => "\xe3\x80\x81", 
		"\xef\xbd\xa5" => "\xe3\x83\xbb", "\xef\xbd\xa6" => "\xe3\x83\xb2", 
		"\xef\xbd\xa7" => "\xe3\x82\xa1", "\xef\xbd\xa8" => "\xe3\x82\xa3", 
		"\xef\xbd\xa9" => "\xe3\x82\xa5", "\xef\xbd\xaa" => "\xe3\x82\xa7", 
		"\xef\xbd\xab" => "\xe3\x82\xa9", "\xef\xbd\xac" => "\xe3\x83\xa3", 
		"\xef\xbd\xad" => "\xe3\x83\xa5", "\xef\xbd\xae" => "\xe3\x83\xa7", 
		"\xef\xbd\xaf" => "\xe3\x83\x83", "\xef\xbd\xb0" => "\xe3\x83\xbc", 
		"\xef\xbd\xb1" => "\xe3\x82\xa2", "\xef\xbd\xb2" => "\xe3\x82\xa4", 
		"\xef\xbd\xb3" => "\xe3\x82\xa6", "\xef\xbd\xb4" => "\xe3\x82\xa8", 
		"\xef\xbd\xb5" => "\xe3\x82\xaa", "\xef\xbd\xb6" => "\xe3\x82\xab", 
		"\xef\xbd\xb7" => "\xe3\x82\xad", "\xef\xbd\xb8" => "\xe3\x82\xaf", 
		"\xef\xbd\xb9" => "\xe3\x82\xb1", "\xef\xbd\xba" => "\xe3\x82\xb3", 
		"\xef\xbd\xbb" => "\xe3\x82\xb5", "\xef\xbd\xbc" => "\xe3\x82\xb7", 
		"\xef\xbd\xbd" => "\xe3\x82\xb9", "\xef\xbd\xbe" => "\xe3\x82\xbb", 
		"\xef\xbd\xbf" => "\xe3\x82\xbd", "\xef\xbe\x80" => "\xe3\x82\xbf", 
		"\xef\xbe\x81" => "\xe3\x83\x81", "\xef\xbe\x82" => "\xe3\x83\x84", 
		"\xef\xbe\x83" => "\xe3\x83\x86", "\xef\xbe\x84" => "\xe3\x83\x88", 
		"\xef\xbe\x85" => "\xe3\x83\x8a", "\xef\xbe\x86" => "\xe3\x83\x8b", 
		"\xef\xbe\x87" => "\xe3\x83\x8c", "\xef\xbe\x88" => "\xe3\x83\x8d", 
		"\xef\xbe\x89" => "\xe3\x83\x8e", "\xef\xbe\x8a" => "\xe3\x83\x8f", 
		"\xef\xbe\x8b" => "\xe3\x83\x92", "\xef\xbe\x8c" => "\xe3\x83\x95", 
		"\xef\xbe\x8d" => "\xe3\x83\x98", "\xef\xbe\x8e" => "\xe3\x83\x9b", 
		"\xef\xbe\x8f" => "\xe3\x83\x9e", "\xef\xbe\x90" => "\xe3\x83\x9f", 
		"\xef\xbe\x91" => "\xe3\x83\xa0", "\xef\xbe\x92" => "\xe3\x83\xa1", 
		"\xef\xbe\x93" => "\xe3\x83\xa2", "\xef\xbe\x94" => "\xe3\x83\xa4", 
		"\xef\xbe\x95" => "\xe3\x83\xa6", "\xef\xbe\x96" => "\xe3\x83\xa8", 
		"\xef\xbe\x97" => "\xe3\x83\xa9", "\xef\xbe\x98" => "\xe3\x83\xaa", 
		"\xef\xbe\x99" => "\xe3\x83\xab", "\xef\xbe\x9a" => "\xe3\x83\xac", 
		"\xef\xbe\x9b" => "\xe3\x83\xad", "\xef\xbe\x9c" => "\xe3\x83\xaf", 
		"\xef\xbe\x9d" => "\xe3\x83\xb3", "\xef\xbe\x9e" => "\xe3\x82\x9b", 
		"\xef\xbe\x9f" => "\xe3\x82\x9c", 
);



%_z2hKanaK = (
		"\xe3\x80\x81" => "\xef\xbd\xa4", "\xe3\x80\x82" => "\xef\xbd\xa1", 
		"\xe3\x83\xbb" => "\xef\xbd\xa5", "\xe3\x82\x9b" => "\xef\xbe\x9e", 
		"\xe3\x82\x9c" => "\xef\xbe\x9f", "\xe3\x83\xbc" => "\xef\xbd\xb0", 
		"\xe3\x80\x8c" => "\xef\xbd\xa2", "\xe3\x80\x8d" => "\xef\xbd\xa3", 
		"\xe3\x82\xa1" => "\xef\xbd\xa7", "\xe3\x82\xa2" => "\xef\xbd\xb1", 
		"\xe3\x82\xa3" => "\xef\xbd\xa8", "\xe3\x82\xa4" => "\xef\xbd\xb2", 
		"\xe3\x82\xa5" => "\xef\xbd\xa9", "\xe3\x82\xa6" => "\xef\xbd\xb3", 
		"\xe3\x82\xa7" => "\xef\xbd\xaa", "\xe3\x82\xa8" => "\xef\xbd\xb4", 
		"\xe3\x82\xa9" => "\xef\xbd\xab", "\xe3\x82\xaa" => "\xef\xbd\xb5", 
		"\xe3\x82\xab" => "\xef\xbd\xb6", "\xe3\x82\xad" => "\xef\xbd\xb7", 
		"\xe3\x82\xaf" => "\xef\xbd\xb8", "\xe3\x82\xb1" => "\xef\xbd\xb9", 
		"\xe3\x82\xb3" => "\xef\xbd\xba", "\xe3\x82\xb5" => "\xef\xbd\xbb", 
		"\xe3\x82\xb7" => "\xef\xbd\xbc", "\xe3\x82\xb9" => "\xef\xbd\xbd", 
		"\xe3\x82\xbb" => "\xef\xbd\xbe", "\xe3\x82\xbd" => "\xef\xbd\xbf", 
		"\xe3\x82\xbf" => "\xef\xbe\x80", "\xe3\x83\x81" => "\xef\xbe\x81", 
		"\xe3\x83\x83" => "\xef\xbd\xaf", "\xe3\x83\x84" => "\xef\xbe\x82", 
		"\xe3\x83\x86" => "\xef\xbe\x83", "\xe3\x83\x88" => "\xef\xbe\x84", 
		"\xe3\x83\x8a" => "\xef\xbe\x85", "\xe3\x83\x8b" => "\xef\xbe\x86", 
		"\xe3\x83\x8c" => "\xef\xbe\x87", "\xe3\x83\x8d" => "\xef\xbe\x88", 
		"\xe3\x83\x8e" => "\xef\xbe\x89", "\xe3\x83\x8f" => "\xef\xbe\x8a", 
		"\xe3\x83\x92" => "\xef\xbe\x8b", "\xe3\x83\x95" => "\xef\xbe\x8c", 
		"\xe3\x83\x98" => "\xef\xbe\x8d", "\xe3\x83\x9b" => "\xef\xbe\x8e", 
		"\xe3\x83\x9e" => "\xef\xbe\x8f", "\xe3\x83\x9f" => "\xef\xbe\x90", 
		"\xe3\x83\xa0" => "\xef\xbe\x91", "\xe3\x83\xa1" => "\xef\xbe\x92", 
		"\xe3\x83\xa2" => "\xef\xbe\x93", "\xe3\x83\xa3" => "\xef\xbd\xac", 
		"\xe3\x83\xa4" => "\xef\xbe\x94", "\xe3\x83\xa5" => "\xef\xbd\xad", 
		"\xe3\x83\xa6" => "\xef\xbe\x95", "\xe3\x83\xa7" => "\xef\xbd\xae", 
		"\xe3\x83\xa8" => "\xef\xbe\x96", "\xe3\x83\xa9" => "\xef\xbe\x97", 
		"\xe3\x83\xaa" => "\xef\xbe\x98", "\xe3\x83\xab" => "\xef\xbe\x99", 
		"\xe3\x83\xac" => "\xef\xbe\x9a", "\xe3\x83\xad" => "\xef\xbe\x9b", 
		"\xe3\x83\xaf" => "\xef\xbe\x9c", "\xe3\x83\xb2" => "\xef\xbd\xa6", 
		"\xe3\x83\xb3" => "\xef\xbe\x9d", 
);



%_h2zKanaD = (
		"\xef\xbd\xb3\xef\xbe\x9e" => "\xe3\x83\xb4", "\xef\xbd\xb6\xef\xbe\x9e" => "\xe3\x82\xac", 
		"\xef\xbd\xb7\xef\xbe\x9e" => "\xe3\x82\xae", "\xef\xbd\xb8\xef\xbe\x9e" => "\xe3\x82\xb0", 
		"\xef\xbd\xb9\xef\xbe\x9e" => "\xe3\x82\xb2", "\xef\xbd\xba\xef\xbe\x9e" => "\xe3\x82\xb4", 
		"\xef\xbd\xbb\xef\xbe\x9e" => "\xe3\x82\xb6", "\xef\xbd\xbc\xef\xbe\x9e" => "\xe3\x82\xb8", 
		"\xef\xbd\xbd\xef\xbe\x9e" => "\xe3\x82\xba", "\xef\xbd\xbe\xef\xbe\x9e" => "\xe3\x82\xbc", 
		"\xef\xbd\xbf\xef\xbe\x9e" => "\xe3\x82\xbe", "\xef\xbe\x80\xef\xbe\x9e" => "\xe3\x83\x80", 
		"\xef\xbe\x81\xef\xbe\x9e" => "\xe3\x83\x82", "\xef\xbe\x82\xef\xbe\x9e" => "\xe3\x83\x85", 
		"\xef\xbe\x83\xef\xbe\x9e" => "\xe3\x83\x87", "\xef\xbe\x84\xef\xbe\x9e" => "\xe3\x83\x89", 
		"\xef\xbe\x8a\xef\xbe\x9e" => "\xe3\x83\x90", "\xef\xbe\x8a\xef\xbe\x9f" => "\xe3\x83\x91", 
		"\xef\xbe\x8b\xef\xbe\x9e" => "\xe3\x83\x93", "\xef\xbe\x8b\xef\xbe\x9f" => "\xe3\x83\x94", 
		"\xef\xbe\x8c\xef\xbe\x9e" => "\xe3\x83\x96", "\xef\xbe\x8c\xef\xbe\x9f" => "\xe3\x83\x97", 
		"\xef\xbe\x8d\xef\xbe\x9e" => "\xe3\x83\x99", "\xef\xbe\x8d\xef\xbe\x9f" => "\xe3\x83\x9a", 
		"\xef\xbe\x8e\xef\xbe\x9e" => "\xe3\x83\x9c", "\xef\xbe\x8e\xef\xbe\x9f" => "\xe3\x83\x9d", 
		
);



%_z2hKanaD = (
		"\xe3\x82\xac" => "\xef\xbd\xb6\xef\xbe\x9e", "\xe3\x82\xae" => "\xef\xbd\xb7\xef\xbe\x9e", 
		"\xe3\x82\xb0" => "\xef\xbd\xb8\xef\xbe\x9e", "\xe3\x82\xb2" => "\xef\xbd\xb9\xef\xbe\x9e", 
		"\xe3\x82\xb4" => "\xef\xbd\xba\xef\xbe\x9e", "\xe3\x82\xb6" => "\xef\xbd\xbb\xef\xbe\x9e", 
		"\xe3\x82\xb8" => "\xef\xbd\xbc\xef\xbe\x9e", "\xe3\x82\xba" => "\xef\xbd\xbd\xef\xbe\x9e", 
		"\xe3\x82\xbc" => "\xef\xbd\xbe\xef\xbe\x9e", "\xe3\x82\xbe" => "\xef\xbd\xbf\xef\xbe\x9e", 
		"\xe3\x83\x80" => "\xef\xbe\x80\xef\xbe\x9e", "\xe3\x83\x82" => "\xef\xbe\x81\xef\xbe\x9e", 
		"\xe3\x83\x85" => "\xef\xbe\x82\xef\xbe\x9e", "\xe3\x83\x87" => "\xef\xbe\x83\xef\xbe\x9e", 
		"\xe3\x83\x89" => "\xef\xbe\x84\xef\xbe\x9e", "\xe3\x83\x90" => "\xef\xbe\x8a\xef\xbe\x9e", 
		"\xe3\x83\x91" => "\xef\xbe\x8a\xef\xbe\x9f", "\xe3\x83\x93" => "\xef\xbe\x8b\xef\xbe\x9e", 
		"\xe3\x83\x94" => "\xef\xbe\x8b\xef\xbe\x9f", "\xe3\x83\x96" => "\xef\xbe\x8c\xef\xbe\x9e", 
		"\xe3\x83\x97" => "\xef\xbe\x8c\xef\xbe\x9f", "\xe3\x83\x99" => "\xef\xbe\x8d\xef\xbe\x9e", 
		"\xe3\x83\x9a" => "\xef\xbe\x8d\xef\xbe\x9f", "\xe3\x83\x9c" => "\xef\xbe\x8e\xef\xbe\x9e", 
		"\xe3\x83\x9d" => "\xef\xbe\x8e\xef\xbe\x9f", "\xe3\x83\xb4" => "\xef\xbd\xb3\xef\xbe\x9e", 
		
);



%_hira2kata = (
		"\xe3\x81\x81" => "\xe3\x82\xa1", "\xe3\x81\x82" => "\xe3\x82\xa2", 
		"\xe3\x81\x83" => "\xe3\x82\xa3", "\xe3\x81\x84" => "\xe3\x82\xa4", 
		"\xe3\x81\x85" => "\xe3\x82\xa5", "\xe3\x81\x86" => "\xe3\x82\xa6", 
		"\xe3\x81\x87" => "\xe3\x82\xa7", "\xe3\x81\x88" => "\xe3\x82\xa8", 
		"\xe3\x81\x89" => "\xe3\x82\xa9", "\xe3\x81\x8a" => "\xe3\x82\xaa", 
		"\xe3\x81\x8b" => "\xe3\x82\xab", "\xe3\x81\x8c" => "\xe3\x82\xac", 
		"\xe3\x81\x8d" => "\xe3\x82\xad", "\xe3\x81\x8e" => "\xe3\x82\xae", 
		"\xe3\x81\x8f" => "\xe3\x82\xaf", "\xe3\x81\x90" => "\xe3\x82\xb0", 
		"\xe3\x81\x91" => "\xe3\x82\xb1", "\xe3\x81\x92" => "\xe3\x82\xb2", 
		"\xe3\x81\x93" => "\xe3\x82\xb3", "\xe3\x81\x94" => "\xe3\x82\xb4", 
		"\xe3\x81\x95" => "\xe3\x82\xb5", "\xe3\x81\x96" => "\xe3\x82\xb6", 
		"\xe3\x81\x97" => "\xe3\x82\xb7", "\xe3\x81\x98" => "\xe3\x82\xb8", 
		"\xe3\x81\x99" => "\xe3\x82\xb9", "\xe3\x81\x9a" => "\xe3\x82\xba", 
		"\xe3\x81\x9b" => "\xe3\x82\xbb", "\xe3\x81\x9c" => "\xe3\x82\xbc", 
		"\xe3\x81\x9d" => "\xe3\x82\xbd", "\xe3\x81\x9e" => "\xe3\x82\xbe", 
		"\xe3\x81\x9f" => "\xe3\x82\xbf", "\xe3\x81\xa0" => "\xe3\x83\x80", 
		"\xe3\x81\xa1" => "\xe3\x83\x81", "\xe3\x81\xa2" => "\xe3\x83\x82", 
		"\xe3\x81\xa3" => "\xe3\x83\x83", "\xe3\x81\xa4" => "\xe3\x83\x84", 
		"\xe3\x81\xa5" => "\xe3\x83\x85", "\xe3\x81\xa6" => "\xe3\x83\x86", 
		"\xe3\x81\xa7" => "\xe3\x83\x87", "\xe3\x81\xa8" => "\xe3\x83\x88", 
		"\xe3\x81\xa9" => "\xe3\x83\x89", "\xe3\x81\xaa" => "\xe3\x83\x8a", 
		"\xe3\x81\xab" => "\xe3\x83\x8b", "\xe3\x81\xac" => "\xe3\x83\x8c", 
		"\xe3\x81\xad" => "\xe3\x83\x8d", "\xe3\x81\xae" => "\xe3\x83\x8e", 
		"\xe3\x81\xaf" => "\xe3\x83\x8f", "\xe3\x81\xb0" => "\xe3\x83\x90", 
		"\xe3\x81\xb1" => "\xe3\x83\x91", "\xe3\x81\xb2" => "\xe3\x83\x92", 
		"\xe3\x81\xb3" => "\xe3\x83\x93", "\xe3\x81\xb4" => "\xe3\x83\x94", 
		"\xe3\x81\xb5" => "\xe3\x83\x95", "\xe3\x81\xb6" => "\xe3\x83\x96", 
		"\xe3\x81\xb7" => "\xe3\x83\x97", "\xe3\x81\xb8" => "\xe3\x83\x98", 
		"\xe3\x81\xb9" => "\xe3\x83\x99", "\xe3\x81\xba" => "\xe3\x83\x9a", 
		"\xe3\x81\xbb" => "\xe3\x83\x9b", "\xe3\x81\xbc" => "\xe3\x83\x9c", 
		"\xe3\x81\xbd" => "\xe3\x83\x9d", "\xe3\x81\xbe" => "\xe3\x83\x9e", 
		"\xe3\x81\xbf" => "\xe3\x83\x9f", "\xe3\x82\x80" => "\xe3\x83\xa0", 
		"\xe3\x82\x81" => "\xe3\x83\xa1", "\xe3\x82\x82" => "\xe3\x83\xa2", 
		"\xe3\x82\x83" => "\xe3\x83\xa3", "\xe3\x82\x84" => "\xe3\x83\xa4", 
		"\xe3\x82\x85" => "\xe3\x83\xa5", "\xe3\x82\x86" => "\xe3\x83\xa6", 
		"\xe3\x82\x87" => "\xe3\x83\xa7", "\xe3\x82\x88" => "\xe3\x83\xa8", 
		"\xe3\x82\x89" => "\xe3\x83\xa9", "\xe3\x82\x8a" => "\xe3\x83\xaa", 
		"\xe3\x82\x8b" => "\xe3\x83\xab", "\xe3\x82\x8c" => "\xe3\x83\xac", 
		"\xe3\x82\x8d" => "\xe3\x83\xad", "\xe3\x82\x8e" => "\xe3\x83\xae", 
		"\xe3\x82\x8f" => "\xe3\x83\xaf", "\xe3\x82\x90" => "\xe3\x83\xb0", 
		"\xe3\x82\x91" => "\xe3\x83\xb1", "\xe3\x82\x92" => "\xe3\x83\xb2", 
		"\xe3\x82\x93" => "\xe3\x83\xb3", 
);



%_kata2hira = (
		"\xe3\x82\xa1" => "\xe3\x81\x81", "\xe3\x82\xa2" => "\xe3\x81\x82", 
		"\xe3\x82\xa3" => "\xe3\x81\x83", "\xe3\x82\xa4" => "\xe3\x81\x84", 
		"\xe3\x82\xa5" => "\xe3\x81\x85", "\xe3\x82\xa6" => "\xe3\x81\x86", 
		"\xe3\x82\xa7" => "\xe3\x81\x87", "\xe3\x82\xa8" => "\xe3\x81\x88", 
		"\xe3\x82\xa9" => "\xe3\x81\x89", "\xe3\x82\xaa" => "\xe3\x81\x8a", 
		"\xe3\x82\xab" => "\xe3\x81\x8b", "\xe3\x82\xac" => "\xe3\x81\x8c", 
		"\xe3\x82\xad" => "\xe3\x81\x8d", "\xe3\x82\xae" => "\xe3\x81\x8e", 
		"\xe3\x82\xaf" => "\xe3\x81\x8f", "\xe3\x82\xb0" => "\xe3\x81\x90", 
		"\xe3\x82\xb1" => "\xe3\x81\x91", "\xe3\x82\xb2" => "\xe3\x81\x92", 
		"\xe3\x82\xb3" => "\xe3\x81\x93", "\xe3\x82\xb4" => "\xe3\x81\x94", 
		"\xe3\x82\xb5" => "\xe3\x81\x95", "\xe3\x82\xb6" => "\xe3\x81\x96", 
		"\xe3\x82\xb7" => "\xe3\x81\x97", "\xe3\x82\xb8" => "\xe3\x81\x98", 
		"\xe3\x82\xb9" => "\xe3\x81\x99", "\xe3\x82\xba" => "\xe3\x81\x9a", 
		"\xe3\x82\xbb" => "\xe3\x81\x9b", "\xe3\x82\xbc" => "\xe3\x81\x9c", 
		"\xe3\x82\xbd" => "\xe3\x81\x9d", "\xe3\x82\xbe" => "\xe3\x81\x9e", 
		"\xe3\x82\xbf" => "\xe3\x81\x9f", "\xe3\x83\x80" => "\xe3\x81\xa0", 
		"\xe3\x83\x81" => "\xe3\x81\xa1", "\xe3\x83\x82" => "\xe3\x81\xa2", 
		"\xe3\x83\x83" => "\xe3\x81\xa3", "\xe3\x83\x84" => "\xe3\x81\xa4", 
		"\xe3\x83\x85" => "\xe3\x81\xa5", "\xe3\x83\x86" => "\xe3\x81\xa6", 
		"\xe3\x83\x87" => "\xe3\x81\xa7", "\xe3\x83\x88" => "\xe3\x81\xa8", 
		"\xe3\x83\x89" => "\xe3\x81\xa9", "\xe3\x83\x8a" => "\xe3\x81\xaa", 
		"\xe3\x83\x8b" => "\xe3\x81\xab", "\xe3\x83\x8c" => "\xe3\x81\xac", 
		"\xe3\x83\x8d" => "\xe3\x81\xad", "\xe3\x83\x8e" => "\xe3\x81\xae", 
		"\xe3\x83\x8f" => "\xe3\x81\xaf", "\xe3\x83\x90" => "\xe3\x81\xb0", 
		"\xe3\x83\x91" => "\xe3\x81\xb1", "\xe3\x83\x92" => "\xe3\x81\xb2", 
		"\xe3\x83\x93" => "\xe3\x81\xb3", "\xe3\x83\x94" => "\xe3\x81\xb4", 
		"\xe3\x83\x95" => "\xe3\x81\xb5", "\xe3\x83\x96" => "\xe3\x81\xb6", 
		"\xe3\x83\x97" => "\xe3\x81\xb7", "\xe3\x83\x98" => "\xe3\x81\xb8", 
		"\xe3\x83\x99" => "\xe3\x81\xb9", "\xe3\x83\x9a" => "\xe3\x81\xba", 
		"\xe3\x83\x9b" => "\xe3\x81\xbb", "\xe3\x83\x9c" => "\xe3\x81\xbc", 
		"\xe3\x83\x9d" => "\xe3\x81\xbd", "\xe3\x83\x9e" => "\xe3\x81\xbe", 
		"\xe3\x83\x9f" => "\xe3\x81\xbf", "\xe3\x83\xa0" => "\xe3\x82\x80", 
		"\xe3\x83\xa1" => "\xe3\x82\x81", "\xe3\x83\xa2" => "\xe3\x82\x82", 
		"\xe3\x83\xa3" => "\xe3\x82\x83", "\xe3\x83\xa4" => "\xe3\x82\x84", 
		"\xe3\x83\xa5" => "\xe3\x82\x85", "\xe3\x83\xa6" => "\xe3\x82\x86", 
		"\xe3\x83\xa7" => "\xe3\x82\x87", "\xe3\x83\xa8" => "\xe3\x82\x88", 
		"\xe3\x83\xa9" => "\xe3\x82\x89", "\xe3\x83\xaa" => "\xe3\x82\x8a", 
		"\xe3\x83\xab" => "\xe3\x82\x8b", "\xe3\x83\xac" => "\xe3\x82\x8c", 
		"\xe3\x83\xad" => "\xe3\x82\x8d", "\xe3\x83\xae" => "\xe3\x82\x8e", 
		"\xe3\x83\xaf" => "\xe3\x82\x8f", "\xe3\x83\xb0" => "\xe3\x82\x90", 
		"\xe3\x83\xb1" => "\xe3\x82\x91", "\xe3\x83\xb2" => "\xe3\x82\x92", 
		"\xe3\x83\xb3" => "\xe3\x82\x93", 
);


}
sub h2zNum {
  my $this = shift;

  if(!defined(%_h2zNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(0|1|2|3|4|5|6|7|8|9)/$_h2zNum{$1}/eg;
  
  $this;
}
sub euc
{
  my $this = shift;
  $this->_s2e($this->sjis);
}
sub z2hKana
{
  my $this = shift;
  
  $this->z2hKanaD;
  $this->z2hKanaK;
  
  $this;
}
sub splitCsv {
  my $this = shift;
  my $text = $this->{str};
  my @field;
  
  chomp($text);

  while ($text =~ m/"([^"\\]*(?:(?:\\.|\"\")[^"\\]*)*)",?|([^,]+),?|,/g) {
    my $field = defined($1) ? $1 : (defined($2) ? $2 : '');
    $field =~ s/["\\]"/"/g;
    push(@field, $field);
  }
  push(@field, '')        if($text =~ m/,$/);

  \@field;

}
sub strlen {
  my $this = shift;
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  my $length = 0;

  foreach my $c(split(/($ch_re)/,$this->{str})) {
    next if(length($c) == 0);
    $length += ((length($c) >= 3) ? 2 : 1);
  }

  return $length;
}
sub join_csv {
  my $this = shift;

  $this->joinCsv(@_);
}
sub utf16
{
  my $this = shift;
  $this->_utf8_utf16($this->{str});
}
sub _utf16_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  my $sa;
  foreach my $uc (unpack("n*", $str))
    {
      ($uc >= 0xd800 and $uc <= 0xdbff and $sa = $uc and next);
      
      ($uc >= 0xdc00 and $uc <= 0xdfff and ($uc = ((($sa - 0xd800) << 10)|($uc - 0xdc00))+0x10000));
      
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	 ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	 ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	 chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub _u2s {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' : (
    $U2S{$1}
      or ($U2S{$1}
	  = ((length($1) == 1) ? $1 :
	     (length($1) == 2) ? (
				  ($c1,$c2) = unpack("C2", $1),
				  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
				  $c = substr($u2s_table, $ch * 2, 2),
				  # UTF-3バイト(U+0x80-U+07FF)からsjis-1バイトへのマッピングはないので\0を削除は必要はない
				  ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 3) ? (
				  ($c1,$c2,$c3) = unpack("C3", $1),
				  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
				  (
				   ($ch <= 0x9fff) ?
				   $c = substr($u2s_table, $ch * 2, 2) :
				   ($ch >= 0xf900 and $ch <= 0xffff) ?
				   (
				    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
				    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
				   ) :
				   (
				    $c = '&#' . $ch . ';'
				   )
				  ),
				  ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 4) ? (
				  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
				  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
				  (
				   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
				   '?'
				   : '&#' . $ch . ';'
				  )
				 ) :
	     (length($1) == 5) ? (($c1,$c2,$c3,$c4,$c5) = unpack("C5", $1),
				  $ch = (($c1 & 0x03) << 24)|(($c2 & 0x3F) << 18)|
				  (($c3 & 0x3f) << 12)|(($c4 & 0x3f) << 6)|
				  ($c5 & 0x3F),
				  '&#' . $ch . ';'
				 ) :
	                         (
				  ($c1,$c2,$c3,$c4,$c5,$c6) = unpack("C6", $1),
				  $ch = (($c1 & 0x03) << 30)|(($c2 & 0x3F) << 24)|
				  (($c3 & 0x3f) << 18)|(($c4 & 0x3f) << 12)|
				  (($c5 & 0x3f) << 6)|($c6 & 0x3F),
				  '&#' . $ch . ';'
				 )
	    )
	 )
			 )
	/eg;
  $str;
  
}
sub _j2s2 {
  my $this = shift;
  my $esc = shift;
  my $str = shift;

  if($esc eq $RE{JIS_0212})
    {
      $str =~ s/../$CHARCODE{UNDEF_SJIS}/g;
    }
  elsif($esc !~ m/^$RE{JIS_ASC}/)
    {
      $str =~ tr/\x21-\x7e/\xa1-\xfe/;
      if($esc =~ m/^$RE{JIS_0208}/)
	{
	  $str =~ s/($RE{EUC_C})/
	    $J2S[unpack('n', $1)] or $this->_j2s3($1)
	      /geo;
	}
    }
  
  $str;
}
sub z2hKanaD {
  my $this = shift;

  if(!defined(%_z2hKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xac|\xe3\x82\xae|\xe3\x82\xb0|\xe3\x82\xb2|\xe3\x82\xb4|\xe3\x82\xb6|\xe3\x82\xb8|\xe3\x82\xba|\xe3\x82\xbc|\xe3\x82\xbe|\xe3\x83\x80|\xe3\x83\x82|\xe3\x83\x85|\xe3\x83\x87|\xe3\x83\x89|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\xb4)/$_z2hKanaD{$1}/eg;
  
  $this;
}
sub _j2s3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 % 2)
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
      $c2 -= 0x60 + ($c2 < 0xe0);
    }
  else
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
      $c2 -= 2;
    }
  
  $J2S[unpack('n', $c)] = pack('CC', $c1, $c2);
}
sub joinCsv {
  my $this = shift;
  my $list;
  
  if(ref($_[0]) eq 'ARRAY')
    {
      $list = shift;
    }
  elsif(!ref($_[0]))
    {
      $list = [ @_ ];
    }
  else
    {
      my $ref = ref($_[0]);
      die "String->joinCsv, Param[1] is not ARRAY/ARRRAY-ref. [$ref]\n";
    }
      
  my $text = join ',', map {(s/"/""/g or /[\r\n,]/) ? qq("$_") : $_} @$list;

  $this->{str} = $text . "\n";

  $this;
}
sub _utf32be_ucs4 {
  my $this = shift;
  my $str = shift;

  $str;
}
sub _s2e2 {
  my $this = shift;
  my $c = shift;
  
  my ($c1, $c2) = unpack('CC', $c);
  if (0xa1 <= $c1 && $c1 <= 0xdf)
    {
      $c2 = $c1;
      $c1 = 0x8e;
    }
  elsif (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2E[unpack('n', $c) or unpack('C', $1)] = pack('CC', $c1, $c2);
}
sub z2hKanaK {
  my $this = shift;

  if(!defined(%_z2hKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x81|\xe3\x80\x82|\xe3\x83\xbb|\xe3\x82\x9b|\xe3\x82\x9c|\xe3\x83\xbc|\xe3\x80\x8c|\xe3\x80\x8d|\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xad|\xe3\x82\xaf|\xe3\x82\xb1|\xe3\x82\xb3|\xe3\x82\xb5|\xe3\x82\xb7|\xe3\x82\xb9|\xe3\x82\xbb|\xe3\x82\xbd|\xe3\x82\xbf|\xe3\x83\x81|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x86|\xe3\x83\x88|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x92|\xe3\x83\x95|\xe3\x83\x98|\xe3\x83\x9b|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xaf|\xe3\x83\xb2|\xe3\x83\xb3)/$_z2hKanaK{$1}/eg;
  
  $this;
}
sub h2zKana
{
  my $this = shift;

  $this->h2zKanaD;
  $this->h2zKanaK;
  
  $this;
}
sub _ucs2_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("n*", $str))
    {
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	  ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	    chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) .
	      chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub z2hAlpha {
  my $this = shift;

  if(!defined(%_z2hAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\xa1|\xef\xbc\xa2|\xef\xbc\xa3|\xef\xbc\xa4|\xef\xbc\xa5|\xef\xbc\xa6|\xef\xbc\xa7|\xef\xbc\xa8|\xef\xbc\xa9|\xef\xbc\xaa|\xef\xbc\xab|\xef\xbc\xac|\xef\xbc\xad|\xef\xbc\xae|\xef\xbc\xaf|\xef\xbc\xb0|\xef\xbc\xb1|\xef\xbc\xb2|\xef\xbc\xb3|\xef\xbc\xb4|\xef\xbc\xb5|\xef\xbc\xb6|\xef\xbc\xb7|\xef\xbc\xb8|\xef\xbc\xb9|\xef\xbc\xba|\xef\xbd\x81|\xef\xbd\x82|\xef\xbd\x83|\xef\xbd\x84|\xef\xbd\x85|\xef\xbd\x86|\xef\xbd\x87|\xef\xbd\x88|\xef\xbd\x89|\xef\xbd\x8a|\xef\xbd\x8b|\xef\xbd\x8c|\xef\xbd\x8d|\xef\xbd\x8e|\xef\xbd\x8f|\xef\xbd\x90|\xef\xbd\x91|\xef\xbd\x92|\xef\xbd\x93|\xef\xbd\x94|\xef\xbd\x95|\xef\xbd\x96|\xef\xbd\x97|\xef\xbd\x98|\xef\xbd\x99|\xef\xbd\x9a)/$_z2hAlpha{$1}/eg;
  
  $this;
}
sub _utf32le_ucs4 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('V*', $str))
    {
      $result .= pack('N', $ch);
    }
  
  $result;
}
sub _utf8_utf16 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $uc;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  pack("n", (($c1 & 0x1F)<<6)|($c2 & 0x3F))) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  pack("n", (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F))) :
	     (length($1) == 4) ? (($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  ($uc = ((($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
					  (($c3 & 0x3f) << 6)|($c4 & 0x3F)) - 0x10000),
				  (($uc < 0x100000) ? pack("nn", (($uc >> 10) | 0xd800), (($uc & 0x3ff) | 0xdc00)) : "\0?")) :
	     "\0?")
	 );
  /eg;
  $str;
}
sub getcode {
  my $this = shift;
  my $str = shift;

  my $l = length($str);
  
  if((($l % 4) == 0)
     and ($str =~ m/^(?:$RE{BOM4_BE}|$RE{BOM4_LE})/o))
    {
      return 'utf32';
    }
  if((($l % 2) == 0)
     and ($str =~ m/^(?:$RE{BOM2_BE}|$RE{BOM2_LE})/o))
    {
      return 'utf16';
    }

  my $str2;
  
  if(($l % 4) == 0)
    {
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_BE})//o);
      if($str2 eq '')
	{
	  return 'utf32-be';
	}
      
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_LE})//o);
      if($str2 eq '')
	{
	  return 'utf32-le';
	}
    }
  
  if($str !~ m/[\e\x80-\xff]/)
    {
      return 'ascii';
    }

  if($str =~ m/$RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA}/o)
    {
      return 'jis';
    }

  if($str =~ m/(?:$RE{E_JSKY})/o)
    {
      return 'sjis-jsky';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{EUC_0212}|$RE{EUC_KANA}|$RE{EUC_C})//o);
  if($str2 eq '')
    {
      return 'euc';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA})//o);
  if($str2 eq '')
    {
      return 'sjis';
    }

  my $str3;
  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_IMODE})//o);
  if($str3 eq '')
    {
      return 'sjis-imode';
    }

  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_DOTI})//o);
  if($str3 eq '')
    {
      return 'sjis-doti';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{UTF8})//o);
  if($str2 eq '')
    {
      return 'utf8';
    }

  return 'unknown';
}
sub _decodeBase64
{
  local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]

  my $this = shift;
  my $str = shift;
  my $res = "";

  $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
  if (length($str) % 4)
    {
      warn("Length of base64 data not a multiple of 4");
    }
  $str =~ s/=+$//;                        # remove padding
  $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
  while ($str =~ /(.{1,60})/gs)
    {
      my $len = chr(32 + length($1)*3/4); # compute length byte
      $res .= unpack("u", $len . $1 );    # uudecode
    }
  $res;
}
sub sjis_doti
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
sub sjis_jsky
{
  my $this = shift;
  $this->_u2sj($this->{str});
}
sub tag2bin {
  my $this = shift;

  $this->{str} =~ s/\&(\#\d+|\#x[a-f0-9A-F]+);/
    (substr($1, 1, 1) eq 'x') ? $this->_ucs4_utf8(pack('N', hex(substr($1, 2)))) :
      $this->_ucs4_utf8(pack('N', substr($1, 1)))
	/eg;
  
  $this;
}
sub strcut
{
  my $this = shift;
  my $cutlen = shift;
  
  if(ref($cutlen))
    {
      die "String->strcut, Param[1] is Ref.\n";
    }
  if($cutlen =~ m/\D/)
    {
      die "String->strcut, Param[1] must be NUMERIC.\n";
    }
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  
  my $result;
  my $line = '';
  my $linelength = 0;
  foreach my $c (split(/($ch_re)/, $this->{str}))
    {
      next if(length($c) == 0);
      if($linelength + (length($c) >= 3 ? 2 : 1) > $cutlen)
	{
	  push(@$result, $line);
	  $line = '';
	  $linelength = 0;
	}
      $linelength += (length($c) >= 3 ? 2 : 1);
      $line .= $c;
    }
  push(@$result, $line);

  $result;
}
sub h2zKanaD {
  my $this = shift;

  if(!defined(%_h2zKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xb3\xef\xbe\x9e|\xef\xbd\xb6\xef\xbe\x9e|\xef\xbd\xb7\xef\xbe\x9e|\xef\xbd\xb8\xef\xbe\x9e|\xef\xbd\xb9\xef\xbe\x9e|\xef\xbd\xba\xef\xbe\x9e|\xef\xbd\xbb\xef\xbe\x9e|\xef\xbd\xbc\xef\xbe\x9e|\xef\xbd\xbd\xef\xbe\x9e|\xef\xbd\xbe\xef\xbe\x9e|\xef\xbd\xbf\xef\xbe\x9e|\xef\xbe\x80\xef\xbe\x9e|\xef\xbe\x81\xef\xbe\x9e|\xef\xbe\x82\xef\xbe\x9e|\xef\xbe\x83\xef\xbe\x9e|\xef\xbe\x84\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9f|\xef\xbe\x8b\xef\xbe\x9e|\xef\xbe\x8b\xef\xbe\x9f|\xef\xbe\x8c\xef\xbe\x9e|\xef\xbe\x8c\xef\xbe\x9f|\xef\xbe\x8d\xef\xbe\x9e|\xef\xbe\x8d\xef\xbe\x9f|\xef\xbe\x8e\xef\xbe\x9e|\xef\xbe\x8e\xef\xbe\x9f)/$_h2zKanaD{$1}/eg;
  
  $this;
}
sub _utf8_ucs2 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|(.))/
    defined($2)?"\0$2":
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  pack("n", (($c1 & 0x1F)<<6)|($c2 & 0x3F))) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  pack("n", (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F))) : "\0?"))
	/eg;
  $str;
}
sub sjis_imode
{
  my $this = shift;
  $this->_u2si($this->{str});
}
sub _utf8_ucs4 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|(.))/
    defined($2) ? "\0\0\0$2" : 
    (length($1) == 1) ? pack("N", unpack("C", $1)) :
    (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
	                pack("N", (($c1 & 0x1F) << 6)|($c2 & 0x3F))) :
    (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
	                pack("N", (($c1 & 0x0F) << 12)|(($c2 & 0x3F) << 6)|
                           ($c3 & 0x3F))) :
    (length($1) == 4) ? (($c1,$c2,$c3,$c4) = unpack("C4", $1),
	                pack("N", (($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
                           (($c3 & 0x3f) << 6)|($c4 & 0x3F))) :
    (length($1) == 5) ? (($c1,$c2,$c3,$c4,$c5) = unpack("C5", $1),
	                pack("N", (($c1 & 0x03) << 24)|(($c2 & 0x3F) << 18)|
                           (($c3 & 0x3f) << 12)|(($c4 & 0x3f) << 6)|
                           ($c5 & 0x3F))) :
    (($c1,$c2,$c3,$c4,$c5,$c6) = unpack("C6", $1),
	                pack("N", (($c1 & 0x03) << 30)|(($c2 & 0x3F) << 24)|
                           (($c3 & 0x3f) << 18)|(($c4 & 0x3f) << 12)|
                           (($c5 & 0x3f) << 6)|($c6 & 0x3F)))
    /eg;

  $str;
}
sub _u2sd {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2d))
    {
      $eu2d = $this->_getFile('jcode/emoji/eu2d.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2d, ($ch - 0x0ff000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub get {
  my $this = shift;
  $this->{str};
}
sub utf8
{
  my $this = shift;
  $this->{str};
}
sub hira2kata {
  my $this = shift;

  if(!defined(%_hira2kata))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x81\x81|\xe3\x81\x82|\xe3\x81\x83|\xe3\x81\x84|\xe3\x81\x85|\xe3\x81\x86|\xe3\x81\x87|\xe3\x81\x88|\xe3\x81\x89|\xe3\x81\x8a|\xe3\x81\x8b|\xe3\x81\x8c|\xe3\x81\x8d|\xe3\x81\x8e|\xe3\x81\x8f|\xe3\x81\x90|\xe3\x81\x91|\xe3\x81\x92|\xe3\x81\x93|\xe3\x81\x94|\xe3\x81\x95|\xe3\x81\x96|\xe3\x81\x97|\xe3\x81\x98|\xe3\x81\x99|\xe3\x81\x9a|\xe3\x81\x9b|\xe3\x81\x9c|\xe3\x81\x9d|\xe3\x81\x9e|\xe3\x81\x9f|\xe3\x81\xa0|\xe3\x81\xa1|\xe3\x81\xa2|\xe3\x81\xa3|\xe3\x81\xa4|\xe3\x81\xa5|\xe3\x81\xa6|\xe3\x81\xa7|\xe3\x81\xa8|\xe3\x81\xa9|\xe3\x81\xaa|\xe3\x81\xab|\xe3\x81\xac|\xe3\x81\xad|\xe3\x81\xae|\xe3\x81\xaf|\xe3\x81\xb0|\xe3\x81\xb1|\xe3\x81\xb2|\xe3\x81\xb3|\xe3\x81\xb4|\xe3\x81\xb5|\xe3\x81\xb6|\xe3\x81\xb7|\xe3\x81\xb8|\xe3\x81\xb9|\xe3\x81\xba|\xe3\x81\xbb|\xe3\x81\xbc|\xe3\x81\xbd|\xe3\x81\xbe|\xe3\x81\xbf|\xe3\x82\x80|\xe3\x82\x81|\xe3\x82\x82|\xe3\x82\x83|\xe3\x82\x84|\xe3\x82\x85|\xe3\x82\x86|\xe3\x82\x87|\xe3\x82\x88|\xe3\x82\x89|\xe3\x82\x8a|\xe3\x82\x8b|\xe3\x82\x8c|\xe3\x82\x8d|\xe3\x82\x8e|\xe3\x82\x8f|\xe3\x82\x90|\xe3\x82\x91|\xe3\x82\x92|\xe3\x82\x93)/$_hira2kata{$1}/eg;
  
  $this;
}
sub z2h {
  my $this = shift;

  $this->z2hKana;
  $this->z2hNum;
  $this->z2hAlpha;
  $this->z2hSym;

  $this;
}
sub _encodeBase64
{
  my $this = shift;
  my $str = shift;
  my $eol = shift;
  my $res = "";
  
  $eol = "\n" unless defined $eol;
  pos($str) = 0;                          # ensure start at the beginning
  while ($str =~ /(.{1,45})/gs)
    {
      $res .= substr(pack('u', $1), 1);
      chop($res);
    }
  $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
  # fix padding at the end
  my $padding = (3 - length($str) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
  # break encoded string into lines of no more than 76 characters each
  if (length $eol)
    {
      $res =~ s/(.{1,76})/$1$eol/g;
    }
  $res;
}
sub h2zKanaK {
  my $this = shift;

  if(!defined(%_h2zKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xa1|\xef\xbd\xa2|\xef\xbd\xa3|\xef\xbd\xa4|\xef\xbd\xa5|\xef\xbd\xa6|\xef\xbd\xa7|\xef\xbd\xa8|\xef\xbd\xa9|\xef\xbd\xaa|\xef\xbd\xab|\xef\xbd\xac|\xef\xbd\xad|\xef\xbd\xae|\xef\xbd\xaf|\xef\xbd\xb0|\xef\xbd\xb1|\xef\xbd\xb2|\xef\xbd\xb3|\xef\xbd\xb4|\xef\xbd\xb5|\xef\xbd\xb6|\xef\xbd\xb7|\xef\xbd\xb8|\xef\xbd\xb9|\xef\xbd\xba|\xef\xbd\xbb|\xef\xbd\xbc|\xef\xbd\xbd|\xef\xbd\xbe|\xef\xbd\xbf|\xef\xbe\x80|\xef\xbe\x81|\xef\xbe\x82|\xef\xbe\x83|\xef\xbe\x84|\xef\xbe\x85|\xef\xbe\x86|\xef\xbe\x87|\xef\xbe\x88|\xef\xbe\x89|\xef\xbe\x8a|\xef\xbe\x8b|\xef\xbe\x8c|\xef\xbe\x8d|\xef\xbe\x8e|\xef\xbe\x8f|\xef\xbe\x90|\xef\xbe\x91|\xef\xbe\x92|\xef\xbe\x93|\xef\xbe\x94|\xef\xbe\x95|\xef\xbe\x96|\xef\xbe\x97|\xef\xbe\x98|\xef\xbe\x99|\xef\xbe\x9a|\xef\xbe\x9b|\xef\xbe\x9c|\xef\xbe\x9d|\xef\xbe\x9e|\xef\xbe\x9f)/$_h2zKanaK{$1}/eg;
  
  $this;
}
sub _u2si {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2i))
    {
      $eu2i = $this->_getFile('jcode/emoji/eu2i.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2i, ($ch - 0x0ff000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub _u2sj {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2j))
    {
      $eu2j = $this->_getFile('jcode/emoji/eu2j.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2j, ($ch - 0x0ff000) * 5, 5),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  1 while($str =~ s/($RE{E_JSKY_START})($RE{E_JSKY1})($RE{E_JSKY2}+)$RE{E_JSKY_END}$RE{E_JSKY_START}\2($RE{E_JSKY2})($RE{E_JSKY_END})/$1$2$3$4$5/o);
  
  $str;
  
}
sub h2zAlpha {
  my $this = shift;

  if(!defined(%_h2zAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)/$_h2zAlpha{$1}/eg;
  
  $this;
}
sub _s2e {
  my $this = shift;
  my $str = shift;
  
  $str =~ s/($RE{SJIS_DBCS}|$RE{SJIS_KANA})/
    $S2E[unpack('n', $1) or unpack('C', $1)] or $this->_s2e2($1)
      /geo;
  
  $str;
}
sub _e2s2 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 == 0x8e)
    {		# SS2
      $E2S[unpack('n', $c)] = chr($c2);
    }
  elsif ($c1 == 0x8f)
    {	# SS3
      $E2S[unpack('N', "\0" . $c)] = $CHARCODE{UNDEF_SJIS};
    }
  else
    {			#SS1 or X0208
      if ($c1 % 2)
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
	  $c2 -= 0x60 + ($c2 < 0xe0);
	}
      else
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
	  $c2 -= 2;
	}
      $E2S[unpack('n', $c)] = pack('CC', $c1, $c2);
    }
}
sub _utf16le_utf16 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('v*', $str))
    {
      $result .= pack('n', $ch);
    }
  
  $result;
}
sub _sj2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ej2u))
    {
      $ej2u = $this->_getFile('jcode/emoji/ej2u.dat');
    }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_JSKY}|[\x00-\xff])/
    (length($1) <= 2) ? 
      (
       $l = (unpack('n', $1) or unpack('C', $1)),
       (
	($l >= 0xa1 and $l <= 0xdf)     ?
	(
	 $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0x8100 and $l <= 0x9fff) ?
	(
	 $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0xe000 and $l <= 0xffff) ?
	(
	 $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l < 0x80) ?
	chr($l) :
	'?'
       )
      ) :
	(
         $l = $1,
	 $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1}),,o,
	 $j1 = $1,
	 $uc = '',
	 $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	 $uc =~ tr,\0,,d,
	 $uc
	)
  /eg;
  
  $str;
  
}
sub _s2j {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS}|$RE{SJIS_KANA})+)/
    $this->_s2j2($1) . $ESC{ASC}
      /geo;

  $str;
}
sub _s2j2 {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS})+|(?:$RE{SJIS_KANA})+)/
    my $s = $1;
  if($s =~ m,^$RE{SJIS_KANA},)
    {
      $s =~ tr,\xa1-\xdf,\x21-\x5f,;
      $ESC{KANA} . $s
    }
  else
    {
      $s =~ s!($RE{SJIS_DBCS})!
	$S2J[unpack('n', $1)] or $this->_s2j3($1)
	  !geo;
      $ESC{JIS_0208} . $s;
    }
  /geo;
  
  $str;
}
sub _s2j3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2J[unpack('n', $c)] = pack('CC', $c1 - 0x80, $c2 - 0x80);
}
sub conv {
  my $this = shift;
  my $ocode = shift;
  my $encode = shift;
  my (@option) = @_;

  my $res;
  if($ocode eq 'utf8')
    {
      $res = $this->utf8;
    }
  elsif($ocode eq 'euc')
    {
      $res = $this->euc;
    }
  elsif($ocode eq 'jis')
    {
      $res = $this->jis;
    }
  elsif($ocode eq 'sjis')
    {
      $res = $this->sjis;
    }
  elsif($ocode eq 'sjis-imode')
    {
      $res = $this->sjis_imode;
    }
  elsif($ocode eq 'sjis-doti')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-jsky')
    {
      $res = $this->sjis_jsky;
    }
  elsif($ocode eq 'ucs2')
    {
      $res = $this->ucs2;
    }
  elsif($ocode eq 'ucs4')
    {
      $res = $this->ucs4;
    }
  elsif($ocode eq 'utf16')
    {
      $res = $this->utf16;
    }
  elsif($ocode eq 'binary')
    {
      $res = $this->{str};
    }
  else
    {
      die qq(String->conv, Param[1] "$ocode" is error.\n);
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $res = $this->_encodeBase64($res, @option);
	}
      else
	{
	  die qq(String->conv, Param[2] "$encode" encode name error.\n);
	}
    }

  $res;
}
sub _s2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xfcff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _j2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA})([^\e]*)/
    $this->_j2s2($1, $2)
      /geo;

  $str;
}
sub h2z {
  my $this = shift;

  $this->h2zKana;
  $this->h2zNum;
  $this->h2zAlpha;
  $this->h2zSym;

  $this;
}
sub ucs2
{
  my $this = shift;
  $this->_utf8_ucs2($this->{str});
}
sub z2hSym {
  my $this = shift;

  if(!defined(%_z2hSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x80|\xef\xbc\x8c|\xef\xbc\x8e|\xef\xbc\x9a|\xef\xbc\x9b|\xef\xbc\x9f|\xef\xbc\x81|\xef\xbd\x80|\xef\xbc\xbe|\xef\xbc\x8f|\xe3\x80\x9c|\xef\xbd\x9c|\xe2\x80\x9d|\xef\xbc\x88|\xef\xbc\x89|\xef\xbc\xbb|\xef\xbc\xbd|\xef\xbd\x9b|\xef\xbd\x9d|\xef\xbc\x8b|\xe2\x88\x92|\xef\xbc\x9d|\xef\xbc\x9c|\xef\xbc\x9e|\xef\xbf\xa5|\xef\xbc\x84|\xef\xbc\x85|\xef\xbc\x83|\xef\xbc\x86|\xef\xbc\x8a|\xef\xbc\xa0)/$_z2hSym{$1}/eg;
  
  $this;
}
sub set
{
  my $this = shift;
  my $str = shift;
  my $icode = shift;
  my $encode = shift;

  if(ref($str))
    {
      die "String->set, Param[1] is Ref.\n";
    }
  if(ref($icode))
    {
      die "String->set, Param[2] is Ref.\n";
    }
  if(ref($encode))
    {
      die "String->set, Param[3] is Ref.\n";
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $str = $this->_decodeBase64($str);
	}
      else
	{
	  die "String->set, Param[3] encode name error.\n";
	}
    }
  
  if(!defined($icode))
    {
      $this->{str} = $str;
    }
  else
    {
      $icode = lc($icode);
      if($icode eq 'auto')
	{
	  $icode = $this->getcode($str);
	}
      if($icode eq 'utf8')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'ucs2')
	{
	  $this->{str} = $this->_ucs2_utf8($str);
	}
      elsif($icode eq 'ucs4')
	{
	  $this->{str} = $this->_ucs4_utf8($str);
	}
      elsif($icode eq 'utf16-be')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16be_utf16($str));
	}
      elsif($icode eq 'utf16-le')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16le_utf16($str));
	}
      elsif($icode eq 'utf16')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16_utf16($str));
	}
      elsif($icode eq 'utf32-be')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32be_ucs4($str));
	}
      elsif($icode eq 'utf32-le')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32le_ucs4($str));
	}
      elsif($icode eq 'utf32')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32_ucs4($str));
	}
      elsif($icode eq 'jis')
	{
	  $this->{str} = $this->_j2s($str);
	  $this->{str} = $this->_s2u($this->{str});
	}
      elsif($icode eq 'euc')
	{
	  $this->{str} = $this->_e2s($str);
	  $this->{str} = $this->_s2u($this->{str});
	}
      elsif($icode eq 'sjis')
	{
	  $this->{str} = $this->_s2u($str);
	}
      elsif($icode eq 'sjis-imode')
	{
	  $this->{str} = $this->_si2u($str);
	}
      elsif($icode eq 'sjis-doti')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-jsky')
	{
	  $this->{str} = $this->_sj2u($str);
	}
      elsif($icode eq 'ascii')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'unknown')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'binary')
	{
	  $this->{str} = $str;
	}
      else
	{
	  use Carp;
	  croak "icode error [$icode]";
	}
    }

  $this;
}
sub ucs4
{
  my $this = shift;
  $this->_utf8_ucs4($this->{str});
}
sub z2hNum {
  my $this = shift;

  if(!defined(%_z2hNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/$_z2hNum{$1}/eg;
  
  $this;
}
sub _si2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ei2u))
    {
      $ei2u = $this->_getFile('jcode/emoji/ei2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_IMODE}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _e2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{EUC_KANA}|$RE{EUC_0212}|$RE{EUC_C})/
    $E2S[unpack('n', $1) or unpack('N', "\0" . $1)] or $this->_e2s2($1)
      /geo;
  
  $str;
}
sub jis
{
  my $this = shift;
  $this->_s2j($this->sjis);
}
sub _utf32_ucs4 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\x00\x00\xfe\xff//)
    {
      $str = $this->_utf32be_ucs4($str);
    }
  elsif($str =~ s/^\xff\xfe\x00\x00//)
    {
      $str = $this->_utf32le_ucs4($str);
    }
  else
    {
      $str = $this->_utf32be_ucs4($str);
    }
  
  $str;
}
sub kata2hira {
  my $this = shift;

  if(!defined(%_kata2hira))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xac|\xe3\x82\xad|\xe3\x82\xae|\xe3\x82\xaf|\xe3\x82\xb0|\xe3\x82\xb1|\xe3\x82\xb2|\xe3\x82\xb3|\xe3\x82\xb4|\xe3\x82\xb5|\xe3\x82\xb6|\xe3\x82\xb7|\xe3\x82\xb8|\xe3\x82\xb9|\xe3\x82\xba|\xe3\x82\xbb|\xe3\x82\xbc|\xe3\x82\xbd|\xe3\x82\xbe|\xe3\x82\xbf|\xe3\x83\x80|\xe3\x83\x81|\xe3\x83\x82|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x85|\xe3\x83\x86|\xe3\x83\x87|\xe3\x83\x88|\xe3\x83\x89|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x92|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x95|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x98|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9b|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xae|\xe3\x83\xaf|\xe3\x83\xb0|\xe3\x83\xb1|\xe3\x83\xb2|\xe3\x83\xb3)/$_kata2hira{$1}/eg;
  
  $this;
}
sub _ucs4_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("N*", $str))
    {
      $result .= ($uc < 0x80) ? chr($uc) :
	($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	  ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	    ($uc < 0x200000) ? chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	      ($uc < 0x4000000) ? chr(0xF8 | ($uc >> 24)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
		chr(0xFC | ($uc >> 30)) . chr(0x80 | (($uc >> 24) & 0x3F)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F));
    }
  
  $result;
}
sub split_csv {
  my $this = shift;

  $this->splitCsv(@_);
}
sub _utf16_utf16 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\xfe\xff//)
    {
      $str = $this->_utf16be_utf16($str);
    }
  elsif($str =~ s/^\xff\xfe//)
    {
      $str = $this->_utf16le_utf16($str);
    }
  else
    {
      $str = $this->_utf16be_utf16($str);
    }
  
  $str;
}
sub _sd2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ed2u))
    {
      $ed2u = $this->_getFile('jcode/emoji/ed2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf000 and $2 <= 0xf4ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_DOTI}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf000 and $l <= 0xf4ff) ?
	    (
	     $uc = substr($ed2u, ($l - 0xf000) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub sjis
{
  my $this = shift;
  $this->_u2s($this->{str});
}
sub _utf16be_utf16 {
  my $this = shift;
  my $str = shift;

  $str;
}
sub h2zSym {
  my $this = shift;

  if(!defined(%_h2zSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\x20|\x21|\x22|\x23|\x24|\x25|\x26|\x27|\x28|\x29|\x2a|\x2b|\x2c|\x2d|\x2e|\x2f|\x3a|\x3b|\x3c|\x3d|\x3e|\x3f|\x40|\x5b|\x5c|\x5d|\x5e|\x60|\x7b|\x7c|\x7d|\x7e)/$_h2zSym{$1}/eg;
  
  $this;
}
          	 
                        ! " # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z [ \ ] ^ _ ` a b c d e f g h i j k l m n o p q r s t u v w x y z { | } ~                                                                                ���N              ���}    �L  ��                                                                �~                                                              ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ����������������������������������  ��������������              ����������������������������������  ��������������                                                                                                              �F                            �@�A�B�C�D�E�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�p�q�r�s�t�u�w�x�y�z�{�|�}�~������������������������������������  �v                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            �]        �\    �e�f    �g�h    ����      �d�c                  ��  ����              ��                                                                                                                                                                                                                                                                                                                                                                                                              ��                                    ��                    ��                  ��                                                                                                        �T�U�V�W�X�Y�Z�[�\�]            鈿鉋鉐銜銖銓銛鉚鋏銹                                            ��������                                                                                                                            ��  ��                                                                                      ��  ����      ����    ��          ��                ��    ��������        �a  ������������  ��          ����              ��                                        ��                          ����        ����    ����                                            ����    ����                                                          ��                                                  ��                                                                                                                                                                    ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S                                                                                                                                                                                                                                                                                        ��������                ��    ����    ����    ����    ������    ��    ������    ��    ����    ����    ����    ����    ����    ��    ��                ��                                                                                                                                                                        ����                                ����                ����                ����      ��    ����                                                              ��                                          ����                                                                                                                  ��  ��                                                                              ��    ��  ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                �@�A�B�V  �X�Y�Z�q�r�s�t�u�v�w�x�y�z�����k�l              ��  ��                                                                  ����������������������������������������������������������������������������������������������������������������������������������������������������������������������              �J�K�T�U    �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~����������������������������������������������        �E�[�R�S                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ����            ��                                                                                                                                                                                                                    ����������                                                                                                                                                                                    �e                  �i            �`      �c                  �a�k    �j�d      �l                    �f        �n                          �_�m    �b      �g          �h                                                                      �~������                              �r�s                        �o�p�q    �u                                                                    �t                ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ����  ｵ      �����O����  �s�^  ���N    ���������u��        ��    ��        ��  �L  ��    ��      ����      ��  ���O  ����    ��    ���T  �v          �V  �����R          �h��������      ������    ��                            ��  ��                    ��  �T  ��    ����  �\��������  ��    �]��  ����    �j�i  ����  �������S��  ������  ��    ��������  ��    ��    ��      �l          �Y�m��  ��  ���w    ����  ������        �e�d�����t��      �W����  �M  ������              ����  ��  ��      ����      �C�N      �O��  �P          ����    ���������x                ��  ���`                                  ����      ��  ��  �L�Q�f  ����          ��    �A��          �����Z���C  ��  �渚R��  �]���������C                    ��          ����    ��  ����        ����    �g      ��    ��  ��  �T��  ��  ��  �俯S  �V  ��  ��  �U��  ��    ����                  �D  ������          �N��                ��    �W����        �E�r    �W��  ����    ��    ����  ����  ��  ��  �M  ������                �C��      �o  �U��  ��  ��      �褄Z          ����    �q  ��  �{  狹  ���|  ��  ��    ����      �[ﾘ  �芻Y���l����  �����������`                ��    ��            �X  �^��    �\������          ����        ����      ��  ��                ��            ��      �]  ﾃ  ������  ��        �U    ��        ��              �T      ��    �_      �P����                                  ���b        ���B����  ��            �X      �C    ��      �@�A    ��  ��  ��      �l�D  �a  ��      �E        �H  �F  �m          �G�I          �`�K      �J  ��        �V�M�N  ��        �L                ��  �Q�P�O  ��  �R        ��  �S                �D              ��        �U    �T�W�V    �X�Y��  ���Z�[���������b���[���e  ��  �Z  �\          �}  ��          �]  �c��    �S�_�`�����Z�a    ��      �������T      ��      �b  �c    ���~    �f��  �e��  �g竚�h�`�i  �j�k��  ﾊ      �d    ��  �n  �l���m  �y�o�p�q�~      �u�s�t�r���v����          �w�e          ���x�y    �y  ������                ��        �z蝪��    �{�}        ����  �}��  �f�~    ���M      ����  �����o    ����  ��    �n��  ������  ����    ��    �Y    ���g  ��          ��            ����  ��  ����      ��  ��    ��    ���������h��              ����    ��    �������O  ��        ��  �U        ��    ��        ������      ����        �������������n              ��  ��      �c      ������      ��      ����  ��            �絡h    ����    ��    �i    ���w������  �[  ��    �J��      ��    ��  �N  �j��  �u  ��  �E  ��      ��        葭    ��  ������  �k  ��������  ������  ����                    �M��  ��    ����ﾙ      ���橄l����    ���壱m��        ��  ����        �����k  ����    �x    ����  �誤n          ��        ��  ��  ��        ���C����      �����\  ��  ������������    ��      ��������    ���P  ��  �m  ��  ��          �T    ��        ���K���謐o���p��  ����    ��      ��    ��  ��                            �p    ��  ��  ��        ����        ����  �~�X      �}��  ��  �q��    ��        ��            �Q��        �����y�F�o����          �f  ����  ��  ��  �r  ��  �b�p������    ���@��������������ｶ�j�E    �����i  ��            ��  �h�e      ���g���D�����@���f��                  �N  ��  ���i          ��    ��  ��������              ��  �z��  ��������  ��  �C      ��  ������      ��    ��                          ��                ��  ��          ����  ��  ������      ������    ��      ��  ��      �u���a  ������  ��                  �t          ��  �B��    ���v  �@��    �]    ���P        ��      �D���C  ���i�A  ��    ������                            �E                ���N    �F�G  ����      �L�K      �N              �M    �J  �w        �S  ���O              �H��      �I  ��                                              �S�B  ��  �Y        �X�O        ��  �P      ���U��          �R    ��      �[    �V�W        �T�Z          �Q                                              �`�e  �a  �\    �f�P  �x�h  �A�^��                        �b�[��  �����c�_              ���i�g�r�i��  �d  ��          �c                          �m�k  ��                        �p          �j  �n    �l      �k�o                                    �r  �w      �u�t              �Q    ��                    �q  �s���R    �v                          ��          ��  ���}  �{  �|  �~                  �\                  �X  �x  �y                    ��                ��      ��  ������              ��      ��  ��          ��          ���d    ��        ��        ��                      ��  �X    ��                ��          ��  ��          ��      ��������        ��          ��    ��  ��      ���d  ���l    ��  ��    �c                    ��  ��  ���}          ����    ��  ����    ����      ����  ��  ��  ��    ����    ��  ��      ��    �y            ������        �\    �n            ����    ��        ��  ��        ��    �V      �������B              �y              ��    �ｍz�R    ����                                        ��    ��          ����  �^              ��                        ��  �C�_��          ��  �{      ��    ��                        ��    ��    �詩}�|    ��    ��      ������  ��          �W    ���u    ��                                ��    ｷ  �|��  ��      �x  ��    ����      ����                  ��      ��      ��      ��    ��          ��        ������    ���g        ��    ��    ����                ����          �Y��  ��    �h������      ��      ��            ��  �U        ��  ��    �o      ��        �m        ��  ��                          ��      ��        ��  ����                �n    ��    ��      ����        ��������    ��    ��      ��  �d    ��  ��        ��  ��  ��  ������    ��  ����        ����          �m�p  �s��������        ��  ����������        ��            ���蓁�      ����        �[�O  ���g������          ��    ��  ��  �V���v������    ｸ��        ����          ��          ��    ������        ���t���_  ���z��  ����  ����  ��    ��  ����  ��  �������D  ��  ��        ���z      �@        �D      �A�@����          �D    �J          �W    �d    ��  ��  �B          �E����    �W      �i          �F            ������    ��              �G    �o  �n        ����  ����        �K�L  �I                �W��  �H  ���P                    ��        ��      �p  ��  ��          �Q              �O            ��  �R  �P    �N�P        �M      ��          ��          �V�W          ��      �S�K        �k    �U                                ��              �X      �w      �Y  �T                                    ��                                    �}              �Z�Q                                                                �[�_�\    ���^            ｹ  �]��      �k          �d�a                  ��  �`    �b    �c                                �e�f                          ��  �h�g                  �i                      ��              �l  ��      �d  �j      �m              �n  �q    �o  �p                    �q�r    �E�s������  �t�u�y�F  ��      �G���v�w    �w  ��        �x��  �y  �z    �{  �}          �~    ��  ��  �F����  �v��ｳ  �G          ��  �@���������X��  ﾀ    �q��ｺ�G��              �{  ��    �Q������  ���e          �h��  ������������  ��    �x      ��  ������      ��    ��  �Q���@  ����  �������J���R  ����  ��  ��    ��  ����  ��  ��      ����  ����  ﾋ�������������q  ������  ��  ��    ��      ��      ��  ��  ��  ��      ��        ��      �A            ����ﾚ�K���s���A����      ����  ��  ����  �r��������  ��  �W                ��  �jﾆ    �w��            ��  ����  �R        ��    ��                                    ��      ����    ��                        ��        ��  �Z��  ����        ��  �x    ������  ������  ��            ��  ��                                  ��            ����            ������    ��  ����        ����      ���s  ��                  ��      ��    ��    ��    �����R����������      ��    ��        ��  ��                                                ��                ����  ��  ��  �剥�                ��                        ��    �簿�  ��      ��    ��                      ��  ��    ��      ����      ��                        ��        ��                  ��  ��                �幎�����  ����                      ��    ����    ��  ����    ��        ��  ���B    ��  ��  �H���I��    ��    ��    �������b��  �J      ��  �F��      �s�z    ��        ����        ��        ��    ������  ��              ��          �t  ��  ���A    ��    ������        �X    ��    ������  ��        �y  ��          ����  ��              ��  ��������                          �����N����  �K�������c�H����  ��  �L��    ��    ��        ��          �����X    �M  �{      ��          �x��      ��  ��              �����N�f                �����p        �����L        ����    �f    �@      �C�D  �B  �_���F�E�A        �G�H    �I      �L�J  �K�M  �����N  �����U  �O��  ��  �P�M        �Q���T����  ｮ���U  �|�����V���O    �o      ��  ��      ������  �W      �X  �^  ��    ����  ���Y      �J  �e    �Z      �K    �[  ��  �\  �]    �_  ��    �`�a  �b    �S�R      �c�`      �F��  ���V���j�d    ���e  �e      �f  ��    ��    �i�����h�g�a��  �m�k  �j����      ���l�k�]      ���p�o        �n  �q��            �r���z    �s��        ����    ��  �O    �t�J          �S  �K            ���E                �u�u�Y�Z    ���z��  ��      �w            ��        ���y      �O    �x    �v  ��  �|                            ������  �{    ���|    ��  �����v    ���}      �}������������      ��  ��                ��            ������    ��      ����  ��    ��  �P    ��      ����    ��  ���~  �������p    ������������  ����        �b  ��                  ��  ����蹇      ｻ蹉������        ��  ��  ����    ����      ���I    ��    �x��  �Y��              ���{������  ��      ����              ������                  �f  ��  蹐    ��  ��  ��  蹌������  �y      ���S              ���詩��z��  ����  ������        ���D  ��    ��  ����      ������  蹤      ��        ����      �危���          ����      ��      踪      ��    蹠        ��������    ��  ��    ����  �����Q���T        ��  ��    ������    ��  ��    ����  ��  �d�S    ��    ��������  �������c��            �|      �J        ��    ��      ��  ����    ��  ��  蹣����                  ��    ��  �e  ����  ��      ��      ��      ��      ��        ��    ����������������    ��                                    ��    ��                      ��  ��  ������  ��  ����������              ������  �����^  ������蹕��  ��      ����  譱�@��  �A        ��      �B      �C�Y�D  �E�F��      ��    ��      �[���G          �鈑���  ��  ���H        ��  ��    ��    �K    �I  �L    �J        �M          ��    ��        �}    ��    �N  �Q���Z  �O�V��        �P�c            �}�R�S�W���T�R��    �e��  ��              蹶        ����        ��      ��      ��  �Z����        �c    �S�]�d�_�f�b  �a��  �[���Y�����U    �X�S��  ���`�q    ���g                    ���@�h�m  �i  ��  �n�A��            �E�\  ���k        �w�l��    �g        ��              ��          ��              �j��    ��      �U                    ��    ���p�}                  ��    �J�q  �s�o        ��  ��        �{                    ��ﾌ��  �~    ��      ��      �x��    ���P        �v    �|        ���{    ��  �u�z    �r      �t  �@    �|      �|�����T�y  ��  �T�����[�w�d          �f  ���}          �~    ��  ��    ����  ��    ��          �`��  ��      �K      �g��          ��  ��          ��        ��          ��蹲��      �h                      ��            ��  ��      ��    ����        �r                  ��  ��      ����            ��  ��      �g      ��      ��                      ��                  �E              蹼            ��  ��          ��            ��  ��  ��                ��        ��                  �T��  ��        �Q    躁��          �P��      ��  ��  �d�B  ��  �o            �h  ����        �i��    ��  ��          ��躇      ��  �^      ��  ��          �����F��    �C��        �[    ��  ����  ��  ��      ��    ����  ��        ��                                    ��      ����          ����          ������    �x        ������������  �U    ����          ��    ��        �庭��q  �~      �����s����      ����      ���U    ��          �h      ��  ��  ���G  �~��                  ����      ���|��    �k  ��  ����          �l  ��  ��ﾎ    ��  ��    ����  ��      ���a�f  �z�V            ��  ��    ���{      ��  ��������        ����    ��    ��        ��  ��  ��        ������    ���U���|��    �{��      ��                ����        躄  �V��    ����  躓��  ��  ����      ���耶�            ��  躔���f      躙�t  ����        尣���  �G    ������        躊��    �E  �����W��        ��  �W      ��    �N        躡  躬      ������    ��  �謐��A������        ���i��    軆��  ��      �q            ��  ����    ������        ��    ��        �g����躱      ��    躾  ��      ��        �b    ��      軅  �\      �A��    ��  ��軈  ��    �@    ��  ��                        �B    ���C  �j��    �D          �F    �G            �H  ���g�X�I  �J����軋�J���]�\����    ��        ���L  ��  ��軛�K        �����L�N      �]  ���M��            �N�O��  �����{�D�Q    ��    �p  �S�V�U  ��    ��  �R  �T        �W    ��        ��������  ﾛ    ��    �Z    �m  �X���Y�����[�\��軼      �a    �Y  �t�^������  �n  �f        �`  ����          �f  ��  �]  �c�b      ��        ��  ��    ��  ���}    �g�e��      �d    �_          ��      �k�i  ���g�m�s  軻        軾��    ��  �u      �A      �t���^��  ���_      ��  �M    �p�o      �q  �n    �v  �l    �j  �r�h  ��  ��ﾄ��          ��    ���`  輊�����h                            ��    ���I            �x    �Z��            �z����            �}  ��      �j��    �i��    �{���j��輅  �y  ��        �|�~  ���K軫���j        ��    ����  �V      ��      �O                        ��  ����            ����  ��  ��  �~              ��  ��      ����    �[      ��  ��  ����  ��      ������        ��  ���B��  ��  ����    ����  ��              ��  ��  �H������  ��  輕    �_  ����  ����  �I        ������  ��      ��            �X��    ��            ����          �o��    ����    ��    �����A����    ��            ��������        ������  ����  ��  ��          ��      ��  ��    ��      ��  ��                    �k                ������      ���^  ������  ������          輙  ����  �����|      ������  ������    �O�y��    ���T              ��      �|    ��    �P��    輜    �Y��      ��            ��            ��    ����  ��            ��    ����  ��  ��      ��    ���\������  ��    ��        �l��      ����      輟        ����    ��  ��        ��            ��  ��  ��  ��    ��    ��        ������          ������    ��  �W  ��    ����  ������          �����~    ��  輛        ����  ������    �M            ��  輦����    ��                        �k��          �@  ����      ��        輌            �迯�        ��          輻���h      ��                ����  ��            �@        �w      ��  ����            �K  �G  ��        �F        �E    �B          ���D�C                          �I  �E            �L��    �H�J    輹  轅      ��  �M                              �Q�N                ���O        ��              �R      �S            �T  �U����  ��      ��                    �~        �W�V�Y�\    ����        �\      �[  �]    ��  �V  �^    ���`        �_  �a      �b  �c�~����  ��    ���c        ��      ����      �d�e  ��      �f�g    �i�h  �w    �}���c  �j              �l�B  �k          �m          �n          �o�p      �q  �s�r�t���i  �u    �E�k�v    �a��        �B�w        �x  ����      ���y��  轂  ��    ��      �z                      �|�{    �~      �}                                        ��            ��  ��  ����    �C      ��              ����                              ��    �X�i          �注����`��                      ��  ｬ        ��  ��    ��  轌�����]�r  ��          ��  ��        轆��  ����            ��    �D��    ������    轉  ��      ����    ��  ���B    ��    ������          �v��                ��    ��    ��  ��        ������｡��������  ��    ����      ����  ��            ��  �@  ��  ��轎��  ��      �A�g��  �D    ��  ��        ������  �j                                轗            �m��          ��        ��  ��  ��    ����          ��      �k�^��            �F��  ����  ��    ��  ���h    ��    ����                                      ����  �l            ����  �Y    �_�Q  �\  ��轢        ��    �C�Z��                      ��  轜��      �O  ��        ��  �櫛@    ��  ����                              �A    �U    �t    ��    ��      ��      ��        ������      ����    �B  �i��    ��    ����        ��    �W    ��  ��  ��  ������  ��    �[�D�~  ��  ���C�����Y�E                ��  ���������a              �k  ��      ������  ��  �����n  �������Q�H  ��  ���������`                �瓊F��  �I  ��        ��            ��    ����              ��  ��    �X�G    ��              �N      ��    ����    ��      ��              �pｼ��  ��                  ��    ����          ��  ��      ���a  ��    ��    ��        ��        ��    ��      �n��    �M    ��  �J    ��  ����      ��  ����        ��  ������              ����                          ��    ��    ��  �H    �B��          ����  ���Y      ｽ    ��          �R  ��  �A����                    ��  ����              ����        ����          �Q          �@��  ��      ��                            ��      �N    �I��    ��        ��  �R            �K���H��      �k      �E  �D  �M      �G�F�L  ��  �C  �K          �O    �P          ��                  �U  �T�V          �Y            �b  �S  �L      �W            �����Q�Z    �X                          �]�[    �^    �a      �Z���G    ��            ���\  �`��  �_  �J  �M��      �d      �h    �f      �N  �O  �b  �c      �g  �e      �m    �m  �j�i  �l�呀n            ���譖P      ��      �o  �q                      �p                          ��        �r            ��                    �s              ��      ���D              ��      ﾜ��              �Q      �F��      ��      �u            �t                                  �R�x�Y�{�v      �z        �y�_�恪F                        ��    �}      �G                  ��      �~  �|                                  �w              �B      ��            �T        ��          �S        ��        ����  ��        ��        ��                              �R          ��                  �V�W  ��    ��  ��            ����    ��    �U          ��  ��������  ��    ��  ﾏ                            ��            ��      ��  �F        ��        �o��      蠅          �n                ��      ��        �M              ��        ��    �Y  �R        ����        ��  ��  ��  ����  ��              �z��        ���W��        ���C��            ��      ��  ����  �Z��            ��            燹    燿                    爍                        爐  ��  爨爛    爭  爬    ﾝ��      �袱�爲�u｢爻爼          爿����    牀�v          ��          牆��  ��  ��  ��  ���S        �q  ��                ��  牋        ��      �÷�  �呀橿�        犂                    犁      犇                  �]  犒        犖        ��    ��  �[犧      ��    犢        �\      �謹死�  犲              狆  ��  狄        ��  �_  ��        狒狢狎            ��    ����                  狡�K狠    �T��                        倏                      猊狷      �呀彼�  ��        �]猯      猴���L    ��猝        猖  �P�Q            猩��        ����                猥猾              獏                      �b        獗  默          獪  �l    獰  �_獨  獵獸                ��    ��  ��  ��                    ��                                    ��                �聳�              玳  �`    珎  ��          獻�a�X    �逗�      �H      �b              珥  ��    �c  玻        �]    �楳�    瓏      �J    瑯          ��        ��  珞���I  ��                                                ��    琅�K    �M�L      �N      琥�������i      珸        琺  瑟                                      琲      琿���l瑙  ��瑕��  �O瑩蝣        瑁瑰        璢瑜    ��    瑣              瑪        ��          �P  瑶                                    瑾�Q    珮        璋                ��                        ｣                        璞        璧        瓊              �Z      �@  �Z�A    �≡B  �C        �D  �F�G�E      �r�I�H                �R  �K�J�L            �M�O�N    ��  �Q  �P    ��  �r  �[  �R��      �Y  ���S  �p    �瘁T    ���c�R�b�\      �j��  ���聲U              �V  �[    �Y�X���E�W  ��  ��    ��        ���\�Z�{��    ��  �L  �^���l�_  �]�壤`  �a  �S��    ���f  �c�諱b            �E    �i      �d�e  �h�g�D    �a�`  �^    �j          �k    �l          �n  �m          �u          �v�聲p  �r    �t�]    �u�sｾ      �o�q  �a  ��    �x    �w        �y  ､��    ���z  ��    �|      ���{          ��            ��  �����s          ��  ��  �}�~  ��              ��  ��  ��                                  ��������  ��    ��                ��      ��            ��            ��      ������      ��          ��      ��  ��      ��        ����        ��������  ��      ��  ��      ��  瓠  ���o瓣���S  瓧  �T瓩�I  �F�c瓮    瓲    瓰  �H    瓸    瓱    瓷甄�W�U  �V              �X              ��  甃      甅    ��甌甎甍        �M    甕�u    �~  �m  �v    甓        甦      甞��      ���X  甬��  甼  ���宦�  畍    畊      ��      ��  ��      ��    畛    ��    ��    畩    畚畆��  ����                            當    畫�^��      畧畭畸    畤                          疆疇  ��  ��      ��          �Z畴                                    疊疔          ��  ��  疚�r  疉    疂                          疣        疥疝                      疳    痂    痃                        疽  疵        ��            �u��    疸    ��    疼    疱  痙痊痒  痍              痣          痞                  痾    痿�求�          �釶�  �m  ��  ��      �Z痰��      ��                痺          ��                  痲          痳  ����                    瘍�\      �u���m                    �C  �j          �v        �{          瘟                �]                            ��            �^            ���d    ��    ��  瘠          �_  瘢        ��        瘡��        瘴�V瘧    ��  �O  ��  �q    瘤                瘰      ��  �怐�        癈          瘻        �m  癨  癢    ･      癩癜      癪癘        �已�    癡          �A                        �@��      癧    ��        �C                �B      ��          �D            �b    �F�E            �G                        瘋      瘉�I�H      �`                  ｦ  ��  ﾐ  �J�V          �_�F��            �S    �P  �O�c�L    �N    �j�_�M�K  �I    ��    �[        ��                  ��    �Q        �R�h��    �\�T        �S    ������        �d            �f  �T                ���U    �W      �X  �H    �Y          �Z�[    �������G��              �\  �H          ���b    �]    ��            �d  �`  �a��  �`�^  ��    �_      ��                    ��        �H              �b    ��  �c��          ��    �B�d�e�t  ��    �g�f                          ��    �i��        �l      �j���m�k�e��  �籵m    �s    �o      ���n����            �n                  �p�q��          �r  �n        �t      ��  ��    �u��    �v  ��  ��  ����      �w                  ����  �y�{�x�z            �A                  �|�E      ���q�~          ��      �M        ��      ������  ���}  ����  ��  ��  �g�鰲�  ��      ����  �鰍�  蓁痹����v  �金��h    �G�j  ��  �[��          ��  �^�|ｱ        ��    ��  ��  ��  ��  ��癶      ��  ��            ����  �J    ��  �}        �y��  ��      ��            ��  ����    ��                      發�M  ����  �憫ｂ�  �鰍��}��  ��  ��            盒              皃  皋        皓  皙  皎皖    皈皀        ��                      ����      盂  皸  盖    盍  ����  �Z皰盞皺  皹皚�k皴  ��                �\    ��      ��    蘯      ��              �烽�    ��  盻��  �z  盡盧    盪                          眈    ﾂ      �亭窒�    眇      �U          眸    睫睇                眦            眛          睨      眄�嘯狽�    睚              睾  ��  睛      睥    睿瞎                      睹��        瞋���謔�    瞠                瞑��  瞰瞹      瞞  瞻  瞿            瞼眥      瞽矇            矍            ��  矗                ��    ���H矚          ��  ��  ��    矜  ��    ��  �e�S    �l      ��  砒矼  矣��  硎�    砌  矮碎    硅礪砠          硴      碆��  硼  碌    碚        ��      �W      碵      ��  碣      碪  �����f  碯        ��              磆    磋  磔  碾  ��  碼�n    ��  �I  �@  ���g磅      �C��  �[    �R      ���B  ﾑ�h�����眼A      �f�a��                ����  �F����  �G�a  �I      ����        �H    �I���g�D�J  �m    �E�o  �M�Q��          �L        �U�n  �i    ���冴R    ��  �O          �P    ���N�K  �G��    ��      �W                      �T          �V      �S          �p�宴X��    �e�p  �a�[              �_���档Z�b�f�j��  �壯\  �o�d  �Y�]  �^����              �]    ����      ��  ����    ���q  �g  ��  �c�h�j  ���m    �i      ����    ��    ��    �l  ��            �k          ��    �裔n      �u�o�v            �r                ��    ﾈ�t  �q�w�p    �c        �D    �k    �s��    �{  �~  �|���z  �`��    ��  �}    �x      �@�q  �J        �r  �D�U��    ����    ����              �y��  ����    ��    �J                ��  ������  ��    �[��        �����@  ��  ���Z��  ������  ��        ����                                                                                                                                                                                                                                                                                                                  ��  ��  ��                    ��  �s        ��磧磚  磽磴    礒礇    礑            礙礬            祠礫祀���r    �u  ��  ��    �l  �諠���                祟祕  ��祚祺祓  �r  祿  ��          禊          齋    禧禝    �t  禪�Q      �A�`        禺禮    禳      秉  秕禹      �H      ��      秬秡      秣  ��          �K  稍稈                    ��稘        稙    稠  ��        ��    稟          禀  �|��      �s�V  �l稾ﾒ稻        稷ｧ      ��  穃    �k  �寃�穉    穡        穢            穩                    ｨ    ��        穰  �^  龝            穽      穹              窈      ��  窗  窕      �激�  �鉇          窩            ��窶  窰竈��  竅�E  竄      窿�W邃        竇竍竊��  ��  �]��            竕    ��  �I  竓竏  ��      ����    ��      ���b  竝站  �m  �n��  ��          �x                �气�  �_          �w  ��              笏    竦笂竡  竭�E    ��    ��竢                  笆  笳    ��      ��      �E�\        ��    �����e��笊��                              �r笘              笞          笙          笵  �E  �]          ��        �B              �A        笨    �t  ���D  �C�o�r                  �T          �H�I        ��    �G  ���F    �J      �����B        �昶N  �O�K        �L  �M        �p      �U  �Q        ��  ���G    �P    �S�R      �c�V            �W    �V  �X    �Z  �^    �[�Y�^�\  �]      ��  �d�_      �`      �a  ��        �c�b�e        �f�g    �b  ��  �h��  ｩ    �L          ���v          �i�j�P  �k    �l�m    �n  �o�����p  �邃qﾉ  �r  ��      �s����    �C�w  ���M                  �t�q�u��  ��        �w  �����巡v�D            �x            ��                                �z�y�|    �{  �}    ��  �~  ��  ��  ����    ����  ���F      ������          ��                        ��  ��        ��            ��      ﾅ  ��          �H��        �����m  �c  ��  �F        �|��  ��  ��              ��                      ��������    �c  ��  �寇�  ����  ��  ��  ������      ��          �p  ����        ������          �v�冷�������    ��        �s              筺筧筰      ��            箍        ��    筴      筥  筍笄  ������  ��筌            笋        筵      ���t        �`筅  �r          ��                  �w                                筝  箙  ��      ��箒    �x          筱  箚  篁箋      箜        ��    箟      筬      �冷�篋  箘          篌  筮��          ��      箏              簍      篥      ��  �y    �e  ��  篝        ��    ��  簔      ��    �p簇                ��  篆      �����H簓  篏  �z籠      簧  篩          簑��    簀      篦�G篳��        箴                        簗  篷            ��簟  籟        ��      籥    篶      簷��                籘  �{�t        ��                ��      ��          ��籵��    ��    籐  籃��簪籏籤  �K      ��  籌  籖��              籀  簽            ��        �N      ｪ        ��    �f    粤  粮                      籔        ��  �|      ��粃  粫��    粐  粳    �~  粲    �u籬�W  粢    粨��        粱    粭粡  �D                              �H  �@          糀              鬻    粽ﾁ          簣                    ��  ��糢糜  糅糂  �U        糒  粹        ��          糘��              ��              ��    糯�@  ��        糶��ﾇ�B    ��        �}  �C  ��糴�~簫                糲        �n������  �J                  �P            �Q  �D      ��    �N�F  �H          �R�G    �K    ��  ��  �L�O              �E  �E  �I�F�d�O��  ������                �V�T            �m              �S      ��  �U�W        �X            �[�Y            �≦Z      �妹M                        ��  �\�a��    �`      �A      �b�h    �]�_              �^    �P�A    �d              �c                    ��  畉�e                            �f                          �g��  �s      �i�|        ��  ��  �驟j              �k      ��          �l              ��  ��                            �痳q�r            �m  �\                          �n�a        �o�p�z      �t�w          �s                          �u  �vﾖ  �x  �`  �u�a          �{        �^  ��    �|��        ��        �}    �~�g�懊�                ����  ��    ��  ��  �I��    ��  ������    ��      ����          �w  ��  ��                ��      ��                    ��    ��      ��      ��                  ��  �X��  ��        ��  �I  ��  ��          ����    ��    ��  ��  紂      ��          ��  ��  ��            ��    絅                    �Z                                  紊    紕                絳      絋      絎            ��絮  紲    紿      絖  絨絲      紮        紵  綮                          經                            絏    絣      絽綛  �I  �a    綏            紜  ��          絛綺綉  綣      緇綵                    綫綽�y      緜                  總        綢    綯  綸        ��  綰  綟  �O          �s��        緘�p      �X  緝  �q  聤�    �t緞��        �\    緻        ��  縒    縊  ��          縣緡��  緲縱          �U    ��  繦        縉      �喝�  縢        縅      繆  縻            ��    縋  縵繃    �刔�  ��              縹  ����縷縲��                  ��        縺�T    繧繝    �矼�  ��  ��            繪                  繩臱蓆�    ��繞    繚����      繙  繼    ��    纃  繻      ��  �J緕                �A纎辮            繿        纈纉                    纓  纔    纐          續  繽纒              纖莎                ��              纜�氤�      �A  �@      �C    �B  �D    �P  �E    �F            �G��  �v  �H    ���e�I  �J��      �K      �K    ���`�L  �o            �M        �O��  �N�e  �P    �Q    �R��            �S    �T  �U�V                                  �p              �W  �X�Y          ��    �G�Z                        �[      �\              ��  ���]        �v  �u  �`  ��  �_  ���P    �^���L    �a  �b  ��      ��  �c        �K    ��      ��  ���i  �d��    �f����        �e        �h  �i              ���蝉g  ���]          �f    ��  �r  �m�w    ��    ��  �l�l�k�F  �l�b�Y��          ��    �j          �o  �p�n  ��  �_    ���F      �s  ��  �a    �U  �v      ��  �醇r  �w�諞t�u���q      ����    �N  ��            ��    �b  ����    �z  �x    �k      ���倅y  �z    ��      �_      �{����  ����������  ��  ���~      �|  �@��    ��  �}    ������  ��      ��  �d�y��  ��    ��        ��  ��  ��      ��  ����  �����u  ﾓ    ���w        ��  ��    ���T            ��          ��        ��    ��              ��    ��  ����      ��    ��  ｯ  ������    ��            �x        ����    罅�c秧��  罌    ��          罍  ��罎    �]            ��  罐  网  �Q  罕罔    罘    罟罠                                                                                                                                                                                                                                                                                                                        �J    罨        罧  罩        ��  罸  �L  羂  羆  羃        羈        ��            蟺�              ����羌                      羔�^羞  羶          羝    羣      羚羯  �e羲羹          羮      羸        �L��  �����v        �n���紋����嚀台�����  翕翔�M  翦����    ���\翊  �f�裝��G���d    ��翩  ��    聒�G    ��  �o            耆�^��  ��  ��  ��飜翹  ��      ｿ    �q    ��      ��          耋耒�w耄            耘耙  耡��  耜��  耿  耨耻  ��聆聘  聚                                                                                                                                                          ��  ﾍ聟      �q  聢    ��聨  聳��  ���N                  聲      ��        �z                            聰                  ��        ��                    ��            聽      聹      聶                肓肅    聿            肆      肄肛  ��  冐  ��  肬        ��  肚肭      �H      ��  �H            胛    胝                胥胙�x        �ユ�                        胄胚脉                    �H          脛      脩胱                        胯  ��    �@�D�A脣  �B      �C        �J      �E          �帛G    �I�F                          �L  �R  �K          �M        �N    �Q�P  �O    �S�R  ��      �U  �T�V        �W              �Y                �X�g�Z    �諛[�]                        �^            �_�\  �`  ﾔ�a�O�R  ��    ��                �b      ��    �]�c              �f                        ｲ    �e�d�y�g        �r  �i      �晏h  �q          �k�m�竍j      �l  �p�n�P  �o            �r    �y��        �S      �s        �A�u  �t    �x�`    �w  ���v�{    �z    �y�Q�|                �}        �~    ��  �D������                                                                                                            �h��  ｫ��      ��      ����        �������C�J�_        ��    ������    �H    �I  ���v                �}    ��    ��          ��              ��    ����    ������  �R  ���q      ��    �仙�����    ��    ����  ��  ���t        ��  ��脾������  ���r������  ����    �仙����∝����A      ��            ��    �T�i    ����  �辯�    �N  腑    ����    �x  ��  腓�V�^  ���熈���隋腆���B�瘍�  腱蝓    ��  腮  ���k  ��  �y  ��腥�K      ��ﾕ腦    膈    ��腴�J�I  ��  �芙�  �韃援亥�����    ��  膤膕        膣  �W                                  ��    �M  腟  ﾗ        膓  膩      膰    �@                ��                �x      �Y                        膽    ��    �S膵  膾      ��        �s              �X  ��          �s        臀                              臂    ��      膺                          ��          �A    臍  臉                                            �刧��Uﾞ�z��      ��  ��  臙  臘                  �|臈  臚      臟��  �V          臧臠  �y  ���_                  臾        ��  臻  臺  ��    ��  ��        ��        �X          舁  ��          與舂      舅        舍舊    ��  舐          舖舩        ����ﾟ舫  舸���d���募���        艀���B  ��艝���j��艙  艘  �滕ｎ��t��          遏遐            艟艤          艚    艨            逎      逾    ���b  遉艱    艪舮                艢                    �n    艫              ��    ��  隨遖  遞    芻遘      �S艾    芫芍  芬    遨  苡遶          艸  遯苳��    艷      ��  芒  豗�                  �z          遽邁          �g  ��    �e  ��    �C                �L  苒  芟苟  ��  �句鼇�                    邂          �K                  范  莓                                          苺邏  �N邵  邯  邊  邉            邱      ��    邀  苻��    �s        �e��        ���I苞扈�|    鄒    鄲      �K                苹��              ���@�B    鄙鄂  ��郤�A�C  郢��  �d    ���B  苜��    �^    �E        �D�F                茆      �B    ��  �t            ��  �K酊      �b�G      �H                      �L  �J  鄰        ��            �I  ��                          ��              �O  ����    ��                  酖    �Z        �M�N��  �L                �P                  �V    酘  �Y              �X�L        �Q�R�U        �W酣    ��    �Z�T    �S                              酥                    �^      �_                �`    �]�\      �����[            �d                  �b          酩      �c�a  ��  �e            �f    �h酳    酲                �嚠g��            �s�i    �l  �j  �k              �m          �o        �p  �q        �t�r�u�w  �v                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ��                ��  �x�M      �y  �第z�J      �[  �寰��壽{  �|  �}�~            ��  ���t�}��  ����        ��        �{            ��  ����  ��        ��      ��    ��  ����            ������  ��      ��        ����    ��                                                                                                            ��        ��            ��  ��      ����    �h                �j      ����  ��  ��            �����~  ����                    �宙�������    �@�w���怦�      ��  茖      �A  茴��  ��������  ��    �z              ����  �G  �珞@  茲�K��        �u荀  茹茱��  ��邗�    �B    ��      荅膃  荐        醫茗茯茫  茘  莅�褂�莪  ����      ����    �Y���W��  莖  莢��茣莟    �G      荼絆    ��  ��莇          ����        �J  ��ｴ        ��  �_      ����  莵  �d        ��      荳  荵�k莠  ��    莊莨萓  菴  莉    菫    菎    ��  ��          菽    ��    萃          菘  �I醯        �P萋  醪  菁菷      萍醵萇  菠  菲萢      醴  醺  釀��    釁��    ��    萠  ��  莽�r��  萸  蔆  菻�v  萪  �x      萼    �C        蕚蒭  葷        葫    ��蒄葮        蒂  ��  葩葆              ��      萬      �f    萵    葹  葯    ��  ��          蓊葢                            蒹    蒿  蒟    蓙              ��                蓍                                蒻�B      蓐��  蓖蓆        �C      ��  ������  ����  �{      蔡    蒡�a������      ����  �z            蔗    蓴              �j��            �o    蔘蓿    �p��蔬                蔟        蔔���z�{蔕        ����  釉��    �^    ��            釋  ��      蓼      蕀蕣�@  �B�A                                                                                                      ��  �C        �D  �E        �F                        �H�G  �I                                        �鱆�    �H    �Q            �J  �K  ���Z��    ��  ��              ���O��        �L  ��      �M�{  �a      �`  �N�跚O      �P        �R�S  �U�Q    �T    釟��      �V  �W                            �X�Y      �Z    �\      �[  �^�a      �]�_�`    �b  ��                                                                                                                            �驩c�d��        釛            �e    �]      �n�f�g        �y��              �h        ��    ���w��  ��              ���m��    ��    �l    �j  �k  �i    �w                    �n�o    �p�q          �s    �r      �x  �t      �v                �R�u    ����          �x                            ��    �y        ��            �z            ��  �}  �|�~  �{              ��釼            ��  ��    �痩�      ��    ��  ����      ������                                                                                                                        ��        ��    ��              �[      ��      ��      ��                    ��  ��  ����      ��釵    釶  ����    ����    ��      ����  �E����  ��    ��    ��      ��                    ��                                  蕁  蘂        蕋    蕕薀  薤  薈薑薊薨      蕭薔  �T薛                磑�S        �@�育�藪��              蕷蕾薜  薐    ��      藉  ��                                        �D    釿  薺鈞                          薹                    �珠�  藐��藏    藕藝              藥藜              藹  ���L  ���N    鈬    蘊        藾  鈕        蘓          藺    �濶�        蘆  蘢蘚  乕  �I        ��          虔蘿蘰虍      �~              蚓虱虧    ��                    鈑      蚰  蚶  蚯蚪蛆  蚌��    �k  蛄蚋蚩蚣          蠣          蛞    蛔蚫              �h蛉�驩�  蛟            �驇�V    蛯              蛛蛬�L                  ��        ��    蜒          蜆            蜈                            蜀  蜃                                                                                                                                                                                                                        ��  蛻  ��  蜊蜑      蜉    �P��  ��                        蜴    蜿�守跚�        ��      蝸    蝟          ��      蜚      蜩    蜻  ��  蜷ｰ��                            ��    蝴蝎  蝌    蝠  蝗  蝨              �D�C              �E    �L�@�A  ����    �B            鉗�Q    �J鉞  �F              �K                        �H  �G          �{                    �L                  �M        �N  �I      蜥    �O  ��      �S  �T�R          �Q�W  �P  �U                �V      �Y          �X                        �[            �\  �]    �h          �Z����    �^                                                      鉉�_�`    �a                                                                                                                                                                            �b    �芽c      �d  ｭ  �e            �f    �g�h        �k�i�[  �j  ��          �l  ��          �m��    �n�p    �q                    �o��������  ����        ��              �s�o�t�u�v鉤��  �w      獎��  �瘧x�z�y  �{        �|    �}            �~        ��  ����  ��  ������                  ����          �C        ��  ��                    �l��                    ��                            �@    ��                      ���V    聊蓚    ��  ��                    �������鉅�    ����    ��  ��          ��      ����                                          ��              ��            ���s    ��                                                                                                                                                                                                                                                                                軣                                                                                                                                                                                                                                                                                                                                                                    醉                                                                                                  �s�~����躰輒輓�X�^�Y�a�b�c�e�i�l�u����������������邨郛醂釐釖釡鉅                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      �I鋺��������錏�i�j���{�C�|�D�^�O�P�Q�R�S�T�U�V�W�X�F�G�������H���`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�m�_�n�O�Q�M�����������������������������������������������������o�b�p�`    � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � �                                                                                                                                 ����銷�P鋩��                                                    鐔￥就鐔ｏ修鐔ワ拾鐔э秀鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔逸襲鐔駕蹴鐔器週鐔駈酬鐔醐醜鐔削住鐔種十鐔常戎鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�鐓�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ���������鐚�鐚���誌��鐚�鐚�鐚�������卒 鐔�即 鐚常殖鐚帥�純�障��������篁������������錫�����鐚�鐚種����ワ�������モ�����������鐚�鐚�������鐚誌悉鐔�鐔�������������������������������鐚�鐚�賊 �� ?  歎 鐚����鐚�鐚������р����癌�����属 ��霞�鰍��鐃ワ��鐃�鐃￥��鐚�鐚�鐚�鐚�則 �����������������������≠����鰍�霞�盾�錫�祉�����������������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ������������������������?  ?  ?  ?  ?  ?  ?  ?  ��р��鐃≒�����������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����モ����������≠�������������盾����汲�����?  ?  ?  ?  ?  ?  ?  �����謂�������������‖� ?  ?  ?  ?  ���?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  鐚�鐚�鐚�鐚�鐚�鐚�鐚�鐚�鐚�鐚�?  ?  ?  ?  ?  ?  ?  鐚￥滋鐚ｏ爾鐚ワ痔鐚э示鐚�鐚�鐚�鐚�鐚�鐚�鐚�鐚逸識鐚駕竺鐚器宍鐚駈七鐚醐執鐚�?  ?  ?  ?  ?  ?  ?  鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�鐔�?  ?  ?  ?  ��������������������������������������������������������������������������������������������������＜�≪�ｃ�ゃ�ャ����с�������������������������違�宴�蚊�潟�眼�泣�吟�激�吾�鴻�冴�祉�若�純�障�帥�����������������������������������������������������������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��＜�≪�ｃ�ゃ�ャ����с�������������������������違�宴�蚊�潟�眼�泣�吟�激�吾�鴻�冴�祉�若�純�障�帥�����������������������������������������������������������������������������������������������?  �����＜�≪�ｃ�ゃ�ャ����с�������������������������違�宴�蚊�潟�眼�泣��?  ?  ?  ?  ?  ?  ?  ?  �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� 痢 裡 里 離 陸 律 率 立 ?  ?  ?  ?  ?  ?  ?  ?  留 硫 粒 隆 竜 龍 侶 慮 旅 虜 了 亮 僚 両 凌 �� �� �� �� �� �� �� �� �� ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� 弌 丐 丕 个 丱 丶 丼 丿 乂 乖 乘 亂 亅 豫 亊 ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  舒 弍 于 亞 亟 亠 �� 亢 亰 亳 亶 从 仍 仄 仆 ?  仂 仗 �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��������������������������も�癌�錫�������������������ｂ�鰍����獅�������������撃�垂����謂�モ�呉��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����≠�≒�ｂ�も�モ����р�������������������������謂�奄�霞�鰍����≠�≒�ｂ�も�モ����р�����?  ��������≪�������с����吟�������������ｃ�������祉������������������｡?  ?  ?  ?  ?  ?  ?  ?  ���?  ��������������＜�ゃ�ャ����с����宴�蚊�鴻�障�純�錫����≠�������������モ�������垂�汲�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  篋����紲���水��������紮狗�∵�笈��腥������≧献���������薇究����ф�≧�怨��紮���脂４腟∝蕎藪����膕�茴桁��綺究�����罅���������鋌ヤ��篏�箴������峨し紮�紲�絨���������井��罎���榊����亥Щ膓�膩�������茵ｈ�������阪�私��篋ュ����臥��脾�筝�紕掩頃��悟┣������薜������医�遵�≦��紮糸��蕋我繰��よ��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��∫�育����糸���勀����靸処��������薺�腦坂��腆���惹研������罨����薜糸Д�ｩ羌����������篋������画�馿���≦�九�医襲�����恰��羂御崖羇�������腥���頑�沿��荅����羔牙�����薈����茗�莇���我���ｭ���?  �����医��絎翫散����ｩ�吚何羲���������������睡����区�����������藉�紂���惹����ュ�劫ぎ絅ュ��綽���惹�堺┴罨ф�雁��膺�茱�藉�藉�藥�絏≧����糸��絮���区��罅句�＞��篆阪�御��羝�腥���割�����篁�篏�篌巡勝篏喝��������紊鎏�絎九�∞����������倶��羃括�����胼�胼丞┝膊���沿�������決��������茯峨��莢�菴����������篆�絣���������肢�ヨ�処�乗�����蕕�薈�篁�篌�茹ｅ��紂�紕�綮糸辱��������∽�����������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  薛����罌井儀��亥�����腟笈�ヨ�拷�����莢���怨�上����喝�喝�����网�羔�腆����茵�荅臥ｧ薨御規薤������ｆ�粋��������������綮���≧�号�惹�御�紫�牙∈腥�荀�茹�莎�莠������ｉ�����絖�絏恰ソ蕁�蕁����膃�罔�?  罘炊�狗��羹���峨����井��羇紙��羯����茲�莉�筝�薜劫嚱��罔咲��������腴���臥��������藉���∵����援殴���������箙鞘�����絲���������у兄������紮�絎�絎�絲�綛峨更��ｆ����ｆ�丈����∽��罅�罍堺�丈��羆�羲∽��羹���亥����ｇ��腴睡�∞亜膩�膽句唇���������荀活��莢���������������∫�ラ��蕕����筝後��絏後���ｩ�����弱鴬膺�茣�������蕁�蕁�篌�篌���怨�������阪��絳�絲�絏�絽�綛上�������堺����∽��罍�罍�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  罘�絽井��羂�羆順�睡��絖ｇ��膣�緇処�頥�莢頑儀荵�莠�蕋∫��薔寂����遵��絋�絎����������罨榊�����腑�臂���肢�取�井ｬ���������������罅�罘�荅亥�ф�級����翫�∵��������筝�箙�篁�篌������後��綣���ユ��?  ��醇��羆我械��悟��腥句��膃�膣�膤丞畿��х���ｻ絮�綏����������羝����荐沿����御��胼�薛�篋�篋�篋�箴�箴�������腴九�怨�九����≦�水û��紜�絣≦七綵����������������罘�羈������������梧����������潔�♂�翠��薊�篁医��絨����罐�絮���我サ���罅�膕������ゅ��綏冗����ゆ�ｆ�順�雁��胼順��膩���壕��茵粋��茗壕�����������箙���九�ュ�榊�����������荳�薈�薈�薈���傑�������亥�阪�九��������筝我����у��絮�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ���腦�羃���頑宗腦�������膕����膵井�������峨�����荐�臂よ����≦��茴�腑�篆���上������������Û��絅�綵√����究�倶�ф���ｲ��堺�����罅�羝����腮順鎧腟�膓�膵�臀����������荐�荅ｈ��荵初��藏���梧��薇�?  ���������羶����罅����罨�羆堺��腥雁��茵�荐ｆ��篁九�劫����ュ�弱�後�ｅ�у�����絆�綮堺�我�御�恰�我��罔���順��������隋�腟合�����荀�茗�莖∵����ｉ�級�咲��薑�藕後������ｳ綛糸痔羝�羣�����憟����決��茫咲��箙������ゅ�弱�阪��絖ゅ訓綺�綣ф�御�����羚����膤�茴頑�∴�∴佈��茯�莊���潔��蕁ч��篋�篋�篌���������上┓緇�緇≧��罌ф�����腆�茯�茯よ�潔��箙�薇�篋や充箴������������������劫�上����ｅ��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����������√ソ絖�絖�絎鎴ュ熊綏桁晃綺�綺�綺桁���������������ｧ��紙�������贋����≧��罕�羆�羇�羌�羝�羣���牙��隋�腮睡��膣�膣�腟�膓沿����������沿�����������茵�茵∴��莢∵骸�����級�援�翠�守�ら��?  ���薤�蕭�藉糸������垸��紕���傑��莟�莉�藝劫����糸����順����潔��藥����羲���亥��綽醇��薨����莨惹�ら��篁���医�ゅ⊂紿���������������号�掩祁���膣肴��薛�篋�篏�������綉�綏�綏���紙����括��荅����茖����綺ф����球�����������紂�絋糸�医秋����｡��醇�恰����初�����������腑����膣域��茖�莠������ゅ�����臀�莢≦�翫�������堺����翫�峨����主��薹坂����������丈�������窮��膈�膣∫��罅�藪�膃劫��������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  絲���倶��������罧肴��������薇�������藪���炊��筝�������絮掩�������ｆ����������ｇ��膾����莅�莖���檎��������罧�篁�篁�篌坂戎��阪夔兂�ｅ��紕�紮�紮�紮水��絮�絽�絽�綽����������絖������醇�����罩�?  罩紙�����腑�腱�膤悟��膣���∵����活��荅�荅�荅�茯�茫�莖�莖����蕋惹��篋�篌寂�����絖�絲堺��������罨≧��羃紫�丞�順��脾�腓肴����活�����莨�羆�藕水�顑�藉�腴肴燦絎����筝��偌�桁け絆�絎ゆ��羚炊����乗蟹絎����膀���我�頑��絮∴��膰�������絨����莎�������腓丞�����茗�荵���������������阪虻�����主�級����������ュ��綣掩�剛源���絎������掩��������腮����莇ｉ��薤����������絲炊��罔合喬������������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  絎�絨怨��篆������丈寛腱�腱�腟�膵�膺����������茵�茱画��莵頑鹿��演�����������篁�篏�������緇�������羆�羝���ｇ研���������紊�絎炊��腑�膰�膕�紂丞����肴��菴遺��絣紙�ョ��腴ｈ��薈水��緇����罐�罧�羞�?  羣�羹ょ�丞��綏♂�級��������������������羝�綺句��臀我�梧����決�後�����絅喝�鏅������ら�ゅ�桁����������������������怨��絅�絋上┝絎球��絨鎞�絨�綺�綺�綮�綵井�炊����������傑����������倶�丈□罔�罔究下羔�羝�羚���主����х�����隋�腓�腑ョО腴�膃�膕х換������������茵�茖活��荐取��荅活院莖���ら����冗��������筝�筝�筝�箙������医����翫��絳√幻�����丈�≧��羌���句�括�ｈ�梧�臥�檎����怨�顔��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ���罎�罧����膵���決�画Е蕋����莨怨飴篌娯拭箴球��紲�絲�絲�綽���������井��罍�网�羌御訓��括�合��腑�腱�膣活�ｈ�����荀�荐肴昆莨���臥�����篋坂�����紂球��絨����絨処��荐�菴���ｉ��膃ヨ�������√�喝ｨ?  �����劫��絽ユｨ羂雁����∞��膺�茵育�����������������蕭�經�綉���井�∵協���������罎����������茖丈����阪�娯����������������九�√��緇���ф����炊�贋����贋２���罩ｆ����牙�����膕乗��紕域�処タ茯�茯�茫����������������腮������糸賢��������ユ�������括��膠�膰乗��莢�莎よ掘莵�腆��������･������荐�腦�膀�茯����腟区�����篁����������絎ｅ��絨�綏���������井����贋��羌�羇����羹������醇��腥睡��膩�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  膵�臂���肴����壕��荅�莖�莊級�檎�潔��������藪�������羲悟�九��胼�膵���括�����紂�絏��ｪ��丈�醇�����������腓�腑�腱�膕�膣�腟����荐顔�脂�♂����у�球����√�����紕�絅���遵��絮ゅ����ｆ�恰�������炊ｻ?  ��������劫沓罕�罕醇����ヤ�������悟��膤�膩靛���∴����������取�肢��莎育�����������薑���鍽���������笈�����篆���翫����恰��������羝�莇渇��篆�絮�莖���靛����茴���倶��絖�絖�絨����������篁�紊�紊�羆域����上��絋ユ�井�������究�����薈�薑�篏����絲乗��絏怨遣緇���������贋�炊外羯������粋��茴�莢檎��������藥�薇�篁ｅ伾ぇ膃����蕁�薹号����у�����絎����������羃∽侵��∵����御��茫乗�後�ц�後��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ���篏����莨医オ��怨圭腴�莨炊��莪欠�檎��罔処�遺弦�������������｢���罩�羞≧��������腴�膊�膓肢�処�����茯������ｅ��綣丈�����罟�罧窮�決����ょ�ュ�医����ユ�堺����雁��臀���頑�����薤括�����腴合�����?  ���腱�腦���九�∞��筝�篁峨��綽���醇�惹�掩絵���茵決┿�����渇��罔���������ц��莢�筝����������絲球��絽喝��綣�綣球繍緇贋�我����∽��羹������榊�肴�頑�壕�梧�区�粋��莇�莊渇����潔��薐ュ�������贋��羃����莖��ｮ��恰乾紜�罎�罕�菴初��������紂�����ｴ罕私��羲����莨肢��膓顔��罎炊衆���紕桁��膣���������ｉ挟篋�篏������球��莢������ゅ��絽�綺�綺�綮桁�������究�堺��罌�羆�腆�胼�腮�膩����荐�茫�莵����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��檎�����藜�羈ユ����∽�究惨���膃�������羣阪�峨捷��よ��菴������後゛紊�絮�綺�羞紫�����莢取拶蕁���剛��罧炊庄��育�糸�������球��絋�絮�緇�������羝∞�肢��莖������初����ョ�阪��綺����絅贋�����������?  ���������紂�紂�絅�絎�絣九����惹�������掩��罌惹�����羞�羚�羔�������綵����腑欠��膈�膈�膤�腟怨�域�ｈ����よ��茗�莟�荼������������狗��薑育��������������絨���ф��羇���括�ヨ�頑��������絣�藉���水��緇恰����合�ｇ�睡�ゆ�����茯����罘≦�悟��罎翫��薐区��絲���������後丑������羃�莟����������������絅���ｅ��箙�������茗������咲��罐∫Υ膰���桁��罐�荵���ｆ��篋�絨弱��菴����莖������劫賛��ヤ抗���?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  絋�絨翠��篁糸��綽�茯�羶∞Π腑√�ц�援����怨拘綽究�紙�����膕�箙�綮寂�������∽��羶�膣���処�活�粋床荀���ゅ郡������荀���傑晦羇丞�句�翫��臀笈��薤�篆喝�������������������������肴而��������劫��罌�?  罐括�ょ�処卸紕画����������睡Г��ц��篌���ュ�������閿���順��膕���区��菴����羲����膰��ｫ薈�藝���順�援＿膊梧��膈�罠�綛∴�������������∽����咲��蕭�篌�臀井��膈���ラ芥��阪����ら�寂軸��ゅ��������絽���������炊鮎羆�������������膵�������莢�膀����������蕋���醇�������ょ�����������������絋�綺�綵惹�我����号�����罸�羈���牙��腆�腱�膩�臀決�ヨ←茯壕音��翠��蕋�罔�膂後��絨上小���罸���窮��臂�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  藜紙��腮���合��蕭�綵�����偒��綣弱����∝����惹：紮�紵�膣���乗��篆球終罔�羂傑����∝エ茵�荅�莟劫��������腱���������画�����薜����綵����羌����莢ц����紙����銀��篁����紊�紿�絲����絽�綺������倶��?  ��ф��羌���句�����������茘�莢�莖�莎顔�����箴����罩������∴�����絨�罐�蘂���肴��篌����緇�綛����胼���壕��荀�羞球�����羃娯�����藪������糸�翫�恰�ゆ�����絅�膕�膤�膣���井�����筝�篏球�球��綛ｅ抗綣����筝���初�����膠渇����糸�����腆у�ョ�ヨ��膊���鎀����膀�膩�莨肴�����箴水��紲�綣����篆�������������罩����茖�莠�腥����紜����������罸�膂粋����ｄ晋��������怨��絎�絣医劾經�綺���掩�ф�丈�号��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  羈�羈∞�合�牙見�����活��������茲�荐�莟�������蕋初崖薺�箙鋋≦��������絋�絽遵��綽���炊�贋�����罍����膣∴�����茗�莢�莢翠�冗�峨��������������紜���我�雁�х��腥�������羃≧�����綛�絅����膺糸�∞��?  ���脾�薛�藝糸��絋号�ф��罸����罕�綛�������藪���冗��罅�篋�篆ｅ����号��羃�菴�箴�膵�藝推����∽��羲������恰��薛�綏括��絏�絲����羚����腮����絋�膕�羂�������紊∝�∞�������ч機罎�紿水����ュ����醇�����菴潔��薐翫И���羯����罍�膓睡桑��∫査��御─���絋�絖�罸������牙恐��������我��藥������√�翠��絨ゆ�紫云莢医����句��������箙���九����肴�狗��綣ョ�√��綵合�����荐活�������活�����������羃合��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  茫�莠後��篏����������絎ュ構���������������羚ф����句�欠�援��茖�茯���������級�����紊�篋�篏�筝�茯�莠翠�����綛弱��絎劫左����寱�����罐�罕�羇�羣句�����腦�臂����������荀�茗∴����ラ�初����丈��罨�?  羃�羌雁��膺惹��臂���肴８��ヨｱ��守�傑��腟∴�初��箙怨�球��罨�羶�������荀у����鎡ユ��罌���������∵�頯♂����∫�後�����腴���������ュ��羌�羣�������隋�膕����腴�蘊�箴倶��������篋�篋����筝≦��絲����罌�羔主��������腮�膤ц��茫���守����級�����膩����������羞������活��莠���ｉ��藝����紂�羔�膣�蕁�篁や雫箴���桁�怨矯����ｲ腓取����顔�潔�狗��藝�藹∽��罩翫����ｇ��茖�綮�������羲ｇ��膂丞郡���?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����ｉ�����薛�罠����莖�莊���峨�翫��綮�綣����罐惹��羌�羲���∝�主�������乗��������藝�胼������画��������荅掩��莖����������薹俄��篋�薜�荅�������罎�羚丞�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  綣�筝�筝�筝�筝延原筝寂舷箙�箙�箙�篋�篋�莟�篋����綣�篋�篋�篋�篋�篋≫紺篋割唆篁�篁�篁�篁�篁�篁�篁�篁�篁�篁隙��篏�篌遺��篏�篏�篏�篏銀��箴鋐�篏私秋篏遺��篏�箴�箴����篆�篆�篆�篆�篆�篆�篆�篆�篆や織��������������ュ��篌�篆九�≦�����篆鞘侵�����������������������������������後����������翫��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��������喝����������ュ����ｅ����劫�球����������������������≦�阪�桁�弱�糸�水�������������∝�後����������������������������������������ゅ����√����������喝�怨�峨�医�球�遵��������������������?  ��医�球�上�������������у�������喝�劫����������������������翫����喝�水�遵����������怨�����莨�莨у�������弱�球�������������ｅ��蕋������喝�球�後�劫�������後����������������ｅ����怨�喝�後��������筝�������������������紊���糸�桁���������ｦ�･�ｮ�ｰ�ｶ���膂���������主������������寯����遵����������弱����九�������������球�������怨�桁�医����糸����九�������������√�後�ュ�����������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��������ゅ�上�弱����ュ����������遵�������阪�√�劫����ｅ�������������������後�喝�������������������糸�上����������弱����������������������������ゅ�������桁����上�遵����劫����������翫�九�峨��?  �����ゅ����������������������������ュ����九�翫����弱����������������������������劫����水����������������������������������桁�後����糸����������������≦�水����������喝�ゅ����医����������������������ｅ��������紂峨�≦、紂�紂井��紂���遵々紜�紜劫��紜�紜阪��紜糸�後〓紕�紕�紕�紕�紕�紕�紕ュ��紕ゅ��紕�紕阪９紕糸�弱�遵��紊�紊�紊�罌�紊ュが紊�紊峨じ紊丞��絅�絅�絅�絅�絅�絅√��絅уガ絅�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  絅後��絋�篏�箴�絋ｅΣ紮�紮�紮�絋�紮�紮�紲ュ��紲�紲�紲�紲�紿�紿�紿�紲球╋紿√��紵�紵弱�上��絆�紵遵�ｅ��絆�絆�絆�絆阪�糸��絳�絳�絳峨��絳�絳九�上��絖�絖�絖�絖�絖�絖�絖ュ��絖医�喝�球�御��絖阪��?  絎�絎�絎後��絲�絲�絲�絲�絲ゅ��絲√��絲ュ��絲医�九�喝��絨�絨�絨�絨�絨�絨√姶絨後姐絮�絮�絮�絮�絮�絮鎕怨卯絮�箙√蔚絮劫��絏�絏�絋�絏�絏糸俺絏弱卸絣�絏上��絣�絣�絣遵該絣�絛�絣�經�經�經�綉�經�經�經�經�經√��經�經�綉�綉�綉�綉�綉�綉喝偽絛�絛�絛�絛√��絛�絛�絛遵��絛桁脅綏�綏�綏�綏�綏�綏�綏�綏峨卦絽�絽�絽�絽�絽�絽九厳綛�綛�綛�綛�綛�綛�綛�綛√垢綛�綛球攻綛咲瑳綛水��綮�綮�綮�綮�綮�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  綮�綮ｅ��綮�綮�綮√察綮�綮�綮�綮怨山綮医惨綮後讃綣�綣�綵�綵�綣�綣�綣�綣�綣�綣後��綵�綵�綵�綣�綵�綵�綵�綵�綵≦臭綵喝酬緇�緇�綵水��緇�緇�緇�緇�緇�緇�緇�緇�緇�緇弱��綽糸燭綽後娠綽���喝真��≧��?  ��������������掩����������������堺����������傑�������������ｆ����ゆ�������������������ф����������������������ф����≧�御�������翫唇��醇����究�������������倶�傑����贋�堺����≧�紙�掩����������丈����ф����炊�惹����贋�醇�������恰�傑�������������贋����ユ�掩����������究����������������������������������������傑����������堺��臀号�������ｆ�倶�堺�贋�炊�醇�惹�丈��������������������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����≧�������井�我�恰����������ｆ����������惹�������丈�������������������������紙����炊�������������������������������������掩�ф����������究����丈������������������ｫ��倶｣����������ｵ���?  ����ｾ�����������ｆ������嚱�������贋����������倶�������������ф����倶�������������ユ�������惹�������������紙�������掩�ц�������≧����ｆ�������倶�贋�我�堺����醇����������ゆ�ｆ����贋�究�傑�倶�悟�������������������������我�御�����莅������������傑����������������������������≧�掩�我�������紙�恰�究�倶�贋����������������������ゆ�ф�������∽�井�������������������������号����丈��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����御����������炊�������井�究�傑�������������ч�御����炊�倶����御�傑�������������ｆ�ゆ����井����惹�������������≧����傑����贋����恰����御�ゆ�������∽����号�������ф�����罅����罅�罅���我��?  罌恰��罅�罅ｆ〃罅炊��罌閄�罌�罌�罌�罌�罟�罌号ヾ罌究��罌堺�閄�罅丈��罍�罎�罍�罎∽う罍≧��罍�罍�罍ф��罎倶��罎�罍�罍ｆぅ罍号��罍�罎�罎�罎�罎ｆぁ罍�罐号シ罐�罐御カ罐�罐丈ギ罎号ゴ罎醇��罎井ァ罐�罐�网�罐�网我Ξ罕�网炊��罕�网丈��絲�罕�罕�网紙��网ф┏网�网�网�网�网贋��罕�罔�罔�罕炊��罕号Р罕ф��网掩��罕�罔�罕�罔�罔�罠�罔ｆ��罘�罔�罘我╋罘御��罘∽��罘�罘�罔御│罟�罟�罟�罟�罟∽��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  罟����罟紙��罠�罟御�恰��罠�罠�罠�罟�罠�罠�罠紙�����罠堺��罨�薔掩��罨御�欠��罨拷��罩�罩�罩�罩�罩�罩�罩�罩�罩≧�御�号�炊��罧�罧�罧�罧�罧�罧�罧ゆ��罧�罧�罧我�掩�恰�傑�惹��罸�罸�罸�罸�罸�罸恰��?  藝丈��羂�羂�羂�羂ゆ娃羆�羆�羆∽迂羃�羃�羃�羃�羃�羆丈烏羆恰��羃�羈�羈掩��羃醇��羈�羈�羃�羃掩仮羃堺��羈�羈�羈�羇�茵�羇倶勧羇醇憾羇�羇究干羇�羇�羌ｆ��羌ゆ��羌号��羔�羔�羶ゆ��羞号��羝�羔究��羞�羔御��羞�羞�羞�羞�羞�羞�羞堺��羞ゆ��羞�羞�羝�羚�羝�羝�羚我��羝丈牽羚�羝�羚倶��羝�羚�羝堺��羝ゆ賛羝�羝御��羣�羣�羯�羣傑��羣醇痕羯�羣我��羯�羣闒ユ��羣�羹�羲����羯�羯御讃羲炊参羲掩晒羲我��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  羲丈��羯傑��羹堺集羮�羮�羹�羹�羶恰臭羮�羹惹��羮�羮�羶�羹�羮恰升羮≧召羮号��羮�羶�羶�羶�羶�羶�羶掩信羶�������羶榊�������闞丞�����羹雁����������亥�丞�牙����ｇ����������援����悟�括�����������?  ��������順�������ョ����������∝�������������紫����������������合�丞�������������������х�窮�主�合�睡�������������������亥�牙�紫�主�睡�������������雁�丞����������������∝�х�合�牙����������������∝����∞�合�桁�������������������雁�������ョ�丞����騌������������亥�悟�窮�紫�榊���ｳ����ｻ�����ョ�������∝�������ョ夝�牙�榊����睡����������������亥�ｇ����句�丞�������х�����������?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����ｇ�х�������牙�亥�援�悟�欠����������������������������������主�������������������������ょ�х�������悟�句�������雁�������������������ョ�ｇ����括����窮�順�悟�主�援�������������ｇ����丞��?  ��主����亥�榊�牙�括�������������х����∞�∝�ょ�雁�亥�紫����������������∞�∝����������х����亥�牙�句�悟�主����������������������������亥�雁�悟�合�榊����������������∞�ョ�х�������紫�������������ょ����ョ�������欠�悟����������������ョ�睡�丞�合����������������亥�句�合�睡�主�順�紫����������������ｇ����主�����腓����腓�隋�腆�隋雁��隋主��腆�腆ｇ�窮→腆�脾�脾�脾�脾�腆丞⊆脾�脾�脾�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  脾х��脾順４腓�腓�腓�腓�腓�腓�腑�腑�腑�腑�腑�腑�腑�腑榊タ胼�胼�胼ч��胼�胼�胼括�合�榊��腱�腱хК腱∞В腮�腮�腮�腮�腮�腮�胼�腮援┿腮丞┠腥�腥�腥�腥∞�∝��蘊�腥亥�合�順��腦�腦�腦�腦�腦�腴�腦�?  腦句��腴�腦翠��腴�腴�腴�腴霱�腴�腴�腴�腴�腴∞�∝��腴�腴亥��膃霳�膃�膃括��膃�膃�膃窮��膃句��膈榊��膈�膃�膈�膈�膈窮�ョ�雁�х�亥�援��膈�膊�膊�膊�膊�膊�膊�膊�膊�膊靁�膊�膀�膀�膀�膀靃雁��膀�膀�膂�膂�膀�膀ョ��膂�膂�膂�膀括�欠��膂�膀句娃膂х葵膂�膂欠茜膂順��膠�膠�膠靏�膠�膠�膠�膠ょ��膠ョ卯膠窮��膕�膕ょ沖膕∝黄膕∞襖膕括臆膕援荻膕合化膤�膤�膤�膤�膤�膤�膤∫�紫劾膤牙慨膤句該膣�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  膣�膣�膣�膣�腟�腟�膣�膣牙歓膣窮��腟括��腟�腟牙季腟�腟靚ｇ��膓�腟�膓靚順��膓榊峡膓ｇ教膩�膓順叫膰順侠膓�膩�膓悟��膓亥��膩�膩ょ��膩紫群膩∞��膰�膰ｇ検膰�膰援��膰�膰�膰∝��膵�膰紫元膰合��膰�?  膰牙減膵х��膵�膵�膵�膵�膵合巧膵�膵主校膾�膩�膵処小膵睡��膾�膾�膾�膾�膾�膾�膾�膾�膾�膾�膽悟失臀�臀�臀�臀�臀�臀�臀�臀�臀�臀�臀�臀�臀�臀х集臂�臂�臂�臂�臂�臂�臂�臂�臂�臂�臂ｇ少臂牙捷臂�臂句掌茘援��膺�膺�膺�膺�膺∞職膺�膺括森蕋������������������������∴����粋�肢�������������������∵����活�画�域�区�壕�処�粋�������������������������������ヨ����������������������沿�������ｈ�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��������乗�������取�沿����ヨ����頑����������������������よ�ｈ����������域�笈�乗�梧�処�������肴����������������������������ц�肴�肢�乗�������������������������������梧�活��������������������?  ��∵�������������沿�決�梧�乗�������������肢����∴�ｈ�������頑�活�肴�������肢�壕����������������笈�頑����画�沿����壕������������������������ｪ����｢�����ｈ����������取ｵ��活�笈������ｨ�吧���ű���恡������������埈������兓����∵���ｽ��梧���嶒�������取�������決�������������������������壕�笈����∵�壕�粋����������肢����������������∴�∴�粋�頑�������������������取����ｈ�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����������������よ�������������������������������決�乗�������肴����壕����������ヨ����壕����������乗�肴����∵����域�粋��箙���������ц�沿����ｈ�������������区����������域����ｈ��������������?  ��������������������������肢����������壕����頑�粋�決�肢�ヨ�������������梧�������頑����������������ｈ�������∵�������������処����������������活�������肢����画����������乗�区�決����������������∵�∴�沿�区�壕�ц�肢��茵�茵�茵�茵�茵∵゛茴�茵乗��茵笈―茴笈＿茴�茴�茴�茴�茴�茴∵��茴よ�域⊃茴沿��茖�茖�茖�茖�茖�茖壕��茖取４茖�茖画��茲�茲�茲�茱�茲�茲ヨお茲�茱�茱�茲肢ざ茲梧��茲�茱�茱�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  茱�茱よキ茱�茱�茱頑シ茱乗��荀�荀�荀�荀�荀∴Ι荀�荀�荀�荀画�肴�処�粋��茹�茹�茹�茹цТ茹梧��荐�荐�荐�荐�荐�荐ヨ╋荅�荅�荅�荅�荅�荅取��荅�荅∵��茯�茯�茯�茯∴��茯ヨ��茯�茯ｈ��茫�茫�茫�茫�茫活��?  茫よ�沿��茫�茫∵�決��茫�茗�茗�茗�茫∴��茗�茗�茗�茗渇��茗�茗�茗乗��茘�茘�茘顑�茘�茘�茘�茘�茘�茘�茘�茘�茘頑�処��莅�莅�莅�莅�莅�莅�莅�莪肴��莪粋��莟�莟�莟�莟�莟∵卯莟梧浦莢�莢�莢�莢�莢�莢�莢�莟取�����莢�莢�莢処臆莢活荻莢区��莖�莖よ械莖�莖処該莖肢��茣�茣�茣�茣顢�茣�藹�茣�莖�茣�茣�莎ц記莎沿騎莇�莇�莊�莇乗矯莊顦�莊�莊�莊�莊�莊�莊�莊�莊ｈ啓荼�荼�莊粋��荼�荼�荼�莵�荼笈鍵荼頑��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  莵�莵�莵�莵�莵�莵�莵よ��荼�莵ｈ��莵区慌莵取��荳�荳�荳�荳�荳�荳�荳�荳�荳�荳�荳∴根荳域��荳沿詐荵�荵�荵�荵�荵ｈ纂荵肢捌荵乗��莠�莠�莠�莠�莠�莠�莠�莠�莠�莠�莠活嫉莠壕��莉�莠乗��莉�莉�莉�莉�莉�?  莉∵州莉よ��莨�莨ｈ将莨�莨決��菴ヨ植菴�菴����菴顔��菴壕榛��������♂�������������ч�狗�級�壕晋��������������������冗����������������狗����臥����初����������������������演�級�∫�ゆ����������������臥�育����������ｉ�ラ����渇�臥����������∫����������級�顔�咲����������������������♂����守�級�狗����翠�������������������������ら�������翠�������������������������拷�潔�������咲�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  �����∫����ｉ�咲�級�脂�������守������ｰ�ｬ�ｭ����ｹ�����������ラ����������������ら�������������������狗����級�♂�咲����������������∫����������育�級�潔�初����守�冗����翠��������������������?  ��������ч����守�脂�拷�冗��羶狗����������������������♂�ラ�∫�♂����������������������潔����������������臥�������������������ч�演�臥�育�顔�狗�檎�拷�����������茱������������拷����������������������������ら����育�拷�初�冗����������������������ら�������������演�拷����守����咲����������������������ｉ�渇�顔�����������������藹���牙����狗�級�������檎�ら�♂�潔�初��蕁馹�蕁�蕁�蕁�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  蕁演ヾ蕁渇→蘂�蘂演�狗��蕋�蕋�蕋�蕋�蕕�蕕�蕕�蕕�蕕�蕕♂��蕕�蕕ら��蕕�蕕�蕕初ぞ薀�薀�薀�薀�薀�薀�薀�薀�薀�薤�薤�薤ラΝ薤�薤守��薈�薈�薈�薈�薈�薈�薈演Р薈脂Ц薑�薑駔�薈∫��薑�薑潔��薊�薊�薊�?  薑冗��薊�薊�薊�薊�薊∫�ラ�ら��薊�薊�薨�薨育�守��蕭駜�蕭�蕭�蕭�蕭�蕭∫�ｉ��蕭�蕭�蕭�蕭顔�演�潔�脂��薔�薔�薔�薔∫�ｉ�ラ�ч��薔�薔�薔�薔�薔臥��薛�薛駧�薛�薛�薛�薛顔��藪�藪�藪�藪�藪�藪�藪�藪顔��薇�藪拷��薇駫�薇�薇ｉ�∫�ら��薇♂虻薇臥�演�育��薜�薜�薜�薜�薜�薜�薜�薜�薜�薜�薜�薜ラ阿薜♂旭蕷�薜臥��薜冗��蕷�蕷ч蔚蕷檎皆薐�薐育��藉�薐�藉�藉�藉�藉�藏�藉ｉ��薺�藉�藉�薺�藉翠款薺�薺�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  薺�薺�薺ら��薺�薺�薺臥��藏�藏�薺�薺咲��藏ら匡藏臥��薹�藏脂狂藏咲��薹騂�薹�薹�薹檎窪薹�薹�薹初��藐�藐�藕級更藕初��藝�藝�藝�藝�藝�藝�藝�藝ラ懇藝檎昏藝���♂��藥�藥騌�藥�藥�藥�藥�藥�藥ラ雑藥�?  藥顔散藥潔珊藥脂纂藥初��藜���潔��藜♂蒔藜冗��藹�藹�藹ｉ��藹�藹♂拾藹ч習藹�藹潔讐藹狗��蘊�蘊����罕������ゅ�����?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  膾�茲����������篆���紙�掩����号�糸��筝�篁＞纂篌�篌�篌剛��箴�箴�箴�箴�篆������≫真��������医�������翫�������ゅ����上�������������������������ゅ�峨���ｲ���鍜������������水�������ュ��������鍜�?  鍜�紜�紜峨��絅�絅�絅�絅ｅΔ絋阪��絲����絲�絲�絨�絏�絏阪概經у��鍜�綉�綉�絛後狭綏�綣≦軸綵у招綽���������������������我����傑�井���������喁�������������������紙����������ゆ�ユ�����鍜���恰�������我�炊�堺��錣������紙��������罅�罍�鍜�罐�鍜�网�罕∽┛罘�罘�罘恰�丈�∽�ゆ��羂炊��羃�羆�羈�羇�羔�羌�羔�羔�羞闋御群羞惹弦羚�羝ф玄羣炊��羮究慎������������������������������鍜������丞��?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��丞�わ����欠ｽ��������ｇ������喂�������������∝��������������������������鍜���������∞��隋ょ〆腓逸��鍜�鍜�胼�鍜�胼�腴�腴э��腴�膊�鍜�腟�腟�膓欠��膩�膵�臀�臂￥�������∵�粋���嚷����頑�����?  ���鍜���逸��鍜∴��茖笈��荐決�壕�ц�乗��鍜∵�区��茘粋外莖頑��莎駈┌荵�鍜わ┘��ч��鍜������ч����������������ら�ラ����������咲����守����������拷�ч�ч�潔�檎�ч��������鍜ч����������ラ�♂�誌┬�����翠�������育���､�������夣�演��������錻�鍜���������渇�脂��������������蕁�蕁ワ┴鍜�蕕э━薤�薊�蕭�蕭�薛級�臥�駪演�脂��薺育徽鍜�藐�藥�?  ?  ��謂�奄�霞�鰍�癌�汲�金�撃�呉�刻植鐃わ��鐚�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ��謂�奄�霞�鰍�癌�汲�金�撃�呉�高����≠�≒�ｂ�も�モ����р�����鐃�鐃わ��鐚���奄����≠�窮��茲����������篆���紙�掩����号�糸��筝�篁＞纂篌�篌�篌剛��箴�箴�箴�箴�篆������≫真��������医�������翫�����?  ��ゅ����上�������������������������ゅ�峨���ｲ���鍜������������水�������ュ��������鍜�鍜�紜�紜峨��絅�絅�絅�絅ｅΔ絋阪��絲����絲�絲�絨�絏�絏阪概經у��鍜�綉�綉�絛後狭綏�綣≦軸綵у招綽���������������������我����傑�井���������喁�������������������紙����������ゆ�ユ�����鍜���恰�������我�炊�堺��錣������紙��������罅�罍�鍜�罐�鍜�网�罕∽┛罘�罘�罘恰�丈�∽�ゆ��羂炊��羃�羆�羈�羇�羔�羌�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  羔�羔�羞闋御群羞惹弦羚�羝ф玄羣炊��羮究慎������������������������������鍜������丞�援�丞�わ����欠ｽ��������ｇ������喂�������������∝��������������������������鍜���������∞��隋ょ〆腓逸��鍜�?  鍜�胼�鍜�胼�腴�腴э��腴�膊�鍜�腟�腟�膓欠��膩�膵�臀�臂￥�������∵�粋���嚷����頑��������鍜���逸��鍜∴��茖笈��荐決�壕�ц�乗��鍜∵�区��茘粋外莖頑��莎駈┌荵�鍜わ┘��ч��鍜������ч����������������ら�ラ����������咲����守����������拷�ч�ч�潔�檎�ч��������鍜ч����������ラ�♂�誌┬�����翠�������育���､�������夣�演��������錻�鍜���������渇�脂��������������蕁�蕁ワ┴鍜�蕕э━薤�薊�蕭�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  蕭�薛級�臥�駪演�脂��薺育徽鍜�藐�藥�?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽◆鷽□鷽■鷽△鷽▲鷽▽鷽▼鷽※鷽〒鷽→鷽←鷽↑鷽↓鷽〓鷽��鷽�鰯植遠植回植鞄植寄植挙植虞植兼植佼植酷植朔植雌植首植藷植杖植嵩殖�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％殖‰殖ｓ殖ん殖ン殖�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽０鷽１鷽２鷽３鷽４鷽５鷽６鷽７鷽８鷽９鷽�朔殖雌殖�?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   ?   ?   鷽��鷽��鷽��?   ?   鷽��鷽��鷽��?   ?   ?   鷽��鷽��鷽��鷽��?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽ゲ鷽コ鷽ゴ鷽サ鷽ザ鷽シ鷽ジ鷽ス鷽ズ鷽セ鷽ゼ鷽ソ鷽ゾ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽Α鷽Β鷽Γ鷽Δ鷽Ε鷽Ζ鷽Η鷽Θ鷽Ι鷽Κ鷽Λ鷽Μ鷽Ν鷽Ξ鷽Ο鷽Π鷽Ρ鷽Σ鷽Τ鷽Υ鷽Φ鷽Χ鷽Ψ鷽Ω鷽�酷職朔職雌職首職藷職杖職嵩色�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽А鷽Б鷽В鷽Г鷽Д鷽Е鷽Ё鷽Ж鷽З鷽И鷽Й鷽К鷽Л鷽М鷽Н鷽О鷽П鷽Р鷽С鷽Т鷽У鷽Ф鷽Х鷽Ц鷽Ч鷽Ш鷽Щ鷽Ъ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷���?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷��杖��嵩���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌���?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷���?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷��杖��嵩���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷���?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷��杖��嵩���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌���?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン���鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯��遠��回��鞄��寄��挙��虞��兼��佼��酷��朔��雌��首��藷���?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽｡鷽｢鷽｣鷽､鷽･鷽ｦ鷽ｧ鷽ｨ鷽ｩ鷽ｪ鷽ｫ鷽ｬ鷽ｭ鷽ｮ鷽ｯ鷽ｰ鷽ｱ鷽ｲ鷽ｳ鷽ｴ鷽ｵ鷽ｶ鷽ｷ鷽ｸ鷽ｹ鷽ｺ鷽ｻ鷽ｼ鷽ｽ鷽ｾ鷽ｿ鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％��‰��ｓ��ん��ン�ή�ѓ���鷽��鷽Ÿ�ÿ���鷽��鷽��鷽��鷽佬�偭�冎�勩�呏�喭�囜�埰�奆�媠���?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽��?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   鷽��鷽��鷽��?   鷽��?   ?   ?   鷽��鷽��鷽��?   鷽��鷽��鷽��鷽��鷽��?   ?   ?   鷽��鷽�％��‰��ｓ���?   ?   ?   鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��?   ?   ?   ?   鷽�寄���?   ?   ?   ?   ?   ?   鷽�首��藷���?   ?   ?   ?   ?   鷽��鷽��?   ?   鷽��?   ?   ?   鷽��?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽�％尻‰尻ｓ尻ん尻ン尻�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯尻遠尻回尻鞄尻寄尻挙尻虞尻兼尻佼尻酷尻朔尻雌尻首尻藷尻杖尻嵩伸�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�％伸‰伸ｓ伸ん伸ン伸�鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽�鰯伸遠伸回伸鞄伸寄伸挙伸虞伸兼伸佼伸酷伸�?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽亜鷽唖鷽娃鷽阿鷽哀鷽愛鷽挨鷽姶鷽逢鷽葵鷽茜鷽穐鷽悪鷽握鷽渥鷽旭鷽葦鷽芦鷽鯵鷽梓鷽圧鷽斡鷽扱鷽宛鷽姐鷽虻鷽飴鷽絢鷽綾鷽鮎鷽或鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽院鷽陰鷽隠鷽韻鷽吋鷽右鷽宇鷽烏鷽羽鷽迂鷽雨鷽卯鷽鵜鷽窺鷽丑鷽碓鷽臼鷽渦鷽嘘鷽唄鷽欝鷽蔚鷽鰻鷽姥鷽厩鷽浦?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   鷽粥鷽刈鷽苅鷽瓦鷽乾鷽侃鷽冠鷽寒鷽刊鷽勘鷽勧鷽巻鷽喚鷽堪鷽姦鷽完鷽官鷽寛鷽干鷽幹鷽患鷽感鷽慣鷽憾鷽換鷽敢鷽柑鷽桓鷽棺鷽款鷽歓鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽��鷽機鷽帰鷽毅鷽気鷽汽鷽畿鷽祈鷽季鷽稀鷽紀鷽徽鷽規鷽記鷽貴鷽起鷽軌鷽輝鷽飢鷽騎鷽鬼鷽亀鷽偽鷽儀鷽妓鷽宜鷽戯?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?                                                                                                                                   ��������������������? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ����������������? ��  �因汚悔F? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? �据遭�? �蒸著�? ? ? �迄�? ? ��? �劍�? ? ? �恫�? ? ��? �戀�? ? ? ? ? ? ? ? ? ? ? ? ? �揮堅腰遇鋸�? ? �利�? ? ? ? ��? ? ��? ? ? �癢璋����§‡�? ? ? ? �~? ? ? ? ? ��������? �����銹�                                                                                                                                      �髦陌���? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ��? ? ��? ? ? �蝌�? ��? ? ? ? ? ? ��? �踐�? ? ? ��? ? ? ? ��? ? ? ?   ? �w��? ? �程�? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ������?                                                                                                                                                                                                                   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?         ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?                   ��? ? ? a b c d e f g h I j k l m n o p q r s t u v w x y z                                                                                                                                       A B C D E F G H I J K L M N O P Q R S T U V W X Y Z ��������������������������������������������������������������������������  ���������������������������������������������������������������������������������������@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i���k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~����������������������������������                                                                                                                                          ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?                                                                                                 ?       ? ? ? ? �序�?   �G? ?   ��      �葺���  �����C�D?       �攪����I?       ����? ? ? ? ����        ? ?             ? ? ?           ? ?     ?       ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    �����§‡ｘ������������������������因汚怪釜揮鋸遇堅公腰錯侍授序蒸据潜遭鐸著程祷賑曝尾葺崩迄柳利恋��偬劍咢囗奚尨广恫戀攪暘椈樢沽滾燔璋癢磋笘鬻纔胯苻蔕蝌褻譏踐逖銹陂頽髦鴕齪�����������������                                                                                                                                      �@�A�B�C�D�E�F�G�H�I            �P�Q�R    �U�V�W      �[�\�]�^                                      �r�s�t�u�v�w�x�y�z�{�|�}�~  �������������������������������������������������������������������☆¶ｙ������������������������姻甥悔鎌机漁隅嫌功甑桜児樹徐譲杉煎鎗濁貯締等肉漠微蕗庖侭薮吏憐��偸劔咸囮奘尸庠恙戈撕暝棘檐泗漿燎璞癨磔笙糯纖胱苹蔔蝎褶譎踟逋銷陌顆髯鴒齷�����������������                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        ? ? �s�r? ? ? ��? ? ? ? ? ? ��? ? ��? ��? ? ? ? ? ? ? ? ? ��? ��? ? ���暘燔�? ? ? �譏�? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ���ｘ�? ��? ? ? ? ? ? ? ? ? ? ? ? �尾恋�? ? ? �賑葺曝�? �崩�?                                                                                                                                                                                                                                                                                                                                             ? ? ? ? ? ? ? ��? ��? �銹頽陂髯�����? ? �z�{? ? ? ? ? ��������������������? ? ? �|? ? ? ? ? ? ? ? ? ? ? ? ? �����I? ? ? ? ���������������������因汚�? ? ��? ? ? ? ? ? ? ? ��? ? ? ?                                                                                                                                                                                                                                                                                                                                             ? ? ��? ? ? ���磋蔕�? ? ��? ? �������公鋸遇�? ��? ? ? �鐸著授�? ? ����? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ��? ��? �恫戀棘}? ? ? �偬咢�? �囗‡����☆C? ? �F? ? �E? ? ? ��? ����?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ������������������������������������������������������������������陝陟陦陲陬隍隘隕隗險隧隱隲隰隴隶隸隹雎雋雉雍襍雜霍雕雹霄霆霈霓霎霑霏霖霙霤霪霰霹霽霾靄靆靈靂靉靜靠靤靦靨勒靫靱靹鞅靼鞁靺鞆鞋鞏鞐鞜鞨鞦鞣鞳鞴韃韆韈韋韜韭齏韲竟韶韵頏頌頸頤頡頷頽顆顏顋顫                                                                                                                                      �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ������������������������������������������������������������������顱顴顳颪颯颱颶飄飃飆飩飫餃餉餒餔餘餡餝餞餤餠餬餮餽餾饂饉饅饐饋饑饒饌饕馗馘馥馭馮馼駟駛駝駘駑駭駮駱駲駻駸騁騏                                                                                                                                                                                                                  �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ������������������������������������������������������������������髻鬆鬘鬚鬟鬢鬣鬥鬧鬨鬩        魄魃魏魍魎魑魘魴鮓鮃鮑鮖鮗鮟鮠鮨鮴鯀鯊鮹鯆鯏鯑鯒鯣鯢鯤鯔鯡鰺鯲鯱鯰鰕鰔鰉鰓鰌                  鰡鰰鱇鰲鱆鰾鱚鱠鱧鱶鱸鳧鳬鳰鴉鴈鳫鴃鴆鴪鴦鶯鴣鴟鵄鴕鴒鵁鴿鴾                                                                                                                                      �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ������������������������������������������������������������������鵝鵞鵤鵑鵐鵙鵲鶉鶇鶫鵯鵺鶚鶤鶩鶲鷄鷁鶻鶸鶺鷆鷏鷂鷙鷓鷸鷦鷭鷯鷽鸚鸛鸞鹵鹹鹽麁麈麋麌麒麕麑麝麥麩麸麪麭靡黌黎黏黐黔黜點黝黠黥黨黯黴黶黷黹黻黼黽鼇鼈皷鼕鼡鼬鼾齊齒齔齣齟齠齡齦齧齬齪齷齲                                                                                                                                          �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O                                                                                                ��      ��������������  ������  ��      ������  ����������      ��堯槇遙瑤      ����������������        �岐�            �儒諸�          �梯�    ��      ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    鞳鞴韃韆韈��? ���u�v�w�x�y�z�{�|�~������? 靂靤靠靉靦靜? �g隍��隕陲��陬險隗����? 靺鞏��雕隰靱靫����雉雋? 隹隴? ? 霍霓��霆? ? 霎? ? 鞣鞦�n�]�z? 餠? �e�d? �q�p�u顋�A顫�@? �矢�頤頡堯槇? �V�`��                                                                                                                                      ? ? ? ����? ����? 遙                                                                                ? ? ? ? ? ��? ? ? ? ? ? 韲  ? ����? ��? ? �A�B�C�D�E�F�G�H�I�@顆��? 顏駻騁駸? ? ? ? ? ? 頷? ? ? ? ��? ? ? ���C�B? ? ? ? ? ? 鰡                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ? ? ��? ? ? ? ? ? ��? ? �v顴�o? 頷餠�����L飄? ? ��? ? 頽? �]? ? 鞆��鞋霆餤�u�r? �q�p? 霽? ? 颪? ? ? ? 霾靆靄? ? ? ��? ? 韈�W? ? ? ? ? 颱? ? ? �z? ? ? ? 鞏��靫靹��鞐? ��靺隰鞨雕陬��                                                                                                                                                                                                                                                                                                                                            隘險? ? ? ? ? 鞦����? 顋顫�A�@? ����? ? ? ? ? ? ? ? ? �A�B�C�D�E�F�G�H�I�@鱇鰲? ? ? ? �^�W頌頏韶韵? ? ? ? ��槇堯遙? ? ? ? ? �u�v�w�x�y�z�{�|�~�������}? 鰡? ? ? ? ? ? ? ? ? ? ? ? ?                                                                                                                                                                                                                                                                                                                                             ����? �����N�V�n�e�d? �i? ? ? 頸頤頡靦靤靠靂? 靉? ? ? ? 隗隍隕? ��顆? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? �b? ����? 勒靱霖? 霓�I颯? 餡? ? 雎雋? 隹韆鞴鞳韃��? ? ��? ? ? ? ��? 駻? 駸騁饕                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $FM?    ?    ?    ?    ?    ?    $FL?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fk$Fg     $Fh$Fi$Fj$Go?    $Gt?    $E*?    ?    ?    ?    ?    ?    ?    $GP$E9?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G!$G"$EZ?    ?    ?    ?    ?    ?    $Ey$G>$F!$G?$G=$F"?    ?    ?    $Ev?    ?    ?    $Gg$Gd$Ge?    ?    ?    ?    ?    $Ex?    ?    $ED?    $G]?    ?    ?    $G[?    ?    ?    ?    ?    $EL$ET$EV$EU?    $G6$G8?    $G5$G4$G3?    $GY$Eo$GZ$Ep?    ?    ?    $Eu$EA$EC$Em$Er?    $Ew$F(?    $Gj$Gi$Gk$Gh$E]?    ?    ?    ?    ?    ?    $FP$FQ$FO$FN$G0$G1$G2$E1$E<$GB?    $F,$F-                                                                                                                                                                                                                                                                                                                                               $F/$F.?    ?    ?    ?    ?    ?    ?    $G^?    ?    ?    ?    $G&?    ?    ?    ?    ?    ?    ?    $G'$E^?    ?    ?    ?    ?    $E>?    ?    ?    ?    $GT?    $G*$G)?    ?    ?    $G,?    ?    ?    ?    $G($E/$EJ$EI$EG?    ?    $EF$E-?    ?    ?    $Eh?    ?    ?    ?         ?    $E#$E4?    ?    $GV?    $GW?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E3?    ?    ?    ?    ?    ?    $E.?    $EO$G_$Ed?    $E6?    ?    ?    ?    ?    ?    ?    ?    ?    $Ga?    ?    $EE$E2?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gv$Gx$Gy?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E5?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?         ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                        ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                                                 $Fm?    $FF$FGa    b    c    d    e    f    g    h    I    j    k    l    m    n    o    p    q    r    s    t    u    v    w    x    y    z                                                                                                                                                                                                                                                                                                                                                   A    B    C    D    E    F    G    H    I    J    K    L    M    N    O    P    Q    R    S    T    U    V    W    X    Y    Z    ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��        ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   �@   �A   �B   �C   �D   �E   �F   �G   �H   �I   �J   �K   �L   �M   �N   �O   �P   �Q   �R   �S   �T   �U   �V   �W   �X   �Y   �Z   �[   �\   �]   �^   �_   �`   �a   �b   �c   �d   �e   �f   �g   �h   �i   ��   �k   �l   �m   �n   �o   �p   �q   �r   �s   �t   �u   �v   �w   �x   �y   �z   �{   �|   �}   �~   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��                                                                                                                                                                                                                                                                                                                                                            ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                                                                                                                                                                                                                                                    ?                   ?    ?    ?    ?    ?    ?    $Ez     ?    ?    $EB     $En               $Et$Eq$F*     ?    ?    $Gl?    ?                   $FV$FX$FW$FY?                   $F2$GA?    ?    $F)?    ?    $F1                    ?    ?                                  ?    ?    ?                             ?    ?              ?                   ?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $Gj$Gi$Gk$Gh$E]?    ?    $F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj?    $G6$G4$G5$G8$G3?    ?    ?    $G>?    $G??    ?    $Ey$G<$G=$GV$GX$Es$Eu$Em$Et$Ex$Ev$GZ$Eo$En$E`$Gc$Ge$Gd$Gg$E@$E^?    $G\$G]$FV$ED$G^?    ?    ?    $EE?    $F($G($E>?    $E2?    ?    $G)$G*?    $EJ$EK$EF$F,$F.$F-$F/?    ?    $G0$G1$G2$FX$FW?    $G'?    $F*                                                                                                                                                                                                                                                                                                                                               ?    ?    ?    $Gl?    $Gr$Go?    ?    $FY                                                                                                                                                                                                        $E$$E#?    ?    ?    ?    ?    ?    $F5$F6$FI$G_?         ?    $E4$F2?    $F1$F0?    $F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$GB?    $GC?    $Gv$Gy?    $Gx?    ?    ?    $EC?    $G#?    $E/?    $G-?    ?    ?    $E\?    ?    ?    ?    ?    $E(?    ?    ?    $Fm                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                $E!$E"$E#$E$$E%$E&$E'$E($E)$E*$E+$E,$E-$E.$E/$E0$E1$E2$E3$E4$E5$E6$E7$E8$E9$E:$E;$E<$E=$E>$E?$E@$EA$EB$EC$ED$EE$EF$EG$EH$EI$EJ$EK$EL$EM$EN$EO$EP$EQ$ER$ES$ET$EU$EV$EW$EX$EY$EZ$E[$E\$E]$E^$E_$E`$Ea$Eb$Ec$Ed$Ee$Ef$Eg$Eh$Ei$Ej$Ek$El$Em$En$Eo$Ep$Eq$Er$Es$Et$Eu$Ev$Ew$Ex$Ey$Ez                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $F!$F"$F#$F$$F%$F&$F'$F($F)$F*$F+$F,$F-$F.$F/$F0$F1$F2$F3$F4$F5$F6$F7$F8$F9$F:$F;$F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$FF$FG$FH$FI$FJ$FK$FL$FM$FN$FO$FP$FQ$FR$FS$FT$FU$FV$FW$FX$FY$FZ$F[$F\$F]$F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Fl$Fm$Fn$Fo$Fp$Fq$Fr$Fs$Ft$Fu$Fv$Fw$Fx$Fy$Fz                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $G!$G"$G#$G$$G%$G&$G'$G($G)$G*$G+$G,$G-$G.$G/$G0$G1$G2$G3$G4$G5$G6$G7$G8$G9$G:$G;$G<$G=$G>$G?$G@$GA$GB$GC$GD$GE$GF$GG$GH$GI$GJ$GK$GL$GM$GN$GO$GP$GQ$GR$GS$GT$GU$GV$GW$GX$GY$GZ$G[$G\$G]$G^$G_$G`$Ga$Gb$Gc$Gd$Ge$Gf$Gg$Gh$Gi$Gj$Gk$Gl$Gm$Gn$Go$Gp$Gq$Gr$Gs$Gt$Gu$Gv$Gw$Gx$Gy$Gz                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         