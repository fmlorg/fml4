# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# sed -n -e '/^References/,$p'

chdir $FML

test -d var/html/FAQ || mkdir var/html/FAQ

perl usr/sbin/fix-wix.pl <doc/smm/op.wix |\
perl bin/fwix.pl -T FAQ  -m html -D var/html/op -d doc/smm -N op.wix


# cat  var/doc/op |\
# sed -e 1d -e '/^\-/d' |\
# aiko2.pl -T -1 '^(\d+)\.\s+(.*)' -2 '^(\d+\.\d+)\s*(.*)' -f fml-FAQ \
# > var/html/FAQ.html

