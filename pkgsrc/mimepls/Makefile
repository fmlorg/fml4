.include "../../distrib/mk/fml.pkg.mk"

PKGNAME      = mimepls
DISTNAME     = mime_pls-1.11a.tar.gz
EXTRACT      = yes

.include "../../distrib/mk/fml.pkgsubr.mk"

link: mimer.pl mimew.pl

mimer.pl: work/mimer.pl
	rm -f mimer.pl
	ln work/mimer.pl mimer.pl

mimew.pl: work/mimew.pl
	rm -f mimew.pl
	ln work/mimew.pl mimew.pl

