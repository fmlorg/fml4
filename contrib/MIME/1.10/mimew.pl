package MIME;
# Copyright (C) 1993-94 Noboru Ikuta <ikuta@crc.co.jp>
#
# mimew.pl: MIME-header encoder library Ver.1.10 ('94/06/12)
#
# ���󥹥ȡ��� : @INC �Υǥ��쥯�ȥ���̾�� /usr/local/lib/perl�ˤ�
#                ���ԡ����Ʋ�������
#
# ������ : require 'mimew.pl';
#          $from = 'From: Noboru Ikuta / ���� �� <ikuta@crc.co.jp>';
#          print &mimeencode($from);
#
# mimeencode:
#   ��������ʬ��7bit JIS(ISO-2022-JP)���Ѵ���MIME(Part2)���󥳡��ɤ��롣
#   ɬ�פ˱�����encoded-word��ʬ���encoded-word������Ǥι�ʬ���Ԥ���
#
#   ���������ɤμ�ưȽ�Ǥϡ�1�Ԥ�SJIS��EUC�����ߤ��Ƥ����������ƴ�
#   �������ɤκ��ߤˤ��б����Ƥ��ޤ���SJIS��EUC���ɤ����Ƥ�Ƚ�ǤǤ���
#   ���Ȥ��� $often_use_kanji �����ꤵ��Ƥ�����������ɤȤߤʤ��ޤ���
#   ISO-2022-JP(JIS����)�Υ��������ץ������󥹤� $jis_in �� $jis_out ��
#   ���ꤹ�뤳�Ȥˤ���ѹ���ǽ�Ǥ���

$often_use_kanji = 'EUC'; # or 'SJIS'

$jis_in  = "\x1b\$B"; # ESC-$-B ( or ESC-$-@ )
$jis_out = "\x1b\(B"; # ESC-(-B ( or ESC-(-J )

# ���۾�� : ������������ޤ��󤬡����ۡ����Ѥϼ�ͳ�Ȥ��ޤ������Ѥ���
#            ���ۤ�����ϡ����ꥸ�ʥ�Ȱۤʤ뤳�Ȥ������������ꥸ�ʥ�
#            �ΥС������ʥ�С��˲����ǥС������ʥ�С����ղä�����
#            �㤨�� Ver.1.10-XXXXX �Τ褦�ʥС������ʥ�С����դ��Ʋ�
#            �������ʤ���Copyright ɽ�����ѹ����ʤ��Ǥ���������
#
# ��� : mimeencode��jperl�ʤ�2�Х���ʸ���б��⡼�ɡˤǻ��Ѥ���ȡ�SJIS
#        ��EUC�򤦤ޤ�7bit JIS(ISO-2022-JP)���Ѵ��Ǥ��ޤ���
#        ���Ϥ˴ޤޤ��ʸ����7bit JIS(ISO-2022-JP)��ASCII�ΤߤǤ��뤳��
#        ���ݾڤ���Ƥ�����������ɬ��original�αѸ��Ǥ�perl�ʤޤ���
#        jperl1.4�ʾ�� -Llatin ���ץ�����դ��ˤ�ư�����Ƥ���������
#
# ���� : RFC1521, RFC1522, RFC1468

## MIME base64 ����ե��٥åȥơ��֥��RFC1521����
%mime = (
"000000", "A",  "000001", "B",  "000010", "C",  "000011", "D",
"000100", "E",  "000101", "F",  "000110", "G",  "000111", "H",
"001000", "I",  "001001", "J",  "001010", "K",  "001011", "L",
"001100", "M",  "001101", "N",  "001110", "O",  "001111", "P",
"010000", "Q",  "010001", "R",  "010010", "S",  "010011", "T",
"010100", "U",  "010101", "V",  "010110", "W",  "010111", "X",
"011000", "Y",  "011001", "Z",  "011010", "a",  "011011", "b",
"011100", "c",  "011101", "d",  "011110", "e",  "011111", "f",
"100000", "g",  "100001", "h",  "100010", "i",  "100011", "j",
"100100", "k",  "100101", "l",  "100110", "m",  "100111", "n",
"101000", "o",  "101001", "p",  "101010", "q",  "101011", "r",
"101100", "s",  "101101", "t",  "101110", "u",  "101111", "v",
"110000", "w",  "110001", "x",  "110010", "y",  "110011", "z",
"110100", "0",  "110101", "1",  "110110", "2",  "110111", "3",
"111000", "4",  "111001", "5",  "111010", "6",  "111011", "7",
"111100", "8",  "111101", "9",  "111110", "+",  "111111", "/",
);

## JIS������(byte��)��encoded-word ��ʸ�����б�
%mimelen = (
 8,30, 10,34, 12,34, 14,38, 16,42,
18,42, 20,46, 22,50, 24,50, 26,54,
28,58, 30,58, 32,62, 34,66, 36,66,
38,70, 40,74, 42,74,
);
$limit=74;

