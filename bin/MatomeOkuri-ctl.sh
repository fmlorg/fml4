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

HOME="/home/axion/fukachan"; export HOME
DIR="$HOME/work/spool"

＃ｐｅｒｌ            MSendv4.pl          ＭＬの場所      ライブラリ
＃/usr/local/bin/perl $DIR/lib/MSendv4.pl $DIR/EXP        $DIR/lib

echo "EXP:"	# bin/MSendv4-stat.pl でのＭＬを示すキーワードエントリ：
date
/usr/local/bin/perl $DIR/lib/MSendv4.pl   $DIR/EXP        $DIR/lib

echo "mama4:"
date
/usr/local/bin/perl $DIR/lib/MSendv4.pl   $DIR/mama4      $DIR/lib

echo "enterprise:"
date
/usr/local/bin/perl $DIR/lib/MSendv4.pl   $DIR/enterprise $DIR/lib

echo "===== HTML Sync ============"
chmod 644 $DIR/phys-faq-submit/spool/*
/usr/local/bin/perl $DIR/http/SyncHTMLfiles.pl $DIR/phys-faq-submit/spool

exit 0;
