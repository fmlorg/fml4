#-*- perl -*-
#
# Copyright (C) 1998 Ken'ichi Fukamachi <fukachan@fml.org>
#          All rights reserved. 
#
# $Id$
#


##### libirc.pl 共通の設定 #####

# join するチャンネル ; ircstat ではどうでもいい 
$IRC_CHANNEL = "";

# name, nick
$IRC_NAME    = 'spam';
$IRC_NICK    = 'spam';

# connect するIRCサーバとポート
$IRC_SERVER  = "irc-server.spam.org";
$IRC_PORT    = 6667;

# なんかつながってるようだけどでもDATAがこの時間何もないなら
# 一回セッションを切って reconnect を試みる
$IRC_SERVER_TIMEOUT = 1800;

# select() のTIMEOUT
$IRC_TIMEOUT = 2;

# さよなら〜 のメッセージ
$IRC_SIGNOFF_MSG = 'Seeing you';

# 関数定義(高度なカスタマイズ用)
# $FP_GET_NEXT_BUFFER = $FP_GET_NEXT_BUFFER || 'GetNextBuffer';

##### IRCSTAT 固有の設定 #####
# 見張るホストのリスト(配列)
# -H host1:host2 で上書きできる
# e.g. @IRCSTAT_HOST = (hikari, teapot)
#
# @IRCSTAT_HOST
#

##### マシン情報 #####
# 注意: fml ではインストーラが定義するもの

# GNU automake の config.guess の値; sysv/solaris でないのならなくてもいい
# $CPU_TYPE_MANUFACTURER_OS

# struct sockaddr の定義
#    4.x BSD では "S n a4 x8"
#    BSD/OS 3.x 以降では "x C n C4 x8"
# など
$STRUCT_SOCKADDR = "S n a4 x8";
