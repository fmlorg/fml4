#!/usr/local/bin/perl
#
# Covert Shift-JIS(MachineDependCode, Hankaku-Kana) to
#	JIS Code(NonMachineDepend, Zenkaku-Kana)
#
# Auther: Toshiyuki Nakano (t-nakano@marimo.org)
# Create: Jun 15, 1999
# Modify: Mar 10, 2000
#		for Mail JConvert (recognize header)
#		Input and Output => JIS

#
# $Id: libhankaku2zenkaku.pl,v 1.3 2000/06/12 11:22:07 fukachan Exp $
#

sub FixJapaneseMDChars
{
    local(*e) = @_;
    local($p, $pp, $buf, $xbuf, $outbuf, $c);

    $c = $pp = 0;
    while (1) {
	# split() to each line
	if (($p = index($e{'Body'}, "\n", $pp)) > 0) {
	    $line++;
	    $buf  = substr($e{'Body'}, $pp, $p - $pp);
	    $xbuf = $buf;
	    $buf  = &ConvertHankakuToZenkaku($buf) if $buf;
	    $outbuf .= $buf. "\n";
	    $pp = $p + 1;

	    if ($xbuf ne $buf) { $c++;}
	}
	else {
	    last;
	}
    }

    if ($c > 0) {
	$e{'Body'} = $outbuf;
	&Log("hankaku to zenkaku conversion: $c lines");
    }

    # XXX change here to "if ($debug_hankaku) {"
    if (1) {
	&Log("(debug)hankaku to zenkaku conversion: $c lines");
    }
}

package han2zen;

sub JConvert;	# Convert Code

sub main::ConvertHankakuToZenkaku
{
    my ($input) = @_;

    require 'jcode.pl';

    &InitTable;

    &jcode::jis(&JConvert(jcode::sjis($input)));
}


sub InitTable
{
    # MachineDepend
    %kishuizon =
	(# Number with circle
	 0x8740 => "(1)",
	 0x8741 => "(2)",
	 0x8742 => "(3)",
	 0x8743 => "(4)",
	 0x8744 => "(5)",
	 0x8745 => "(6)",
	 0x8746 => "(7)",
	 0x8747 => "(8)",
	 0x8748 => "(9)",
	 0x8749 => "(10)",
	 0x874a => "(11)",
	 0x874b => "(12)",
	 0x874c => "(13)",
	 0x874d => "(14)",
	 0x874e => "(15)",
	 0x874f => "(16)",
	 0x8750 => "(17)",
	 0x8751 => "(18)",
	 0x8752 => "(19)",
	 0x8753 => "(20)",
	 # Roman number/upper case
	 0x8754 => "I",
	 0x8755 => "II",
	 0x8756 => "III",
	 0x8757 => "IV",
	 0x8758 => "V",
	 0x8759 => "VI",
	 0x875a => "VII",
	 0x875b => "VIII",
	 0x875c => "IX",
	 0x875d => "X",
	 # Units
	 0x875f => "ミリ",
	 0x8760 => "キロ",
	 0x8761 => "センチ",
	 0x8762 => "メートル",
	 0x8763 => "グラム",
	 0x8764 => "トン",
	 0x8765 => "アール",
	 0x8766 => "ヘクタール",
	 0x8767 => "リットル",
	 0x8768 => "ワット",
	 0x8769 => "カロリー",
	 0x876a => "ドル",
	 0x876b => "セント",
	 0x876c => "パーセント",
	 0x876d => "ミリバール",
	 0x876e => "ページ",
	 0x876f => "mm",
	 0x8770 => "cm",
	 0x8771 => "km",
	 0x8772 => "mg",
	 0x8773 => "kg",
	 0x8774 => "cc",
	 0x8775 => "m2",
	 # Symbols
	 0x8782 => "No.",
	 0x8783 => "K.K.",
	 0x8784 => "TEL",
	 0x8785 => "(上)",
	 0x8786 => "(中)",
	 0x8787 => "(下)",
	 0x8788 => "(左)",
	 0x8789 => "(右)",
	 0x878a => "(株)",
	 0x878b => "(有)",
	 0x878c => "(代)",
	 0x878d => "明治",
	 0x878e => "大正",
	 0x878f => "昭和",
	 0x877e => "平成",
	 # Roman number/lower case
	 0xfa40 => "i",
	 0xfa41 => "ii",
	 0xfa42 => "iii",
	 0xfa43 => "iv",
	 0xfa44 => "v",
	 0xfa45 => "vi",
	 0xfa46 => "vii",
	 0xfa47 => "viii",
	 0xfa48 => "ix",
	 0xfa49 => "x"
	 );

    # Hankaku-Kana/Normal
    @normal =
	(' ',
	 '。',
	 '「',
	 '」',
	 '、',
	 '・',
	 'ヲ',
	 'ァ',
	 'ィ',
	 'ゥ',
	 'ェ',
	 'ォ',
	 'ャ',
	 'ュ',
	 'ョ',
	 'ッ',
	 'ー',
	 'ア',
	 'イ',
	 'ウ',
	 'エ',
	 'オ',
	 'カ',
	 'キ',
	 'ク',
	 'ケ',
	 'コ',
	 'サ',
	 'シ',
	 'ス',
	 'セ',
	 'ソ',
	 'タ',
	 'チ',
	 'ツ',
	 'テ',
	 'ト',
	 'ナ',
	 'ニ',
	 'ヌ',
	 'ネ',
	 'ノ',
	 'ハ',
	 'ヒ',
	 'フ',
	 'ヘ',
	 'ホ',
	 'マ',
	 'ミ',
	 'ム',
	 'メ',
	 'モ',
	 'ヤ',
	 'ユ',
	 'ヨ',
	 'ラ',
	 'リ',
	 'ル',
	 'レ',
	 'ロ',
	 'ワ',
	 'ン',
	 '゛',
	 '゜'
	 );

    # Hankaku-Kana/Dakuten
    @dakuten =
	('', # *SP*
	 '', # 。
	 '', # 「
	 '', # 」
	 '', # 、
	 '', # ・
	 '', # ヲ
	 '', # ァ
	 '', # ィ
	 '', # ゥ
	 '', # ェ
	 '', # ォ
	 '', # ャ
	 '', # ュ
	 '', # ョ
	 '', # ッ
	 '', # ー
	 '', # ア
	 '', # イ
	 'ヴ',
	 '', # エ
	 '', # オ
	 'ガ',
	 'ギ',
	 'グ',
	 'ゲ',
	 'ゴ',
	 'ザ',
	 'ジ',
	 'ズ',
	 'ゼ',
	 'ゾ',
	 'ダ',
	 'ヂ',
	 'ヅ',
	 'デ',
	 'ド',
	 '', # ナ
	 '', # ニ
	 '', # ヌ
	 '', # ネ
	 '', # ノ
	 'バ',
	 'ビ',
	 'ブ',
	 'ベ',
	 'ボ',
	 '', # マ
	 '', # ミ
	 '', # ム
	 '', # メ
	 '', # モ
	 '', # ヤ
	 '', # ユ
	 '', # ヨ
	 '', # ラ
	 '', # リ
	 '', # ル
	 '', # レ
	 '', # ロ
	 '', # ワ
	 '', # ン
	 '', # ゛
	 ''  # ゜
	 );

    # Hankaku-Kana/Handakuten
    @handakuten =
	('', # *SP*
	 '', # 。
	 '', # 「
	 '', # 」
	 '', # 、
	 '', # ・
	 '', # ヲ
	 '', # ァ
	 '', # ィ
	 '', # ゥ
	 '', # ェ
	 '', # ォ
	 '', # ャ
	 '', # ュ
	 '', # ョ
	 '', # ッ
	 '', # ー
	 '', # ア
	 '', # イ
	 '', # ウ
	 '', # エ
	 '', # オ
	 '', # カ
	 '', # キ
	 '', # ク
	 '', # ケ
	 '', # コ
	 '', # サ
	 '', # シ
	 '', # ス
	 '', # セ
	 '', # ソ
	 '', # タ
	 '', # チ
	 '', # ツ
	 '', # テ
	 '', # ト
	 '', # ナ
	 '', # ニ
	 '', # ヌ
	 '', # ネ
	 '', # ノ
	 'パ',
	 'ピ',
	 'プ',
	 'ペ',
	 'ポ',
	 '', # マ
	 '', # ミ
	 '', # ム
	 '', # メ
	 '', # モ
	 '', # ヤ
	 '', # ユ
	 '', # ヨ
	 '', # ラ
	 '', # リ
	 '', # ル
	 '', # レ
	 '', # ロ
	 '', # ワ
	 '', # ン
	 '', # ゛
	 ''  # ゜
	 );
}

