# 
# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: Makefile,v 2.96 2001/03/29 16:03:19 fukachan Exp $

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
FMLMK_CONF=fmlmk.conf
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
EXPORT_ENV = MAKE=${MAKE} FML=${FML} DESTDIR=${DESTDIR} BRANCH=${BRANCH} MODE=${MODE} FMLMK_CONF=${FMLMK_CONF}


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

__dist:
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator 2>&1| tee $(DESTDIR)/_distrib.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_distrib.log
	@ env ${EXPORT_ENV} ${MAKE} usage

distsnap:
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	@ (cd $(DESTDIR)/fml-current/; $(RSYNC) -auv . $(SNAPSHOT_DIR))

# If release branch, use this
snapshot:
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	@ if [ "X`tty`" != X ]; then \
	     ssh-add -l |\
	     grep `hostname -s` >/dev/null || printf "\n ! please ssh-add.\n\n";\
	  fi
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator -ip 2>&1| tee $(DESTDIR)/_release.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_release.log


release:
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	(env ${EXPORT_ENV} /bin/sh ${DIST_BIN}/generator -rp 2>&1|\
		tee $(DESTDIR)/_release.log)
	@ env ${EXPORT_ENV} ${DIST_BIN}/error_report.sh $(DESTDIR)/_release.log


### "make build"
.include "distrib/mk/fml.build.mk"
build: init_build plaindoc htmldoc __dist ${__BUILD_END__}

doc: plaindoc htmldoc

INFO:	$(WORK_DOC_DIR)/INFO $(WORK_DOC_DIR)/INFO-e

INFO-common: $(FML)/CHANGES
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	@ $(MKDIR) $(COMPILE_DIR)
	@ rm -f $(COMPILE_DIR)/INFO
	($(ECONV) doc/ri/INFO; $(ECONV) CHANGES)|\
		$(ECONV) |\
		tee $(WORK_DOC_DIR)/INFO > $(COMPILE_DIR)/INFO.src

$(WORK_DOC_DIR)/INFO: INFO-common
	${FWIX} -n i ${COMPILE_DIR}/INFO.src > ${COMPILE_DIR}/INFO

$(WORK_DOC_DIR)/INFO-e: INFO-common
	${PERL} ${DIST_BIN}/remove_japanese_line.pl \
		< $(COMPILE_DIR)/INFO.src |\
		uniq > $(COMPILE_DIR)/INFO-e

init_dir:
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup

plaindoc: init_dir INFO doc/smm/op.wix
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.doc.mk plaindocbuild TUTORIAL_LANGUAGE=Japanese
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.doc.mk plaindocbuild TUTORIAL_LANGUAGE=English

htmldoc: init_dir INFO doc/smm/op.wix
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.sys.mk __setup
	@ find $(WORK_HTML_DIR) -type l -print |${PERL} -nle unlink
	@ $(MKDIR) $(WORK_HTML_DIR)/op
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.doc.mk htmlbuild TUTORIAL_LANGUAGE=Japanese
	@ env ${EXPORT_ENV} ${MAKE} -f distrib/mk/fml.doc.mk htmlbuild TUTORIAL_LANGUAGE=English

syncwww: doc
	$(RSYNC) -av $(WORK_HTML_DIR)/ ${WWW_DIR}/

syncinfo:
	$(JCONV) $(WORK_DOC_DIR)/INFO > $(SNAPSHOT_DIR)/info

search:
	@ env ${EXPORT_ENV} echo now we make namazu on external www server.

##### make distribution #####
update_configuration: libkern menu.conf.toggle etc/makefml/list.procedure etc/makefml/cf.recommended

libkern: proc/libkern.pl

menu.conf.toggle: etc/makefml/menu.conf.toggle

proc/libkern.pl: kern/fml.pl
	sed '/^$$Rcsid/,/MAIN ENDS/d' kern/fml.pl > proc/libkern.pl

etc/makefml/menu.conf.toggle: cf/MANIFEST
	perl distrib/bin/gen_menu.conf.toggle cf/MANIFEST \
		> etc/makefml/menu.conf.toggle

etc/makefml/list.procedure: proc/libfml.pl
	perl distrib/bin/show_procedure.pl proc/libfml.pl > etc/makefml/list.procedure.new
	mv etc/makefml/list.procedure.new etc/makefml/list.procedure

etc/makefml/cf.recommended: etc/makefml/cf etc/makefml/secure_config.ph etc/makefml/secure_local_config
	cp etc/makefml/cf etc/makefml/cf.recommended
	echo >> etc/makefml/cf.recommended
	echo LOCAL_CONFIG >> etc/makefml/cf.recommended
	perl bin/more_secure_cf.pl \
		-c etc/makefml/secure_config.ph \
		-f etc/makefml/secure_local_config \
		etc/makefml/cf.recommended > etc/makefml/cf.recommended.new
	mv etc/makefml/cf.recommended.new etc/makefml/cf.recommended

### utils
bsdmake:
	(cd dist/NetBSD;make bsdmake)
