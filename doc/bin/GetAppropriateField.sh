#!/bin/sh

DIR=$1
i=800

while [ $i -gt 0 ]
do
	(echo "$DIR/$i" 1>&2)

	if [ -f "$DIR/$i" ]
	then
		(echo "Parging $DIR/$i" 1>&2)
		jconv -e "$DIR/$i" |\
		perl doc/bin/GetAppropriateField.pl |\
		perl contrib/MIME/v1.1a/rmime 	>> tmp/rl0609
	fi

	i=`expr $i - 1`
done

exit 0

cd $*

for file in ? ?? ??? ????
#for file in 13[789] 1[4-5]? [2-9]??
do
	jconv -e $file|\
	perl /home/axion/fukachan/work/spool/EXP/bin/GetAppropriateField.pl
done
