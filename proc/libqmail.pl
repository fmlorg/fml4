# Copyright (C) 1993-1999,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

use vars qw($debug $debug_qmail);


sub DotQmailExt
{
    local(*e) = @_;
    my ($ext, $key, $keyctl);

    # get ?
    ($ext = $ENV{'EXT'}) || return $NULL;

    &Log("dot-qmail-ext[0]: $ext") if $debug_qmail;

    $key    = (split(/\@/, $MAIL_LIST))[0];
    $keyctl = (split(/\@/, $CONTROL_ADDRESS))[0];

    if ($ext =~ /^($key)$/i) {
	return $NULL;
    }
    elsif ($keyctl && ($ext =~ /^($keyctl)$/i)) {
	return $NULL;
    }

    &Log("dot-qmail-ext: $ext") if $debug_qmail;
    $ext =~ s/^$key//i;
    $ext =~ s/\-\-/\@/i; # since @ cannot be used
    $ext =~ s/\-/ /g;
    $ext =~ s/\@/-/g;
    &Log("\$ext -> $ext");

    # XXX: "# command" is internal represention
    $e{'Body'} = sprintf("# %s", $ext);
}

1;
