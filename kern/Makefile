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
DOC      = INFO FAQ README FILES INSTALL INSTALL.eng RELEASE_NOTES 
TRASH	 = /home/axion/fukachan/work/trash
# doc/NetNews
MDOC     = COPYING 
SOURCES = Makefile \
	config.ph fml.c fml.pl guide help help.eng \
	help.example2 \
	libfml.pl liblock.pl libsmtp.pl SendFile.pl RecreateConfig.pl \
	libutils.pl MSendv4.pl \
	librfc1153.pl \
	libStardate.pl \
	libnewsyslog.pl \
	config.h 
#	configure_fml
#	Configure Wanted config_h.SH MANIFEST.new 

BIN_SOURCES = 	 bin/Archive.pl     \
	bin/Archive.cron   \
	bin/maintenance.pl \
	bin/pmail.pl       \
	bin/html-driver    \
	bin/texinfo-driver \
	bin/cron.pl        \
	bin/fix-makefile.pl \
	bin/MatomeOkuri-ctl.sh \
	config/arch config/os-type \
	bin/newsyslog.sh \
	bin/geturl.pl \
	bin/expire.pl

OLDSOURCES = split_and_sendmail.pl libnounistd.pl MSend-cron.pl

RCSID=`sed -n 's/\(.*\)Id\(.*\)fml\.pl,v \(.*\) [0-9][0-9][0-9][0-9]\/\(.*\)/\3/p' $(PWD)/fml.pl`

LIBID=`cat $(PWD)/contrib/version`

COUNT_FILE = var/run/snap_counter

COUNT=`cat var/run/snap_counter`

DATE=`date +%y%h%d`

#BETH

CC 	= cc
CFLAGS	= -s -O
SH	= /bin/sh

all:	config fml.c fml.pl config.ph
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml)
	@ echo " "
	@ echo " "
	@ echo "Please try \"make doc\" to make a html tree and texinfo files"
	@ echo "Attention! Require jperl for compile"
	@ echo " "
	@ echo " "
	@ if [ -f etc/motd ]; then cat etc/motd; fi

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


depend: Makefile
	perl bin/fix-makefile.pl Makefile > _Makefile_
	mv _Makefile_ Makefile

link:	etc/list_of_use
	(cd lib/perl; ln `cat ../../etc/list_of_use` .)

reconfig: fml.c
	cc -s -O fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

config: fml.c fml.pl config1 config2
	sed 's@XXFMLDIR@$(XXFMLDIR)@g' fml.c > __TMP__
	mv __TMP__ fml.c 
	sed 's@XXFMLDIR@$(XXFMLDIR)@' fml.pl > __TMP__
	mv __TMP__ fml.pl
	sed -e 's/XXML/$(XXML)/' -e 's/XXMAINTAINER/$(XXMAINTAINER)/' \
	config.ph > __TMP__
	mv __TMP__ config.ph

config1: config.ph-fundamental
	sed -e 's/XXML/$(XXML)/' -e 's/XXMAINTAINER/$(XXMAINTAINER)/' \
	config.ph-fundamental > __TMP__
	mv __TMP__ config.ph-fundamental

config2:config.ph-fundamental-j
	sed -e 's/XXML/$(XXML)/' -e 's/XXMAINTAINER/$(XXMAINTAINER)/' \
	config.ph-fundamental-j > __TMP__
	mv __TMP__ config.ph-fundamental-j

versionup:
	(cd ../distrib/lib; tar cvf ../../fml_pl_packages.tar perl)
	rm -f ../fml_pl_packages.tar.gz 
	gzip -9 ../fml_pl_packages.tar 

doc: 
	$(SH) bin/html-driver
	$(SH) bin/texinfo-driver

clean:
	gar *~ _* tmp/mget* core tmp/MSend*.[0-9] tmp/extrac* tmp/pipe*

DISTRIB: distrib versionup archive
fj: distrib archive fj.sources

