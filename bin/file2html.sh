#!/bin/sh
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

SRC=$1
FILE=$2
DIR=$3

cd $FML

test -d $DIR       || mkdir $DIR
test -d $DIR/$FILE || mkdir $DIR/$FILE

if [ "X" != "X$MASTER" ]
then
	perl usr/sbin/fix-wix.pl $SRC |\
	perl bin/fwix.pl -T $FILE -m html -D $DIR/$FILE -d doc/smm -N 
else
	perl bin/fwix.pl -T $FILE -m html -D $DIR/$FILE -d doc/smm -N < $SRC
fi
