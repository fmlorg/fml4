.include "../../distrib/mk/fml.pkg.mk"

PKGNAME      = mimepls2
DISTNAME     = mime_pls-2.00alpha.tar.gz
EXTRACT      = yes

.include "../../distrib/mk/fml.pkgsubr.mk"

link: mimer20alpha.pl mimew20alpha.pl

mimer20alpha.pl: work/mimer.pl
	ln work/mimer.pl mimer20alpha.pl

mimew20alpha.pl: work/mimew.pl
	ln work/mimew.pl mimew20alpha.pl
