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
#

# The directory above each mailing list.
$MAIL_LIST_DIR     = "_ML_DIR_";

# fmlserv's HOME directory. "fmlserv" is just one of mailing lists.
$FMLSERV_DIR       = "$MAIL_LIST_DIR/fmlserv";

# log file
$FMLSERV_LOGFILE   = "$FMLSERV_DIR/log";

# In default, "lists" command is NOT AVAILABLE FOR SECURITY.
# If you permit "lists" command in fmlserv, you set 1.
$FMLSERV_PERMIT_LISTS_COMMAND = 0;

1;
