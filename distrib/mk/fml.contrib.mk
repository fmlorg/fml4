.include "$(FML)/distrib/mk/fml.sys.mk"

CONTRIB_DIR = ${DESTDIR}/distrib/contrib


.POHNY: install
install: ${SOURCES}
	$(MKDIR) ${TARGET_DIR}
	${RSYNC} -C -av ${SOURCES} ${TARGET_DIR}/


distribution:
.for dir in ${SUBDIRS}
	(cd ${dir}; ${MAKE} install)
.endfor
