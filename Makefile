# fml Makefile
# $Id$

######## Please custumize below ########
XXML         = Elena@phys.titech.ac.jp
XXMAINTAINER = Elena@phys.titech.ac.jp
XXFMLDIR     = /home/axion/fukachan/work/spool/EXP

# Attention!
# Mailing List Name is 
# XXML         = Elena@phys.titech.ac.jp
#
# Maintainer(maybe your own) address is
# XXMAINTAINER = Elena@phys.titech.ac.jp
# Be an address different from ML own one!
# Recommended address is e.g. MailingList-request@... created for this purpose.
# 
# ML Server works in the directory 
# XXFMLDIR     = /home/axion/fukachan/work/spool/EXP

######## Custumization part ends ########
#BETH

MAKE     = /usr/local/bin/gmake
SHELL    = /bin/sh
UPDIR    = /home/axion/fukachan/work/spool
PWD      = /home/axion/fukachan/work/spool/EXP
OPT      =
XXUID    =
XXGID    =
OPTS     = $(OPT) $(XXUID) $(XXGID)
DOC      = INFO op README FILES INSTALL INSTALL.eng RELEASE_NOTES COPYING 
TRASH	 = /home/axion/fukachan/work/trash
SOURCES = Makefile \
	config.ph \
	fml.c \
	fml.pl \
	doc/master/guide \
	doc/master/objective \
	doc/master/deny \
	doc/master/help \
	doc/master/help.eng \
	doc/master/help.example2 \
	doc/master/help-admin \
	bin/RecreateConfig.pl \
	etc/config.h \
	MSendv4.pl \
	libsmtp.pl \
	proc/libfml.pl \
	proc/liblock.pl \
	proc/libsendfile.pl \
	proc/libutils.pl \
	proc/libfop.pl \
	proc/librfc1153.pl \
	proc/libremote.pl \
	proc/libra.pl \
	proc/libwhois.pl \
	proc/libstardate.pl \
	proc/libnewsyslog.pl \
	proc/libcompat.pl \
	proc/libhref.pl \
	proc/libsynchtml.pl \
	proc/libcrosspost.pl \
	proc/libcrypt.pl \
	proc/libftp.pl \
	proc/libsid.pl \
	proc/mimer.pl \
	proc/mimew.pl \
	proc/libMIME.pl \
	proc/liblibrary.pl \
	proc/jcode.pl \
	lib/traffic/libtraffic.pl 



BIN_SOURCES = 	 bin/Archive.pl     \
	bin/Archive.cron   \
	bin/vipw.pl	\
	bin/pmail.pl       \
	bin/texinfo-driver \
	bin/cron.pl        \
	bin/MSendv4-stat.pl \
	bin/MatomeOkuri-ctl.sh \
	bin/newsyslog.sh \
	bin/geturl.pl \
	bin/fwix.pl \
	bin/split_and_msend.pl \
	bin/passwd.pl \
	bin/inc_via_pop.pl \
	bin/Html.pl \
	bin/daemon.pl \
	bin/expire.pl


OLDSOURCES = split_and_sendmail.pl libnounistd.pl MSend-cron.pl

#shell
#25.490u 4.640s 0:39.51 76.2% 26+61k 0+0io 0pf+0w
#perl
#1.180u 4.170s 0:10.86 49.2% 18+12k 0+8io 0pf+0w
#
RCSID=`$(FML)/usr/sbin/get-rcsid.pl $(FML)/fml.pl`
SIDID=`$(FML)/usr/sbin/get-rcsid.pl $(FML)/libexec/sid.pl`

RCSID=2.0alpha

LIBID="\#`cat $(PWD)/var/doc/version`"

COUNT_FILE = var/run/version

COUNT=`cat var/run/version`

DATE=`date +%y%h%d`

#BETH

CC 	= cc
CFLAGS	= -s -O
SH	= /bin/sh
FIX_SOURCES = fml.c fml.pl config.ph \
	config.ph-fundamental config.ph-fundamental-j


all:	config fml.c fml.pl config.ph
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	perl ./sbin/gen-samples.pl $(XXML) $(XXMAINTAINER) $(XXFMLDIR)
	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml )
	@ echo " "
	@ if [ -f etc/motd ]; then cat etc/motd; fi

newconfig:
	perl configure cf/Elena > config.ph

reconfig: fml.c
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

config: fml.c fml.pl config.ph
	@ echo "Fixing " $(FIX_SOURCES)
	@ echo -n "."
	@ rm -f tmp/fix.pl	
	@ echo 's#XXFMLDIR#$(XXFMLDIR)#g;'		>> tmp/_fix.pl
	@ echo 's#XXML#$(XXML)#g;' 			>> tmp/_fix.pl
	@ echo 's#XXMAINTAINER#$(XXMAINTAINER)#;' 	>> tmp/_fix.pl	
	@ echo 'print;' 				>> tmp/_fix.pl	
	@ perl -nle 's#@#\\@#g;print ' tmp/_fix.pl 	> tmp/fix.pl 
	@ echo -n "."
	@ perl -i'.bak' -nle "`cat tmp/fix.pl`" $(FIX_SOURCES)
	@ echo -n "."
	@ rm -f tmp/fix.pl tmp/_fix.pl *.bak
	@ echo " Done."; echo " "

