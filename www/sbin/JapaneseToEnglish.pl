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

    # フレーズ
    s/メーリングリストの/ mailing list\'s /g;
    s/ＭＬの/ ML\'s /g;
    s/メーリングリスト/ mailing list /g;
    s/リモート管理者の登録/ add a new remote administrator /g;
    s/リモート管理者の削除/ remove a remote administrator /g;
    s/メンバーの登録/ add a new member /g;
    s/メンバーの削除/ remove a member /g;
    s/メンバー登録/ add a new member /g;
    s/メンバー削除/ remove a member /g;
    s/メンバーリストの確認/ verify the member list /g;
    s/既存リストからの選択/ choice from the current list /g;
    s/現在のメンバーの確認/ verify current members /g;
    s/確認のため同じパスワード/ password again /g;

    # 単語
    s/ＭＬ/ ML /g;
    s/選択/ choice /g;
    s/設定/ setup /g;
    s/アカウント/ account /g;
    s/メールアドレス/ Email address /g;
    s/アドレス/ address /g;
    s/名/ name /g;
    s/パスワード/ password /g;
    s/1993-1999/1993-2000/g;

    # fix spaces
    s/\s+:/:/;
    s/([A-Za-z])\s+([A-Za-z])/$1 $2/g;

    print $_, "\n";
}


exit 0;
