# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1998 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

SH = /bin/sh 

# 
# HTML_SOURCE = index.html index-e.html roadmap.html
HTML_SOURCE = roadmap.html releng.ja.html
SPECIAL_DOC = INDEX SEARCH INFO RELEASE_NOTES 
CONV_TARGET = README INSTALL INSTALL_on_NT4 INSTALL_with_QMAIL CHECK_LIST UPGRADE

DOC_GENERATOR   = $(SH) $(FML)/distrib/doc/bin/generator.sh
DOC_GENERATOR_D = $(SH) $(FML)/distrib/doc/bin/depend_wrapper.sh
DOC_CONV        = $(DOC_GENERATOR)


all: $(SPECIAL_DOC) $(CONV_TARGET)


INDEX:
	cp $(HTML_SOURCE) $(FML)/var/html/ 
	cpp -P -DJAPANESE index.html |nkf -j> $(FML)/var/html/index.html
	cpp -P -UJAPANESE index.html > $(FML)/var/html/index-e.html
	cp -p nt.html $(FML)/var/html/


SEARCH:
	cp search*.html $(FML)/var/html/


INFO: INFO.html INFO-e.html


INFO.html: $(FML)/.info
	cat $(FML)/doc/html/INFOpre $(FML)/var/doc/INFO.jp \
	> $(FML)/var/html/INFO.html


INFO-e.html: $(FML)/.info
	cat $(FML)/doc/html/INFOpre $(FML)/var/doc/INFO.en \
	> $(FML)/var/html/INFO-e.html


RELEASE_NOTES:
	cat $(FML)/doc/html/RELEASE_NOTESpre $(FML)/var/doc/RELEASE_NOTES.jp \
	> $(FML)/var/html/RELEASE_NOTES.html


op:	var/html/op/index.html


var/html/op/index.html: doc/smm/*wix
	(FML=$(FML);  export FML; $(DOC_GENERATOR) -a op smm)


README:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) README ri)

INSTALL:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) INSTALL ri)

INSTALL_on_NT4:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) INSTALL_on_NT4 ri)

INSTALL_with_QMAIL:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) INSTALL_with_QMAIL ri)

do_README:
	(FML=$(FML);  export FML; $(DOC_CONV) README ri)

do_INSTALL:
	(FML=$(FML);  export FML; $(DOC_CONV) INSTALL ri)

do_INSTALL_on_NT4:
	(FML=$(FML);  export FML; $(DOC_CONV) INSTALL_on_NT4 ri)

do_INSTALL_with_QMAIL:
	(FML=$(FML);  export FML; $(DOC_CONV) INSTALL_with_QMAIL ri)


UPGRADE:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) UPGRADE ri)

do_UPGRADE:
	(FML=$(FML);  export FML; $(DOC_CONV) UPGRADE ri)

CHECK_LIST:
	(FML=$(FML);  export FML; $(DOC_GENERATOR_D) CHECK_LIST ri)

do_CHECK_LIST:
	(FML=$(FML);  export FML; $(DOC_CONV) CHECK_LIST ri)

clean:
	gar *~ *.bak
