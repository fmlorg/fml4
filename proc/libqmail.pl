# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

sub DotQmailExt
{
    local(*e) = @_;
    local($ext, $key, $keyctl);

    # get ?
    ($ext = $ENV{'EXT'}) || return $NULL;

    &Log("dot-qmail-ext[0]: $ext") if $debug_qmail;

    $key    = (split(/\@/, $MAIL_LIST))[0];
    $keyctl = (split(/\@/, $CONTROL_ADDRESS))[0];

    if ($ext =~ /^($key)$/i) {
	return $NULL;
    }
    elsif ($keyctl&& ($ext =~ /^($keyctl)$/i)) {
	return $NULL;
    }

    &Log("dot-qmail-ext: $ext") if $debug_qmail;
    $ext =~ s/^$key//i;
    $ext =~ s/\-/ /g;    
    $e{'Body'} = sprintf("# %s", $ext);
}

1;
