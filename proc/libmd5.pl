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

use vars qw($debug);
use MD5;

sub main::Md5
{
    my ($data) = @_;
    my ($p, $pe);

    $pe = length($data);

    my $md5 = new MD5;
    $md5->reset();

    $p = 0;
    while (1) {
	last if $p > $pe;
	$_  = substr($data, $p, 128);
	$p += 128;
	$md5->add($_);
    }

    $md5->hexdigest();
}


# XXX: called under perl 5
sub main::MailBodyMD5Cksum
{
    local(*e) = @_;
    my ($p, $pe);

    $pe = length($e{'Body'});

    my $md5 = new MD5;
    $md5->reset();

    $p = 0;
    while (1) {
	last if $p > $pe;
	$_  = substr($e{'Body'}, $p, 128);
	$p += 128;
	$md5->add($_);
    }

    $md5->hexdigest();
}


1;
