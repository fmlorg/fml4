# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
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


1;
