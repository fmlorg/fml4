######## Please custumize below ########
#BETH
PWD      = $(UPDIR)/EXP/contrib/crosspost
UPMATOME = $(UPDIR)/distrib/contrib/crosspost
SOURCES  = README
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
	mkdir $(UPMATOME)/Cache
	cp -p Cache/Cache $(UPMATOME)/Cache
#	perl ../../bin/Skip.pl -mif -mdebug Cache/Cache \
#	> $(UPMATOME)/Cache/Cache
