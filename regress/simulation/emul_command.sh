#!/bin/sh
#
# $FML$
#

buf=/var/tmp/buf$$
trap "rm -f $buf" 0 1 3 15

ml_home_dir=/var/spool/ml/elena

cd $ml_home_dir || exit 1

if [ -d emul ];then
	cat > $buf
	cat $buf | sh emul/bin/command
	sh `dirname $0`/check.sh
else
	echo "error: set up ./emul at $ml_home_dir"
fi

exit 0
