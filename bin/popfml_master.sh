#!/bin/sh
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$

### configuration ###
POP_SERVER=`hostname`
PORT=110
SLEEPTIME=3
OPT=

### LIBS
cannot_chdir () {
	local dir=$1
	echo "cannot chdir $dir";
	exit 1;
}


### MAIN ###

CONFIG_DIR=`dirname $0`/..
if [ -f $CONFIG_DIR/sbin/showsystem.pl ];then
	eval `$CONFIG_DIR/sbin/showsystem.pl $CONFIG_DIR/.fml/system`
	echo EXEC_DIR=$EXEC_DIR
	echo ML_DIR=$ML_DIR
else
	echo "ERROR: cannot find $CONFIG_DIR/sbin/showsystem.pl"
	exit 1
fi

set -- `getopt dhvs: $*`
if test $? != 0; then echo 'Usage: ...'; exit 2; fi
for i
do
	case $i
	in
	-s )
		shift
		SLEEPTIME=$1
		shift;;
	-h )
		echo "$0: [-dvh]";
		shift;;
	-d )
		OPT="$OPT -d "
		shift;;
	-v )
		set -x 
		shift;;
	--)
		shift; break;;
	esac
done

# MAIN IN MAIN
chdir $ML_DIR || cannot_chdir $ML_DIR

# check /var/spool/ml/etc/netrc
if [ ! -f $ML_DIR/etc/netrc ];then
	echo "ERROR: cannot find $ML_DIR/etc/netrc"
	exit 1
fi

# 
for ml in *
do
   if [ "X$ml" = "Xpopfml" -o "X$ml" = "Xetc" -o "X$ml" = "Xfmlserv" ];then
	continue
   fi

   if [ -d "$ML_DIR/$ml" -a -f "$ML_DIR/$ml/config.ph" ]
   then
	$EXEC_DIR/libexec/popfml.pl $ML_DIR/popfml $EXEC_DIR \
		$OPT \
		-user $ml \
		-host $POP_SERVER \
		-pwfile $ML_DIR/etc/netrc \
		-pop_PORT $PORT \
		-include_file $ML_DIR/$ml/include

	sleep $SLEEPTIME

	$EXEC_DIR/libexec/popfml.pl $ML_DIR/popfml $EXEC_DIR \
		$OPT \
		-user ${ml}-ctl \
		-host $POP_SERVER \
		-pwfile $ML_DIR/etc/netrc \
		-pop_PORT $PORT \
		-include_file $ML_DIR/$ml/include-ctl

	sleep $SLEEPTIME
   fi
done

exit 0
