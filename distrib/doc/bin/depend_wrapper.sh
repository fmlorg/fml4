#!/bin/sh

FILE=$1
SOURCE_DIR=$2
TARGET=${FILE}
m=/tmp/_makefile

rm -f $m
echo "DOC_CONV = /bin/sh \$(FML)/distrib/doc/bin/generator.sh" >> $m
echo "var/html/$TARGET/index.html: doc/$SOURCE_DIR/$FILE.wix"        >> $m
echo "	      (FML=$FML; export FML; cd doc/html; \$(DOC_CONV) $FILE $SOURCE_DIR)"  >> $m
cd $FML
exec make -f /tmp/_makefile
