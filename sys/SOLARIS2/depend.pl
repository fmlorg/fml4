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

# open LOCK ">> lockfile", flock(LOCK, LOCK_EX, ..)
$FlockFile   = ">> $VARRUN_DIR/flock";
$__FlockFile = "$VARRUN_DIR/flock";

eval q{ 
   if ($DIR) {
	my $dir = "$DIR/$VARRUN_DIR";
	-d $dir || &MkDir($dir); 
   }
};

1;
