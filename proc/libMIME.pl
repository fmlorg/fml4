# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;

require 'mimer.pl';
require 'mimew.pl';

### debug ###
if ($0 eq __FILE__) { 
    while (<>) { 
	print &MIME'MimeBDecode($_); #';
    }
}


sub DecodeMimeStrings 
{ 
    # 2.1A4 test phase (2.1REL - 2.1A3 requires explicit $MIME_EXT_TEST=1)
    if ($MIME_EXT_TEST) {
	&MIME'MimeDecode(@_);
    }
    else {
	&mimedecode(@_);
    }
}


sub EnvelopeMimeDecode
{ 
    local(*e) = @_;

    if ($MIME_EXT_TEST) {
	$e{'Hdr'}  = &DecodeMimeStrings($e{'Hdr'});
	$e{'Body'} = &DecodeMimeStrings($e{'Body'});
    }
    else {
	$e{'Hdr'}  = &mimedecode($e{'Hdr'});
	$e{'Body'} = &mimedecode($e{'Body'});
    }
}


sub StripMIMESubject
{
    local(*e) = @_;
    local($r)  = 10;	# recursive limit against infinite loop

    &Debug("MIME  INPUT:      [$_]") if $debug;
    ($_ = $e{'h:Subject:'}) || return;
    &Debug("MIME  INPUT GO:   [$_]") if $debug;
    $_ = &mimedecode($_);
    &Debug("MIME  REWRITTEN 0:[$_]") if $debug;

    # 97/03/28 trick based on fml-support:02372 (uematsu@iname.com)
    $_ = &StripBracket($_);
    $e{'h:Subject:'} = &mimeencode("$_\n");
    $e{'h:Subject:'} =~ s/\n$//;

    &Debug("MIME OUTPUT:[$_]") if $debug;
    &Debug("MIME OUTPUT:[". $e{'h:Subject:'}."]") if $debug;
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
    local($_, $out) = @_;

    $MimeBEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';

    $MimeQEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Qq]\?([\011\040-\176]+)=*\?=';


    while (s/($MimeBEncPat)[ \t]*\n?[ \t]+($MimeBEncPat)/$1$3/o) {;}

    s/$MimeBEncPat/&kconv(&mimedecode($1))/geo;
    s/$MimeQEncPat/&kconv(&MimeQDecode($1))/geo;

    s/(\x1b[\$\(][BHJ@])+/$1/g;

    while (s/(\x1b\$[B@][\x21-\x7e]+)\x1b\$[B@]/$1/) { ;}
    while (s/(\x1b\([BHJ][\t\x20-\x7e]+)\x1b\([BHJ]/$1/) { ;}

    s/^([\t\x20-\x7e]*)\x1b\([BHJ]/$1/;

    $_;
}


1;
