# $Id$


${WORK_HTML_LIST_DIR}/menu_hier.ja.txt: etc/makefml/menu.conf
	${FML}/distrib/bin/make-menu-hier.pl -j ${FML}/etc/makefml/menu.conf |\
		${JCONV} > ${WORK_HTML_LIST_DIR}/menu_hier.ja.txt

${WORK_HTML_LIST_DIR}/menu_hier.en.txt: etc/makefml/menu.conf
	${FML}/distrib/bin/make-menu-hier.pl ${FML}/etc/makefml/menu.conf |\
		${JCONV} > ${WORK_HTML_LIST_DIR}/menu_hier.en.txt

# make target
__HTML_MANIFEST__ += ${WORK_HTML_LIST_DIR}/menu_hier.ja.txt
__HTML_MANIFEST__ += ${WORK_HTML_LIST_DIR}/menu_hier.en.txt
