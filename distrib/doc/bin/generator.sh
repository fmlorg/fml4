#!/bin/sh

FILE=$1

chdir $FML

test -d var/html/$FILE || mkdir var/html/$FILE

perl usr/sbin/fix-wix.pl doc/ri/$FILE |\
perl bin/fwix.pl -T $FILE -m html -D var/html/$FILE -d doc/smm -N 

