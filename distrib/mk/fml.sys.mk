.include "distrib/mk/fml.prog.mk"

.if !defined(FML)
FML     = $(PWD)
.endif

.if !defined(DESTDIR)
DESTDIR = /var/tmp/fml
.endif


### generators to export ###
DIST_DIR     = $(FML)/distrib
DIST_BIN     = $(DIST_DIR)/bin
DIST_DOC_BIN = $(DIST_DIR)/doc/bin


### exports  ###
FTP_DIR      = $(DESTDIR)/exports/ftp
SNAPSHOT_DIR = $(FTP_DIR)/snapshot

WWW          = $(DESTDIR)/exports/www
WWW_DIR      = $(WWW)

VAR_DIR        = $(FML)/var
WORK_DOC_DIR   = $(VAR_DIR)/doc
WORK_HTML_DIR  = $(VAR_DIR)/html


######################################################################
###
### if ($0 eq __FILE__)
###
__ALL__  = $(DESTDIR) $(FTP_DIR) $(SNAPSHOT_DIR) $(WWW_DIR)
__ALL__ += $(VAR_DIR) $(WORK_DOC_DIR) $(WORK_HTML_DIR)

.for dir in ${__ALL__}
.PHONY: ${dir}
${dir}: 
	@ echo ${dir}
	if [ ! -d ${dir} ]; then $(MKDIR) ${dir} ; fi
.endfor

__setup: $(__ALL__)