update:  DISTRIB SNAPSHOT UpDate
local:  local-update
local-update:  distrib UpDate
snap: DISTRIB SNAPSHOT
snapshot: DISTRIB SNAPSHOT

UpDate:  $(SOURCES)
	@ echo "if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi"
	@ if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi
	(cd ../lib; ./UpDate)

SNAPSHOT: 
	uuencode ../fml-$(RCSID)-lib$(LIBID).tar.gz fml-$(RCSID)-lib$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current
	rsh beth "cd $(PWD); ./bin/UpDate_in_A_FTP fml-$(RCSID)-lib$(LIBID).tar.gz fml-current.$(DATE).tar.gz"

faq:	make-faq
make-faq: MasterDoc/FAQ
	(echo -n "Last modified: "; date) > /tmp/__TMP__
	(echo -n "	Last modified: "; date) > /tmp/__TMP2__
	sh bin/DocReconfigure
	rm -f /tmp/__TMP__ /tmp/__TMP2__

distrib: message make-faq dist

message: 
	@echo  "" 
	@echo  "YOU USE        gmake        ? O.K.?" 
	@echo  "" 

metaconfig: MANIFEST.new
	rsh exelion "cd $(PWD); metaconfig"

# apply 'echo %1=\"\$\(%1\)\"\; export %1\;\\' `cat tmp/list `
dist: $(SOURCES)
	@ sh bin/counter++
	(BIN_SOURCES="$(BIN_SOURCES)"; export BIN_SOURCES;\
	DOC="$(DOC)"; export DOC;\
	HOME="$(HOME)"; export HOME;\
	MDOC="$(MDOC)"; export MDOC;\
	OLDSOURCES="$(OLDSOURCES)"; export OLDSOURCES;\
	PWD="$(PWD)"; export PWD;\
	SOURCES="$(SOURCES)"; export SOURCES;\
	TMP="$(TMP)"; export TMP;\
	UPDIR="$(UPDIR)"; export UPDIR;\
	sh bin/make-distribution)

archive:
	@ sh bin/counter++
	@ if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi
	sed '/^DISTRIB/,$$d' Makefile | sed 's/gar/rm \-f/' |\
	sed '/XXMAINTAINER/s/Elena/Elena-request/g' |\
	sed '/#BETH/,/#BETH/d' > $(UPDIR)/distrib/Makefile
	(cd ../distrib; egrep 'Id:' *.pl */*.pl contrib/*/*.pl) |\
	perl bin/Cal_Id.pl |tee contrib/version > $(UPDIR)/distrib/lib/version 
	@ echo $(RCSID)-lib$(LIBID)
	@ echo COUNTER IS $(COUNT)
	@ echo " "
	@ echo rm -f $(UPDIR)/fml-$(RCSID)
	@ rm -f $(UPDIR)/fml-$(RCSID)
	@ echo "if [ -d $(UPDIR)/fml-$(RCSID) ]; then mv $(UPDIR)/fml-$(RCSID) $(TRASH)/fml-$(RCSID).$(COUNT) ;fi"
	@ if [ -d $(UPDIR)/fml-$(RCSID) ]; then mv $(UPDIR)/fml-$(RCSID) $(TRASH)/fml-$(RCSID).$(COUNT) ;fi

#	(cd $(UPDIR); ln -s distrib fml-$(RCSID)-lib$(LIBID))
	(cd $(UPDIR); mv distrib fml-$(RCSID))
	(cd $(UPDIR); tar cvf fml-$(RCSID)-lib$(LIBID).tar fml-$(RCSID) )
#	(cd $(UPDIR); mv distrib.tar fml-$(RCSID)-lib$(LIBID).tar)
	(cd $(UPDIR); gzip -9 -f fml-$(RCSID)-lib$(LIBID).tar)
#	(cd $(UPDIR); ln fml-$(RCSID)-lib$(LIBID).tar.gz fml-current.$(DATE).tar.gz)

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

C:
	rsh beth "cd $(PWD); make c"
