# $FML: virus_check.ph,v 1.15 2002/05/23 14:57:57 fukachan Exp $
# 
# これは perl script です。
#
# 全ＭＬに一気に適用するためには
#    /var/spool/ml/etc/fml/site_force.ph
# に付け加えて使用します(pathはよみかえてくださいね)。
#
# フィルタリング全般
#    http://www.fml.org/fml/Japanese/filter/index.html
#
# チュートリアル
#    http://www.fml.org/fml/Japanese/tutorial.html
#
# CERT ADVISORY など
#   CERT Summary CS-2001-04 nimda など最近のウィルスについてのサマリ？  
#

# フィルタリング ON
$USE_DISTRIBUTE_FILTER   = 1;

# 著名なウィルス(の original)
# どうせ変形版がすぐにでるので subject: で弾くのは気安めだが
# やらないよりはましだとおもう
# X-Spanska                 happy99 original
# Subject: Important ...    Melissa original    (Word's macro)
# Subject: ILOVEYOU         I Love You original (VB script)
&DEFINE_FIELD_PAT_TO_REJECT("X-Spanska", ".*Yes.*");
&DEFINE_FIELD_PAT_TO_REJECT("Subject", ".*Important Message From .*");
&DEFINE_FIELD_PAT_TO_REJECT("Subject", "ILOVEYOU");

# Word ファイルなどにマクロが仕込まれているかどうかを検査する
# virus かどうかを検査しているわけではないので弾き過ぎるのは
# 承知の上で使うこと 
#   例: Melissa シリーズ
# 
$FILTER_ATTR_REJECT_MS_GUID = 1;

# (メモリ使用量がぐーんと上がるとおもうが)
# 正規表現が複数行マッチをするように設定する。
# 設定を有効にするなら次の行の先頭の"#"(コメント)をはずす
#    $DISTRIBUTE_FILTER_HOOK .= q@ $* = 1; @;


# ちょっと複雑な HOOK
# XXX multipart の場合のみ適用
$DISTRIBUTE_FILTER_HOOK .= q#
    if ($e{'h:content-type:'} =~ /multipart/i) {
	if ($e{'Body'} =~ /Content.*\.vbs|(filename|name)=.*\.vbs/i) {
	    return 'VB script attatchment';
	}

	if ($e{'Body'} =~ /(filename|name)=.*\.Pretty Park\.exe/i ) {
	    return 'original Pretty Park virus';
	}

	if ($e{'Body'} =~ /(filename|name)=.*\.Pretty.*Park.*\.exe/i ) {
	    return 'original Pretty Park familly ?';
	}

	if ($e{'Body'} =~ /(filename|name)=.*search.*URL.*\.exe/i ) {
	    return 'P2000 virus familly?';
	}
    }
#;

# さらに HOOK へつけたす
# このHOOKを使うなら 上のHOOK例は含まれているので不必要
# XXX multipart の場合のみ適用
#
#   ファイル拡張子 .xxx が危なそうなもの(?)はかたっぱしから認めない
#   .vbs: VB script
#   .js : Java script ?
#   .exe: executable
#   .doc: word
#   .rtf: RTF (embedded object in RTF is possible?) ?
#   .pif: win32/MTX sircam?
#   .scr: win32/MTX
#   .lnk: sircam ?  
$DISTRIBUTE_FILTER_HOOK .= q#
    my($extension) = 
	'lnk|hta|com|pif|vbs|vbe|js|jse|exe|bat|cmd|vxd|scr|shm|dll';
    if ($e{'h:content-type:'} =~ /multipart/i) {
	if ($e{'Body'} =~ /(filename|name)=.*\.($extension)/i) {
	    return 'dangerous attatchment ?';
	}
    }
#;


#
# uuencode されてるものはすべからく怪しい？
# (このチェックを有効にするには以下の行頭の # をはずしてください)
# Against MyParty et.al.
#
$DISTRIBUTE_FILTER_HOOK .= q{
    if ($e{'Body'} =~ /^begin\s+\d{3}\s+\S+|\nbegin\s+\d{3}\s+\S+/m) {
	return 'uuencoded attachment';
    }
};


# 参照: fml-help:01853
# Norton Antivirus for Gateways を使っている場合、
# ウィルスと判定されたメールのウィルス部分が
#    除去されてテキスト（text/plain; name="DELETED[番号].TXT"）
# という案内にさしかわるケースがあるそうです。
# 例: http://www.firstserver.ne.jp/function/l_virus.html
#
# でも、これだとウィルス駆除されたどうでもいいメールも流れてしまうです。
# このメールを弾きたい場合 (0) を (1) にしてください。 
$DISTRIBUTE_FILTER_HOOK .= q#
    if ($e{'h:content-type:'} =~ /multipart/i) {
	my $re = ';\s*(file)?name='
	    .'("(DELETED\d+\.TXT|.*\.($extension))"|.*\.($extension))';
	if ($e{'Body'} =~ /$re/i) {
	    return 'disabled virus attachment';
	}
    }
# if (0);


# XXX TODO 
#
#   MIME encoding されているものを一度分解してからの検査モード
#
#   Index server だと uuencode されていることがあるそうなので
#   uuencode も一度分解してから検査するモード
#   uuencode, base64, quoted-printable, binhex, ... 

1;
