#!/bin/sh

CF=$HOME/.popfmlrc

DIR=$FML/w
USER=elena
SERVER=iris.sapporo.iij.ad.jp
PASSWD=/var/tmp/nt/w/pw
OPT="$FML $FML/proc -d"

exec libexec/popfml.pl $DIR \
	-user $USER -host $SERVER -f $CF -pwfile $PASSWD $OPT

exit 0;
