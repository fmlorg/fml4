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
#
# $Id$
#

# fml system (executables) directory
EXEC_DIR=/usr/local/fml

# ML's parent directory
ML_DIR=/var/spool/ml

#####
ERROR () {
	echo "cannot chdir $ML_DIR";
	exit 1;
}

#####

chdir $ML_DIR || ERROR

for ml in *
do
	if [ -d "$ML_DIR/$ml" -a -f "$ML_DIR/$ml/config.ph" ]
	then
		$EXEC_DIR/msend.pl $ML_DIR/$ml
	fi
done

exit 0;
