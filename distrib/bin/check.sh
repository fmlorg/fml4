for x in *.pl bin/*pl sbin/*pl sbin/ccfml sbin/makefml proc/*.p? libexec/*.p? 
do 
	echo "--- $x"
	(
	 perl4.036 -cw $x 2>&1
	 perl5.003 -cw $x 2>&1
	)|\
	egrep -iv 'OK|once|typo'
 done

echo "gmake varcheck IS ALSO USEFUL"
