# fml Makefile
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$

CC 	  = cc
CFLAGS	  = -s -O
SH	  = /bin/sh
PWD       = `pwd`
CONFIG_PH = ./config.ph
GENHOST   = _`hostname`_

include usr/mk/prog

all:
	perl ./makefml

install:
	perl ./makefml install

old-install:	fml.c src/fml.pl config.ph
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 src/fml.pl src/msend.pl sbin/* bin/* libexec/*
	@ if [ ! -f etc/config.ph.org -a -f config.ph ];then \
		echo "";echo "*** backuping config.ph at etc/config.ph.org";\
		cp -p config.ph etc/config.ph.org;\
	  elif [ -f config.ph ] ; then \
		echo "";echo "*** backuping config.ph at tmp/config.ph.org";\
		cp -p config.ph tmp/config.ph.org;\
	  fi
	@ touch config.ph
	@ perl sbin/compat_p.pl > cf/__compat__
	@ echo " "
	@ cp /dev/null cf/$(GENHOST)
	@ if [ "X$(MAIL_LIST)" != "X" ];  then \
		echo MAIL_LIST	$(MAIL_LIST)  >> cf/$(GENHOST);\
		echo MAINTAINER	$(MAINTAINER) >> cf/$(GENHOST);\
		perl sbin/compat_p.pl	      >> cf/$(GENHOST);\
	  fi
	@ echo "Reconfiguring fml to fit your environment ... "
	@ if [ -s cf/$(GENHOST) ]; then \
		echo "	Generating your config.ph from cf/$(GENHOST) ... "; \
		echo "	perl cf/config cf/$(GENHOST) > config.ph"; \
		echo ""; \
		perl cf/config cf/$(GENHOST) > config.ph; \
	  fi
	@ perl cf/config -c -I cf/compat.ignore > src/libcompat_cf1.pl 
	@ echo " "
	@ (perl etc/samples/configure.pl etc/samples/[ai]* \
		etc/samples/crontab |tee tmp/samples)
	@ perl cf/config -F cf/command > samples/sitedef.ph
	@ echo "		samples/sitedef.ph" | tee -a tmp/samples
	@ echo " "
	@ echo "Configure..."; echo " ";
	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml2 )
	@ echo " "
	@ if [ -f etc/motd ]; then cat etc/motd; fi




# @ echo "Generating sample settings"
# perl ./sbin/gen-samples.pl $(CONFIG_PH) $(FMLDIR)
#	( SH=$(SH); export SH; $(SH) ./sbin/configure_fml )

fixenv:
	@ echo " "
	@ echo "Reconfiguring fml to fit your environment ... "
	@ perl cf/config -c -I cf/compat.ignore > src/libcompat_cf1.pl 
	@ echo " "

sampels: sample
sample:
	@ (perl etc/samples/configure.pl etc/samples/[ai]*)

newconfig:
	perl cf/config cf/Elena > config.ph

reconfig: fml.c
	perl sbin/ccfml $(CC) $(CFLAGS) $(OPTS) fml.c -o fml
	chmod 4755 fml
	chmod 755 *.pl

dns_check:
	@ perl bin/dns_check.pl

localtest: 
	@ echo " "
	@ echo "LOCALLY CLOSED TEST in DEBUG MODE(-d option)"
	@ echo "perl sbin/localtest.pl | perl $(PWD)src/fml.pl -d $(PWD) "
	@ echo " "
	@ echo IF YOU WOULD LIKE TO TEST THE DELIVERY WITHOUT Sendmail
	@ echo JUST TYPE
	@ echo "perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -udebug $(PWD)"
	@ echo " "
	@ echo " "
	@ echo "O.K.?(wait 3 sec.)"; sleep 3;
	@ echo INPUT:
	@ echo "-----------------------------------"
	@ perl sbin/localtest.pl 
	@ echo "==================================="
	@ echo " "
	@ echo " "
	@ echo " "
	@ echo "This Header O.K.?(wait 3 sec.)"; sleep 3;
	@ echo OUTPUT: debug info from src/fml.pl 
	@ echo "   *** DEBUG MODE! ***  "
	@ echo "-----------------------------------"
	perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -d $(PWD) 
	@ echo "   DEBUG MODE!   "
	@ echo "-----------------------------------"

link:	etc/list_of_use
	(cd lib/perl; ln `cat ../../etc/list_of_use` .)

doc: 	htmldoc

roff:	doc/smm/op.wix
	@ echo "Making nroff of doc/smm/op => var/man"
	@ test -d var/man || mkdir var/man
	@ perl bin/fwix.pl -T smm/op -m roff -R var/man -I doc/smm doc/smm/op.wix

texinfo:
	$(SH) bin/texinfo-driver

allclean: clean cleanfr

clean:
	gar *~ _* proc/*~ \
	tmp/mget* *.core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*.[0-9] \
	tmp/release.info* tmp/sendfilesbysplit* \
	var/simulation/var/queue*/*

