Newsgroups: fj.questions.unix
Path: phys.titech!is.s.u-tokyo!news.tisn.ad.jp!news.u-tokyo.ac.jp!wnoc-tyo-news!tweedledum!sazae.im.uec.ac.jp!pink!uecgw!uecgw.cs.uec.ac.jp!tate
From: tate@cs.uec.ac.jp (Tateoka Takamichi)
Subject: Re: [Q] RMAIL => folders (MH)
In-Reply-To: s7091411@ipc.akita-u.ac.jp's message of Sat, 1 Oct 1994
 08:22:01 GMT
Content-Type: text/plain; charset=ISO-2022-JP
Message-ID: <TATE.94Oct2004535@twoheaded.cs.uec.ac.jp>
Sender: usenet@uecgw.cs.uec.ac.jp
Nntp-Posting-Host: twoheaded.cs.uec.ac.jp
Reply-To: tate@cs.uec.ac.jp
Organization: The University of Electro-Communications, Tokyo, Japan.
References: <S7091411.94Oct1172201@octet.ipc.akita-u.ac.jp>
Mime-Version: 1.0
Distribution: fj
Date: Sat, 1 Oct 1994 15:45:33 GMT
Lines: 49

  �ݲ���������Ǥ���

In article <S7091411.94Oct1172201@octet.ipc.akita-u.ac.jp> s7091411@ipc.akita-u.ac.jp (TERUI Tomohiro) writes:
> �������᡼��Τ��Ȥ�� RMAIL �ǹԤäƤ����ΤǤ��������� Mail Handler 
> �˰ܹԤ��ޤ������Ĥ��ޤ��Ƥϡ�RMAIL ���ߤ����᡼��� Mail Handler �� 
> folder ��ž������ˤϤɤ��������ɤ��ΤǤ��礦����

  rmail-to-mbox.el �Ȥ����Τ����ꡢ�����Ȥ��� RMAIL �������� unix
mail (mbox) �������Ѵ��Ǥ��ޤ������ȤϤ��Υե������
% inc -file mbox
�ʤɤȤ��� MH �������Ѵ�������ɤ��Ǥ��礦��

  �ɤ������ꤷ����˺��ޤ�������û���Τǡ����ε������դ��ޤ���

BEGIN--- cut here ---
;;
;; rmail-to-mbox
;;	K.Yasuda, K.Shirakami and H.Tsujimura (PFU Ltd.)

(defun rmail-to-mbox (&optional rfile mfile no-mesg)
"Convert and append Rmail file to Unix-format mail file.
Optional arg RMAIL means Rmail format file.
Optional arg MBOX means Unix-format mail file."
  (interactive)
  (if (null rfile)
      (setq rfile
	    (read-file-name "Rmail File name (input): "
			    "~/RMAIL" "~/RMAIL" t)))
  (if (null mfile)
      (setq mfile
	    (read-file-name "Mbox File name (output): "
			    "~/mbox" "~/mbox" nil)))
  (let (buf (current-buffer))
    (rmail rfile)
    (let ((abc rmail-total-messages))
      (rmail-show-message 1)
      (while (> abc 0)
	(rmail-output mfile)
	(rmail-next-message 1)
	(setq  abc (1- abc))))
    (bury-buffer (current-buffer))
    (switch-to-buffer buf))
  (if (not no-mesg)
      (message (format "%s to %s ... done" rfile mfile))))
END--- cut here ---
--
 �ŵ��̿���� �ŵ��̿��ظ���� ���󹩳��칶 ����ʬ���������漼(������) M1
 �ݲ���ƻ (Tateoka, Takamichi)   tate@cs.uec.ac.jp (Internet)
                          <http://smiley.cs.uec.ac.jp/pdl/tate.html>
