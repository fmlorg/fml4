#!/bin/sh

cd $FML

mf=/tmp/makefml$$

trap "rm -f $mf" 0 1 3 15

(
	echo var/html/op/index.html: doc/smm/*wix
	echo "	(cd doc/html; make -f Makefile do_op)"
) > $mf

make -f $mf

exit 0;
