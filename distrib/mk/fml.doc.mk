.include "distrib/mk/fml.prog.mk"

# ordinary source
DOC_RI_SRC     = README INSTALL INSTALL_on_NT4 INSTALL_with_QMAIL UPGRADE

# these files need a special converter.
DOC_RI_CNV_SRC = 

### executables
# document generators

# release snapshot generator library
GEN_PLAIN_DOC = $(SH) $(DIST_DOC_BIN)/genplaindoc.sh

DOC_GENERATOR_D = $(SH) $(FML)/distrib/doc/bin/depend_wrapper.sh
DOC_CONV        = $(DOC_GENERATOR)




op: var/doc/op.jp

var/doc/op.jp: doc/smm/*wix
	env FML=${FML} $(SH) distrib/bin/DocReconfigure.op