cleanfr:
	gar *.frbak */*.frbak



DISTRIB: distrib 
### ATTENTION! CUT OUT HEREAFTER WHEN RELEASE
#
# OLD# 
#     DISTRIB: distrib export archive versionup 
#     fj: distrib archive fj.sources

local: distrib 

ntdist: 
	(/bin/sh usr/sbin/release.sh 2>&1| tee /var/tmp/_distrib.log)
	(/bin/sh usr/sbin/nt-release.sh /tmp/distrib 2>&1|\
	 tee -a /var/tmp/_distrib.log)
	@ usr/sbin/error_report.sh /var/tmp/_distrib.log
	@ echo "(chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)"
	@ (chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)
	@ chmod -R 777 /tmp/nt

nt:	
	@ (chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)
	@ chmod -R 777 /tmp/nt

dist:	distrib 
distrib:
	(/bin/sh usr/sbin/release.sh 2>&1| tee /var/tmp/_distrib.log)
	@ usr/sbin/error_report.sh /var/tmp/_distrib.log

snapshot: 
	(/bin/sh usr/sbin/release.sh -ip 2>&1| tee /var/tmp/_release.log)
	@ usr/sbin/error_report.sh /var/tmp/_release.log

faq:	 plaindoc
textdoc: plaindoc

plaindoc: doc/smm/op.wix
	@ if [ ! -d /var/tmp/.fml ]; then mkdir /var/tmp/.fml; fi
	@ rm -f /var/tmp/.fml/INFO
	@ (nkf -e doc/ri/INFO ; nkf -e .info ; nkf -e doc/ri/README.wix) |\
		nkf -e > /var/tmp/.fml/INFO
	@ sh usr/sbin/sync-rcs-of-doc.sh
	@ sh usr/sbin/DocReconfigure
	@ perl bin/fwix.pl -n i doc/master/help.wix  > doc/master/help

htmldoc:	doc/smm/op.wix
	@ (chdir doc/html;make)
	@ echo "Making WWW pages of doc/smm/op => var/html/op"
	@ test -d var/html/op || mkdir var/html/op
	@ perl doc/ri/conv-install.pl < doc/ri/INSTALL.wix > doc/smm/install-new.wix 
	@ perl usr/sbin/fix-wix.pl doc/smm/op.wix |\
	  perl bin/fwix.pl -T smm/op -m html -D var/html/op -I doc/smm
	@ echo "Please see ./var/html/index.html for html version documents"

message: 

fix-rcsid:
	@ echo " "; echo "Fixing rcsid ... " 
	@ /bin/sh usr/sbin/fix-rcsid.sh
	@ chmod 755 *.pl bin/*.pl sbin/*.pl libexec/*.pl 
	@ echo " Done. " 

contents: FAQ
	sed -n '/Appendix/,$$p' FAQ |\
	egrep '^[0-9]\.' | perl -nle '/^\d\.\s/ && print ""; print $_'

check:	fml.pl
	sh usr/sbin/check.sh

c:	*.p?
	(2>&1; for x in *.p? ; do perl -cw $$x ; done ) |\
	perl usr/sbin/fix-perl-c-output.pl

C:
	rsh beth "cd $(PWD); make c"

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



test:
	h.pl | $(HOME)/libexec/fml/fml.pl $(FML) -d --distribute
	(h.pl; echo "# mget last:2 mp") |\
	 $(HOME)/libexec/fml/fml.pl $(FML) -d --caok

syncwww:
	sh usr/sbin/syncwww

syncinfo:
	nkf -j var/doc/INFO > $(HOME)/.ftp/snapshot/info

bethdoc: newdoc
newdoc: plaindoc htmldoc syncwww syncinfo

varcheck:
	perl usr/sbin/search-config-variables.pl -D -s -m *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

v2: varcheck2

varcheck2:
	perl usr/sbin/search-config-variables.pl -E -D -s -m *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

v3:
	perl usr/sbin/search-config-variables.pl \
	-E -D -s *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST
sync:
	scp -v -p /tmp/distrib/src/*.pl eriko:~/.fml

TEST:
	tar cf - `find etc/ sbin |grep -v RCS` | ( chdir /tmp/distrib ; tar xvf - )

ruby:
	tar cf - bin cf *.p? etc libexec proc sbin |\
	/usr/bin/rsh ruby 'chdir /usr/local/fml; tar xvf -'


makefml:
	sh usr/sbin/reset-makefml

init-makefml:
	cp sbin/makefml /tmp/distrib
	(chdir /tmp/distrib ; perl makefml )

admin-ci:
	ci usr/bin/[^c^r]* usr/sbin/*
	chmod 755 usr/*bin/*

ci:
	ci *pl libexec/*pl proc/lib[a-jl-z]*pl *bin/[a-z]* Makefile C/*.[ch]
	chmod 755 fml.pl msend.pl libexec/*pl

rd:
	perl usr/bin/rdiff.pl *pl libexec/*pl proc/lib[a-jl-z]*pl *bin/[a-z]* Makefile C/*.[ch]


simulation:
	cp /tmp/log /tmp/log.old
	sh .simulation/bootstrap
	diff -u /tmp/log.old /tmp/log|Mail -s Diff:fml.simulation.log elena
	grep XXX /tmp/log|Mail -s fml.simulation.log elena
