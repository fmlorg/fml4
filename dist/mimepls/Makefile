## Makefile for mime_pls (install & archive)
INSTALL_DIR = /usr/local
LIB_DIR = $(INSTALL_DIR)/lib/perl
BIN_DIR = $(INSTALL_DIR)/bin

APPLICATION = rmime wmime
LIBRARY = mimer.pl mimew.pl
DOCUMENT = mime_pls.doc history Makefile
ARCHIVE = mime_pls
SUF = gz
TAR = tar
COMPRESS = gzip
INSTALL = install -c

all: ppack archive

install: $(APPLICATION) $(LIBRARY)
	$(INSTALL) -m 755 -o root $(APPLICATION) $(BIN_DIR)
	$(INSTALL) -m 644 -o root $(LIBRARY) $(LIB_DIR)

uninstall:
	cd $(BIN_DIR);\
	rm -f $(APPLICATION)
	cd $(LIB_DIR);\
	rm -f $(LIBRARY)

ppack: $(ARCHIVE).pp

$(ARCHIVE).pp: $(APPLICATION) $(LIBRARY) $(DOCUMENT)
	ppack $(DOCUMENT) $(LIBRARY) $(APPLICATION) > $(ARCHIVE).pp

archive: $(ARCHIVE).tar.$(SUF).uue

$(ARCHIVE).tar.$(SUF).uue: $(APPLICATION) $(LIBRARY) $(DOCUMENT)
	$(TAR) cvf $(ARCHIVE).tar $(DOCUMENT) $(LIBRARY) $(APPLICATION)
	$(COMPRESS) $(ARCHIVE).tar
	uuencode $(ARCHIVE).tar.$(SUF) $(ARCHIVE).tar.$(SUF) > $(ARCHIVE).tar.$(SUF).uue

clean:
	rm -f $(ARCHIVE).tar.* $(ARCHIVE).pp
