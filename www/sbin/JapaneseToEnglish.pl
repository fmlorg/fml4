#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
# $NetBSD$
# $FML$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");

chop($NKF = `which nkf`);
-x $NKF || die("ERROR: nkf not found");

while (<>) {
    chop;

    # �ե졼��
    s/�᡼��󥰥ꥹ�Ȥ�/ mailing list\'s /g;
    s/�̤ͣ�/ ML\'s /g;
    s/�᡼��󥰥ꥹ��/ mailing list /g;
    s/��⡼�ȴ����Ԥ���Ͽ/ add a new remote administrator /g;
    s/��⡼�ȴ����Ԥκ��/ remove a remote administrator /g;
    s/���С�����Ͽ/ add a new member /g;
    s/���С��κ��/ remove a member /g;
    s/���С���Ͽ/ add a new member /g;
    s/���С����/ remove a member /g;
    s/���С��ꥹ�Ȥγ�ǧ/ verify the member list /g;
    s/��¸�ꥹ�Ȥ��������/ choice from the current list /g;
    s/���ߤΥ��С��γ�ǧ/ verify current members /g;
    s/��ǧ�Τ���Ʊ���ѥ����/ password again /g;

    # ñ��
    s/�ͣ�/ ML /g;
    s/����/ choice /g;
    s/����/ setup /g;
    s/���������/ account /g;
    s/�᡼�륢�ɥ쥹/ Email address /g;
    s/���ɥ쥹/ address /g;
    s/̾/ name /g;
    s/�ѥ����/ password /g;
    s/1993-1999/1993-2000/g;

    # fix spaces
    s/\s+:/:/;
    s/([A-Za-z])\s+([A-Za-z])/$1 $2/g;

    print $_, "\n";
}


exit 0;
