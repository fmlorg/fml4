#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
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
	@ echo \"make config.ph\"	to make config.ph from ./cf
	@ echo \"make fml\"		to make fml from fml.c
	@ echo ""

config.ph: cf
	@ eval 'cp -p config.ph config.ph.old >/dev/null 2>&1'
	perl _EXEC_DIR_/cf/config -m _EXEC_DIR_/cf/MANIFEST ./cf > config.ph

fml: fml.c config.h
	$(CC) $(CFLAGS) -o fml fml.c
	$(CHMOD) $(MODE) fml
