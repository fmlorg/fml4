#!/bin/sh
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$

# set -- `getopt d:h:v $*`
# if test $? != 0; then echo 'Usage: ...'; exit 2; fi
# for i
# do
# 	case $i
# 	in
# 	-d)
# 		DIR=$2; 
# 		shift;	shift;;
# 	-h)
# 		HOST=$2; 
# 		shift;	shift;;
# 	-v)
# 		set -x 
# 		shift;;
# 	--)
# 		shift; break;;
# 	esac
# done

list=/tmp/list$$
x=/tmp/xbuf$$
y=/tmp/ybuf$$

if [ ! -d ./Japanese ];then
	echo ./Japanese does not exist
	exit 1;
fi

trap "rm -f $x $y $list" 0 1 3 15

echo echo [JGa-z]* | tr ' ' '\012' |\
perl -nle 'print if -d $_' > $list

awk '{print $1}' INDEX | egrep '^[a-zJ]+' > $x

echo "----------------------------";
echo "$list  directory list";
echo "$x  INDEX list";

echo ""; echo "----------------------------";
echo "% egrep -v -f $list $x"
egrep -v -f $list $x |\
egrep -v 'obsolete|template'

echo ""; echo "----------------------------";
echo "% egrep -v -f $x $list"
egrep -v -f $x $list |\
egrep -v 'obsolete|template'

exit 0
