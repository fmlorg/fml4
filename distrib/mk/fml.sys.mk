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


### exports  ###
FTP_DIR      = $(DESTDIR)/exports/ftp
SNAPSHOT_DIR = $(FTP_DIR)/current/src

WWW          = ${DESTDIR}/exports/www
WWW_DIR      = ${WWW}

VAR_DIR           = ${FML}/var
TMP_DIR           = ${FML}/var/tmp
COMPILE_DIR       = ${TMP_DIR}

# var/doc/
WORK_DOC_DIR      = ${VAR_DIR}/doc
WORK_DOC_DIR_JP   = ${WORK_DOC_DIR}/Japanese
WORK_DRAFTS_DIR   = ${WORK_DOC_DIR}/drafts

# var/html/
WORK_HTML_DIR          = ${VAR_DIR}/html
WORK_HTML_ADV_DIR      = ${WORK_HTML_DIR}/advisories
WORK_EXAMPLES_DIR      = ${WORK_HTML_DIR}/examples
WORK_HTML_JAPANESE_DIR = ${WORK_HTML_DIR}/Japanese
WORK_HTML_ENGLISH_DIR  = ${WORK_HTML_DIR}/English
WORK_HTML_SOURCES_DIR  = ${WORK_HTML_DIR}/sources
WORK_HTML_LIST_DIR     = ${WORK_HTML_DIR}/Japanese/Lists


__EXPORTS_DIR__ = FML COMPILE_DIR DESTDIR DIST_BIN DIST_DIR \
		DIST_DOC_BIN FTP_DIR SNAPSHOT_DIR \
		VAR_DIR TMP_DIR \
		WORK_DOC_DIR WORK_DRAFTS_DIR \
		WORK_DOC_DIR_JP \
		WORK_HTML_LIST_DIR \
		WORK_EXAMPLES_DIR \
		WORK_HTML_DIR WORK_HTML_ADV_DIR WWW_DIR \
		WORK_HTML_JAPANESE_DIR WORK_HTML_ENGLISH_DIR \
		WORK_HTML_SOURCES_DIR \
		ARCHIVE_DIR \
		BRANCH MODE

######################################################################
###
### if ($0 eq __FILE__)
###
__ALL__  = $(DESTDIR) $(FTP_DIR) $(SNAPSHOT_DIR) $(WWW_DIR)
__ALL__ += $(TMP_DIR) $(VAR_DIR)
__ALL__ += $(WORK_DOC_DIR) ${WORK_DOC_DIR_JP} $(WORK_DRAFTS_DIR)
__ALL__ += $(WORK_HTML_JAPANESE_DIR) $(WORK_HTML_ENGLISH_DIR)
__ALL__ += $(WORK_HTML_SOURCES_DIR)
__ALL__ += $(WORK_HTML_DIR) $(WORK_HTML_ADV_DIR) ${WORK_EXAMPLES_DIR}
__ALL__ += $(WORK_HTML_LIST_DIR)
__ALL__ += $(COMPILE_DIR)

.for dir in ${__ALL__}
.PHONY: ${dir}
${dir}: 
	@ if [ ! -d ${dir} ]; then \
		echo "creating ${dir}";\
		$(MKDIR) ${dir} ; fi
.endfor

__setup: __debug $(__ALL__)

__debug:
	@ echo "(debug) MKDIR=${MKDIR}"


__import_variables:
.for dir in ${__EXPORTS_DIR__} ${__EXPORTS_PROGS__}
	@ echo ${dir}=\"${$(dir)}\"
.endfor


# dirty hack
scan: __scan
clean:__clean

# tricky definition but to overwrite doc/*/Makefile's scan: rules
scan:
	@ echo ""

clean:
	@ echo ""
