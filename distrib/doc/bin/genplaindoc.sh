#!/bin/sh

perl doc/ri/conv-install.pl < doc/ri/INSTALL.wix > doc/smm/install-new.wix 

# /var/tmp/.fml/INFO is also a wix format
for x in doc/ri/*.wix /var/tmp/.fml/INFO
do
	if [ -f $x ]
	then
		file=`basename $x .wix`
		echo "$x	=>	./var/doc/$file"
		cat $x | perl bin/fwix.pl -n i > ./var/doc/$file
		cat $x | perl bin/fwix.pl -L ENGLISH -n i > ./var/doc/${file}.English
	else
		echo "cannot found $x"
	fi
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
