#!/usr/local/bin/perl
#
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

require 'getopts.pl';
&Getopts("dI:");

$libdir = $0; 
$libdir =~ s/base64decode.pl//;
push(@INC, "$libdir/../");

if ($opt_I) {
    for (split(/:/, $opt_I)) { push(@INC, $_);}
}

require 'mimer202.pl';

undef $/;
undef $body;
binmode(STDOUT);

while (sysread(STDIN, $_, 1024)) { 
    print &bodydecode($_);
}


1;
