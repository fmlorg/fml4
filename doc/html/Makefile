# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1998 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

SH = /bin/sh 

# 
# HTML_SOURCE = index.html index-e.html roadmap.html
HTML_SOURCE = roadmap.html
CONV_TARGET = README INSTALL INSTALL_on_NT4 INSTALL_with_QMAIL CHECK_LIST

all: INDEX SEARCH INFO RELEASE_NOTES UPGRADE $(CONV_TARGET)

scan:
	fvs scan .

INDEX:
	cp $(HTML_SOURCE) $(FML)/var/html/ 
	cpp -P -DJAPANESE index.html |nkf -j> $(FML)/var/html/index.html
	cpp -P -UJAPANESE index.html > $(FML)/var/html/index-e.html

SEARCH:
	cp search*.html $(FML)/var/html/

FAQ:
	(FML=$(FML);  export FML; $(SH) make-FAQ.sh)

INFO:
	(FML=$(FML);  export FML; $(SH) make-INFO.sh)

RELEASE_NOTES:
	(FML=$(FML);  export FML; $(SH) make-RELEASE_NOTES.sh)

op:	
	(FML=$(FML);  export FML; $(SH) op_depend.sh)

do_op:
	(FML=$(FML);  export FML; $(SH) Converter.sh -a op smm)


README:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh README ri)

INSTALL:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh INSTALL ri)

INSTALL_on_NT4:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh INSTALL_on_NT4 ri)

INSTALL_with_QMAIL:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh INSTALL_with_QMAIL ri)

do_README:
	(FML=$(FML);  export FML; $(SH) Converter.sh README ri)

do_INSTALL:
	(FML=$(FML);  export FML; $(SH) Converter.sh INSTALL ri)

do_INSTALL_on_NT4:
	(FML=$(FML);  export FML; $(SH) Converter.sh INSTALL_on_NT4 ri)

do_INSTALL_with_QMAIL:
	(FML=$(FML);  export FML; $(SH) Converter.sh INSTALL_with_QMAIL ri)


UPGRADE:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh UPGRADE ri)

do_UPGRADE:
	(FML=$(FML);  export FML; $(SH) Converter.sh UPGRADE ri)

CHECK_LIST:
	(FML=$(FML);  export FML; $(SH) depend_wrapper.sh CHECK_LIST ri)

do_CHECK_LIST:
	(FML=$(FML);  export FML; $(SH) Converter.sh CHECK_LIST ri)
