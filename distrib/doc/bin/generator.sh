#!/bin/sh

# formatter
FWIX="perl bin/fwix.pl -F -Z fml-bugs@fml.org"
export FWIX


always=0

set -- `getopt da $*`

if test $? != 0; then echo 'Usage: ...'; exit 2; fi

for i
do
	case $i
	in
	-d)
		debug=1;
		shift;;
	-a)
		always=1;
		shift;;

	-v)
		set -x 
		shift;;
	--)
		shift; break;;
	esac
done



FILE=$1
SOURCE_DIR=$2

GEN_HTML () {
	chdir $FML

	if [ doc/$SOURCE_DIR/$FILE.wix -nt var/html/$TARGET/index.html -o $always ]
	then
		test -d var/html/$TARGET || mkdir var/html/$TARGET

		perl .release/bin/fix-wix.pl doc/$SOURCE_DIR/$FILE.wix |\
		$FWIX -L $LANG -T $FILE -m html -D var/html/$TARGET -d doc/smm
	else
	   echo "doc/$SOURCE_DIR/$FILE.wix !-nt var/html/$TARGET/index.html"
	fi

	if [ "X$LINK" != "X" ]
	then
		(chdir var/html;
		   ln -s $TARGET $LINK
		)
	fi
}

LANG=JAPANESE
TARGET=${FILE}
LINK=${FILE}-jp
GEN_HTML;

LANG=ENGLISH
TARGET=${FILE}-e
LINK=${FILE}-en
GEN_HTML;
