#!/bin/sh

eval umask 022;

DIRS="bin sbin libexec cf etc doc doc/html"
EXEC_DIR=$1
ARCH_DIR="$1/arch"
DOC_DIR="$EXEC_DIR/doc"
DRAFTS_DIR="$DOC_DIR/drafts"

test -d $EXEC_DIR   || mkdir $EXEC_DIR
test -d $ARCH_DIR   || mkdir $ARCH_DIR
test -d $DOC_DIR    || mkdir $DOC_DIR
test -d $DRAFTS_DIR || mkdir $DRAFTS_DIR

for dir in $DIRS
do
	echo "Installing $dir ..."
	rm -fr $EXEC_DIR/$dir
	tar cf - $dir|(cd $EXEC_DIR; tar xf -)
done

echo "Installing perl scripts (*.pl) files ..."
chmod -R +w $EXEC_DIR/*

# since rm -fr ...
test -d $DOC_DIR    || mkdir $DOC_DIR
test -d $DRAFTS_DIR || mkdir $DRAFTS_DIR

cp -p fml.c src/*.pl $EXEC_DIR
cp -p src/arch/*.pl $ARCH_DIR
cp -p help* guide deny objective confirm welcome $DRAFTS_DIR
cp -p sbin/makefml $EXEC_DIR/makefml

chmod 755 $EXEC_DIR/fml.pl $EXEC_DIR/msend.pl $EXEC_DIR/makefml $EXEC_DIR/libexec/fmlserv.pl

exit 0;
