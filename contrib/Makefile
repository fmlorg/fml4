# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;

all: distrib

clean:
	delete *~ _* mget* core

DISTRIB: distrib

distrib: README
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	cp -p README $(UPDIR)/distrib/contrib
