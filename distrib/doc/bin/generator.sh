#!/bin/sh

FILE=$1
SOURCE_DIR=$2

FWIX="perl bin/fwix.pl"

GEN_HTML () {
	chdir $FML

	if [ doc/$SOURCE_DIR/$FILE.wix -nt var/html/$TARGET/index.html ]
	then
		test -d var/html/$TARGET || mkdir var/html/$TARGET

		perl usr/sbin/fix-wix.pl doc/$SOURCE_DIR/$FILE.wix |\
		$FWIX -L $LANG -T $FILE -m html -D var/html/$TARGET -d doc/smm
	fi

}

LANG=JAPANESE
TARGET=${FILE}
GEN_HTML;

LANG=ENGLISH
TARGET=${FILE}-e
GEN_HTML;
