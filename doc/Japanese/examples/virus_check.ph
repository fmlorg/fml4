# $Id$
# 
# ����� perl script �Ǥ���
#
# ���̤ͣ˰쵤��Ŭ�Ѥ��뤿��ˤ�
#    /var/spool/ml/etc/fml/site_force.ph
# ���դ��ä��ƻ��Ѥ��ޤ�(path�Ϥ�ߤ����Ƥ���������)��
#
# �ե��륿�������
#    http://www.fml.org/fml/Japanese/filter/index.html
#
# ���塼�ȥꥢ��
#    http://www.fml.org/fml/Japanese/tutorial.html
#

# �ե��륿��� ON
$USE_DISTRIBUTE_FILTER   = 1;

# ��̾�ʥ����륹(�� original)
# �ɤ����ѷ��Ǥ������ˤǤ�Τ� subject: ���Ƥ��Τϵ��¤����
# ���ʤ����Ϥޤ����Ȥ��⤦
# X-Spanska                 happy99 original
# Subject: Important ...    Melissa original    (Word's macro)
# Subject: ILOVEYOU         I Love You original (VB script)
&DEFINE_FIELD_PAT_TO_REJECT("X-Spanska", ".*Yes.*");
&DEFINE_FIELD_PAT_TO_REJECT("Subject", ".*Important Message From .*");
&DEFINE_FIELD_PAT_TO_REJECT("Subject", "ILOVEYOU");

# Word �ե�����ʤɤ˥ޥ����Ź��ޤ�Ƥ��뤫�ɤ����򸡺�����
# virus ���ɤ����򸡺����Ƥ���櫓�ǤϤʤ��Τ��Ƥ��᤮��Τ�
# ���Τξ�ǻȤ����� 
#   ��: Melissa ���꡼��
# 
$FILTER_ATTR_REJECT_MS_GUID = 1;

# (��������̤�������Ⱦ夬��Ȥ��⤦��)
# ����ɽ����ʣ���ԥޥå��򤹤�褦�����ꤹ�롣
# �����ͭ���ˤ���ʤ鼡�ιԤ���Ƭ��"#"(������)��Ϥ���
#    $DISTRIBUTE_FILTER_HOOK .= q@ $* = 1; @;


# ����ä�ʣ���� HOOK
$DISTRIBUTE_FILTER_HOOK .= q#
    if ($e{'Body'} =~ /Content.*\.vbs|filename=.*\.vbs/i) {
	return 'VB script attatchment';
    }

    if ($e{'Body'} =~ /filename=.*\.Pretty Park\.exe/i ) {
	return 'original Pretty Park virus';
    }

    if ($e{'Body'} =~ /filename=.*\.Pretty.*Park.*\.exe/i ) {
	return 'original Pretty Park familly ?';
    }

    if ($e{'Body'} =~ /filename=.*search.*URL.*\.exe/i ) {
	return 'P2000 virus familly?';
    }
#;

# ����� HOOK �ؤĤ�����
# ����HOOK��Ȥ��ʤ� ���HOOK��ϴޤޤ�Ƥ���Τ���ɬ��
#
#   �ե������ĥ�� .xxx ����ʤ����ʤ��(?)�Ϥ����äѤ�����ǧ��ʤ�
#   .vbs: VB script
#   .js : Java script ?
#   .exe: executable
#   .doc: word
#   .rtf: RTF (embedded object in RTF is possible?) ?
#   .pif: win32/MTX
#   .scr: win32/MTX
$DISTRIBUTE_FILTER_HOOK .= q#
    my($extension) = 'com|vbs|vbe|wsh|wse|js|exe|doc|rtf|pif|scr';

    if ($e{'Body'} =~ /filename=.*\.($extension)/i) {
	return 'dangerous attatchment ?';
    }
#;


# XXX TODO 
#
#   MIME encoding ����Ƥ����Τ����ʬ�򤷤Ƥ���θ����⡼��
#
#   Index server ���� uuencode ����Ƥ��뤳�Ȥ����뤽���ʤΤ�
#   uuencode �����ʬ�򤷤Ƥ��鸡������⡼��
#   uuencode, base64, quoted-printable, binhex, ... 

1;
