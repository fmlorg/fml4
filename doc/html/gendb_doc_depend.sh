#!/bin/sh

cd $FML

mf=/tmp/makefml$$

trap "rm -f $mf" 0 1 3 15

(
	echo /usr/local/SSE/db/fml-j.inv.new: doc/ri*/wix doc/smm/*wix
	echo "	(cd $(FML); make search)"
) > $mf

make -f $mf

exit 0;
