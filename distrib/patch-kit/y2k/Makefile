TARGETS = compile/README.html


.include "../../mk/fml.prog.mk"

package: __init_package compile/README.html compile/fix-gettime.pl

__init_package:
	test -d compile || mkdir compile

compile/README.html: README.wix
	${FWIX} -n i -m htmlconv -o compile/README.html README.wix

compile/fix-gettime.pl: fix-gettime.pl
	cp -p fix-gettime.pl compile

scan:
	cvs -n update

clean:
	rm -fr compile
