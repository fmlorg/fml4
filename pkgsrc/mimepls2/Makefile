.include "../../distrib/mk/fml.pkg.mk"

PKGNAME      = mimepls2
DISTNAME     = mime_pls202.tgz
EXTRACT      = yes

.include "../../distrib/mk/fml.pkgsubr.mk"

link: mimer202.pl mimew202.pl

mimer202.pl: work/mimer.pl
	ln work/mimer.pl mimer.pl
	ln work/mimer.pl mimer202.pl

mimew202.pl: work/mimew.pl
	ln work/mimew.pl mimew.pl
	ln work/mimew.pl mimew202.pl
