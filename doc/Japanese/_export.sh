#!/bin/sh

egrep '^M' __scan__ |while read x y
do
	echo cp $y ../English/$y
done

x=`sort TODO++ |uniq|wc`

echo "# $x"

exit 0
