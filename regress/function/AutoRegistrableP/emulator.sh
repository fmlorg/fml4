#!/bin/sh
#
# Copyright (C) 1999 Ken'ichi Fukamachi
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

i=0
max=20

while [ $i -le $max ]
do
	echo --- $i ---
	perl emul_config.pl -i $i
	echo $*

	perl emul_config.pl -i $i >> config.ph
	echo '1;' >> config.ph

	eval $*

	sleep 1;

	i=`expr $i + 1`
done

exit 0;
