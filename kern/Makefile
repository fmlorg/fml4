# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

CC 	  = cc
CFLAGS	  = -s -O -DPOSIX

SH	  = /bin/sh

PWD       = `pwd`
CONFIG_PH = ./config.ph
GENHOST   = _`hostname`_
FWIX      = perl bin/fwix.pl

all:
	perl ./makefml

install:
	perl ./makefml install

# install-withcgi:
#	perl ./makefml -W cgi install
install-withcgi: install

dns_check:
	@ perl bin/dns_check.pl

doc: 	html_doc

html_doc:
	$(FWIX) -T op -m html -D doc/html/op -d doc/smm < doc/smm/op.wix

roff:
	@ echo sorry, not implemetend yet

texinfo:
	@ echo sorry, not implemetend yet
