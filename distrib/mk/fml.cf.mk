# $Id$

MANIFEST2INDEX = ${PERL} ./distrib/bin/manifest2index.pl

var/html/variable-list.ja.html: cf/MANIFEST.Japanese
	$(ECONV) cf/MANIFEST.Japanese |\
	$(MANIFEST2INDEX) -m html -L Japanese |\
	$(JCONV) > var/html/variable-list.ja.html

var/html/sorted-variable-list.ja.html: cf/MANIFEST.Japanese
	$(ECONV) cf/MANIFEST.Japanese |\
	$(MANIFEST2INDEX) -m html -s  -L Japanese |\
	$(JCONV) > var/html/sorted-variable-list.ja.html

var/html/variable-list.html: cf/MANIFEST
	$(ECONV) cf/MANIFEST |\
	$(MANIFEST2INDEX) -m html -L English |\
	$(JCONV) > var/html/variable-list.html

var/html/sorted-variable-list.html: cf/MANIFEST
	$(ECONV) cf/MANIFEST |\
	$(MANIFEST2INDEX) -m html -s  -L English |\
	$(JCONV) > var/html/sorted-variable-list.html

# make target
__HTML_MANIFEST__ += var/html/variable-list.html
__HTML_MANIFEST__ += var/html/variable-list.ja.html
__HTML_MANIFEST__ += var/html/sorted-variable-list.html
__HTML_MANIFEST__ += var/html/sorted-variable-list.ja.html
