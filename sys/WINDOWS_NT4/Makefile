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
#


scan:
	fvs scan

clean:
	gar *~ */*~

check:
	for file in *.pl ; do \
		echo "" ; \
		echo $$file ; \
		perl -nle 's/Win32[:\w]+/Socket/g; next if /Win32/; print' \
		$$file| tee /tmp/$$file |\
		 perl -cw 2>&1 | grep -v 'only once' ;\
	done
