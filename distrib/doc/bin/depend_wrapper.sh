#!/bin/sh

FILE=$1
SOURCE_DIR=$2
TARGET=${FILE}
m=/tmp/_makefile

rm -f $m
echo "var/html/$TARGET/index.html: doc/$SOURCE_DIR/$FILE.wix">>$m
echo "	      (FML=$FML; export FML; cd doc/html; sh Converter.sh $FILE $SOURCE_DIR)">>$m
cd $FML
exec make -f /tmp/_makefile
