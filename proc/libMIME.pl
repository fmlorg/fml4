# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
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
    $_ = &mimedecode($_);

    # e.g. Subject: [Elena:003] E.. U so ...
    s/\[$BRACKET:\d+\]\s*//g;

    #'/gi' is required for RE: Re: re: format are available
    while (s/Re:\s*Re:\s*/Re: /gi && $r-- > 0) { ;}

    $e{'h:Subject:'} = &mimeencode($_);
}


1;
