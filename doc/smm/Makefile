tmp = $(HOME)/w/trash/___scanbuffer___

scan:
	@ fvs scan *wix 2>&1|tee $(tmp)
	@ grep '^Modifi' $(tmp) || echo OK
	@ rm -f $(tmp)

check: fix-files 

fix-rcsid:
	@ sh .list

fix-files:
	@ sh .fix_files

all:

clean:
	gar *~ *.bak

wc:
	@ echo *wix|tr ' ' '\012'| wc -l > /tmp/.wc0
	@ wc  `egrep '^[a-z]' CHECKLIST `|grep -v total|wc -l  > /tmp/.wc1
	@ wc  `egrep '^[a-z]' CHECKLIST `|sort -n 
	@ echo ""; echo -n "	left files: "
	@ echo -n `cat /tmp/.wc1`; echo -n " / "; echo `cat /tmp/.wc0`
	@ wc -l *wix |tail -1 > /tmp/.wc0
	@ wc -l `egrep '^[a-z]' CHECKLIST ` |tail -1 > /tmp/.wc1
	@ echo ""; echo -n "	left lines: "
	@ echo -n `cat /tmp/.wc1`; echo -n " / "; echo `cat /tmp/.wc0`
