# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id: liblangdep.pl,v 1.5 2000/03/18 16:27:01 fukachan Exp $

# patch from OGAWA Kunihiko <kuni@edit.ne.jp>
# fml-support: 07599, 07600
package Japanese;

sub Japanese'Log	{ &main'Log(@_) };

# fml-support: 07507
# sub CutOffRe
# {
#    ���ޤޤǤɤ���� Re: �Ȥ��ȤäѤ餦 
#
#   if ($LANGUAGE eq 'Japanese') {
#	���ܸ������¸�饤�֥�������
#	������� $CUT_OFF_PATTERN (config.ph)�ʤɤˤ������ä�
#	�ڤ���Ȥ��Τ��ɤ��ʤ��ä����ܸ��񤯤����Ȥ��⤦�櫓��
#	�ǡ����Υ饤�֥�����Ǽ¹Ԥ����
#   }
#
#   run-hooks $CUT_OFF_HOOK(�桼�����HOOK)
#}
# �����к�
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
    $pattern .= '|(�ֿ�|��|�ң�|�ң�)(\s*:|��)';
    $pattern .= '|' . $CUT_OFF_RERERE_PATTERN if ($CUT_OFF_RERERE_PATTERN);

    $x =~ s/^((\s*|(��)*)*($pattern)\s*)+/Re: /oi;

    if ($CUT_OFF_RERERE_HOOK) {
	eval($CUT_OFF_RERERE_HOOK);
	&Log($@) if $@;
    }

    &jcode'convert(*x, 'jis'); #';
    $x;
}

1;
