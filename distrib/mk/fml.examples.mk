### procs
HTML_FILTER = $(FML)/bin/fwix.pl -m htmlconv

### fundamental rules
.for dir in ${DOC_EXAMPLES_SUBDIR}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${dir}

${WORK_EXAMPLES_DIR}/${dir}:
	test -d ${WORK_EXAMPLES_DIR}/${dir} ||\
	   ${MKDIR} ${WORK_EXAMPLES_DIR}/${dir}

.endfor


.for file in ${DOC_EXAMPLES_SOURCES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}-e.html

${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.wix
	${HTML_FILTER} -L JAPANESE -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}.html doc/examples/${file}.wix

${WORK_EXAMPLES_DIR}/${file}-e.html: doc/examples/${file}.wix
	${HTML_FILTER} -L ENGLISH -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}-e.html doc/examples/${file}.wix
.endfor

.for file in ${DOC_EXAMPLES_RAW_SOURCES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}

${WORK_EXAMPLES_DIR}/${file}: doc/examples/${file}
	cp doc/examples/${file} ${WORK_EXAMPLES_DIR}/${file}
.endfor



### doc/examples/*txt
__HTML_EXAMPLES_TXT__        = makefml.cgi 
__HTML_EXAMPLES_IMPORT_TXT__ = INSTALL TODO IMPLEMENTATION QandA

.for file in ${__HTML_EXAMPLES_TXT__}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.txt
${WORK_EXAMPLES_DIR}/${file}.txt: doc/examples/${file}.txt
	${JCONV} doc/examples/${file}.txt > ${WORK_EXAMPLES_DIR}/${file}.txt
.endfor

.for file in ${__HTML_EXAMPLES_IMPORT_TXT__}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/cgi-${file}.txt
${WORK_EXAMPLES_DIR}/cgi-${file}.txt: www/${file}.jp
	${JCONV} www/${file}.jp > ${WORK_EXAMPLES_DIR}/cgi-${file}.txt
.endfor


### doc/examples/index{,-e}.html and doc/examples/*html
__HTML_EXAMPLES_HTML__ += index index-e
__HTML_EXAMPLES_HTML__ += examples examples-e
__HTML_EXAMPLES_HTML__ += ptr-customize-header

.for file in ${__HTML_EXAMPLES_HTML__}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html
${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.html
	${JCONV} doc/examples/${file}.html > ${WORK_EXAMPLES_DIR}/${file}.html
.endfor

.for file in ${DOC_EXAMPLES_SAMPLES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}
${WORK_EXAMPLES_DIR}/${file}: doc/examples/${file}
	cp -p doc/examples/${file} ${WORK_EXAMPLES_DIR}/${file}
.endfor
