TARGETS = y2k-fix/README.html

Y2K_DOC_SOURCE = ../../../doc/advisories/year2000.wix
TARGETS        = y2k-fix/year2000-j.txt y2k-fix/fix-gettime.pl 

.include "../../mk/fml.prog.mk"

package: __init_package ${TARGETS} __make_package

__init_package:
	test -d y2k-fix || mkdir y2k-fix

__make_package: y2k-fix.tar.gz

y2k-fix.tar.gz: ${TARGETS}
	tar cvf y2k-fix.tar y2k-fix
	gzip -9 y2k-fix.tar

y2k-fix/README.html: README.wix
	${FWIX} -n i -m htmlconv -o y2k-fix/README.html README.wix

y2k-fix/fix-gettime.pl: fix-gettime.pl
	cp -p fix-gettime.pl y2k-fix

scan:
	cvs -n update

clean:
	rm -fr y2k-fix y2k-fix.tar.gz


y2k-fix/year2000-j.txt: ${Y2K_DOC_SOURCE}
	${FWIX} -n i -m text ${Y2K_DOC_SOURCE} |nkf -j > y2k-fix/year2000-j.txt
