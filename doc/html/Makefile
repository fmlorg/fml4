# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

SH = /bin/sh 

all: INDEX INFO README RELEASE_NOTES INSTALL INSTALL_on_NT4 UPGRADE

INDEX:
	cp index.html index-e.html $(FML)/var/html/

FAQ:
	(FML=$(FML);  export FML; $(SH) make-FAQ.sh)

INFO:
	(FML=$(FML);  export FML; $(SH) make-INFO.sh)

README:
	(FML=$(FML);  export FML; $(SH) Converter.sh README ri)

INSTALL:
	(FML=$(FML);  export FML; $(SH) Converter.sh INSTALL ri)

INSTALL_on_NT4:
	(FML=$(FML);  export FML; $(SH) Converter.sh INSTALL_on_NT4 ri)

RELEASE_NOTES:
	(FML=$(FML);  export FML; $(SH) make-RELEASE_NOTES.sh)

op:
	(FML=$(FML);  export FML; $(SH) Converter.sh op smm)

UPGRADE:
	(FML=$(FML);  export FML; $(SH) plain2html.sh UPGRADE UPGRADE)

