# Copyright (C) 1994-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public Licence(see ./COPYING)
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

    # e.g. Subject: [Elena:003] E.. U so ...
    $pat = $SUBJECT_HML_FORM ? "\\[$BRACKET:\\d+\\]" : $SUBJECT_FREE_FORM_REGEXP;
    s/$pat\s*//g;

    #'/gi' is required for RE: Re: re: format are available
    while (s/Re:\s*Re:\s*/Re: /gi && $r-- > 0) { ;}

    $e{'h:Subject:'} = &mimeencode($_);
    &Debug("MIME OUTPUT:[$_]") if $debug;
    &Debug("MIME OUTPUT:[". $e{'h:Subject:'}."]") if $debug;
}


1;
