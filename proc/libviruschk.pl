# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#
# Research by Yoshihiro Kawashima <katino@kyushu.iij.ad.jp>
# helps me to speculate the virus family?
# This idea is based on ZDNet news information.


sub VirusCheck
{
    local(*e) = @_;
    local($ptr) = 0;
    local($i, @id, $guid_pat);

    # M$ GUID pattern ; thanks to hama@sunny.co.jp
    $guid_pat = 
	'\{([0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12})\}';

    if ($e{'Body'} =~ 
	/Content-Transfer-Encoding:\s*(base64|quoted-principle)/i) {
	require 'mimer.pl';
    }

    for ($i = 0; $i < 10 ; $i++)  {
	($xhdr, $xbuf, $ptr) = &GetNextMultipartBlock(*e, $ptr);

	$xbuf =~ s/^[\n\s]+//;
	$xbuf =~ s/[\n\s]+$//;

	last unless $xbuf;

	if ($xhdr =~ 
	    /Content-Transfer-Encoding:\s*base64/i) {
	    $xbuf  = &bodydecode($xbuf, "b64");
	    $xbuf .= &bdeflush;
	}
	elsif ($xhdr =~ 
	    /Content-Transfer-Encoding:\s*quoted-principle/i) {
	    $xbuf  = &bodydecode($xbuf, "qp");
	    $xbuf .= &bdeflush;
	}

	# M$ GUID pattern
	@id = ($xbuf =~ /$guid_pat/g);
	if (@id) {
	    &Log("Microsoft GUID found, this mail may be a virus");
	    for (@id) { &Log("found GUID=$_");}
	    return 'melissa family computer virus';
	}
    }

    return $NULL;
}


sub GetNextMultipartBlock
{
    local(*e, $ptr) = @_;
    local($pb0, $pb1, $pb, $pe, $xbuf);
    
    if ($e{'MIME:boundary'}) {
	$pb  = index($e{'Body'}, $e{'MIME:boundary'}, $ptr);
	$pb0 = $pb;
	$pb  = index($e{'Body'}, "\n\n", $pb);
	$pb1 = $pb;
	$pe  = index($e{'Body'}, $e{'MIME:boundary'}, $pb);

	if ($pb > 0 && $pe > 0) { 
	    $xhdr = substr($e{'Body'}, $pb0, $pb1 - $pb0);
	    $xbuf = substr($e{'Body'}, $pb, $pe - $pb);
	    ($xhdr, $xbuf, $pe)
	}
	else {
	    $NULL;
	}
    }
    else {
	&Log("GetNextMultipartBlock: no MIME boundary definition");
	$NULL;
    }
}


1;
