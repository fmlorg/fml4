UPMATOME = $(UPDIR)/distrib/contrib/mail2fax
SOURCES  = README libfax.pl

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPMATOME)
	mkdir $(UPMATOME)
	cp -p $(SOURCES) $(UPMATOME)
