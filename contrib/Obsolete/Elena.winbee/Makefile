# Makefile 

#BETH
PWD      = $(UPDIR)/EXP/contrib/Elena.sample
UPELENA = $(UPDIR)/distrib/contrib/Elena.sample
SOURCES  = vote.pl vote.ph Elena.pl Elena.ph README help
PRINT_SOURCES = vote.pl vote.ph Elena.pl Elena.ph
#BETH

all:	vote.pl
	rm -f init.pl summary.pl
	ln vote.pl init.pl
	ln vote.pl summary.pl
	chmod 755 vote.pl summary.pl init.pl

init:
	cp /dev/null log
	cp /dev/null summary
	rm -fr ./spool
		

clean:
	rm -f *~ _* mget* core

print:
	\a2ps $(PRINT_SOURCES) |lpr -St

# Makefile 

#BETH
PWD      = $(UPDIR)/EXP/contrib/Elena.sample
UPELENA = $(UPDIR)/distrib/contrib/Elena.sample
SOURCES  = vote.pl vote.ph Elena.pl Elena.ph README patch.fml.pl  help
PRINT_SOURCES = vote.pl vote.ph Elena.pl Elena.ph
#BETH

DISTRIB: distrib

distrib: $(SOURCES)
	@if [ ! -d $(UPDIR)/distrib/contrib ];\
	then mkdir $(UPDIR)/distrib/contrib; fi;
	rm -fr $(UPELENA)
	mkdir $(UPELENA)
#	(cd $(UPDIR)/distrib/contrib; ln -s Elena VotingSystem)
#	(cd $(UPDIR)/distrib/contrib; ln -s Elena Osakana)
	cp -p $(SOURCES) $(UPELENA)
	sed '/^DISTRIB/,$$d' Makefile | sed 's/delete/rm \-f/' > $(UPELENA)/Makefile | sed '/#BETH/,/#BETH/d' > $(UPELENA)/Makefile
