# Copyright (C) 1993-1998,2000,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2000,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

use vars qw($debug 
	    $MIME_BROKEN_ENCODING_FIXUP);

require 'mimer.pl';


################################################################
#
# wrapper functions for fml internal use
#
sub EnvelopeMimeDecode
{ 
    local(*e) = @_;

    # XXX malloc() too much?
    $e{'Hdr'}  = &DecodeMimeStrings($e{'Hdr'});
    $e{'Body'} = &DecodeMimeStrings($e{'Body'});
}


sub StripMIMESubject
{
    local(*e) = @_;

    &Debug("MIME  INPUT:      [$_]") if $debug;
    ($_ = $e{'h:Subject:'}) || return;
    &Debug("MIME  INPUT GO:   [$_]") if $debug;
    $_ = &MIMEDecode($_);
    &Debug("MIME  REWRITTEN 0:[$_]") if $debug;

    # 97/03/28 trick based on fml-support:02372 (uematsu@iname.com)
    $_ = &StripBracket($_);
    $e{'h:Subject:'} = &mimeencode("$_\n");
    $e{'h:Subject:'} =~ s/\n$//;

    &Debug("MIME OUTPUT:[$_]") if $debug;
    &Debug("MIME OUTPUT:[". $e{'h:Subject:'}."]") if $debug;
}



################################################################
#
# MIME ENCODING
#

# XXX YOU SNOHLD NOT USE THESE FUNCTIONS IN fml main libraries
# XXX defined just for convenience e.g. for old HOOKS
sub MimeEncode { &mimeencode(@_); }
sub MIMEEncode { &mimeencode(@_); }

sub mimeencode
{
    my ($s) = @_;

    my $pkg = 'IM::Iso2022jp';
    eval qq{ require $pkg; $pkg->import();};
    unless ($@) {
	line_iso2022jp_mimefy($s);
    }
    else {
	Log("mimeencode cannot load $pkg, fallback to mimew.pl");
	Log($@);

	# XXX CAUTION: mimew.pl overload main::mimeencode(), so
	# XXX          this block is called once before overloading.
	require 'mimew.pl';
	mimeencode($s);
    }    
}


################################################################
#
# MIME DECODING
#

# XXX YOU SNOHLD NOT USE THESE FUNCTIONS IN fml main libraries
# XXX defined just for convenience e.g. for old HOOKS
sub MimeDecode        { &DecodeMimeString(@_); }
sub MIMEDecode        { &DecodeMimeString(@_); }
sub DecodeMimeStrings { &DecodeMimeString(@_); }

sub DecodeMimeString
{ 
    # 2.1A4 test phase (2.1REL - 2.1A3 requires explicit $MIME_EXT_TEST=1)
    &MIME::MimeDecode(@_);
}


###
### import fml-support: 02651 (hirono@torii.nuie.nagoya-u.ac.jp)
### import fml-support: 03440, Masaaki Hirono <hirono@highway.or.jp>
package MIME;

sub MimeQDecode
{
    local($_) = @_;
    s/=*$//;
    s/=(..)/pack("H2", $1)/ge;
    $_;
}


sub MimeDecode 
{
    local($_) = @_;

    my $MimeBEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';

    my $MimeQEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Qq]\?([\011\040-\176]+)=*\?=';


    while (s/($MimeBEncPat)[ \t]*\n?[ \t]+($MimeBEncPat)/$1$3/o) {;}

    # XXX: 1.11a
    # s/$MimeBEncPat/&kconv(&mimedecode($1))/geo;
    # XXX: 2.02
    s/$MimeBEncPat/&kconv(&base64decode($1))/geo;
    s/$MimeQEncPat/&kconv(&MimeQDecode($1))/geo;

    if ($main::MIME_BROKEN_ENCODING_FIXUP) {
	s/\0//g;
	s/$/\x1b(B/;
    }

    s/(\x1b[\$\(][BHJ@])+/$1/g;

    while (s/(\x1b\$[B@][\x21-\x7e]+)\x1b\$[B@]/$1/) { ;}
    while (s/(\x1b\([BHJ][\t\x20-\x7e]+)\x1b\([BHJ]/$1/) { ;}

    s/^([\t\x20-\x7e]*)\x1b\([BHJ]/$1/;

    $_;
}


package main;

# for debug
if ($0 eq __FILE__) {
    eval q{ sub Log { print STDERR "LOG>", $_, "\n";} };
    while (<>) {
	my ($x) = $_;
	chop $x;

	print "    IN> ", $x, "\n";

	$x = &MimeEncode($x);
	print "encode> ", $x, "\n";

	$x = &MimeDecode($x);
	print "decode> ", $x, "\n";
    }
}

1;
