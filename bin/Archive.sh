#!/bin/sh
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

(cd /var/spool/ml/Elena;    /usr/local/bin/perl bin/Archive.pl)
(cd /var/spool/ml/Freekick; /usr/local/bin/perl bin/Archive.pl)

exit 0;
