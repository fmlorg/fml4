HTML_FILTER = $(FML)/bin/fwix.pl -m html -f tmp/html_index.ph

WORK_TUTORIAL_DIR = ${WORK_HTML_DIR}/${TUTORIAL_LANGUAGE}




# index list
__HTML_TUTORIAL__ += tmp/text_index.ph
__HTML_TUTORIAL__ += tmp/html_index.ph

.for dir in ${DOC_TUTORIAL_SUBDIR}
# prepare directory to be created
__HTML_TUTORIAL_SUBDIRS__ += ${dir}

__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/${dir}/index.html

__HTML_TUTORIAL_SOURCES__ += doc/${TUTORIAL_LANGUAGE}/${dir}/*wix

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


# %index list
tmp/text_index.ph: ${__HTML_TUTORIAL_SOURCES__}
	@ echo creating text_index.ph
	@ for dir in ${__HTML_TUTORIAL_SUBDIRS__} ;\
	do \
	   echo -n '.';\
	   ${FWIX} -m text -i $$dir doc/${TUTORIAL_LANGUAGE}/$$dir/index.wix \
		>> tmp/text_index.ph.new 2>/dev/null; \
	done
	@ echo ""
	@ mv tmp/text_index.ph.new tmp/text_index.ph
	@ perl -cw tmp/text_index.ph
	@ echo done.

tmp/html_index.ph: ${__HTML_TUTORIAL_SOURCES__}
	@ echo creating html_index.ph
	@ for dir in ${__HTML_TUTORIAL_SUBDIRS__} ;\
	do \
	   echo -n '.';\
	   ${FWIX} -D /tmp -m html -i $$dir \
		doc/${TUTORIAL_LANGUAGE}/$$dir/index.wix \
		>> tmp/html_index.ph.new 2>/dev/null; \
	done
	@ echo ""
	@ mv tmp/html_index.ph.new tmp/html_index.ph
	@ perl -cw tmp/html_index.ph
	@ echo done.
