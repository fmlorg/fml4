.include "distrib/mk/fml.prog.mk"

### sources ###
HTML_MISC_SOURCES += roadmap.html nt.html search-j.html search-e.html 
HTML_MISC_SOURCES += releng.ja.html
HTML_MISC_SOURCES += ftphier.ja.html ftphier.html
HTML_MISC_SOURCES += anoncvs.ja.html anoncvs.html anoncvs.en.html
HTML_MISC_SOURCES += good_bye_perl4.html CGIstatus.ja.html
HTML_MISC_SOURCES += menu.html menubar.html
HTML_MISC_SOURCES += menu-e.html menubar-e.html
HTML_MISC_SOURCES += index.ja.html index.en.html

### targets ###
HTML_REQ_CPP_SOURCES  = history download links mailinglist people
HTML_REQ_CPP_SOURCES += 3.0-new-features

HTML_MISC        += var/html/advisories/index.html var/html/advisories/index-e.html
HTML_SMM          = var/html/op/index.html var/html/op-e/index.html

# doc/ri
.include "doc/ri/Makefile"

# drafts
.include "drafts/Makefile"

# doc/advisory
.include "doc/advisories/Makefile"

# doc/examples
# .include "doc/examples/Makefile"
# .include "doc/examples/filter/Makefile"
# .include "doc/examples/tips/Makefile"
# .include "doc/examples/header/Makefile"
# .include "doc/examples/body/Makefile"
# .include "doc/examples/manual/Makefile"
# .include "doc/examples/virtual/Makefile"

# doc/devel/
.include "doc/devel/Makefile"

# doc/Japanese
.include "doc/${TUTORIAL_LANGUAGE}/Makefile"

### RULES ###
.include "distrib/mk/fml.sys.mk"

# special PLAINDOC rurles (depends on *SOURCES*)
.include "distrib/mk/fml.plaindoc.mk"

# examples; I provides this in html format only.
.include "distrib/mk/fml.examples.mk"

# tutorial;
.include "distrib/mk/fml.tutorial.mk"

# doc/devel/
.include "distrib/mk/fml.devel.mk"

# special HTML rurles (depends on *SOURCES*)
.include "distrib/mk/fml.htmldoc.mk"
