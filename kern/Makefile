# fml Makefile
# $Id$

CC 	  = cc
CFLAGS	  = -s -O
SH	  = /bin/sh
PWD       = /home/beth/fukachan/w/fml
CONFIG_PH = ./config.ph
#XXFMLDIR  = $(PWD)
XXFMLDIR  = /home/beth/fukachan/w/fml
HOME      = /home/beth/fukachan

include usr/mk/prog


all:	fml.c fml.pl config.ph
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl
	@ echo " "
	@ echo "Generating sample settings"
	perl ./sbin/gen-samples.pl $(CONFIG_PH) $(XXFMLDIR)
	@ echo " "
	@ echo "Configure..."
	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml2 )
#	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml )
	@ echo " "
	@ if [ -f etc/motd ]; then cat etc/motd; fi

newconfig:
	perl cf/config cf/Elena > config.ph

reconfig: fml.c
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

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

allclean: clean cleanfr

clean:
	gar *~ _* proc/*~ tmp/mget* core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*:*.[0-9]

cleanfr:
	gar *.frbak proc/*.frbak

DISTRIB: distrib 
#DISTRIB: distrib export archive versionup 
### CUT OUT HEREAFTER WHEN RELEASE

fj: distrib archive fj.sources


local:  local-update
local-update:  distrib UpDate
snap: DISTRIB SNAPSHOT

update:  DISTRIB SNAPSHOT UpDate sid_update fml_local_update
#snapshot: DISTRIB SNAPSHOT sid_update fml_local_update

snapshot: 
	(/bin/sh usr/sbin/release.sh 2>&1| tee /var/tmp/release.log)

export:

#	(cd ../distrib/; RCP2 -h beth -d .ftp/pub/net/fml-current/snapshot .)

mirror:
	(cd ..; \
	 tar cvf - EXP |gzip > EXP.tar.gz; \
	 RCP2 -h paffy.hss -d work 		EXP.tar.gz; \
	 rcp EXP.tar.gz exelion:/var/local ; \
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

SNAPSHOT: uuencode ftp

uuencode:
	@ echo "uuencode ../fml-$(RCSID)$(LIBID).tar.gz fml-$(RCSID)$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current"
	@ uuencode ../fml-$(RCSID)$(LIBID).tar.gz fml-$(RCSID)$(LIBID)_$(DATE).tar.gz > ../fml-current/fml-current

ftp:
	@ echo "$(FML)/usr/sbin/UpDate_in_A_FTP fml-$(RCSID)$(LIBID).tar.gz fml-current.$(DATE).tar.gz"
#	@ rsh ftp "$(FML)/usr/sbin/UpDate_in_A_FTP \"fml-$(RCSID)$(LIBID).tar.gz\" fml-current.$(DATE).tar.gz"
#	@ rsh beth "$(FML)/usr/sbin/UpDate_in_A_FTP \"fml-$(RCSID)$(LIBID).tar.gz\" fml-current.$(DATE).tar.gz"

#cur-chk:
#	rsh ftp "cd /usr/local/ftp/pub/net/fml-current; ls -l;"

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

compat:
	perl cf/config -c > proc/libcompat_cf1.pl

message: 
	@echo  "" 
	@echo  "YOU USE        gmake        ? O.K.?" 
	@echo  "" 

#@rm -f $(UPDIR)/distrib $(UPDIR)/fml-$(RCSID)
#@echo  "" 

fix-rcsid:
	@ echo " "; echo "Fixing rcsid ... " 
	@ /bin/sh usr/sbin/fix-rcsid.sh
	@ chmod 755 *.pl bin/*.pl sbin/*.pl libexec/*.pl 
	@ echo " Done. " 


dist: compat $(SOURCES)
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
	@ echo " "
	@ echo "Fixing Makefile"
	sed '/^DISTRIB/,$$d' Makefile | sed 's/gar/rm \-f/' |\
	sed '/^include/'d > $(UPDIR)/distrib/Makefile

archive:
	@ (chdir var/run; version.pl)
	if [ ! -d $(UPDIR)/distrib ]; then ln -s $(UPDIR)/fml-$(RCSID) $(UPDIR)/distrib ;fi
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



