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

### themost important variable ! ###
FML  = ${.CURDIR}

# search ${HOME} also for ~/.fmlmk.conf
.PATH: ${HOME}

# branch
.if exists(conf/branch)
BRANCH=`cat conf/branch`
.else
.BEGIN:
	@echo please prepare conf/branch to define branch/trunk
	@false
.endif

# mode {daily,}
.if exists(conf/mode)
MODE=`cat conf/mode`
.endif

# standard includes
.include "distrib/mk/fml.sys.mk"
.include "distrib/mk/fml.prog.mk"
.include "distrib/mk/fml.doc.mk"

.if exists(Makefile.local)
.include "Makefile.local"
.endif

###
### include site specific configuration files: fmlmk.conf
### For example, ./fmlmk.conf,  ~/.fmlmk.conf, ..
.if exists(fmlmk.conf)
FMLMK_CONF=mk.conf
.elif exists(.fmlmk.conf)
FMLMK_CONF=.fmlmk.conf
.else
.BEGIN:
	@echo please prepare ./fmlmk.conf or ~/.fmlmk.conf
	@false
.endif

.if! empty(FMLMK_CONF)
.include "${FMLMK_CONF}"
.endif

### export environmental variable
EXPORT_ENV = FML=${FML} DESTDIR=${DESTDIR}


### MAIN ###
.MAIN: usage
all:	usage

usage:
	@ echo ""
	@ echo "\"make all\"       not works!!!"
	@ echo ""
	@ echo "\"make build\"     to set up fundamentals and run \"make dist\""
	@ echo "                   It is suitable for the first time."	
	@ echo ""
	@ echo "\"make release\"   to make the release"
	@ echo "\"make snapshot\"  to make a snapshot to export"
	@ echo "\"make dist \"     to make a snapshot to use internally" 
	@ echo "\"make distsnap\"  to export snapshot to ftp.iij.ad.jp"
	@ echo "";
	@ echo "-- Makefile.local";
	@ echo "\"make sync\"      to syncrhonize -> fml.org mail server"
	@ echo ""

	
_dist:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator 2>&1| tee $(DESTDIR)/_distrib.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_distrib.log
	@ env ${EXPORT_ENV} make usage

distsnap:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	@ (cd $(DESTDIR)/fml-current/; $(RSYNC) -auv . $(SNAPSHOT_DIR))

# If release branch, use this
snapshot:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	@ ssh-add -l |grep beth >/dev/null || printf "\n--please ssh-add.\n"
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator -ip 2>&1| tee $(DESTDIR)/_release.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_release.log

	
exp: experimental-snapshot
experimental-snapshot:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator -b 2>&1|\
		tee $(DESTDIR)/_release.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_release.log

release:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator -rp 2>&1|\
		tee $(DESTDIR)/_release.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_release.log


### "make build"
.include "distrib/mk/fml.build.mk"
build: init_build plaindoc htmldoc pkgsrc dist ${__BUILD_END__}


doc: INFO syncinfo newdoc search
newdoc: htmldoc syncwww syncinfo 

INFO:	$(WORK_DOC_DIR)/INFO $(WORK_DOC_DIR)/INFO-e

INFO-common: $(FML)/.info
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	@ $(MKDIR) $(COMPILE_DIR)
	@ rm -f $(COMPILE_DIR)/INFO
	($(ECONV) doc/ri/INFO; $(ECONV) .info; $(ECONV) doc/ri/README.wix)|\
		$(ECONV) |\
		tee $(WORK_DOC_DIR)/INFO > $(COMPILE_DIR)/INFO

$(WORK_DOC_DIR)/INFO: INFO-common
	$(GEN_PLAIN_DOC) -o $(WORK_DOC_DIR) $(COMPILE_DIR)/INFO 

$(WORK_DOC_DIR)/INFO-e: INFO-common
	${PERL} ${DIST_BIN}/remove_japanese_line.pl \
		< $(COMPILE_DIR)/INFO > $(COMPILE_DIR)/INFO-e

init_dir:
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup

plaindoc: init_dir INFO doc/smm/op.wix
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.doc.mk plaindocbuild

htmldoc: init_dir INFO doc/smm/op.wix
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.sys.mk __setup
	@ find $(WORK_HTML_DIR) -type l -print |${PERL} -nle unlink
	@ $(MKDIR) $(WORK_HTML_DIR)/op
	@ env ${EXPORT_ENV} make -f distrib/mk/fml.doc.mk htmlbuild

syncwww:
	$(RSYNC) -av $(WORK_HTML_DIR)/ $(WWW)/

syncinfo:
	$(JCONV) $(WORK_DOC_DIR)/INFO > $(SNAPSHOT_DIR)/info

libkern: proc/libkern.pl

proc/libkern.pl: kern/fml.pl
	sed '/^$$Rcsid/,/MAIN ENDS/d' kern/fml.pl > proc/libkern.pl

clean:
	find . |grep '/\.#' |${PERL} -nple unlink
