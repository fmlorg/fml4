.include "$(FML)/distrib/mk/fml.sys.mk"

CONTRIB_DIR = ${DESTDIR}/distrib/contrib

.POHNY: install
install: ${SOURCES}
	$(MKDIR) ${TARGET_DIR}
	${INSTALL} ${SOURCES} ${TARGET_DIR}
