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

CC     = cc
# CFLAGS = -DPOSIX
CFLAGS = 

CHMOD  = chmod
MODE   = 4755

all:
	@ echo ""
	@ echo "\"make config.ph\"	make config.ph from ./cf"
	@ echo "\"make fml\"		make fml from fml.c"
	@ echo "\"make config\"		\"makefml config _ML_\" # run CUI menu"
	@ echo "			You can control fundamental parameters"
	@ echo "\"make spool2html\"	convert spool to html files"
	@ echo "\"make secure\"		set cf be more secure"
	@ echo "			e.g. disable a user to get member list"
	@ echo "			set the mail size limit,"
	@ echo "			filter on, traffic monitor on ..."
	@ echo "\"make doc-template\"	create documents e.g. help,welcome,..."
	@ echo ""

config.ph: cf
	@ eval 'cp -p config.ph config.ph.old >/dev/null 2>&1'
	perl _EXEC_DIR_/cf/config -m _EXEC_DIR_/cf/MANIFEST ./cf > config.ph
	@ touch cf
	@ perl -c config.ph

fml: fml.c config.h
	$(CC) $(CFLAGS) -o fml fml.c
	$(CHMOD) $(MODE) fml
	$(CC) $(CFLAGS) -DCTLADDR -o fml-ctl fml.c
	$(CHMOD) $(MODE) fml-ctl

spool2html:
	perl _EXEC_DIR_/bin/spool2html.pl \
		-I _EXEC_DIR_ \
		-d htdocs \
		-f config.ph \
		spool

config:
	perl _EXEC_DIR_/makefml config _ML_

outgoing:
	perl _EXEC_DIR_/makefml conv _ML_ \
		_EXEC_DIR_/etc/makefml/include-outgoing include-outgoing

doc-template:
	perl _EXEC_DIR_/makefml create-doc-template _ML_

secure:
	@ echo "Converting cf to be more secure"
	@ echo " (original is renamed to cf.bak)"
	@ perl -i.bak _EXEC_DIR_/bin/more_secure_cf.pl cf
	@ make config.ph

