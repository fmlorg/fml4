#-*- perl -*-
#
# Copyright (C) 1998 Ken'ichi Fukamachi <fukachan@fml.org>
#          All rights reserved. 
#
# $Id$
#


##### libirc.pl ���̤����� #####

# join ��������ͥ� ; ircstat �ǤϤɤ��Ǥ⤤�� 
$IRC_CHANNEL = "";

# name, nick
$IRC_NAME    = 'spam';
$IRC_NICK    = 'spam';

# connect ����IRC�����Фȥݡ���
$IRC_SERVER  = "irc-server.spam.org";
$IRC_PORT    = 6667;

# �ʤ󤫤Ĥʤ��äƤ�褦�����ɤǤ�DATA�����λ��ֲ���ʤ��ʤ�
# ��󥻥å������ڤä� reconnect ���ߤ�
$IRC_SERVER_TIMEOUT = 1800;

# select() ��TIMEOUT
$IRC_TIMEOUT = 2;

# ����ʤ�� �Υ�å�����
$IRC_SIGNOFF_MSG = 'Seeing you';

# �ؿ����(���٤ʥ������ޥ�����)
# $FP_GET_NEXT_BUFFER = $FP_GET_NEXT_BUFFER || 'GetNextBuffer';

##### IRCSTAT ��ͭ������ #####
# ��ĥ��ۥ��ȤΥꥹ��(����)
# -H host1:host2 �Ǿ�񤭤Ǥ���
# e.g. @IRCSTAT_HOST = (hikari, teapot)
#
# @IRCSTAT_HOST
#

##### �ޥ������ #####
# ���: fml �Ǥϥ��󥹥ȡ��餬���������

# GNU automake �� config.guess ����; sysv/solaris �Ǥʤ��Τʤ�ʤ��Ƥ⤤��
# $CPU_TYPE_MANUFACTURER_OS

# struct sockaddr �����
#    4.x BSD �Ǥ� "S n a4 x8"
#    BSD/OS 3.x �ʹߤǤ� "x C n C4 x8"
# �ʤ�
$STRUCT_SOCKADDR = "S n a4 x8";
