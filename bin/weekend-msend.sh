#!/bin/sh
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;

# perl
PERL=perl

# fml execution and library files directory (location of fml.pl, libsmtp.pl)
FML=$PWD

# maling list directory
DIR=$PWD

# weekend digest delivery special directory and configuration files
MSEND_RC=$DIR/weekend/msendrc
ACTIVE_LIST=$DIR/weekend/actives
MEMBER_LIST=$DIR/weekend/members

chdir $DIR || cannot chdir $DIR

$PERL $FML/msend.pl $DIR \
--MSEND_RC=$MSEND_RC --MEMBER_LIST=$MEMBER_LIST --ACTIVE_LIST=$ACTIVE_LIST

exit 0;
