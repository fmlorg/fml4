#!/bin/sh
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
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
