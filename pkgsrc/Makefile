.include "../distrib/mk/fml.pkg.mk"

SUB_DIR = jcode mimepls mimepls2 traffic

all: ${SUB_DIR}

.for dir in ${SUB_DIR}
.PHONY: ${dir}
${dir}: 
	@ echo "===> ${dir}"
	@ (chdir ${dir}; make fetch)
	@ (chdir ${dir}; make extract)
	@ (chdir ${dir}; make link)
.endfor
