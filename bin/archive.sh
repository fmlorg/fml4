#!/bin/sh
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.


CONFIG_DIR=`dirname $0`/..
if [ -f $CONFIG_DIR/sbin/showsystem.pl ];then
	eval `$CONFIG_DIR/sbin/showsystem.pl $CONFIG_DIR/.fml/system`
	echo EXEC_DIR=$EXEC_DIR
	echo ML_DIR=$ML_DIR
else
	echo "ERROR: cannot find $CONFIG_DIR/sbin/showsystem.pl"
	exit 1
fi

chdir $ML_DIR || cannot_chdir $ML_DIR

for ml in *
do
   if [ -d "$ML_DIR/$ml" -a -f "$ML_DIR/$ml/config.ph" ]
   then
	(cd $ML_DIR/$ml
	   $EXEC_DIR/bin/archive.pl
	)
   fi
done

exit 0;
