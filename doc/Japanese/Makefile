# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

all: scan

scan:
	cvs -n update

clean:
	gar *~ *.bak

toc:
	@ if [ -f  ../../var/doc/op.jp ] ; then \
		../../distrib/doc/bin/gen_toc.pl ../../var/doc/op.jp ; \
	else \
		echo cannot find ../../var/doc/op.jp;  \
	fi
