#BETH
PWD      = $(UPDIR)/EXP/contrib/fml_R1_localhack/schwalben
UPSCH    = $(UPDIR)/distrib/contrib/fml_R1_localhack/schwalben
SOURCES  = Makefile README auto-return.doc config.ph.example example-install.doc libsch.pl patch.sed
RCSID=`sed -n 's/\(.*\)Id\(.*\)fml\.pl,v \(.*\) 19\(.*\)/\3/p' $(PWD)/fml.pl`
#BETH

all:	config fml.c fml.pl config.ph
	cc -s -O fml.c -o fml
	chown $(XXUID) fml
	chmod 6755 fml
	chmod 755 *.pl

config: fml.c fml.pl setup.pl
	sed 's/FMLDIR/$(FMLDIR)/' fml.c |\
	sed 's/XXUID/$(XXUID)/' > __TMP__
	mv __TMP__ fml.c 
	sed 's/FMLDIR/$(FMLDIR)/' fml.pl > __TMP__
	mv __TMP__ fml.pl
	sed 's/XXML/$(XXML)/' config.ph |\
	sed 's/XXMAINTAINER/$(XXMAINTAINER)/'	> __TMP__
	mv __TMP__ config.ph
	sed 's/FMLDIR/$(FMLDIR)/' setup.pl > __TMP__
	mv __TMP__ setup.pl
	sed 's/FMLDIR/$(FMLDIR)/' split_and_sendmail.pl > __TMP__
	mv __TMP__ split_and_sendmail.pl

clean:
	rm -f *~ _* mget* core

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPSCH)
	mkdir $(UPSCH)
	cp -p $(SOURCES) $(UPSCH)
#	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' | sed '/#BETH/,/#BETH/d' > $(UPSCH)/Makefile
