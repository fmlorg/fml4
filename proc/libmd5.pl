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

# XXX: called under perl 5
sub main::MailBodyMD5Cksum
{
    local(*e) = @_;

    $md5 = new MD5;
    $md5->reset();
    $md5->add($e{'Body'});
    $digest = $md5->digest();
    unpack("H*", $digest);
}


1;
