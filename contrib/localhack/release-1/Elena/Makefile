TARGET  = $(UPDIR)/distrib/lib/fml_R1_localhack/Elena
SOURCES = vote.pl vote.ph Elena.pl Elena.ph README patch.fml.pl  help

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(TARGET)
	mkdir $(TARGET)
	cp -p $(SOURCES) $(TARGET)
