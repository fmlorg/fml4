#!/bin/sh

file=$1
title=$2

out=`basename $file .wix`

(
	echo "<TITLE>$title</TITLE>"
	echo 
	echo "<PRE>"
	nkf -j $FML/doc/ri/$file.wix
	echo "</PRE>"

) > $FML/var/html/$out/index.html

exit 0;
