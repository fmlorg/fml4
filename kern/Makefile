# fml Makefile
# $Id$

######## Please custumize below ########
XXML         = erica@phys.titech.ac.jp
XXMAINTAINER = erica@phys.titech.ac.jp
XXFMLDIR     = \/home\/axion\/fukachan\/work\/spool\/EXP

# Attention!
# Mailing List Name is 
# XXML         = erica@phys.titech.ac.jp
#
# Maintainer(maybe your own) address is
# XXMAINTAINER = erica@phys.titech.ac.jp
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
SOURCES  = Makefile FAQ COPYING PREHISTORY README FILES INSTALL Configure config.ph fml.c fml.pl guide help libfml.pl liblock.pl libsmtp.pl pmail.pl sendmail.pl split_and_sendmail.pl maintenance.pl NetNews
RCSID=`sed -n 's/\(.*\)Id\(.*\)fml\.pl,v \(.*\) [0-9][0-9][0-9][0-9]\/\(.*\)/\3/p' $(PWD)/fml.pl`
DATE=`date +%y%h%d`
#BETH

all:	config fml.c fml.pl config.ph
	cc -s -O fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	/bin/sh ./Configure

config: fml.c fml.pl 
	sed 's/XXFMLDIR/$(XXFMLDIR)/g' fml.c > __TMP__
	mv __TMP__ fml.c 
	sed 's/XXFMLDIR/$(XXFMLDIR)/' fml.pl > __TMP__
	mv __TMP__ fml.pl
	sed 's/XXML/$(XXML)/' config.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph
	sed 's/XXFMLDIR/$(XXFMLDIR)/' split_and_sendmail.pl > __TMP__
	mv __TMP__ split_and_sendmail.pl

clean:
	delete *~ _* mget* core

DISTRIB: distrib archive

snap: DISTRIB SNAPSHOT
snapshot: DISTRIB SNAPSHOT

SNAPSHOT:
	uuencode ../fml-$(RCSID).tar.gz fml-$(RCSID)_$(DATE).tar.gz > ../fml-current/fml-current
	./UpDate_in_A_FTP

distrib: $(SOURCES)
	@ echo $(RCSID)
	@ echo $(UPDIR)
	@if [ -d $(UPDIR)/distrib ]; then rm -fr $(UPDIR)/distrib;mkdir $(UPDIR)/distrib;\
	else (echo make a directry $(UPDIR)/distrib; mkdir $(UPDIR)/distrib;)  fi
	cp -p $(SOURCES) $(UPDIR)/distrib
	rm -f $(UPDIR)/distrib/LOCK
	mkdir $(UPDIR)/distrib/LOCK
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' fml.c |\
	cat > $(UPDIR)/distrib/fml.c
#	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' master-fml.c |\
#	cat > $(UPDIR)/distrib/master-fml.c
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' fml.pl > $(UPDIR)/distrib/fml.pl
	sed '/MAINTAINER/s/erica@phys.titech.ac.jp/XXMAINTAINER/g' config.ph |\
	sed 's/erica@phys.titech.ac.jp/XXML/g' > $(UPDIR)/distrib/config.ph
#	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' setup.pl > $(UPDIR)/distrib/setup.pl
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP/XXFMLDIR/g' split_and_sendmail.pl > $(UPDIR)/distrib/split_and_sendmail.pl
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' > $(UPDIR)/distrib/Makefile
	cp -p     EasyConfigure $(UPDIR)/distrib/EasyConfigure.euc
	chmod +x $(UPDIR)/distrib/EasyConfigure.euc
	(cd $(UPDIR)/distrib; ln -s contrib/sys sys)
#	jconv -es EasyConfigure > $(UPDIR)/distrib/EasyConfigure.sjis
#	chmod +x $(UPDIR)/distrib/EasyConfigure.sjis
#	jconv -ej EasyConfigure > $(UPDIR)/distrib/EasyConfigure.jis
#	chmod +x $(UPDIR)/distrib/EasyConfigure.jis
	(cd $(PWD)/contrib; make DISTRIB)
	(cd $(PWD)/contrib/MatomeOkuri; make DISTRIB)
	(cd $(PWD)/contrib/Cpcmp; make DISTRIB)
	(cd $(PWD)/contrib/Schwalben; make DISTRIB)
	(cd $(PWD)/contrib/Osakana; make DISTRIB)
	(cd $(PWD)/contrib/Utilities; make DISTRIB)
	(cd $(PWD)/contrib/MIME; make DISTRIB)
	(cd $(PWD)/contrib/sys; make DISTRIB)

archive:
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' |\
	sed '/XXMAINTAINER/s/erica/erica-request/g' |\
	sed '/#BETH/,/#BETH/d' > $(UPDIR)/distrib/Makefile
	(cd $(UPDIR); ln -s distrib fml-$(RCSID))
	(cd $(UPDIR); tar cvf distrib.tar distrib fml-$(RCSID))
	(cd $(UPDIR); mv distrib.tar fml-$(RCSID).tar)
	(cd $(UPDIR); gzip -9 -f fml-$(RCSID).tar)
	(cd $(UPDIR); cp fml-$(RCSID).tar.gz fml-current.$(DATE).tar.gz)
	(cd $(UPDIR); cp fml-$(RCSID).tar.gz /home/axion/fukachan/work/gopher/software)

print:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl setup.pl config.ph 
	ra2ps fml.pl libfml.pl config.ph README INSTALL FILES FAQ | lpr -St

doc:	fml.pl pmail.pl libsmtp.pl liblock.pl libfml.pl split_and_sendmail.pl setup.pl config.ph 
	ra2ps README INSTALL FAQ config.ph| lpr -St

contents: FAQ
	egrep '^[0-9]\.' FAQ

check:	*.p?
	(for x in *.p? ; do perl -c $$x;done)
