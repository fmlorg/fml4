MANIFEST2INDEX = ./distrib/bin/manifest2index.pl

var/html/variable-list.html: cf/MANIFEST.Japanese
	nkf -e cf/MANIFEST.Japanese |\
	$(MANIFEST2INDEX) -m html  |\
	nkf -j > var/html/variable-list.html

var/html/sorted-variable-list.html: cf/MANIFEST.Japanese
	nkf -e cf/MANIFEST.Japanese |\
	$(MANIFEST2INDEX) -m html -s |\
	nkf -j > var/html/sorted-variable-list.html

# make target
__HTML_MANIFEST__ += var/html/variable-list.html
__HTML_MANIFEST__ += var/html/sorted-variable-list.html
