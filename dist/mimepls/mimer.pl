package MIME;
# Copyright (C) 1993-94 Noboru Ikuta <ikuta@crc.co.jp>
#
# mimer.pl: MIME base64 decoder library Ver.2.00alpha ('94/08/27)
#
# ���󥹥ȡ��� : @INC �Υǥ��쥯�ȥ���̾�� /usr/local/lib/perl�ˤ˥��ԡ�
#                ���Ʋ�������
#
# ������1 : require 'mimer.pl';
#           $from = "From: Noboru Ikuta =?ISO-2022-JP?B?GyRCQDhFRBsoQg==?=";
#           $from .= "\n\t=?ISO-2022-JP?B?GyRCPjobKEI=?= <ikuta@crc.co.jp>";
#           print &mimedecode($from, "EUC");
#
# ������2 : # UNIX �ξ��
#           require 'mimer.pl';
#           undef $/;
#           $body = <>;
#           print &bodydecode($body);
#           print &bdeflush;
#
# &bodydecode:
#   MIME base64 encoding ���줿�ǡ�����ǥ����ɤ��롣���Х���ñ�̤��Ѵ���
#   ��Τǡ��Ϥ��줿�ǡ����Τ���Ⱦü����ʬ�ϥХåե�����¸���켡�˸ƤФ�
#   ���Ȥ��˽�������롣�Ǹ�˥Хåե��˻Ĥä��ǡ����� &bdeflush ��Ƥ֤�
#   �Ȥˤ���������Хåե����饯�ꥢ����롣
#
# &bdeflush:
#   &bodydecode ���������Ĥ����ǡ�����ʤ⤷����С˽������롣����˥���
#   �����ɤ��줿�ǡ����Ǥ���У��Х��Ȥ��ܿ���Ĺ���ΤϤ��ʤΤǺǸ�˥ǡ�
#   �����Хåե���˻Ĥ뤳�ȤϹͤ����ʤ�������ĤΥǡ�����ʣ���ޤ���
#   ���󤫤�ʬ���ơ�&bodydecode �������ǰ�Τ��ᣱ��Ƥ֤��Ȥ�侩���롣
#
# &mimedecode:
#   encoded-word��"=?ISO2022-JP?B?" �� "?=" �˰Ϥޤ줿ʸ����ˤ򥵡�����
#   �ƥǥ����ɤ��롣�裲�ѥ�᡼���Ȥ��� "EUC" �ޤ��� "SJIS" ����ꤹ��
#   �ȥǥ����ɤ�����ʬ�δ��������ɤ�����Ū�˴����Ѵ����롣
#   �裲�ѥ�᡼�����ά�ʤޤ���̵�����ͤ����ˤ����JIS�����ɤ��֤롣
#   RFC1522�˴�Ť���encoded-word�ǤϤ��ޤ줿LWS�ʶ���ˤϺ�����롣
#
# ���۾�� : ������������ޤ��󤬡����ۡ����Ѥϼ�ͳ�Ȥ��ޤ������Ѥ���
#            ���ۤ�����ϡ����ꥸ�ʥ�Ȱۤʤ뤳�Ȥ������������ꥸ�ʥ�
#            �ΥС������ʥ�С��˲����ǥС������ʥ�С����ղä�����
#            �㤨�� Ver.2.00-XXXXX �Τ褦�ʥС������ʥ�С����դ��Ʋ�
#            �������ʤ���Copyright ɽ�����ѹ����ʤ��Ǥ���������
#
# ��� : &mimedecode��jperl�ʤ�2�Х���ʸ���б��⡼�ɡˤǻ��Ѥ���Ȥ��ϡ�
#        tr/// �ν������ۤʤ�ޤ��Τǡ�ɬ�פ˱����� 'sub j2e'�Υ����
#        ��(#)���դ��ؤ��Ƥ���������jperl1.4�ʾ�� -Llatin ���ץ������
#        ���ǻ��Ѥ����礪��� EUC�Ѵ���ǽ��Ȥ�ʤ����Ϥ���ɬ�פϤ�
#        ��ޤ���
#
# ���� : RFC1521, RFC1522, RFC1468

