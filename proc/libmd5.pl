# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$


use MD5;

sub Md5
{
    local($data) = @_;

    $md5 = new MD5;
    $md5->reset();
    $md5->add($data);
    $digest = $md5->digest();
    unpack("H*", $digest);
}


1;
