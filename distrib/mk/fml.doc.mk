.include "distrib/mk/fml.prog.mk"

### executables; document generators ###
# release snapshot generator library
GEN_PLAIN_DOC   = $(SH) $(DIST_DOC_BIN)/genplaindoc.sh
DOC_GENERATOR   = $(SH) $(FML)/distrib/doc/bin/generator.sh
DOC_GENERATOR_D = $(SH) $(FML)/distrib/doc/bin/depend_wrapper.sh
DOC_CONV        = $(DOC_GENERATOR)
FIX_WIX         = $(PERL) ${FML}/distrib/bin/fix-wix.pl -X ${FML}

### sources ###
HTML_MISC_SOURCES = roadmap.html nt.html search-j.html search-e.html

### targets ###
HTML_MISC         = var/html/index.html var/html/index-e.html
HTML_SMM          = var/html/op/index.html var/html/op-e/index.html

## doc/ri
DOC_RI_SOURCES  = CHANGES CHECK_LIST FILES 
DOC_RI_SOURCES += INSTALL INSTALL_on_NT4 INSTALL_with_QMAIL 
DOC_RI_SOURCES += PORTINGS README UPGRADE
DOC_RI_EXCEPTIONAL_SOURCES = RELEASE_NOTES INFO


## doc/master
DOC_DRAFT_SOURCES  = confirm confirmd.ackreq deny guide 
DOC_DRAFT_SOURCES += help-admin help-fmlserv help objective welcome


### special PLAINDOC rurles (depends on *SOURCES*) ###
.include "distrib/mk/fml.plaindoc.mk"


### special HTML rurles (depends on *SOURCES*) ###
.include "distrib/mk/fml.htmldoc.mk"
