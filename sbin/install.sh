#!/bin/sh
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

#####   functions   #####
MOVE () {
	suffix=new$$	

	# echo "cp -p $src $dst.$suffix"
	cp -p $src $dst.$suffix

	if [ -x $src ] 
	then
		chmod 755 $dst.$suffix
	fi

	# echo "mv -f $dst.$suffix $dst"
	mv -f $dst.$suffix $dst
}
#########################

##### variables
list=/tmp/.fml-install$$

eval umask 022;

DIRS="bin sbin libexec cf etc sys src drafts messages doc"
CHDIRS="bin sbin libexec"
EXEC_DIR=$1
SYS_DIR="$1/sys"
DOC_DIR="$EXEC_DIR/doc"
DRAFTS_DIR="$EXEC_DIR/drafts"

trap "rm -f $list" 0 1 3 15

##### MAIN #####

test -d $EXEC_DIR   || mkdir $EXEC_DIR
test -d $SYS_DIR    || mkdir $SYS_DIR
test -d $DOC_DIR    || mkdir $DOC_DIR
test -d $DRAFTS_DIR || mkdir $DRAFTS_DIR


### chmod ###

for dir in $CHDIRS
do
	chmod 755 $dir/*
done

chmod 755 src/fml.pl src/msend.pl makefml


### here we go! ###
for dir in $DIRS
do
	echo "Installing $dir ..."

	# making directories
	find $dir -type d -print|while read x
	do  
		# "src" is an exceptional!!!
		if [ X$x != Xsrc ]
		then
		   test -d $EXEC_DIR/$x || mkdir $EXEC_DIR/$x
		fi
	done

	# check files to install
	find $dir -type f -print |\
	sed -e "s%^$dir/%%" |grep -v '\.bak' > $list


	cat $list | while read x
	do
	   src=$dir/$x
	   dst=$EXEC_DIR/$dir/$x

	   # "src" is an exceptional!!!
	   if [ X$dir = Xsrc ]
	   then
		dst=$EXEC_DIR/$x
	   else
	   	test -d $EXEC_DIR/$dir || mkdir $EXEC_DIR/$dir
	   fi

	   MOVE
	done
done

chmod -R +w $EXEC_DIR/*

cp C/fml.c $EXEC_DIR
cp -p sbin/makefml*  $EXEC_DIR

chmod 755 $EXEC_DIR/fml.pl $EXEC_DIR/msend.pl $EXEC_DIR/makefml*
chmod 755 $EXEC_DIR/libexec/* $EXEC_DIR/bin/* $EXEC_DIR/sbin/*


(
	cd $EXEC_DIR;

	# link doc/drafts ?
	# (chdir doc/; ln -s ../drafts .)

	rm -f libexec/listserv_compat.pl
	ln libexec/fmlserv.pl libexec/listserv_compat.pl

	rm -f libexec/majordomo_compat.pl
	ln libexec/fmlserv.pl libexec/majordomo_compat.pl

	rm -f libexec/fml_local2.pl
	ln libexec/fml_local.pl libexec/fml_local2.pl

	rm -f bin/fml_local.pl
	ln libexec/fml_local.pl bin/fml_local.pl

	rm -f bin/pop2recv.pl
	ln libexec/popfml.pl bin/pop2recv.pl

	rm -f bin/localtest.pl
	ln sbin/localtest.pl bin/localtest.pl

	rm -f bin/inc_via_pop.pl
	ln bin/pop2recv.pl bin/inc_via_pop.pl
)


exit 0;
