#BETH
TARGET   = $(UPDIR)/distrib/contrib/fml_R1_localhack
SOURCES  = mnews schwalben putfiles Elena
#BETH

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(TARGET)
	mkdir $(TARGET)
	cp README $(TARGET)
	@ for dir in $(SOURCES); do (chdir $$dir; make DISTRIB) ; done;

uja:
	find $(SOURCES) -type f -print |grep -v RCS > /tmp/.fml.list
	cat /tmp/.fml.list
