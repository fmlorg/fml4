#!/bin/sh
# 
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

renice +18 $$

LOG=logfile
CF=example.ph
INC=/usr/local/fml

tail -f $LOG | perl stdin2irc.pl -f $CF -I $INC

exit 0;
