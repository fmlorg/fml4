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

$RA = 'remote administrator';

while (<>) {
    chop;

    # �ե졼��
    s@��⡼�ȴ����Ԥ���Ͽ/���@ add/remove a $RA @g;
    s@�̥ͣ��С�����Ͽ/���@ add/remove a ML member @g;
    s@���С�����Ͽ/���@ add/remove a ML member @g;
    s@��⡼�ȴ����ԥѥ���ɤ�����@ password for a $RA @g;
    s@��⡼�ȴ����ԥѥ����@ password for a $RA @g;
    s@��⡼�ȴ����ԤȤ�����Ͽ@ (add a $RA)@;
    s@��⡼�ȴ����ԤȤ��ƺ��@ (remove a $RA)@;
    s/��⡼�ȴ����Ԥ���Ͽ/ add a new $RA /g;
    s/��⡼�ȴ����Ԥκ��/ remove a $RA /g;
    s/���С�����Ͽ/ add a new member /g;
    s/���С��κ��/ remove a member /g;
    s/���С���Ͽ/ add a new member /g;
    s/���С����/ remove a member /g;
    s/���С��ꥹ�Ȥγ�ǧ/ verify the member list /g;
    s/��¸�ꥹ�Ȥ��������/ choice from the current list /g;
    s/���ߤΥ��С��γ�ǧ/ verify current members /g;
    s/��ǧ�Τ���Ʊ���ѥ����/ password again /g;
    s/�̤ͣΥ��򸫤�/ see ML\'s log /g;
    s/�᡼��󥰥ꥹ�ȤΥ��򸫤�/ see ML\'s log /g;
    s/���򸫤�/ see ML\'s log /g;
    s/�Ǹ�Σι�/ the last N lines /g;

    s@��Ͽ/���@ add/remove @g;
    s/�ܺ�����/ setup in detail /g;
    s/�����̤ͣκ���/ make a new ML /g;
    s/�̤ͣο�������/ make a new ML /g;
    s/�̤ͣκ��/ remove a ML /g;
    s/�̤ͣ�����/ choose a ML /g;
    s/�����᡼��󥰥ꥹ�Ȥκ���/ make a new ML /g;
    s/�᡼��󥰥ꥹ�Ȥκ��/ remove a ML /g;
    s/�᡼��󥰥ꥹ�Ȥ�����/ choose a ML /g;
    s/�᡼��󥰥ꥹ�Ȥ�/ mailing list\'s /g;
    s/�̤ͣ�/ ML\'s /g;

    s@\(��˥塼��\[����\]��UPDATE���뤿���\)@update [choices] in the menu bar@;
    s@\[���Υ�˥塼��򹹿�\]@update menu in the left of screen@;

    s@CGI\s*����������桼��@setup a user which can control this CGI@;
    s@����� ML �� CGI ����ǽ��@enable some ML CGI controllable@;

    # ñ��
    s/������/ one day /g;
    s/����/ all /g;
    s/�᡼��󥰥ꥹ��/ mailing list /g;
    s/�ͣ�/ ML /g;
    s/����/ basic /;
    s/������/ choice /g;
    s/������/ setup /g;
    s/�δ���/ administration /;
    s/����/ setup /g;
    s/����/ choice /g;
    s/����/ administration /;

    s/��˥塼/ menu /;
    s/���������/ account /g;
    s/�᡼�륢�ɥ쥹/ Email address /g;
    s/���ɥ쥹/ address /g;
    s/̾/ name /g;
    s/�ѥ����/ password /g;
    s/���С�/ member /g;
    s/1993-1999/1993-2000/g;

    # fix spaces
    s/\s+:/:/;
    s/([A-Za-z])\s+([A-Za-z])/$1 $2/g;

    print $_, "\n";
}


exit 0;
