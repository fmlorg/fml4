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

if (-f $ARGV[0]) {
    require $ARGV[0];
    print "EXEC_DIR=$EXEC_DIR\n";
    print "ML_DIR=$ML_DIR\n";
}
else {
    print STDERR "$0\nERROR: no such file $ARGV[0]\n";
}

exit 0;


