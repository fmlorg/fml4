#BETH
PWD      = $(UPDIR)/EXP/contrib/fml_R1_localhack/putfiles
UPMATOME = $(UPDIR)/distrib/contrib/fml_R1_localhack/putfiles
SOURCES  = INSTALL Makefile README restructure-summary.pl
#BETH

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPMATOME)
	mkdir $(UPMATOME)
	cp -p $(SOURCES) $(UPMATOME)
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' > $(UPMATOME)/Makefile | sed '/#BETH/,/#BETH/d' > $(UPMATOME)/Makefile
	(cd $(UPMATOME); ln -s INSTALL patch-config.ph)
