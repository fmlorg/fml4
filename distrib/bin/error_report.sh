#!/bin/sh

echo "Possible Error Report ($1):"; 
echo "";

egrep -ni 'no |not | no| not|error' $1 |\
egrep -v "analize_mail_error| Nov |:\+|RCS|:var/html/RELEASE_NOTES.html|:doc/ri/RELEASE_NOTES|:Crosspost|:\(FML=/home/beth/fukachan/w/fml" |\
perl -nle ' s/:/  /; print "   $_\n"'

echo "";

if [ -f /var/tmp/_datelog_ ]
then
	/bin/cat /var/tmp/_datelog_
fi
echo "";

exit 0;
