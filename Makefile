# fml Makefile
# $Id$

######## Please custumize below ########
XXML         = Elena@phys.titech.ac.jp
XXMAINTAINER = Elena@phys.titech.ac.jp
XXFMLDIR     = \/home\/axion\/fukachan\/work\/spool\/EXP

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
# XXFMLDIR     = \/home\/axion\/fukachan\/work\/spool\/EXP
# escape '\' in XXFMLDIR is needed for 'sed' 

######## Custumization part ends ########
#BETH
# Old version fml.c uses built-in constant
# Please set the uid of Maintainer! about uid see below. 
# "fukachan:********:256:***:Gecos Field:home:shell" in /etc/passwd 
# where the third field is uid(User ID).
# if using yp(NIS), see /etc/passwd in NIS Master Server.
XXUID    = 256

######## Custumization part ends ########

MAKE     = /usr/gnu/bin/gmake
SHELL    = /bin/sh
UPDIR    = /home/axion/fukachan/work/spool
PWD      = /home/axion/fukachan/work/spool/EXP

DOC      = doc/INFO doc/FAQ doc/NetNews
MDOC     = COPYING RELEASE_NOTES README FILES INSTALL INSTALL.eng 
SOURCES = Makefile Configure config.ph fml.c fml.pl guide help help.eng \
	libfml.pl liblock.pl libsmtp.pl SendFile.pl RecreateConfig.pl \
	libutils.pl MSendv4.pl MatomeOkuri-ctl.sh crontab
OLDSOURCES = split_and_sendmail.pl libnounistd.pl MSend-cron.pl
RCSID=`sed -n 's/\(.*\)Id\(.*\)fml\.pl,v \(.*\) [0-9][0-9][0-9][0-9]\/\(.*\)/\3/p' $(PWD)/fml.pl`
DATE=`date +%y%h%d`
#BETH

all:	config fml.c fml.pl config.ph
	cc -s -O fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	/bin/sh ./Configure
	@ echo " "
	@ echo " "
	@ echo "Please try \"make doc\" to make a html tree and texinfo files"
	@ echo "Attention! Require jperl for compile"

reconfig: fml.c
	cc -s -O fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

config: fml.c fml.pl 
	sed 's/XXFMLDIR/$(XXFMLDIR)/g' fml.c > __TMP__
	mv __TMP__ fml.c 
	sed 's/XXFMLDIR/$(XXFMLDIR)/' fml.pl > __TMP__
	mv __TMP__ fml.pl
	sed 's/XXML/$(XXML)/' config.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph

doc: FAQ
	sh bin/html-driver
	sh bin/texinfo-driver

clean:
	delete *~ _* tmp/mget* core tmp/MSend*.[0-9]

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
	uuencode ../fml-$(RCSID).tar.gz fml-$(RCSID)_$(DATE).tar.gz > ../fml-current/fml-current
	./bin/UpDate_in_A_FTP

faq:	make-faq
make-faq: MasterDoc/FAQ
	(echo -n "Last modified: "; date) > /tmp/__TMP__
	sh bin/MakeINFO
	rm -f /tmp/__TMP__
	perl bin/conv-faq.pl MasterDoc/FAQ > doc/FAQ

distrib: make-faq $(SOURCES)
	@ echo $(RCSID)
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
	mkdir $(UPDIR)/distrib/http
	mkdir $(UPDIR)/distrib/contrib
	@ echo "--- Compatibility ---"
	mkdir $(UPDIR)/distrib/contrib/Compatibility
	(cd obsolute; cp -p $(OLDSOURCES) $(UPDIR)/distrib/contrib/Compatibility)
	@ echo "--- ./bin ---"
	cp -p bin/Archive.pl     $(UPDIR)/distrib/bin
	cp -p bin/Archive.cron   $(UPDIR)/distrib/bin
	cp -p bin/maintenance.pl $(UPDIR)/distrib/bin
	cp -p bin/pmail.pl       $(UPDIR)/distrib/bin
	cp -p bin/html-driver    $(UPDIR)/distrib/bin
	cp -p bin/texinfo-driver $(UPDIR)/distrib/bin
	@ echo "--- ./http ---"
	cp -p http/release-index.html $(UPDIR)/distrib/http/index.html
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' fml.c |\
	cat > $(UPDIR)/distrib/fml.c
#	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' master-fml.c |\
#	cat > $(UPDIR)/distrib/master-fml.c
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' fml.pl |\
	perl bin/Skip.pl | sed 's/rmsc/rms/' > $(UPDIR)/distrib/fml.pl
	sed '/MAINTAINER/s/Elena@phys.titech.ac.jp/XXMAINTAINER/g' config.ph |\
	sed 's/Elena@phys.titech.ac.jp/XXML/g' > $(UPDIR)/distrib/config.ph
# config.ph is set to my preference			
	( cd $(UPDIR)/distrib; \
	ln -s config.ph config.master;\
	ln -s FAQ CONFIGURATION;\
	perl RecreateConfig.pl -i config.ph > _config.ph_;\
	mv _config.ph_ config.ph ;\
	rm config.master;)
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
	(cd $(PWD)/contrib/Elena.winbee; make DISTRIB)
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

	mkdir $(UPDIR)/distrib/contrib/AIKO
	(cd $(HOME)/work/AIKO; make DISTRIB)
	(cd $(UPDIR)/distrib; ln -s contrib/sys sys)
	(cd $(UPDIR)/distrib; ln -s contrib/Whois/jcode.pl jcode.pl)

	perl bin/NoSkip.pl fml.pl > $(UPDIR)/distrib/contrib/Crosspost/fml.pl
	perl bin/Skip.pl contrib/Crosspost/libcrosspost.pl > $(UPDIR)/distrib/contrib/Crosspost/libcrosspost.pl
#	(cd $(UPDIR)/distrib/contrib/Elena;\
#	 ln -s ../Whois/jcode.pl jcode.pl)
	( cd $(UPDIR)/distrib/; mv contrib lib; ln -s lib contrib)

archive:
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' |\
	sed '/XXMAINTAINER/s/Elena/Elena-request/g' |\
	sed '/#BETH/,/#BETH/d' > $(UPDIR)/distrib/Makefile
	(cd $(UPDIR); rm -f fml-$(RCSID))
	(cd $(UPDIR); ln -s distrib fml-$(RCSID))
	(cd $(UPDIR); tar cvf distrib.tar distrib fml-$(RCSID))
	(cd $(UPDIR); mv distrib.tar fml-$(RCSID).tar)
	(cd $(UPDIR); gzip -9 -f fml-$(RCSID).tar)
	(cd $(UPDIR); cp fml-$(RCSID).tar.gz fml-current.$(DATE).tar.gz)
	(cd $(UPDIR); cp fml-$(RCSID).tar.gz /home/axion/fukachan/work/gopher/software)

fj.sources:


print:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl SendFile.pl setup.pl config.ph 
	ra2ps fml.pl libfml.pl config.ph README INSTALL FILES FAQ | lpr -St

#doc:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl SendFile.pl setup.pl config.ph 
#	ra2ps README INSTALL FAQ config.ph| lpr -St

contents: FAQ
	sed -n '/Appendix/,$$p' FAQ |\
	egrep '^[0-9]\.' | perl -nle '/^\d\.\s/ && print ""; print $_'

check:	*.p?
	(for x in *.p? ; do perl -c $$x;done)
