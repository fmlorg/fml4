HTML_FILTER = $(FML)/bin/fwix.pl -m htmlconv 

.for file in ${DOC_EXAMPLE_SOURCES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}-e.html

${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.wix
	${HTML_FILTER} -L JAPANESE -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}.html doc/examples/${file}.wix

${WORK_EXAMPLES_DIR}/${file}-e.html: doc/examples/${file}.wix
	${HTML_FILTER} -L ENGLISH -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}-e.html doc/examples/${file}.wix
.endfor

# doc/examples/index{,-e}.html
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/index.html
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/index-e.html

${WORK_EXAMPLES_DIR}/index.html: doc/examples/index.html
	${JCONV} doc/examples/index.html > ${WORK_EXAMPLES_DIR}/index.html

${WORK_EXAMPLES_DIR}/index-e.html: doc/examples/index-e.html
	${JCONV} doc/examples/index-e.html > ${WORK_EXAMPLES_DIR}/index-e.html
