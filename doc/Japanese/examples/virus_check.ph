# $FML: virus_check.ph,v 1.15 2002/05/23 14:57:57 fukachan Exp $
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
# CERT ADVISORY �ʤ�
#   CERT Summary CS-2001-04 nimda �ʤɺǶ�Υ����륹�ˤĤ��ƤΥ��ޥꡩ  
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
# XXX multipart �ξ��Τ�Ŭ��
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

# ����� HOOK �ؤĤ�����
# ����HOOK��Ȥ��ʤ� ���HOOK��ϴޤޤ�Ƥ���Τ���ɬ��
# XXX multipart �ξ��Τ�Ŭ��
#
#   �ե������ĥ�� .xxx ����ʤ����ʤ��(?)�Ϥ����äѤ�����ǧ��ʤ�
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
# uuencode ����Ƥ��ΤϤ��٤��餯��������
# (���Υ����å���ͭ���ˤ���ˤϰʲ��ι�Ƭ�� # ��Ϥ����Ƥ�������)
# Against MyParty et.al.
#
$DISTRIBUTE_FILTER_HOOK .= q{
    if ($e{'Body'} =~ /^begin\s+\d{3}\s+\S+|\nbegin\s+\d{3}\s+\S+/m) {
	return 'uuencoded attachment';
    }
};


# ����: fml-help:01853
# Norton Antivirus for Gateways ��ȤäƤ����硢
# �����륹��Ƚ�ꤵ�줿�᡼��Υ����륹��ʬ��
#    �����ƥƥ����ȡ�text/plain; name="DELETED[�ֹ�].TXT"��
# �Ȥ�������ˤ�������륱���������뤽���Ǥ���
# ��: http://www.firstserver.ne.jp/function/l_virus.html
#
# �Ǥ⡢������ȥ����륹������줿�ɤ��Ǥ⤤���᡼���ή��Ƥ��ޤ��Ǥ���
# ���Υ᡼����Ƥ�������� (0) �� (1) �ˤ��Ƥ��������� 
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
#   MIME encoding ����Ƥ����Τ����ʬ�򤷤Ƥ���θ����⡼��
#
#   Index server ���� uuencode ����Ƥ��뤳�Ȥ����뤽���ʤΤ�
#   uuencode �����ʬ�򤷤Ƥ��鸡������⡼��
#   uuencode, base64, quoted-printable, binhex, ... 

1;
