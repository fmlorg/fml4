# 
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

CC 	  = cc
CFLAGS	  = -s -O

SH	  = /bin/sh
MKDIR     = mkdirhier

PWD       = `pwd`
CONFIG_PH = ./config.ph
GENHOST   = _`hostname`_

include usr/mk/prog

all:
	perl ./makefml

install:
	perl ./makefml install

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

doc: 	html_doc

html_doc:
	perl bin/fwix.pl -T op -m html -D doc/html/op -d doc/smm < doc/smm/op.wix


roff:	doc/smm/op.wix
	@ echo "sorry, not yet implemetend but halfly completed?"
	@ echo ""
	@ echo "Making nroff of doc/smm/op => var/man"
	@ $(MKDIR) var/man
	@ perl bin/fwix.pl -T smm/op -m roff -R var/man -I doc/smm doc/smm/op.wix

texinfo:
	@ echo sorry, not yet implemetend


DISTRIB: distrib 


allclean: clean cleanfr

clean:
	gar *~ _* proc/*~ \
	tmp/mget* *.core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*.[0-9] \
	tmp/release.info* tmp/sendfilesbysplit* 
	(chdir $(HOME)/var/simulation/var; gar queue*/*)
	(chdir w; 	gar *~ _* proc/*~ \
	tmp/mget* *.core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*.[0-9] \
	tmp/release.info* tmp/sendfilesbysplit* )


cleanfr:
	gar *.frbak */*.frbak



### ATTENTION! CUT OUT HEREAFTER WHEN RELEASE
#
# OLD# 
#     DISTRIB: distrib export archive versionup 
#     fj: distrib archive fj.sources

local: distrib 

ntdist: 
	(/bin/sh .release/generator 2>&1| tee /var/tmp/_distrib.log)
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
	(/bin/sh .release/generator 2>&1| tee /var/tmp/_distrib.log)
	@ usr/sbin/error_report.sh /var/tmp/_distrib.log
	@ echo "";
	@ echo "make distsnap  (make snapshot of dist) "
	@ echo "make sync      (syncrhonize -> fml.org)"

distsnap:
	@ (cd /var/tmp/fml-current/; rsync -auv . $(HOME)/.ftp/snapshot)

snapshot: 
	(/bin/sh .release/generator -ip 2>&1| tee /var/tmp/_release.log)
	@ usr/sbin/error_report.sh /var/tmp/_release.log

release:
	(/bin/sh .release/generator -rp 2>&1| tee /var/tmp/_release.log)
	@ usr/sbin/error_report.sh /var/tmp/_release.log

faq:	 plaindoc
textdoc: plaindoc

INFO:	$(FML)/.info
	$(MKDIR) /var/tmp/.fml
	rm -f /var/tmp/.fml/INFO
	(nkf -e doc/ri/INFO ; nkf -e .info ; nkf -e doc/ri/README.wix) |\
		nkf -e |tee var/doc/INFO > /var/tmp/.fml/INFO

plaindoc: doc/smm/op.wix
	@ $(MKDIR) /var/tmp/.fml
	@ rm -f /var/tmp/.fml/INFO
	@ (nkf -e doc/ri/INFO ; nkf -e .info ; nkf -e doc/ri/README.wix) |\
		nkf -e > /var/tmp/.fml/INFO
	@ sh usr/sbin/DocReconfigure

htmldoc:	doc/smm/op.wix
	@ (chdir doc/html; make)
	@ $(MKDIR) var/html/op
	@ (chdir doc/html; make op)
	@ echo "Please see ./var/html/index.html for html version documents"

search:
	@ echo ""
	@ sh .release/search_doc_generator
	@ (cd /usr/local/SSE; make)

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
#	usr/bin/uncomments.pl $(HOME)/work/src/USEFUL/hml-1.6/hml.pl |wc

use:
	grep require *pl | grep "\'lib"

reset:
	gar summary log members actives seq
	gar *.bak
	gar var/log/*.[0-9]



capital:
	cat `echo *pl proc/*pl | sed 's#proc/libcompat.pl##'| sed 's#proc/libsid.pl##'` |\
	perl usr/bin/getcapital.pl | sort -n | uniq | sed 's/\$\(.*\)/\1:/' 


syncwww:
	rsync -aubv $(FML)/var/html/ $(WWW)

syncinfo:
	nkf -j var/doc/INFO > $(HOME)/.ftp/snapshot/info

bethdoc: INFO syncinfo newdoc search
newdoc: htmldoc syncwww syncinfo 

varcheck:
	perl usr/sbin/search-config-variables.pl -D -s -m *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

v2: varcheck2

varcheck2:
	perl usr/sbin/search-config-variables.pl -E -D -s -m *pl libexec/*pl proc/*pl bin/*pl |\
	tee /tmp/VARLIST
	@ wc /tmp/VARLIST

v3:
	perl usr/sbin/search-config-variables.pl \
	-E -D -s *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

sync:
	# scp -v -p /var/tmp/distrib/src/*.pl eriko:~/.fml
	rsync --rsh ssh -aubzv /var/tmp/fml-current/src/ eriko:~/.fml
	rsync --rsh ssh -aubzv /var/tmp/fml-current/drafts/ eriko:~/.fml
	rsync --rsh ssh -aubzv /var/tmp/fml-current/libexec/ eriko:~/.fml/libexec
	(echo test of new FML snapshot; echo ; echo "--fukachan")|\
	Mail test@fml.org

test:
	(bin/emumail.pl; echo test )|perl fml.pl $(PWD) $(PWD)/proc

makefml:
	sh usr/sbin/reset-makefml

init-makefml:
	cp sbin/makefml /tmp/distrib
	(chdir /tmp/distrib ; perl makefml )

admin-ci:
	ci usr/bin/[^c^r]* usr/sbin/*
	chmod 755 usr/*bin/*

rd:
	perl usr/bin/rdiff.pl *pl libexec/*pl proc/lib[a-jl-z]*pl *bin/[a-z]* Makefile C/*.[ch]


simulation:
	sh $(FML)/.simulation/bootstrap

rel:
	rm -f /tmp/relnotes

libkern:
	sed '/^$$Rcsid/,/MAIN ENDS/d' fml.pl > proc/libkern.pl

asuka:
	(chdir sbin; ( echo put makefml; echo quit;) | ftp -ivd asuka)

diff:
	fvs diff * proc/* libexec/* 

ci:
	fvs ci * proc/* libexec/* 

docdiff:
	fvs diff doc/ri/*wix doc/smm/*wix

scan:
	fvs scan * proc/* libexec/* doc/ri/*wix doc/smm/*wix |\
	tee /tmp/_scan_
	@ grep Modified /tmp/_scan_
	@ rm /tmp/_scan_

loop:
	perl usr/sbin/search_loop.pl *pl libexec/* proc/lib*pl|less -plocal

e:
	@ (cd /var/tmp/fml-current; pwd ; make install)
