#!/bin/sh
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

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
