#!/bin/sh

DIR='/var/spool/ml'

chdir /var/spool/ml/etc

rm -f crosspost.cache

#
# XXX: Config.fml format
#      mladdr directory -ext
#
cat Config.fml | while read a b c
do
	F="$DIR/$b/members"

	if [ "X$c" = "X" ]; then
		# $c null
		file="actives-$b"
	else
		file="actives-$c"
	fi

	if [ -f $F ]
	then
		echo $a
		cp $F $file
		echo "$a $file" >> crosspost.cache

	else
		echo " "
		echo "Not found: [$a] 	$F"
	fi

	chmod 600 actives-*
done

exit 0;
