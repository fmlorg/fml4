# contrib/MatomeOkuri Makefile
######## Please custumize below ########

# Mailing List Name
XXML = erica@phys.titech.ac.jp

# Maintainer(maybe your own) address. 
# Be an address different from ML own one!
# Recommended address is e.g. MailingList-request@... created for this purpose.
XXMAINTAINER = erica@phys.titech.ac.jp

# where ML Server works. 
# escape '\' in XXFMLDIR is needed for 'sed' 
XXFMLDIR = \/home\/axion\/fukachan\/work\/spool\/contrib\/MatomeOkuri

# Please set the uid of Maintainer! about uid see below. 
# "fukachan:********:1304:***:Gecos Field:home:shell" in /etc/passwd 
# where the third field is uid(User ID).
# if using yp(NIS), see /etc/passwd in NIS Master Server.
XXUID    = 1304

# file registerd for matome okuri
SPOOLEDFILE = katori

#BETH
MAKE     = /usr/gnu/bin/gmake
SHELL    = /bin/sh
UPDIR    = /home/axion/fukachan/work/spool
PWD      = $(UPDIR)/EXP/contrib/MatomeOkuri
UPMATOME = $(UPDIR)/distrib/contrib/MatomeOkuri
SOURCES  = setup.pl control README README.2
#BETH

all: config $(SPOOLEDFILE)
	touch $(SPOOLEDFILE)
	chmod 660 $(SPOOLEDFILE)

config: msend.pl msend.ph setup.pl
	sed 's/XXFMLDIR/$(XXFMLDIR)/' msend.pl > __TMP__
	mv __TMP__ msend.pl
	sed 's/XXML/$(XXML)/' msend.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ msend.ph
	sed 's/XXFMLDIR/$(XXFMLDIR)/' setup.pl > __TMP__
	mv __TMP__ setup.pl

clean:
	delete *~ _* mget* core

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPMATOME)
	mkdir $(UPMATOME)
	cp -p $(SOURCES) $(UPMATOME)
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP\/contrib\/MatomeOkuri/XXFMLDIR/g' msend.pl > $(UPMATOME)/msend.pl
	sed '/MAINTAINER/s/erica@phys.titech.ac.jp/XXMAINTAINER/g' msend.ph |\
	sed 's/erica@phys.titech.ac.jp/XXML/g' > $(UPMATOME)/msend.ph
	sed 's/\/home\/axion\/fukachan\/work\/spool\/EXP\/contrib\/MatomeOkuri/XXFMLDIR/g' setup.pl > $(UPMATOME)/setup.pl
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' > $(UPMATOME)/Makefile | sed '/#BETH/,/#BETH/d' > $(UPMATOME)/Makefile

