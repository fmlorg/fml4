#!/bin/sh

exit 1

# formatter
# -Z address
# -S stylesheet
FORMATTER="perl bin/fwix.pl -Z fml-bugs@fml.org"; export FORMATTER


set -- `getopt do:v $*`

if test $? != 0; then echo 'Usage: ...'; exit 2; fi

for i
do
	case $i
	in
	-d)
		debug=1;
		shift;;
	-o)
		OUT_DIR=$2; 
		shift;	shift;;
	-v)
		set -x 
		shift;;
	--)
		shift; break;;
	esac
done


### SUBROUTINE
gendoc ()
{
	if [ -f $x ]
	then
		file=`basename $x .wix`

		echo "";
		echo "________________________";
		echo "";
		echo "$x	=>	$OUT_DIR/$file"

		if [ $x -nt $OUT_DIR/${file}.jp -o ! -e $OUT_DIR/${file}.jp ]
		then
		   test -d $OUT_DIR || mkdirhier $OUT_DIR
		   $FORMATTER -n i < $x > $OUT_DIR/${file}.jp
		   $FORMATTER -L ENGLISH -n i < $x > $OUT_DIR/${file}.en
		fi
	else
		echo "cannot found $x"
	fi
}


MAIN () 
{

	# /var/tmp/.fml/INFO is also a wix format
	for x in doc/ri/*.wix /var/tmp/.fml/INFO
	do
		OUT_DIR=var/doc
		gendoc
	done

	for x in doc/master/*.wix
	do
		OUT_DIR=var/doc/drafts
		gendoc
	done

	### XXX: remove the old code 
	# trap "rm -f /tmp/makefml$$" 0 1 3 15
	# echo "make depend "
	# (
	# 	echo var/doc/op.jp: doc/smm/*wix
	# 	echo "	/bin/sh distrib/bin/DocReconfigure.op"
	# ) > /tmp/makefml$$
	# make -f /tmp/makefml$$
}


if [ $# -gt 0 ]
then
	for x in $*
	do
		gendoc
	done
else
	MAIN
fi

exit 0
