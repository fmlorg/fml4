# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id:$

package Japanese;

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

    require 'jcode.pl'; # not needed but try again

    &jcode'convert(*x, 'euc'); #';

    if ($CUT_OFF_RERERE_PATTERN) {
	&jcode'convert(*CUT_OFF_RERERE_PATTERN, 'euc'); #';
    }

    $limit = 10;
    while ($limit-- > 0) {
	$y = $x;
	$x =~ s/^[\s]*//;
	$x =~ s/^��*//;
	$x =~ s/^(�ֿ�:|�ֿ���|��:|�֡�|�ң�:|�ңš�|�ң�:|�ң塧)//;
	if ($CUT_OFF_RERERE_PATTERN) { $x =~ s/^($CUT_OFF_RERERE_PATTERN)//;}
	last if $y eq $x;
    }

    if ($CUT_OFF_RERERE_HOOK) {
	eval($CUT_OFF_RERERE_HOOK);
	&Log($@) if $@;
    }

    &jcode'convert(*x, 'jis'); #';
    $x;
}

1;
