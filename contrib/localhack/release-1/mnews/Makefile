#BETH
PWD      = $(UPDIR)/EXP/contrib/fml_R1_localhack/mnews
UPSCH    = $(UPDIR)/distrib/contrib/fml_R1_localhack/mnews
SOURCES  = README* patch*
#BETH

clean:
	rm -f *~ _* mget* core

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPSCH)
	mkdir $(UPSCH)
	cp -p $(SOURCES) $(UPSCH)
