HTML_FILTER = $(FML)/bin/fwix.pl -m html

WORK_TUTORIAL_DIR = ${WORK_HTML_DIR}/${TUTORIAL_LANGUAGE}


.for dir in ${DOC_TUTORIAL_SUBDIR}
# prepare directory to be created
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}/index.html

# make directory
${WORK_TUTORIAL_DIR}/${dir}:
	test -d ${WORK_TUTORIAL_DIR}/${dir} ||\
	   ${MKDIR} ${WORK_TUTORIAL_DIR}/${dir}

# creation rule
${WORK_TUTORIAL_DIR}/${dir}/index.html: doc/${TUTORIAL_LANGUAGE}/${dir}/*wix
	${HTML_FILTER} -L ${TUTORIAL_LANGUAGE} \
		-D ${WORK_TUTORIAL_DIR}/${dir} \
		doc/${TUTORIAL_LANGUAGE}/${dir}/index.wix
.endfor

.for dir in ${DOC_TUTORIAL_RAW_SUBDIR}
# prepare directory to be created
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}/index.html

# make directory
${WORK_TUTORIAL_DIR}/${dir}:
	test -d ${WORK_TUTORIAL_DIR}/${dir} ||\
	   ${MKDIR} ${WORK_TUTORIAL_DIR}/${dir}

# creation rule
${WORK_TUTORIAL_DIR}/${dir}/index.html: doc/${TUTORIAL_LANGUAGE}/${dir}/*
	${RSYNC} -C -av doc/${TUTORIAL_LANGUAGE}/${dir}/ \
		${WORK_TUTORIAL_DIR}/${dir}/
.endfor

# make $LANGUAGE/tutorial.html
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/tutorial.html
${WORK_TUTORIAL_DIR}/tutorial.html: doc/${TUTORIAL_LANGUAGE}/INDEX
	${PERL} distrib/bin/mkindex.pl \
		-f doc/${TUTORIAL_LANGUAGE}/INDEX \
		> ${WORK_TUTORIAL_DIR}/tutorial.html