# Convert SJIS -> EUC with Hankaku-Kana & Machine-dependent
sub JConvert #(str) return $str
{
    my ($str) = @_;
    my ($len, $retstr);
    my ($i, $c0, $c1, $zp);
    
    $len = length($str);
    $retstr = '';
    for ($i = 0; $i < $len; $i++) {
	$c0 = substr($str, $i, 1);
	if (ord($c0) < 128) {
	    # ASCII
	    $retstr .= $c0;
	    next;
	}
	# 2byte code
	$i++;
	$c1 = substr($str, $i, 1);
	if (defined $kishuizon{(ord($c0) << 8) + ord($c1)}) {
	    # Machine depend code
	    $retstr .= $kishuizon{(ord($c0) << 8) + ord($c1)};
	    next;
	}
	if (((ord($c0) >= 0x81 && ord($c0) <= 0x9f) ||
	     (ord($c0) >= 0xe0 && ord($c0) <= 0xef)) &&
	    ((ord($c1) >= 0x40 && ord($c1) <= 0x7e) ||
	     (ord($c1) >= 0x80 && ord($c1) <= 0xfc))) {
	    # KANJI
	    $retstr .= jcode::euc($c0 . $c1);
	    next;
	}
	if (ord($c0) >= 0xa0 && ord($c0) <= 0xdf) {
	    # HANKAKU-KANA
	    $zp = ord($c0) - 0xa0;
	    if (ord($c1) == 0xde) {
		# DAKUTEN
		if ($dakuten[$zp] eq '') {
		    $retstr .= $normal[$zp];
		    $i--;
		} else {
		    $retstr .= $dakuten[$zp];
		}
	    } elsif (ord($c1) == 0xdf) {
		# HANDAKUTEN
		if ($handakuten[$zp] eq '') {
		    $retstr .= $normal[$zp];
		    $i--;
		} else {
		    $retstr .= $handakuten[$zp];
		}
	    } else {
		$retstr .= $normal[$zp];
		$i--;
	    }
	}
	# Invalid code / skip
    }

    return $retstr;
}

1;
