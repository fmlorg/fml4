#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$

CC     = cc
CFLAGS = -DPOSIX
CHMOD  = chmod
MODE   = 4755

all:
	@ echo ""
	@ echo \"make config.ph\"	to make config.ph from ./cf
	@ echo \"make fml\"		to make fml from fml.c
	@ echo ""

config.ph: cf
	@ eval 'mv -f config.ph config.ph.old >/dev/null 2>&1'
	perl _EXEC_DIR_/cf/config -m _EXEC_DIR_/cf/MANIFEST ./cf > config.ph

fml: fml.c config.h
	$(CC) $(CFLAGS) -o fml fml.c
	$(CHMOD) $(MODE) fml
