## Makefile for mime_pls (install & archive)
INSTALL_DIR = /usr/local
LIB_DIR = $(INSTALL_DIR)/lib/perl
BIN_DIR = $(INSTALL_DIR)/bin

APPLICATION = rmime wmime rbody wbody
LIBRARY = mimer.pl mimew.pl
DOCUMENT = mime_pls.doc history Makefile \
	   index.html document.html history.html

ARCHIVE = mime_pls202
CSUF = gz
SUF = tgz

TAR = tar
COMPRESS = gzip
INSTALL = install -c
RENAME = mv

all: rats archive

install: $(APPLICATION) $(LIBRARY)
	$(INSTALL) -m 755 -o root $(APPLICATION) $(BIN_DIR)
	$(INSTALL) -m 644 -o root $(LIBRARY) $(LIB_DIR)

uninstall:
	cd $(BIN_DIR);\
	rm -f $(APPLICATION)
	cd $(LIB_DIR);\
	rm -f $(LIBRARY)

rats: $(ARCHIVE).rat

$(ARCHIVE).rat: $(APPLICATION) $(LIBRARY) $(DOCUMENT)
	rat $(DOCUMENT) $(LIBRARY) $(APPLICATION) > $(ARCHIVE).rat

archive: $(ARCHIVE).$(SUF).uue

$(ARCHIVE).$(SUF).uue: $(APPLICATION) $(LIBRARY) $(DOCUMENT)
	$(TAR) cvf $(ARCHIVE).tar $(DOCUMENT) $(LIBRARY) $(APPLICATION)
	$(COMPRESS) $(ARCHIVE).tar
	$(RENAME) $(ARCHIVE).tar.$(CSUF) $(ARCHIVE).$(SUF)
	uuencode $(ARCHIVE).$(SUF) $(ARCHIVE).$(SUF) > $(ARCHIVE).$(SUF).uue

clean:
	rm -f $(ARCHIVE).tar* $(ARCHIVE).$(SUF)* $(ARCHIVE).rat
