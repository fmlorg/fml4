# contrib/libhml Makefile
######## Please custumize below ########

#BETH
PWD      = $(UPDIR)/EXP/contrib/libhml
UPMATOME = $(UPDIR)/distrib/contrib/libhml
SOURCES  = README help-admin FmlRemoreControl
#BETH

clean:
	delete *~ _* mget* core

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	(cd $(UPDIR)/distrib/contrib/; ln -s libhml remote)
	rm -fr $(UPMATOME)
	mkdir $(UPMATOME)
	cp -p $(SOURCES) $(UPMATOME)
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' > $(UPMATOME)/Makefile | sed '/#BETH/,/#BETH/d' > $(UPMATOME)/Makefile

print: $(SOURCES)
	ra2ps $(SOURCES) |lpr -St
