#!/bin/sh
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

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
