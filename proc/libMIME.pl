# Copyright (C) 1994-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# q$Id$;

require 'mimer.pl';
require 'mimew.pl';
sub DecodeMimeStrings { &mimedecode(@_);}

sub EnvelopeMimeDecode
{ 
    local(*e) = @_;

    $e{'Hdr'}  = &mimedecode($e{'Hdr'});
    $e{'Body'} = &mimedecode($e{'Body'});
}


sub StripMIMESubject
{
    local(*e) = @_;
    local($r)  = 10;	# recursive limit against infinite loop

    ($_ = $e{'h:Subject:'}) || return;
    &Debug("MIME  INPUT:[$_]") if $debug;
    $_ = &mimedecode($_);
    &Debug("MIME  INPUT:[$_]") if $debug;

    $_ = &StripBracket($_);
    $e{'h:Subject:'} = &mimeencode($_);

    &Debug("MIME OUTPUT:[$_]") if $debug;
    &Debug("MIME OUTPUT:[". $e{'h:Subject:'}."]") if $debug;
}


1;
