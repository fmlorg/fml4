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

all: tutorial.html

scan:
	@ cvs -n update 2>&1| grep -v ':' || echo 'nothing changes'

clean:
	gar *~ *.bak

prep_index:
	@ apply echo *[a-z0-9]|egrep -v 'CVS|Makefile|INDEX|index'

index:
	@ perl ../../distrib/bin/mkindex.pl INDEX

tutorial.html: INDEX
	perl ../../distrib/bin/mkindex.pl INDEX > tutorial.html

subdir_index:
	for d in Japanese [a-z]* ; \
	do \
	  if [ -d $$d -a X$$d != "Xtemplate" -a X$$d != "Xobsolete" ]; \
	  then \
	     perl ../../distrib/bin/mkindex.pl -r -f INDEX $$d \
		> $$d/index.wix.new; \
	     mv	$$d/index.wix.new $$d/index.wix;\
	  fi ;\
	done
