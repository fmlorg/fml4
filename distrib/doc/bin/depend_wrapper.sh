#!/bin/sh

exit 1

FILE=$1
SOURCE_DIR=$2
TARGET=${FILE}

# temporary Makefile
m=/tmp/_makefile$$

trap "rm -f $m" 0 1 3 15

rm -f $m
echo "DOC_CONV = /bin/sh \$(FML)/distrib/doc/bin/generator.sh" >> $m
echo "var/html/$TARGET/index.html: doc/$SOURCE_DIR/$FILE.wix"        >> $m
echo "	      (FML=$FML; export FML; cd doc/html; \$(DOC_CONV) $FILE $SOURCE_DIR)"  >> $m
cd $FML
${MAKE} -f /tmp/_makefile

exit 0
