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

CC 	  = cc
CFLAGS	  = -s -O -DPOSIX

SH	  = /bin/sh
MKDIR     = mkdirhier

PWD       = `pwd`
CONFIG_PH = ./config.ph
GENHOST   = _`hostname`_
FWIX      = perl bin/fwix.pl

all:
	perl ./makefml

install:
	perl ./makefml install

install-withcgi:
	perl ./makefml -W cgi install

dns_check:
	@ perl bin/dns_check.pl

localtest: 
	@ echo " "
	@ echo "LOCALLY CLOSED TEST in DEBUG MODE(-d option)"
	@ echo "perl sbin/localtest.pl | perl $(PWD)src/fml.pl -d $(PWD) "
	@ echo " "
	@ echo IF YOU WOULD LIKE TO TEST THE DELIVERY WITHOUT Sendmail
	@ echo JUST TYPE
	@ echo "perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -udebug $(PWD)"
	@ echo " "
	@ echo " "
	@ echo "O.K.?(wait 3 sec.)"; sleep 3;
	@ echo INPUT:
	@ echo "-----------------------------------"
	@ perl sbin/localtest.pl 
	@ echo "==================================="
	@ echo " "
	@ echo " "
	@ echo " "
	@ echo "This Header O.K.?(wait 3 sec.)"; sleep 3;
	@ echo OUTPUT: debug info from src/fml.pl 
	@ echo "   *** DEBUG MODE! ***  "
	@ echo "-----------------------------------"
	perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -d $(PWD) 
	@ echo "   DEBUG MODE!   "
	@ echo "-----------------------------------"

doc: 	html_doc

html_doc:
	$(FWIX) -T op -m html -D doc/html/op -d doc/smm < doc/smm/op.wix

roff:	doc/smm/op.wix
	@ echo "sorry, not implemetend yet but halfly completed?"
	@ echo ""
	@ echo "Making nroff of doc/smm/op => var/man"
	@ $(MKDIR) var/man
	@ $(FWIX) -T smm/op -m roff -R var/man -I doc/smm doc/smm/op.wix

texinfo:
	@ echo sorry, not implemetend yet
