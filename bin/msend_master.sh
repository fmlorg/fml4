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

### LIBS
cannot_chdir () {
	local dir=$1
	echo "cannot chdir $dir";
	exit 1;
}

### MAIN ###

CONFIG_DIR=`dirname $0`
CONFIG_DIR="$CONFIG_DIR/../.fml"

if [ -f $CONFIG_DIR/system.sh ];then
	. $CONFIG_DIR/system.sh
else
	echo "ERROR: cannot find $CONFIG_DIR/system.sh"
	exit 1
fi

while [ $# -gt 0 ]
do
    case $1 in
    -E )
	shift
	EXEC_DIR=$1
	;;
    -M )
	shift
	ML_DIR=$1
	;;
    -v )
	set -vx
	;;
     * )
	echo $1 "is not matched option"
	exit 2
    esac
    shift
done


##### MAIN

# 
# renice +18 $$ >/dev/null 2>&1
#

chdir $ML_DIR || cannot_chdir $ML_DIR

for ml in *
do
	if [ -d "$ML_DIR/$ml" -a -f "$ML_DIR/$ml/config.ph" ]
	then
		$EXEC_DIR/msend.pl $ML_DIR/$ml
	fi

	sleep 3
done

exit 0;
