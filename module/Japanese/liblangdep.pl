# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

# patch from OGAWA Kunihiko <kuni@edit.ne.jp>
# fml-support: 07599, 07600
package Japanese;

sub Japanese'Log	{ &main'Log(@_) };

# fml-support: 07507
# sub CutOffRe
# {
#    いままでどおりの Re: とかとっぱらう 
#
#   if ($LANGUAGE eq 'Japanese') {
#	日本語処理依存ライブラリへ飛ぶ
#	この中で $CUT_OFF_PATTERN (config.ph)などにしたがって
#	切り落とすのも良し（きっと日本語を書くだろうとおもうわけで
#	で、このライブラリの先で実行する）
#   }
#
#   run-hooks $CUT_OFF_HOOK(ユーザ定義HOOK)
#}
# レレレ対策
sub CutOffReReRe
{
    local($x) = @_;
    local($y, $limit);
    local($pattern);

    require 'jcode.pl'; # not needed but try again

    # import
    @Import = (CUT_OFF_RERERE_PATTERN, CUT_OFF_RERERE_HOOK);
    for (@Import) { eval("\$Japanese'$_ = \$main'$_;");}

    &jcode'convert(*x, 'euc'); #';

    if ($CUT_OFF_RERERE_PATTERN) {
	&jcode'convert(*CUT_OFF_RERERE_PATTERN, 'euc'); #';
    }

    # apply patch from OGAWA Kunihiko <kuni@edit.ne.jp> 
    #            fml-support:7626 7653 07666
    #            Re: Re2:   Re[2]:     Re(2):     Re^2:    Re*2:
    $pattern  = 'Re:|Re\d+:|Re\[\d+\]:|Re\(\d+\):|Re\^\d+:|Re\*\d+:';
    $pattern .= '|(返信|返|ＲＥ|Ｒｅ)(\s*:|：)';
    $pattern .= '|' . $CUT_OFF_RERERE_PATTERN if ($CUT_OFF_RERERE_PATTERN);

    # for i-mode? What is 'Re>' ?
    $pattern .= '|Re>';

    # fixed by OGAWA Kunihiko <kuni@edit.ne.jp> (fml-support: 07815)
    # $x =~ s/^((\s*|(　)*)*($pattern)\s*)+/Re: /oi;
    $x =~ s/^((\s|(　))*($pattern)\s*)+/Re: /oi;

    if ($CUT_OFF_RERERE_HOOK) {
	eval($CUT_OFF_RERERE_HOOK);
	&Log($@) if $@;
    }

    &jcode'convert(*x, 'jis'); #';
    $x;
}

1;
