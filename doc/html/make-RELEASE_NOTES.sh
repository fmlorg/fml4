#!/bin/sh
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

chdir $FML;

(
	cat doc/html/RELEASE_NOTESpre
	cat var/doc/RELEASE_NOTES.jp
) > var/html/RELEASE_NOTES.html
