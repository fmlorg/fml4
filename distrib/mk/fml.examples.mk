HTML_FILTER = $(FML)/bin/fwix.pl -m htmlconv 

.for file in ${DOC_EXAMPLE_SOURCES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html

${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.wix
	${HTML_FILTER} -L JAPANESE -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}.html doc/examples/${file}.wix
.endfor
