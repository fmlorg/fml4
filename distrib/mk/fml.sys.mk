.if !defined(FML)
FML     = $(PWD)
.endif

.if !defined(DESTDIR)
DESTDIR = /var/tmp/fml
.endif

.include "$(FML)/distrib/mk/fml.prog.mk"


### generators to export ###
DIST_DIR     = $(FML)/distrib
DIST_BIN     = $(DIST_DIR)/bin
DIST_DOC_BIN = $(DIST_DIR)/doc/bin

COMPILE_DIR  = $(DIST_DIR)/compile


### exports  ###
FTP_DIR      = $(DESTDIR)/exports/ftp
SNAPSHOT_DIR = $(FTP_DIR)/snapshot

WWW          = ${DESTDIR}/exports/www
WWW_DIR      = ${WWW}

TMP_DIR           = ${FML}/tmp
VAR_DIR           = ${FML}/var
WORK_DOC_DIR      = ${VAR_DIR}/doc
WORK_HTML_DIR     = ${VAR_DIR}/html
WORK_HTML_ADV_DIR = ${VAR_DIR}/html/advisories
WORK_EXAMPLES_DIR = ${VAR_DIR}/html/examples
WORK_DRAFTS_DIR   = ${WORK_DOC_DIR}/drafts


__EXPORTS_DIR__ = FML COMPILE_DIR DESTDIR DIST_BIN DIST_DIR \
		DIST_DOC_BIN FTP_DIR SNAPSHOT_DIR TMP_DIR \
		VAR_DIR WORK_DOC_DIR WORK_DRAFTS_DIR \
		WORK_EXAMPLES_DIR \
		WORK_HTML_DIR WORK_HTML_ADV_DIR WWW_DIR \
		BRANCH MODE


######################################################################
###
### if ($0 eq __FILE__)
###
__ALL__  = $(DESTDIR) $(FTP_DIR) $(SNAPSHOT_DIR) $(WWW_DIR)
__ALL__ += $(TMP_DIR) $(VAR_DIR)
__ALL__ += $(WORK_DOC_DIR) $(WORK_DRAFTS_DIR)
__ALL__ += $(WORK_HTML_DIR) $(WORK_HTML_ADV_DIR) ${WORK_EXAMPLES_DIR}
__ALL__ += $(COMPILE_DIR)

.for dir in ${__ALL__}
.PHONY: ${dir}
${dir}: 
	@ if [ ! -d ${dir} ]; then \
		echo creating ${dir} ;\
		$(MKDIR) ${dir} ; fi
.endfor

__setup: $(__ALL__)


__import_variables:
.for dir in ${__EXPORTS_DIR__}
	@ echo ${dir}=${$(dir)}
.endfor
