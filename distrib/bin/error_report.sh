#!/bin/sh

echo "Possible Error Report ($1):"; 
echo "";

egrep -ni 'stop|no |not | no| not|error' $1 |\
egrep -v -f distrib/etc/log.ignore |\
perl -nle ' s/:/  /; print "   $_\n"'

echo "";

if [ -f /var/tmp/_datelog_ ]
then
	/bin/cat /var/tmp/_datelog_
fi
echo "";

exit 0;
