#!/bin/sh

nkf=`which nkf`

tmp="/tmp/fml.buf.$$"
trap "rm -f $tmp" 0 1 3 15

# check
if [ ! -x $nkf ];then
	echo error: cannot find nkf
	exit 1
fi


for x in INDEX *wix */*wix
do
	echo "euc: $x"
	$nkf -e $x > $tmp; mv $tmp $x
done


for x in */*html
do
	echo "jis: $x"
	$nkf -e $x > $tmp; mv $tmp $x 
done
