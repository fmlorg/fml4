#!/bin/sh
#
# $Id$
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.


list=/tmp/.fml-install$$

eval umask 022;

trap "rm -f $list" 0 1 2 3 15

DIRS="bin sbin libexec cf etc doc doc/html"
EXEC_DIR=$1
ARCH_DIR="$1/arch"
DOC_DIR="$EXEC_DIR/doc"
DRAFTS_DIR="$EXEC_DIR/drafts"

test -d $EXEC_DIR   || mkdir $EXEC_DIR
test -d $ARCH_DIR   || mkdir $ARCH_DIR
test -d $DOC_DIR    || mkdir $DOC_DIR
test -d $DRAFTS_DIR || mkdir $DRAFTS_DIR

for dir in $DIRS
do
	echo "Installing $dir ..."
	rm -fr $EXEC_DIR/$dir
	find $dir -type f -print |grep -v '\.bak' > $list

	# echo "----"; echo $dir; cat $list; echo "--------";

	tar cf - `cat $list` | (cd $EXEC_DIR; tar xf - )
done

echo "Installing perl scripts (fml-source/src/*.pl) files ..."
chmod -R +w $EXEC_DIR/*

# since rm -fr ...
test -d $DOC_DIR    || mkdir $DOC_DIR
test -d $DRAFTS_DIR || mkdir $DRAFTS_DIR

(cd src; tar cf - *.pl )      | (cd $EXEC_DIR; tar xf - )
(cd src/arch/; tar cf - *.pl) | (cd $ARCH_DIR; tar xf - )
(cd doc/drafts/; tar cf - .)  | (cd $DRAFTS_DIR; tar xf - )

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

	(cd doc;
		rm -f doc/fml_operations_manual
		ln -s op fml_operations_manual

		rm -f "doc/Daemon_Book_of_fml"
		ln -s op "Daemon_Book_of_fml"
	)
)


cp C/fml.c $EXEC_DIR
cp -p sbin/makefml*  $EXEC_DIR

chmod 755 $EXEC_DIR/fml.pl $EXEC_DIR/msend.pl $EXEC_DIR/makefml*
chmod 755 $EXEC_DIR/libexec/* $EXEC_DIR/bin/* $EXEC_DIR/sbin/*

exit 0;
