# 
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

.include "distrib/mk/fml.sys.mk"
.include "distrib/mk/fml.prog.mk"
.include "distrib/mk/fml.doc.mk"

.if exists(Makefile.local)
.include "Makefile.local"
.endif

.MAIN: usage
all:	usage

usage:
	@ echo ""
	@ echo "\"make all\"       not works!!!"
	@ echo ""
	@ echo "\"make release\"   to make the release"
	@ echo "\"make snapshot\"  to make a snapshot to export"
	@ echo "\"make dist \"     to make a snapshot to use internally" 
	@ echo "\"make distsnap\"  to export snapshot to ftp.iij.ad.jp"
	@ echo "";
	@ echo "-- Makefile.local";
	@ echo "\"make sync\"      to syncrhonize -> fml.org mail server"
	@ echo ""

dist:	
	(/bin/sh $(DIST_BIN)/generator 2>&1| tee $(DESTDIR)/_distrib.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_distrib.log
	@ make usage

distsnap:
	@ (cd $(DESTDIR)/fml-current/; $(RSYNC) -auv . $(SNAPSHOT_DIR))

snapshot:
	@ ssh-add -l |grep beth >/dev/null || printf "\n--please ssh-add.\n"
	(/bin/sh $(DIST_BIN)/generator -ip 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log

branch:
	(/bin/sh $(DIST_BIN)/generator -b 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log

release:
	(/bin/sh $(DIST_BIN)/generator -rp 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log


doc: INFO INFO-e syncinfo newdoc search

newdoc: htmldoc syncwww syncinfo 

INFO:	$(WORK_DOC_DIR)/INFO $(WORK_DOC_DIR)/INFO-e

INFO-common: $(FML)/.info
	@ make -f distrib/mk/fml.sys.mk __setup
	@ $(MKDIR) $(COMPILE_DIR)
	@ rm -f $(COMPILE_DIR)/INFO
	($(ECONV) doc/ri/INFO; $(ECONV) .info; $(ECONV) doc/ri/README.wix)|\
		$(ECONV) |\
		tee $(WORK_DOC_DIR)/INFO > $(COMPILE_DIR)/INFO

$(WORK_DOC_DIR)/INFO: INFO-common
	$(GEN_PLAIN_DOC) -o $(WORK_DOC_DIR) $(COMPILE_DIR)/INFO 

$(WORK_DOC_DIR)/INFO-e: INFO-common
	perl $(DIST_BIN)/remove_japanese_line.pl \
		< $(COMPILE_DIR)/INFO > $(COMPILE_DIR)/INFO-e

plaindoc: INFO doc/smm/op.wix
	@ make -f distrib/mk/fml.sys.mk __setup
	@ $(GEN_PLAIN_DOC)

htmldoc: INFO doc/smm/op.wix
	@ make -f distrib/mk/fml.sys.mk __setup
	@ find $(WORK_HTML_DIR) -type l -print |perl -nle unlink
	@ (chdir doc/html; make)
	@ $(MKDIR) $(WORK_HTML_DIR)/op
	@ (chdir doc/html; make op)

syncwww:
	$(RSYNC) -av $(WORK_HTML_DIR)/ $(WWW)/

syncinfo:
	$(JCONV) $(WORK_DOC_DIR)/INFO > $(SNAPSHOT_DIR)/info


search:
	@ echo ""
	@ sh $(DIST_DOC_BIN)/search_doc_generator

libkern:
	sed '/^$$Rcsid/,/MAIN ENDS/d' fml.pl > proc/libkern.pl
