#BETH
PWD      = $(UPDIR)/EXP/contrib/MIME
UPMATOME = $(UPDIR)/distrib/contrib/MIME
SOURCES  = README v1.1a/*
#BETH

all: config $(SPOOLEDFILE)
	touch $(SPOOLEDFILE)
	chmod 660 $(SPOOLEDFILE)

config: msend.pl msend.ph setup.pl
	sed 's/FMLDIR/$(FMLDIR)/' msend.pl > __TMP__
	mv __TMP__ msend.pl
	sed 's/XXML/$(XXML)/' msend.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ msend.ph
	sed 's/FMLDIR/$(FMLDIR)/' setup.pl > __TMP__
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
	rm -f $(UPMATOME)/*.pl

print: msend.pl msend.ph setup.pl mm.pl README msend-300.pl
	ra2ps msend.pl msend.ph setup.pl mm.pl README msend-300.pl | lpr -St
