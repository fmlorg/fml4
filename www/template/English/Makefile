RSYNC = rsync
ECONV = nkf -e
PERL  = perl
FIX   = ../../sbin/JapaneseToEnglish.pl

import:
	$(RSYNC) -C -av  ../Japanese/ ./
	for x in */*.html ; do $(ECONV) $$x > $$x.new ; mv $$x.new $$x ; done
	$(PERL) -i.bak $(FIX) *admin/*.html
