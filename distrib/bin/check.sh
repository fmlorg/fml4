buf=/tmp/buf$$
tmp=/tmp/p$$
sed=/tmp/sed$$

CHECK_IGNORE=distrib/etc/check.ignore

trap "rm -f $buf $tmp $sed" 0 1 3 15

echo ""
echo "Ignore Pattern: $FML/.check_ignore";
echo ""

for x in kern/*.pl bin/*pl sbin/*pl sbin/makefml proc/*.p? libexec/*.p? 
do 
	echo "--- $x"
	echo "s#$x ##g" > $sed

	(
	   perl4.036 -cw $x 2>$buf
	   sed -f $sed $buf |\
	   awk -v x=$x '{printf("4 %-20s %s\n", x, $0)}'

	   perl5.003 -cw $x 2>$buf
	   sed -f $sed $buf |\
	   awk -v x=$x '{printf("5 %-20s %s\n", x, $0)}'
	)|\
	egrep -iv -f $FML/.check_ignore | tee -a $tmp

done

echo ""
echo "--- summary (expected) ---"
cp $tmp /tmp/fml.check
sort -n $tmp | egrep -f $CHECK_IGNORE
echo ""
echo "--- summary (unexpected) ---"
echo ""
sort -n $tmp | egrep -v -f $CHECK_IGNORE
echo ""
echo "gmake varcheck IS ALSO USEFUL"




exit 0
