#!/bin/sh
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$


GETOPT () {
   set -- `getopt c:dv $*`
   if test $? != 0; then echo 'Usage: ...'; exit 2; fi
   for i
   do
   	case $i
   	in
   	-c)
   		command=$2; 
   		shift;	shift;;
   	-v | -d)
   		set -x 
   		shift;;
   	--)
   		shift; break;;
   	esac
   done
}


DIFF () {
	echo ""
	diff -u actives.bak actives
	echo ""
	diff -u members.bak members
	echo ""
}


RESET () {
	echo fukachan@sapporo.iij.ad.jp > actives
	echo fukachan@sapporo.iij.ad.jp > members
	echo fukachan@sapporo.iij.ad.jp > actives.bak
	echo fukachan@sapporo.iij.ad.jp > members.bak
}


INIT () {
   cd /var/spool/ml/elena || exit 1
   echo "create/reset elena ML"
   makefml -F newml elena >/dev/null 2>&1

   # default is "bye" test
   command=bye
}


### MAIN ###

INIT

GETOPT $*

for x in reject auto_subscribe auto_asymmetirc_regist auto_regist
do
   sed -e "s/^REJECT_COMMAND_HANDLER.*/REJECT_COMMAND_HANDLER $x/" cf >cf.new
   mv cf.new cf
   sleep 3
   touch cf
   make -n config.ph |sh

   printf "\n\n\n";
   echo ============================================================

   echo ''
   echo '   configuration'
   grep HANDLER config.ph | grep -v '^#' | perl -nple 's/^/   /;'
   echo ''

   RESET

   makefml $command elena fukachan@sapporo.iij.ad.jp >/dev/null
   DIFF
done

exit 0
