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

##### POSIX
# Please set the uid of Maintainer! about uid see below. 
# simple way to know your uid may be 
# % echo $UID 
# gid is you can know by /etc/group 
# e.g.  
# "fukachan:********:256:***:Gecos Field:home:shell" in /etc/passwd 
# where the third field is uid(User ID).
# if using yp(NIS), see /etc/passwd in NIS Master Server.

# default is 4.3BSD, so not POSIX, if under POSIX
# define parameters below
# XXUID   = 256
# XXGID   = 103
# ADD_CFLAGS  = -DPOSIX -DXXUID=$(XXUID) -DXXGID=$(XXGID)

######## Custumization part ends ########
#BETH

MAKE     = /usr/gnu/bin/gmake
SHELL    = /bin/sh
UPDIR    = /home/axion/fukachan/work/spool
PWD      = /home/axion/fukachan/work/spool/EXP

DOC      = doc/INFO doc/FAQ 
# doc/NetNews
MDOC     = COPYING RELEASE_NOTES README FILES INSTALL INSTALL.eng 
SOURCES = Makefile \
	config.ph fml.c dummy.c fml.pl guide help help.eng \
	libfml.pl liblock.pl libsmtp.pl SendFile.pl RecreateConfig.pl \
	libutils.pl MSendv4.pl MatomeOkuri-ctl.sh librfc1153.pl \
	Configure Wanted config_h.SH MANIFEST.new \
	configure_fml
BIN_SOURCES = 	 bin/Archive.pl     \
	bin/Archive.cron   \
	bin/maintenance.pl \
	bin/pmail.pl       \
	bin/html-driver    \
	bin/texinfo-driver \
	bin/cron.pl        \
	bin/fix-makefile.pl \
	bin/expire.pl
OLDSOURCES = split_and_sendmail.pl libnounistd.pl MSend-cron.pl
RCSID=`sed -n 's/\(.*\)Id\(.*\)fml\.pl,v \(.*\) [0-9][0-9][0-9][0-9]\/\(.*\)/\3/p' $(PWD)/fml.pl`
LIBID=`cat $(PWD)/contrib/version`
DATE=`date +%y%h%d`
#BETH

CC 	= cc
CFLAGS	=  -s -O

