package MIME;
# Copyright (C) 1993-94,1997 Noboru Ikuta <noboru@ikuta.ichihara.chiba.jp>
#
# mimer.pl: MIME decoder library Ver.2.02 (1997/12/30)

$main'mimer_version = 2.02;

# インストール : @INC のディレクトリ（通常は /usr/local/lib/perl）にコピー
#                して下さい。
#
# 使用例1 : require 'mimer.pl';
#           $from = "From: Noboru Ikuta / =?ISO-2022-JP?B?GyRCQDhFRBsoQg==?=";
#           $from .= "\n\t=?ISO-2022-JP?B?GyRCPjobKEI=?=";
#           $from .= " <noboru\@ikuta.ichihara.chiba.jp>";
#           print &mimedecode($from, "EUC");
#
# 使用例2 : # UNIXでBase64デコードする場合
#           require 'mimer.pl';
#           undef $/;
#           $body = <>;
#           print &bodydecode($body);
#           print &bdeflush;
#
# &bodydecode($data,$coding):
#   Base64形式またはQuoted-Printable形式のデータをデコードする。
#   第2パラメータに"qp"または"b64"を指定することによりコーディング形式
#   を指示することができる。第2パラメータを省略するとBase64形式として
#   処理される。
#   Base64形式のデコードの場合は、4バイト単位で変換するので、渡された
#   データのうち半端な部分はバッファに保存され次に呼ばれたときに処理
#   される。最後にバッファに残ったデータは&bdeflushを呼ぶことにより処理
#   されバッファからクリアされる。
#   Quoted-Printable形式のデコードの場合は、上記のバッファは使用しない
#   ので&bdeflushを呼ぶ必要はないが呼んでも構わない(何もしない)。
#
# &bdeflush($coding):
#   第1パラメータに"b64"または"qp"を指定することにより、それぞれBase64
#   形式またはQuoted-Printable形式のデコードを指定することができる。
#   第1パラメータに何も指定しなければBase64形式として処理される。
#   &bodydecodeが処理し残したデータがバッファに残っていれば、それを処理
#   しバッファをクリアする。
#   Base64のデコードの場合、正常にエンコードされたデータであれば4バイト
#   の倍数の長さのはずなので最後にデータがバッファ上に残ることは考えられ
#   ないが、一つのデータを(1回または何回かに分けて)&bodydecodeした後に
#   念のため1回呼ぶことを推奨する。
#
# &mimedecode($text,$kanjicode):
#   第1パラメータのデータ中にencoded-word("=?ISO2022-JP?B?"と"?="に囲ま
#   れた文字列、RFC2047参照)があればその部分を選び出してデコードする。
#   第2パラメータとして"EUC"または"SJIS"を指定するとデコードした部分の
#   日本語文字列部分を指定した文字コードに変換する。
#   第2パラメータを省略(または無効な値を指定)するとJISコードを返す。
#   RFC2047に基づき、encoded-wordではさまれたLWS(空白)は削除する。
#
# 配布条件 : 著作権は放棄しませんが、配布・改変は自由とします。改変して
#            配布する場合は、オリジナルと異なることを明記し、オリジナル
#            のバージョンナンバーに改変版バージョンナンバーを付加した形
#            例えば Ver.2.02-XXXXX のようなバージョンナンバーを付けて下
#            さい。なお、Copyright表示は変更しないでください。
#
# 注意 : &mimedecodeをjperl1.X(の2バイト文字対応モード)で使用するときは、
#        tr/// の書き方が異なりますので、必要に応じて 'sub j2e'のコメント(#)
#        を付け替えてください。jperl1.4を-Llatinオプション付きで使用する
#        場合および EUC変換機能を使わない場合はその必要はありません。
#        なお、Perl5対応のjperlは試したことがないのでどのような動作になる
#        かわかりません。
#
# 参照 : RFC1468, RFC2045, RFC2047

## MIME base64 アルファベットテーブル（RFC2045より）
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

## ASCII, 7bit JISの各々にマッチするパターン
$match_ascii = '\x1b\([BHJ]([\t\x20-\x7e]*)';
$match_jis = '\x1b\$[@B](([\x21-\x7e]{2})*)';

## charset=`ISO-2022-JP',encoding=`B' の encoded-word にマッチするパターン
$match_mime = '=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';

## &bodydecode が使う処理残しデータ用バッファ
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
    local($_, $coding) = @_;
    if (!defined($coding) || $coding eq "" || $coding eq "b64"){
	s/[^A-Za-z0-9\+\/\=]//g;
	$_ = $bdebuf . $_;
	local($cut) = int((length)/4)*4;
	$bdebuf = substr($_, $cut+$[);
	$_ = substr($_, $[, $cut);
	&base64decode($_);
    }elsif ($coding eq "qp"){
	&qpdecode($_);
    }
}

## &bdeflush interface ##
sub main'bdeflush {
    local($coding) = @_;
    local($ret) = "";
    if ((!defined($coding) || $coding eq "" || $coding eq "b64")
	&& $bdebuf ne ""){
        $ret = &base64decode($bdebuf);
        $bdebuf = "";
    }
    $ret;
}

## BASE64 デコーディング
sub base64decode {
    local($bin) = @_;
    $bin = join('', @code{split(//, $bin)});
    $bin = pack("B".(length($bin)>>3<<3), $bin);
}

## Quoted-Printable デコーディング
sub qpdecode {
    local($qptxt) = @_;

    # ソフト改行を削除
    $qptxt =~ s/=\r\n//g;
    $qptxt =~ s/=\n//g;
    $qptxt =~ s/=\r//g;

    # 不適切な場所に`='がある場合は標準エラー出力にメッセージを出力する
    if ($qptxt =~ /=[^0-9A-Za-z]/){
	print STDERR "[MIME::qpdecode] Illegal '=' character exists.\n";
    }

    # 16進表現の復元
    $qptxt =~ s/=([0-9A-Fa-f]{2})/pack("C",hex($1))/ge;

    $qptxt;
}

## 漢字コード変換(JIS to EUC/SJIS)
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

## 7bit JIS を EUC に変換
sub j2e {
    local($_) = @_;
    tr/\x21-\x7e/\xa1-\xfe/;  # for original perl (or jperl -Llatin)
#   tr/\x21-\x7e/\xa1-\xfe/B; # for jperl
    $_;
}

## 7bit JIS を Shift-JIS に変換
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
