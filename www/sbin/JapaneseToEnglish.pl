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

    # フレーズ
    s@リモート管理者の登録/削除@ add/remove a $RA @g;
    s@ＭＬメンバーの登録/削除@ add/remove a ML member @g;
    s@メンバーの登録/削除@ add/remove a ML member @g;
    s@リモート管理者パスワードの設定@ password for a $RA @g;
    s@リモート管理者パスワード@ password for a $RA @g;
    s@リモート管理者として登録@ (add a $RA)@;
    s@リモート管理者として削除@ (remove a $RA)@;
    s/リモート管理者の登録/ add a new $RA /g;
    s/リモート管理者の削除/ remove a $RA /g;
    s/メンバーの登録/ add a new member /g;
    s/メンバーの削除/ remove a member /g;
    s/メンバー登録/ add a new member /g;
    s/メンバー削除/ remove a member /g;
    s/メンバーリストの確認/ verify the member list /g;
    s/既存リストからの選択/ choice from the current list /g;
    s/現在のメンバーの確認/ verify current members /g;
    s/確認のため同じパスワード/ password again /g;
    s/ＭＬのログを見る/ see ML\'s log /g;
    s/メーリングリストのログを見る/ see ML\'s log /g;
    s/ログを見る/ see ML\'s log /g;
    s/最後のＮ行/ the last N lines /g;

    s@登録/削除@ add/remove @g;
    s/詳細設定/ setup in detail /g;
    s/新規ＭＬの作成/ make a new ML /g;
    s/ＭＬの新規作成/ make a new ML /g;
    s/ＭＬの削除/ remove a ML /g;
    s/ＭＬの選択/ choose a ML /g;
    s/新規メーリングリストの作成/ make a new ML /g;
    s/メーリングリストの削除/ remove a ML /g;
    s/メーリングリストの選択/ choose a ML /g;
    s/メーリングリストの/ mailing list\'s /g;
    s/ＭＬの/ ML\'s /g;

    s@\(メニューの\[選択\]をUPDATEするために\)@update [choices] in the menu bar@;
    s@\[左のメニュー欄を更新\]@update menu in the left of screen@;

    s@CGI\s*の操作を許すユーザ@setup a user which can control this CGI@;
    s@特定の ML を CGI 操作可能に@enable some ML CGI controllable@;

    # 単語
    s/ある日/ one day /g;
    s/全部/ all /g;
    s/メーリングリスト/ mailing list /g;
    s/ＭＬ/ ML /g;
    s/基本/ basic /;
    s/の選択/ choice /g;
    s/の設定/ setup /g;
    s/の管理/ administration /;
    s/設定/ setup /g;
    s/選択/ choice /g;
    s/管理/ administration /;

    s/メニュー/ menu /;
    s/アカウント/ account /g;
    s/メールアドレス/ Email address /g;
    s/アドレス/ address /g;
    s/名/ name /g;
    s/パスワード/ password /g;
    s/メンバー/ member /g;
    s/1993-1999/1993-2000/g;

    # fix spaces
    s/\s+:/:/;
    s/([A-Za-z])\s+([A-Za-z])/$1 $2/g;

    print $_, "\n";
}


exit 0;
