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

set -- `getopt m: $*`

if test $? != 0; then echo 'Usage: ...'; exit 2; fi

for i
do
	case $i
	in
	-m)
		m=$2; 
		shift;	shift;;
	--)
		shift; break;;
	esac
done

for x in $*
do
	r=`usr/sbin/get-rcsid.pl -ci $x`;

	echo "$x $r"
	echo "ci -l$r -m\"$m\" $x"
	ci -l$r -m"$m" $x
	chmod 755 $x
done

exit 0