all:	config fml.c fml.pl config.ph
	$(CC) -o _dummy dummy.c && ./_dummy && rm -f ./_dummy
	$(CC) $(CFLAGS) $(ADD_CFLAGS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	/bin/sh ./configure_fml
	@ echo " "
	@ echo " "
	@ echo "Please try \"make doc\" to make a html tree and texinfo files"
	@ echo "Attention! Require jperl for compile"

depend: Makefile
	perl bin/fix-makefile.pl Makefile > _Makefile_
	mv _Makefile_ Makefile

reconfig: fml.c
	cc -s -O fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

config: fml.c fml.pl config1 config2
	sed 's@XXFMLDIR@$(XXFMLDIR)@g' fml.c > __TMP__
	mv __TMP__ fml.c 
	sed 's@XXFMLDIR@$(XXFMLDIR)@' fml.pl > __TMP__
	mv __TMP__ fml.pl
	sed 's/XXML/$(XXML)/' config.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph

config1: config.ph-fundamental
	sed 's/XXML/$(XXML)/' config.ph-fundamental |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph-fundamental

config2:config.ph-fundamental-j
	sed 's/XXML/$(XXML)/' config.ph-fundamental-j |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph-fundamental-j


doc: FAQ
	sh bin/html-driver
	sh bin/texinfo-driver

clean:
	delete *~ _* tmp/mget* core tmp/MSend*.[0-9] tmp/extrac* tmp/pipe*

DISTRIB: distrib archive
fj: distrib archive fj.sources

update:  DISTRIB SNAPSHOT UpDate
local:  local-update
local-update:  distrib UpDate
snap: DISTRIB SNAPSHOT
snapshot: DISTRIB SNAPSHOT

UpDate:  $(SOURCES)
	(cd ../lib; ./UpDate)

SNAPSHOT:
	uuencode ../fml-$(RCSID)-lib$(LIBID).tar.gz fml-$(RCSID)-lib$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current
	rsh beth "cd $(PWD); ./bin/UpDate_in_A_FTP fml-$(RCSID)-lib$(LIBID).tar.gz fml-current.$(DATE).tar.gz"

faq:	make-faq
make-faq: MasterDoc/FAQ
	(echo -n "Last modified: "; date) > /tmp/__TMP__
	sh bin/MakeINFO
	rm -f /tmp/__TMP__
	perl bin/conv-faq.pl MasterDoc/FAQ > doc/FAQ

distrib: make-faq dist

metaconfig: MANIFEST.new
	rsh exelion "cd $(PWD); metaconfig"

dist: $(SOURCES)
	@ echo $(UPDIR)
	@if [ -d $(UPDIR)/distrib ]; then rm -fr $(UPDIR)/distrib;mkdir $(UPDIR)/distrib;\
	else (echo make a directry $(UPDIR)/distrib; mkdir $(UPDIR)/distrib;)  fi
	(cd http; make)
	@ echo " "
	@ echo "-----------"
	@ echo " "
	(rm -f $(UPDIR)/fml-*.gz)
	@ echo "--- Sources ---"
	cp -p $(SOURCES) $(UPDIR)/distrib
	@ echo "--- Doc     ---"
	cp -p $(DOC)     $(UPDIR)/distrib
	(cd MasterDoc; cp -p $(MDOC)   $(UPDIR)/distrib)
	rm -f $(UPDIR)/distrib/LOCK
	mkdir $(UPDIR)/distrib/LOCK
	mkdir $(UPDIR)/distrib/bin
	mkdir $(UPDIR)/distrib/etc
	mkdir $(UPDIR)/distrib/var
	mkdir $(UPDIR)/distrib/var/run
	mkdir $(UPDIR)/distrib/var/spool
	mkdir $(UPDIR)/distrib/var/mail
	mkdir $(UPDIR)/distrib/http
	mkdir $(UPDIR)/distrib/contrib
	@ echo "--- Compatibility ---"
	mkdir $(UPDIR)/distrib/contrib/Compatibility
	(cd obsolete; cp -p $(OLDSOURCES) $(UPDIR)/distrib/contrib/Compatibility)
	@ echo "--- ./bin ---"
	cp -p $(BIN_SOURCES) $(UPDIR)/distrib/bin
	@ echo "--- ./etc ---"
	cp -p etc/crontab-4.[34]     $(UPDIR)/distrib/etc
	@ echo "--- ./http ---"
	cp -p http/release-index.html $(UPDIR)/distrib/http/index.html
	sed 's@/home/axion/fukachan/work/spool/EXP@XXFMLDIR@g' fml.c |\
	cat > $(UPDIR)/distrib/fml.c
#	sed 's@/home/axion/fukachan/work/spool/EXP@XXFMLDIR@g' master-fml.c |\
#	cat > $(UPDIR)/distrib/master-fml.c
	sed 's@/home/axion/fukachan/work/spool/EXP@XXFMLDIR@g' fml.pl |\
	perl bin/Skip.pl -mforward -mif -mdebug -mm5| sed 's/rmsc/rms/' > $(UPDIR)/distrib/fml.pl
# CONFIG.PH
	sed '/MAINTAINER/s/Elena@phys.titech.ac.jp/XXMAINTAINER/g' config.ph |\
	sed '/RFC1153/d'|\
	sed 's/Elena@phys.titech.ac.jp/XXML/g' > $(UPDIR)/distrib/config.ph
# config.ph is set to my preference			
	( cd $(UPDIR)/distrib; \
	ln -s config.ph config.master;\
	ln -s FAQ CONFIGURATION;\
	perl RecreateConfig.pl -i config.ph > _config.ph_;\
	mv _config.ph_ config.ph ;\
	rm config.master;)
# END OF CONFIG.PH
# FUNDAMENTAL
	sed '/MAINTAINER/s/Elena@phys.titech.ac.jp/XXMAINTAINER/g' config.ph-fundamental |\
	sed '/RFC1153/d'|\
	sed 's/Elena@phys.titech.ac.jp/XXML/g' > $(UPDIR)/distrib/config.ph-fundamental
	sed '/MAINTAINER/s/Elena@phys.titech.ac.jp/XXMAINTAINER/g' config.ph-fundamental-j |\
	sed '/RFC1153/d'|\
	sed 's/Elena@phys.titech.ac.jp/XXML/g' > $(UPDIR)/distrib/config.ph-fundamental-j
# END OF FUNDAMENTAL
# includes libutils.pl
#	 sed '/^\#include/q' SendFile.pl > $(UPDIR)/distrib/SendFile.pl
#	 cat libutils.pl >> $(UPDIR)/distrib/SendFile.pl
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' \
	> $(UPDIR)/distrib/Makefile
	cp -p     EasyConfigure $(UPDIR)/distrib/EasyConfigure.euc
	chmod +x $(UPDIR)/distrib/EasyConfigure.euc
#	jconv -es EasyConfigure > $(UPDIR)/distrib/EasyConfigure.sjis
#	chmod +x $(UPDIR)/distrib/EasyConfigure.sjis
#	jconv -ej EasyConfigure > $(UPDIR)/distrib/EasyConfigure.jis
#	chmod +x $(UPDIR)/distrib/EasyConfigure.jis
	(cd $(PWD)/contrib; make DISTRIB)
	(cd $(PWD)/contrib/MatomeOkuri; make DISTRIB)
	(cd $(PWD)/contrib/MatomeOkuri2; make DISTRIB)
	(cd $(PWD)/contrib/Cpcmp; make DISTRIB)
	(cd $(PWD)/contrib/Schwalben; make DISTRIB)
#	(cd $(PWD)/contrib/Elena.winbee; make DISTRIB)
	(cd $(PWD)/contrib/Elena; make DISTRIB)
	(cd $(PWD)/contrib/whois; make DISTRIB)
	(cd $(PWD)/contrib/Utilities; make DISTRIB)
	(cd $(PWD)/contrib/MIME; make DISTRIB)
	(cd $(PWD)/contrib/sys; make DISTRIB)
	(cd $(PWD)/contrib/libhml; make DISTRIB)
	(cd $(PWD)/contrib/ftpmail; make DISTRIB)
	(cd $(PWD)/contrib/http; make DISTRIB)
	(cd $(PWD)/contrib/www-mail; make DISTRIB)
	(cd $(PWD)/contrib/Sendmail; make DISTRIB)
	(cd $(PWD)/contrib/Crosspost; make DISTRIB)
	(cd $(PWD)/contrib/Master; make DISTRIB)
	(cd $(PWD)/contrib/putfiles; make DISTRIB)
	mkdir $(UPDIR)/distrib/contrib/AIKO
	(cd $(HOME)/work/AIKO; make DISTRIB)
	(cd $(UPDIR)/distrib; ln -s contrib/sys sys)
	(cd $(UPDIR)/distrib; ln -s contrib/Whois/jcode.pl jcode.pl)
#
#      PATCHES
#
#	forward
	sed 's@/home/axion/fukachan/work/spool/EXP@XXFMLDIR@g' fml.pl |\
	perl bin/Skip.pl -mif -mdebug -mm5| sed 's/rmsc/rms/' > ./tmp/fml.pl
	(gdiff -c ./tmp/fml.pl ../distrib/fml.pl| cat > ./tmp/fml.pl-forward-patch)
	cp ./tmp/fml.pl-forward-patch $(UPDIR)/distrib/contrib/Utilities
	rm -f ./tmp/fml.pl ./tmp/fml.pl-forward-patch 
#	smtp
	perl bin/Skip.pl -mforward -mif libsmtp.pl > $(UPDIR)/distrib/libsmtp.pl
	perl bin/Skip.pl -mforward -mif libsmtp.pl > ./tmp/libsmtp.pl.org
	perl bin/Skip.pl libsmtp.pl      > ./tmp/libsmtp.pl
	(gdiff -c ./tmp/libsmtp.pl.org ./tmp/libsmtp.pl |\
	 cat > ./tmp/libsmtp.pl-dns-debug-patch)
	cp ./tmp/libsmtp.pl-dns-debug-patch $(UPDIR)/distrib/contrib/Utilities
	rm -f ./tmp/libsmtp.pl.org ./tmp/libsmtp.pl ./tmp/libsmtp.pl-dns-debug-patch
#	Matomeokuri no-cron
	mkdir $(UPDIR)/distrib/contrib/MatomeOkuri-NOCRON
	cp ./config/*.p? $(UPDIR)/distrib/contrib/MatomeOkuri-NOCRON
#	Crosspost
	perl bin/Skip.pl -mforward -mm5 fml.pl > $(UPDIR)/distrib/contrib/Crosspost/fml.pl
	perl bin/Skip.pl -mforward -mif -mdebug contrib/Crosspost/libcrosspost.pl > $(UPDIR)/distrib/contrib/Crosspost/libcrosspost.pl
	( cd $(UPDIR)/distrib/; mv contrib lib; ln -s lib contrib)

archive:
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' |\
	sed '/XXMAINTAINER/s/Elena/Elena-request/g' |\
	sed '/#BETH/,/#BETH/d' > $(UPDIR)/distrib/Makefile
	(cd ../distrib; egrep 'Id:' *.pl */*.pl contrib/*/*.pl) |\
	perl bin/Cal_Id.pl |tee contrib/version > $(UPDIR)/distrib/fml-version 
	@ echo $(RCSID)-lib$(LIBID)
	(cd $(UPDIR); rm -f fml-$(RCSID)-lib$(LIBID))
	(cd $(UPDIR); ln -s distrib fml-$(RCSID)-lib$(LIBID))
	(cd $(UPDIR); tar cvf distrib.tar distrib fml-$(RCSID)-lib$(LIBID))
	(cd $(UPDIR); mv distrib.tar fml-$(RCSID)-lib$(LIBID).tar)
	(cd $(UPDIR); gzip -9 -f fml-$(RCSID)-lib$(LIBID).tar)
	(cd $(UPDIR); cp fml-$(RCSID)-lib$(LIBID).tar.gz fml-current.$(DATE).tar.gz)
	(cd $(UPDIR); cp fml-$(RCSID)-lib$(LIBID).tar.gz /home/axion/fukachan/work/gopher/software)

fj.sources:


print:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl SendFile.pl setup.pl config.ph 
	ra2ps fml.pl libfml.pl config.ph README INSTALL FILES FAQ | lpr -St

#doc:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl SendFile.pl setup.pl config.ph 
#	ra2ps README INSTALL FAQ config.ph| lpr -St

contents: FAQ
	sed -n '/Appendix/,$$p' FAQ |\
	egrep '^[0-9]\.' | perl -nle '/^\d\.\s/ && print ""; print $_'

check:	*.p?
	(for x in *.p? config.ph-fundamental-j bin/*.p? ; do perl -c $$x;done)

c:	*.p?
	(for x in *.p? ; do perl -w -c $$x;done) 2>&1 |perl bin/GREP-V.pl

