.include "distrib/mk/fml.prog.mk"

### executables; document generators ###
# release snapshot generator library
GEN_PLAIN_DOC   = $(SH) $(DIST_DOC_BIN)/genplaindoc.sh
DOC_GENERATOR   = $(SH) $(FML)/distrib/doc/bin/generator.sh
DOC_GENERATOR_D = $(SH) $(FML)/distrib/doc/bin/depend_wrapper.sh
DOC_CONV        = $(DOC_GENERATOR)
FIX_WIX         = $(PERL) ${FML}/distrib/bin/fix-wix.pl -X ${FML}

### sources ###
HTML_MISC_SOURCES += roadmap.html nt.html search-j.html search-e.html 
HTML_MISC_SOURCES += releng.ja.html

### targets ###
HTML_REQ_CPP_SOURCES  = index history download links mailinglist people
HTML_REQ_CPP_SOURCES += 3.0-new-features

HTML_MISC        += var/html/advisories/index.html var/html/advisories/index-e.html
HTML_SMM          = var/html/op/index.html var/html/op-e/index.html

## doc/ri
DOC_RI_SOURCES  = CHANGES CHECK_LIST FILES 
DOC_RI_SOURCES += CHANGES-3-0-maint
DOC_RI_SOURCES += INSTALL INSTALL_on_NT4 INSTALL_on_MacOS_X_Server
DOC_RI_SOURCES += INSTALL_with_SENDMAIL INSTALL_with_POSTFIX
DOC_RI_SOURCES += INSTALL_with_QMAIL INSTALL_with_EXIM
DOC_RI_SOURCES += INSTALL_with_ZMAILER
DOC_RI_SOURCES += PORTINGS README UPGRADE FEATURES TODO UPGRADE-3.0
DOC_RI_EXCEPTIONAL_SOURCES = RELEASE_NOTES INFO

# raw copy
DOC_RI_RAW     += COPYING


## doc/drafts
DOC_DRAFT_SOURCES  = confirm confirmd.ackreq deny guide 
DOC_DRAFT_SOURCES += help-admin help-fmlserv help objective welcome


## doc/advisory
DOC_ADVISORY_SOURCES  = happy99 migrating_domains melissa melissa_family year2000


### doc/examples
.include "doc/examples/Makefile"
.include "doc/examples/filter/Makefile"
.include "doc/examples/tips/Makefile"
.include "doc/examples/header/Makefile"
.include "doc/devel/Makefile"

### RULES ###
.include "distrib/mk/fml.sys.mk"

# special PLAINDOC rurles (depends on *SOURCES*)
.include "distrib/mk/fml.plaindoc.mk"

# examples; I provides this in html format only.
.include "distrib/mk/fml.examples.mk"

# doc/devel/
.include "distrib/mk/fml.devel.mk"

# special HTML rurles (depends on *SOURCES*)
.include "distrib/mk/fml.htmldoc.mk"