## null bit�������� padʸ���������Τ���Υơ��֥�
@zero = ( "", "00000", "0000", "000", "00", "0" );
@pad  = ( "", "===",   "==",   "=" );

## ASCII, 7bit JIS, Shift-JIS �ڤ� EUC �γơ��˥ޥå�����ѥ�����
$match_ascii = '\x1b\([BHJ]([\t\x20-\x7e]*)';
$match_jis = '\x1b\$[@B](([\x21-\x7e]{2})*)';
$match_sjis = '([\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc])+';
$match_euc  = '([\xa1-\xfe]{2})+';

## MIME Part 2(charset=`ISO-2022-JP',encoding=`B') �� head �� tail
$mime_head = '=?ISO-2022-JP?B?';
$mime_tail = '?=';

## mimeencode interface ##
sub main'mimeencode {
    local($_) = @_;
    s/$match_jis/$jis_in$1/go;
    s/$match_ascii/$jis_out$1/go;
    $kanji = &checkkanji;
    s/$match_sjis/&s2j($&)/geo if ($kanji eq 'SJIS');
    s/$match_euc/&e2j($&)/geo if ($kanji eq 'EUC');
    s/(\x1b[\$\(][BHJ@])+/$1/go;
    1 while s/$match_jis/&mimeencode($&,$`,$')/eo;
    s/$match_ascii/$1/go;
    $_;
}

## MIME ���󥳡��ǥ���
sub mimeencode {
    local($_, $befor, $after) = @_;
    local($back, $forw, $blen, $len, $flen, $str, @mline);
    $befor = substr($befor, rindex($befor, "\n")+1);
    $after = substr($after, 0, index($after, "\n")-$[);
    $back = " " unless ($befor eq ""
                     || $befor =~ /[ \t\(]$/);
    $forw = " " unless ($after =~ /^\x1b\([BHJ]$/
                     || $after =~ /^\x1b\([BHJ][ \t\)]/);
    $blen = length($befor);
    $flen = length($forw)+length($&)-3 if ($after =~ /^$match_ascii/o);
    $len = length($_);
    return "" if ($len <= 3);
    if ($blen + $mimelen{$len>39 ? 42 : $len+3} > $limit){
        if ($limit-$blen < 30){
            $len = 0;
        }else{
            $len = int(($limit-$blen-26)/4)*2+3;
        }
        if ($len >= 5){
            $str = substr($_, 0, $len).$jis_out;
            $str = unpack("B".((length($str))<<3), $str);
            $str .= $zero[(length($str))%6];
            $str =~ s/.{6}/$mime{$&}/go;
            $str .= $pad[(length($str))%4];
            $str = $mime_head.$str.$mime_tail;
            $back.$str."\n ".$jis_in.substr($_, $len);
        }else{
            "\n ".$_;
        }
    }else{
        $_ .= $jis_out;
        $_ = unpack("B".((length)<<3), $_);
        $_ .= $zero[(length)%6];
        s/.{6}/$mime{$&}/go;
        $_ .= $pad[(length)%4];
        $_ = $back.$mime_head.$_.$mime_tail;
        if ($blen + (length) + $flen > $limit){
            $_."\n ";
        }else{
            $_.$forw;
        }
    }
}

## Shift-JIS �� EUC �Τɤ���δ��������ɤ��ޤޤ�뤫������å�
sub checkkanji {
    local($sjis,$euc);
    $sjis += length($&) while(/$match_sjis/go);
    $euc  += length($&) while(/$match_euc/go);
    return 'NONE' if ($sjis == 0 && $euc == 0);
    return 'SJIS' if ($sjis > $euc);
    return 'EUC'  if ($sjis < $euc);
    $often_use_kanji;
}

## EUC �� 7bit JIS ���Ѵ�
sub e2j {
    local($_) = @_;
    tr/\xa1-\xfe/\x21-\x7e/;
    $jis_in.$_.$jis_out;
}

## Shift-JIS �� 7bit JIS ���Ѵ�
sub s2j {
    local($string);
    local(@ch) = split(//, $_[0]);
    while(($j1,$j2)=unpack("CC",shift(@ch).shift(@ch))){
        if ($j2 > 0x9e){
            $j1 = (($j1>0x9f ? $j1-0xb1 : $j1-0x71)<<1)+2;
            $j2 -= 0x7e;
        }
        else{
            $j1 = (($j1>0x9f ? $j1-0xb1 : $j1-0x71)<<1)+1;
            $j2 -= ($j2>0x7e ? 0x20 : 0x1f);
        }
        $string .= pack("CC", $j1, $j2);
    }
    $jis_in.$string.$jis_out;
}
1;