localtest:
	@ echo INPUT:
	@ echo "-----------------------------------"
	@ perl sbin/localtest.pl 
	@ echo "==================================="
	@ echo " "
	@ echo " "
	@ echo " "
	@ echo OUTPUT: debug info from fml.pl 
	@ echo "-----------------------------------"
	perl sbin/localtest.pl | perl fml.pl $(PWD) $(PWD)


link:	etc/list_of_use
	(cd lib/perl; ln `cat ../../etc/list_of_use` .)

doc: 	html

html:	doc/smm/op.wix
	@ echo "Making WWW pages of doc/smm/op => var/html/op"
	@ test -d var/html/op || mkdir var/html/op
	@ perl bin/fwix.pl -T smm/op -m html -D var/html/op -I doc/smm doc/smm/op.wix

roff:	doc/smm/op.wix
	@ echo "Making nroff of doc/smm/op => var/man"
	@ test -d var/man || mkdir var/man
	@ perl bin/fwix.pl -T smm/op -m roff -R var/man -I doc/smm doc/smm/op.wix

texinfo:
	$(SH) bin/texinfo-driver

versionup:
	(cd $(FML); sh usr/sbin/fix-package)
	(cd ../distrib/lib; tar cvf ../../fml_pl_packages.tar perl)
	rm -f ../fml_pl_packages.tar.gz 
	gzip -9 ../fml_pl_packages.tar 

