#
# $FML$
#
# これは perl script です。
# 使い方は virus_check.ph などと同様です。
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

#
# 1. SPAM について 
#
#    フィルタの仕方には大きく分けて２とおりあります。
#    「送信元」で弾くか、メールのコンテンツで判断するか？です。


#
# Q: メールの内容に応じて弾く
#

# http://www.meti.go.jp/kohosys/press/0002285/
# ！ (←２バイト)で単語をはさんだフレーズを Subect: につけると
# SPAM は合法化されるのでしょうか？ (どういう法律じゃ〜)
# そういうわけで、弾いてみましょう。
# 弾きたい単語を | で区切って繋げて下さい↓
&DEFINE_FIELD_PAT_TO_REJECT('Subject', '！スパム！|！広告！');

# ”！なんでも！ ”を弾くと弾き過ぎかもしれません。
# が、その方が良いと言う場合は、以下のコメント( # )を外して見て下さい。
# &DEFINE_FIELD_PAT_TO_REJECT('Subject', '！\S+！');



#
# Q: 送信元に応じて弾く
#

# 送信元で弾く場合は、RBL を利用するのが普通ですし、
# メールサーバに弾く仕組みがあるので、それを利用することが多いです。
#     A1. まずは rbl でサーチ！ 一杯ページがみつかりまっせ:)
#     A2. postfix では maps_rbl_domains という変数を参照して下さい。
#     A3. qmail では rblsmtpd などに入れ替えるなどの手段があります。
#         まずは www.qmail.org からリンクをたどって下さい。
#     A4. sendmail は www.sendmail.org からたどろうね。


# リファレンス
#    SPAM のリスト
#    http://libertas.wirehub.net/spamlist.txt 
#

1;