## MIME base64 ����ե��٥åȥơ��֥��RFC1521����
%code = (
"A", "000000",  "B", "000001",  "C", "000010",  "D", "000011",
"E", "000100",  "F", "000101",  "G", "000110",  "H", "000111",
"I", "001000",  "J", "001001",  "K", "001010",  "L", "001011",
"M", "001100",  "N", "001101",  "O", "001110",  "P", "001111",
"Q", "010000",  "R", "010001",  "S", "010010",  "T", "010011",
"U", "010100",  "V", "010101",  "W", "010110",  "X", "010111",
"Y", "011000",  "Z", "011001",  "a", "011010",  "b", "011011",
"c", "011100",  "d", "011101",  "e", "011110",  "f", "011111",
"g", "100000",  "h", "100001",  "i", "100010",  "j", "100011",
"k", "100100",  "l", "100101",  "m", "100110",  "n", "100111",
"o", "101000",  "p", "101001",  "q", "101010",  "r", "101011",
"s", "101100",  "t", "101101",  "u", "101110",  "v", "101111",
"w", "110000",  "x", "110001",  "y", "110010",  "z", "110011",
"0", "110100",  "1", "110101",  "2", "110110",  "3", "110111",
"4", "111000",  "5", "111001",  "6", "111010",  "7", "111011",
"8", "111100",  "9", "111101",  "+", "111110",  "/", "111111",
);

## ASCII, 7bit JIS�γơ��˥ޥå�����ѥ�����
$match_ascii = '\x1b\([BHJ]([\t\x20-\x7e]*)';
$match_jis = '\x1b\$[@B](([\x21-\x7e]{2})*)';

## charset=`ISO-2022-JP',encoding=`B' �� encoded-word �˥ޥå�����ѥ�����
$match_mime = '=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';

## &bodydecode ���Ȥ������Ĥ��ǡ����ѥХåե�
$bdebuf = "";

## mimedecode interface ##
sub main'mimedecode {
    local($_, $kout) = @_;
    1 while s/($match_mime)[ \t]*\n?[ \t]+($match_mime)/$1$3/o;
    s/$match_mime/&kconv(&base64decode($1))/geo;
    s/(\x1b[\$\(][BHJ@])+/$1/g;
    1 while s/(\x1b\$[B@][\x21-\x7e]+)\x1b\$[B@]/$1/;
    1 while s/(\x1b\([BHJ][\t\x20-\x7e]+)\x1b\([BHJ]/$1/;
    s/^([\t\x20-\x7e]*)\x1b\([BHJ]/$1/;
    $_;
}

## bodydecode interface ##
sub main'bodydecode {
    local($_) = @_;
    s/[^A-Za-z0-9\+\/\=]//g;
    $_ = $bdebuf . $_;
    local($cut) = int((length)/4)*4;
    $bdebuf = substr($_, $cut+$[);
    $_ = substr($_, $[, $cut);
    &base64decode($_);
}

## &bdeflush interface ##
sub main'bdeflush {
    local($ret) = "";
    if ($bdebuf ne ""){
        $ret = &base64decode($bdebuf);
        $bdebuf = "";
    }
    $ret;
}

## MIME �ǥ����ǥ���
sub base64decode {
    local($bin) = @_;
    $bin = join('', @code{split(//, $bin)});
    $bin = pack("B".(length($bin)>>3<<3), $bin);
}

## �����������Ѵ�(JIS to EUC/SJIS)
sub kconv {
    local($_) = @_;
    if ($kout eq "EUC"){
        s/$match_jis/&j2e($1)/geo;
        s/$match_ascii/$1/go;
    }
    elsif ($kout eq "SJIS"){
        s/$match_jis/&j2s($1)/geo;
        s/$match_ascii/$1/go;
    }
    $_;
}

## 7bit JIS �� EUC ���Ѵ�
sub j2e {
    local($_) = @_;
    tr/\x21-\x7e/\xa1-\xfe/;  # for original perl (or jperl -Llatin)
#   tr/\x21-\x7e/\xa1-\xfe/B; # for jperl
    $_;
}

## 7bit JIS �� Shift-JIS ���Ѵ�
sub j2s {
    local($string);
    local(@ch) = split(//, $_[0]);
    while(($j1,$j2) = unpack("CC", shift(@ch).shift(@ch))){
        if ($j1 % 2) {
            $j1 = ($j1>>1) + ($j1 >= 0x5f ? 0xb1 : 0x71);
            $j2 += ($j2 > 0x5f ? 0x20 : 0x1f);
        }else {
            $j1 = ($j1>>1) + ($j1 > 0x5f ? 0xb0 : 0x70);
            $j2 += 0x7e;
        }
        $string .= pack("CC", $j1, $j2);
    }
    $string;
}
1;
