#!/bin/sh

egrep '^M' __scan__ |while read x y
do
	echo cp $y ../English/$y
done

for x in basic_setup/*.html.en
do
	y=`basename $x .en`
	echo cp $x ../English/basic_setup/$y
done

echo "# $x"

exit 0
