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

local($WinSiz);

sub VirusCheck
{
    local(*e) = @_;
    local($i, $guid_pat);
    local($pb, $hpe, $pe, $xr, $gpe);

    # M$ GUID pattern ; thanks to hama@sunny.co.jp
    $WinSiz = 1024; # at lease 32*2
    $guid_pat = 
	'\{([0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12})\}';

    $gpe = index($e{'Body'}, $e{'MIME:boundary'}.'--', 0);
    for ($pb = $pe = $i = 0; $i < 16; $i++)  {
	($pb, $hpe, $pe) = &GetNextMPBPtr(*e, $pb + 1);
	last if $pb < 0;
	last if $pb >= $gpe;

	$xhdr = substr($e{'Body'}, $pb, $hpe - $pb);
	if ($xhdr =~ /Content-Transfer-Encoding:\s*base64/i) {
	    $enc = 'b64';
	}
	elsif ($xhdr =~ /Content-Transfer-Encoding:\s*quoted-principle/i) {
	    $enc = 'qp';
	}
	else {
	    undef $enc;
	}

	$xr = &ProbeSlidingWindow(*e, $enc, $guid_pat, $hpe + 2, $pe);
	return $xr if $xr;
    }

    $NULL;
}


sub ProbeSlidingWindow
{
    local(*e, $enc, $pat, $pb, $pe) = @_;
    local($buf, $pbuf, $xbuf, $found, @id);

    require 'mimer.pl';

  loop:
    while (1) {
	last loop if $pb >= $pe;

	# get $WinSiz bytes window and decode it
	$buf = substr($e{'Body'}, $pb, 
		      ($pe - $pb) > $WinSiz ? $WinSiz : ($pe - $pb));

	$pb  += $WinSiz;
	$buf  = &bodydecode($buf, $enc);

	# check current window
	if ($buf =~ /($pat)/) { push(@id, $1); $found++;}

	# check previous + current window (1024 bytes)
	$xbuf = $pbuf . $buf;
	if ($xbuf =~ /($pat)/) { push(@id, $1); $found++;}

	# save current as the prev window for the next loop use
	$pbuf = $buf;
    }

    if ($found) {
	&Log("Microsoft GUID found, this mail may be a virus");
	for (@id) { &Log("found GUID=$_");}

	return 'melissa family computer virus';
    }
    else {
	$NULL;
    }
}


1;
