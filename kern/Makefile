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

SH	  = /bin/sh
# PWD       = `pwd`

all:
	@ echo "run 'make install' to install fml"

install:
	perl ./makefml install

install-withcgi: install

dns_check:
	@ perl bin/dns_check.pl