clean:
	gar *~ _* proc/*~ tmp/mget* core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*:*.[0-9]


DISTRIB: distrib export archive versionup 
fj: distrib archive fj.sources


local:  local-update
local-update:  distrib UpDate
snap: DISTRIB SNAPSHOT

update:  DISTRIB SNAPSHOT UpDate sid_update fml_local_update
snapshot: DISTRIB SNAPSHOT sid_update fml_local_update


export:
	(cd ../distrib/; RCP2 -h beth -d .ftp/pub/net/fml-current/snapshot .)

mirror:
	(cd ..; \
	 tar cvf - EXP |gzip > EXP.tar.gz; \
	 RCP2 -h beth       -d /var/src/EXP 	EXP.tar.gz; \
	 RCP2 -h vivian.psy -d work 		EXP.tar.gz; \
	rm -f EXP.tar.gz;\
	)

UpDate:  $(SOURCES)
	@ echo "if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi"
	@ if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi
	@ (cd $(FML);perl usr/sbin/lock4update.pl 'cd ../lib;./UpDate;cd ../SID;./UpDate')

sid_update:
	(cd $(FML); sh usr/sbin/make-sid.sh)
	
fml_local_update:
	(cd $(FML); sh usr/sbin/make-fmllocal.sh)

SNAPSHOT: uuencode beth

uuencode:
	@ echo "uuencode ../fml-$(RCSID)$(LIBID).tar.gz fml-$(RCSID)$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current"
	@ uuencode ../fml-$(RCSID)$(LIBID).tar.gz fml-$(RCSID)$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current

beth:
	@ echo "$(FML)/usr/sbin/UpDate_in_A_FTP fml-$(RCSID)$(LIBID).tar.gz fml-current.$(DATE).tar.gz"
	@ rsh beth "$(FML)/usr/sbin/UpDate_in_A_FTP \"fml-$(RCSID)$(LIBID).tar.gz\" fml-current.$(DATE).tar.gz"

cur-chk:
	rsh beth "cd /usr/local/ftp/pub/net/fml-current; ls -l;"

SID:
	sh $(FML)/usr/sbin/make-sid.sh

faq:	make-faq
make-faq: doc/smm/op.wix
	@ sh usr/sbin/sync-rcs-of-doc.sh
	@ (echo -n "Last modified: "; date) > /tmp/__TMP__
	@ (echo -n "	Last modified: "; date) > /tmp/__TMP2__
	@ sh usr/sbin/DocReconfigure
	@ rm -f /tmp/__TMP__ /tmp/__TMP2__


distrib: message fix-include fix-rcsid make-faq dist

message: 
	@echo  "" 
	@echo  "YOU USE        gmake        ? O.K.?" 
	@echo  "" 
	@rm -f $(UPDIR)/distrib $(UPDIR)/fml-$(RCSID)
	@echo  "" 

fix-rcsid:
	@ echo " "; echo "Fixing rcsid ... " 
	@ /bin/sh usr/sbin/fix-rcsid
	@ chmod 755 *.pl bin/*.pl sbin/*.pl libexec/*.pl 
	@ echo " Done. " 


dist: $(SOURCES)
	@ (chdir var/run; version.pl)
	(BIN_SOURCES="$(BIN_SOURCES)"; export BIN_SOURCES;\
	DOC="$(DOC)"; export DOC;\
	HOME="$(HOME)"; export HOME;\
	MDOC="$(MDOC)"; export MDOC;\
	OLDSOURCES="$(OLDSOURCES)"; export OLDSOURCES;\
	PWD="$(PWD)"; export PWD;\
	SOURCES="$(SOURCES)"; export SOURCES;\
	TMP="$(TMP)"; export TMP;\
	UPDIR="$(UPDIR)"; export UPDIR;\
	sh usr/sbin/make-distribution.sh )

archive:
	@ (chdir var/run; version.pl)
	if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi
	sed '/^DISTRIB/,$$d' Makefile | sed 's/gar/rm \-f/' |\
	sed '/XXMAINTAINER/s/Elena/Elena-request/g' |\
	sed '/#BETH/,/#BETH/d' > $(UPDIR)/distrib/Makefile
	@ echo  "LIBID = " $(LIBID)
	@ echo -n Fixing Directory ...
	@ /bin/sh usr/sbin/MoveDir $(UPDIR) $(TRASH) $(RCSID)
	@ echo done.; echo " "
	@ echo "(cd $(UPDIR); mv distrib fml-$(RCSID))"
	@ (cd $(UPDIR); mv distrib fml-$(RCSID))
	@ echo "(cd $(UPDIR); ln -s fml-$(RCSID) distrib)"
	@ (cd $(UPDIR); ln -s fml-$(RCSID) distrib)
	@ echo "(cd $(UPDIR); tar cvf fml-$(RCSID)$(LIBID).tar fml-$(RCSID) )"
	@ (cd $(UPDIR); tar cvf fml-$(RCSID)$(LIBID).tar fml-$(RCSID))
	@ echo "(cd $(UPDIR); gzip -9 -f fml-$(RCSID)$(LIBID).tar)"
	@ (cd $(UPDIR); gzip -9 -f fml-$(RCSID)$(LIBID).tar)

fj.sources:


print:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl libsendfile.pl setup.pl config.ph 
	ra2ps fml.pl libfml.pl config.ph README INSTALL FILES FAQ | lpr -St

#doc:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl libsendfile.pl setup.pl config.ph 
#	ra2ps README INSTALL FAQ config.ph| lpr -St

contents: FAQ
	sed -n '/Appendix/,$$p' FAQ |\
	egrep '^[0-9]\.' | perl -nle '/^\d\.\s/ && print ""; print $_'

check:	fml.pl
	(for x in *.pl proc/*.p? libexec/*.p? ; do perl -c $$x;done)
#	(for x in `sh sbin/bin.list.sh` ; do perl -c $$x;done)

c:	*.p?
	(2>&1; for x in *.p? ; do perl -cw $$x ; done ) |\
	perl usr/sbin/fix-perl-c-output.pl

C:
	rsh beth "cd $(PWD); make c"

vivian: 
	(chdir ..; tar chf - EXP/*.pl EXP/*bin*/*.pl EXP/libexec/*.pl) |\
	rsh vivian.psy.titech.ac.jp 'chdir work; tar xvhf -'

paffy: 
	(chdir ..; tar chf - EXP/*.pl EXP/*bin*/*.pl EXP/libexec/*.pl) |\
	rsh paffy.psy.titech.ac.jp 'chdir work; tar xvhf -'

fml.local:
	RCP2 -h vivian.psy -d work/EXP/libexec libexec/fml_local.pl

fix-include: 
	sh usr/sbin/fix-include.sh

cmp:
	usr/bin/uncomments.pl fml.pl | wc
	usr/sbin/fpp.pl -mCROSSPOST fml.pl | usr/bin/uncomments.pl | wc
	usr/bin/uncomments.pl libsmtp.pl | wc
	(usr/sbin/fpp.pl -mCROSSPOST fml.pl; cat libsmtp.pl)|\
	usr/bin/uncomments.pl|wc
	usr/bin/uncomments.pl $(HOME)/work/src/USEFUL/hml-1.6/hml.pl |wc

use:
	grep require *pl | grep "\'lib"

reset:
	gar summary log members actives seq
	gar *.bak
	gar var/log/*.[0-9]


diff:
	usr/bin/rcsdiff++.sh *.pl

test-sid:
	(bin/h.pl ; echo help   fml-test)|(chdir ../SID/; perl $(FML)/libexec/sid.pl . $(FML) -d)

capital:
	cat `echo *pl proc/*pl | sed 's#proc/libcompat.pl##'| sed 's#proc/libsid.pl##'` |\
	perl usr/bin/getcapital.pl | sort -n | uniq | sed 's/\$\(.*\)/\1:/' 
#	@ echo " "
#	@ echo "libexec"
#	@ echo " "
#	cat `libexec/*pl | sed 's#proc/libcompat.pl##'` |\
#	perl usr/bin/getcapital.pl | sort -n | uniq | sed 's/\$\(.*\)/\1:/' 
