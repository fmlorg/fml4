#!/bin/sh

### SUBROUTINE
gendoc ()
{

	FORMATTER="perl bin/fwix.pl "

	if [ -f $x ]
	then
		file=`basename $x .wix`

		echo "";
		echo "________________________";
		echo "";
		echo "$x	=>	./$OUT_DIR/$file"

		$FORMATTER -n i < $x > ./$OUT_DIR/$file
		$FORMATTER -L ENGLISH -n i < $x > ./$OUT_DIR/${file}.English
	else
		echo "cannot found $x"
	fi
}


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


#####
echo " "
sh usr/sbin/make-fmllocal.man.sh


#####
echo "Makeing var/doc/op"

(cd var/doc; version.pl)

perl usr/sbin/fix-wix.pl doc/smm/op.wix |\
perl bin/fwix.pl -M tmp/MANIFEST -d doc/smm > var/doc/op

perl usr/sbin/fix-wix.pl doc/smm/op.wix |\
perl bin/fwix.pl -M tmp/MANIFEST -d doc/smm -L ENGLISH > var/doc/op.English

exit 0
