#!/usr/local/bin/perl
#
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


####### Section: TRAP
### Hmm, I call this section locore but .. :-)
sub Trap__ChaddrConfirm
{
    local(*e) = @_;

    &Log("Trap__ChaddrConfirm");

    if ($CHADDR_AUTH_TYPE ne 'confirmation') {
	&Log("Trap__ChaddrConfirm: invalid trap");
	&Log("\$CHADDR_AUTH_TYPE != confirmation");
	return $NULL;
    }

    &Log("chaddr-confirm request") if $debug;
    &use('confirm');
    &FML_SYS_ChaddrConfirm(*e, $e{'buf:req:chaddr-confirm'});
}

sub Trap__ChaddrRequest
{
    local(*e) = @_;

    &Log("Trap__ChaddrRequest");

    if ($CHADDR_AUTH_TYPE ne 'confirmation') {
	&Log("Trap__ChaddrConfirm: invalid trap");
	&Log("\$CHADDR_AUTH_TYPE != confirmation");
	return $NULL;
    }

    &Log("chaddr request") if $debug;
    &use('confirm');
    &FML_SYS_ChaddrRequest(*e, $e{'buf:req:chaddr'});
}


1;
