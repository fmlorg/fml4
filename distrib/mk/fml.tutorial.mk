HTML_CONV   = $(FML)/bin/fwix.pl -m htmlconv
HTML_FILTER = $(FML)/bin/fwix.pl -m html -f tmp/html_index.ph
TEXT_FILTER = $(FML)/bin/fwix.pl -m text -f tmp/text_index.ph

WORK_TUTORIAL_DIR = ${WORK_HTML_DIR}/${TUTORIAL_LANGUAGE}


# index list dependence
__TUTORIAL_DOC_TARGETS__ += tmp/text_index.ph
__HTML_TUTORIAL__        += tmp/html_index.ph


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

# html: creation rule
${WORK_TUTORIAL_DIR}/${dir}/index.html: doc/${TUTORIAL_LANGUAGE}/${dir}/*wix
	if [ -f doc/${TUTORIAL_LANGUAGE}/${dir}/index.wix ]; then \
	   ${HTML_FILTER} -L ${TUTORIAL_LANGUAGE} \
		-D ${WORK_TUTORIAL_DIR}/${dir} \
		doc/${TUTORIAL_LANGUAGE}/${dir}/index.wix ;\
	fi

# plaintext:
__TUTORIAL_DOC_TARGETS__ += var/doc/${TUTORIAL_LANGUAGE}/${dir}

var/doc/${TUTORIAL_LANGUAGE}/${dir}: doc/${TUTORIAL_LANGUAGE}/${dir}/*.wix
	${TEXT_FILTER} doc/${TUTORIAL_LANGUAGE}/${dir}/index.wix \
		 > var/doc/${TUTORIAL_LANGUAGE}/${dir}

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

# raw copy for ${DOC_TUTORIAL_EXC_SUBDIR}
.for file in ${TUTORIAL_BASIC_SAMPLES}
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/basic_setup/${file}

${WORK_TUTORIAL_DIR}/basic_setup/${file}: doc/${TUTORIAL_LANGUAGE}/basic_setup/${file}
	@ test -d ${WORK_TUTORIAL_DIR}/basic_setup || mkdir ${WORK_TUTORIAL_DIR}/basic_setup
	cp doc/${TUTORIAL_LANGUAGE}/basic_setup/${file} \
		${WORK_TUTORIAL_DIR}/basic_setup/${file}
.endfor

.for file in ${TUTORIAL_BASIC_SOURCES}
__HTML_TUTORIAL__ += ${WORK_TUTORIAL_DIR}/basic_setup/${file}.html

${WORK_TUTORIAL_DIR}/basic_setup/${file}.html: doc/${TUTORIAL_LANGUAGE}/basic_setup/${file}.wix
	${HTML_CONV} -L ${TUTORIAL_LANGUAGE} -n i \
		-o ${WORK_TUTORIAL_DIR}/basic_setup/${file}.html \
		doc/${TUTORIAL_LANGUAGE}/basic_setup/${file}.wix
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
	   if [ ! -f doc/${TUTORIAL_LANGUAGE}/$$dir/index.wix ]; then \
		exit 1 ; \
	   fi ; \
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


__plainbuild_new: ${__TUTORIAL_DOC_TARGETS__}

