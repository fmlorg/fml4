.for file in ${DOC_DRAFT_SOURCES}
__DOC_TARGETS__ += var/doc/drafts/Japanese/${file}
__DOC_TARGETS__ += var/doc/drafts/English/${file}
var/doc/drafts/Japanese/${file}: drafts/${file}.wix
	${FWIX} -n i drafts/${file}.wix > var/doc/drafts/Japanese/${file}

var/doc/drafts/English/${file}: drafts/${file}.wix
	${FWIX} -n i drafts/${file}.wix > var/doc/drafts/English/${file}
.endfor

.for file in ${DOC_ADVISORY_SOURCES}
__DOC_TARGETS__ += var/doc/advisories/${file}.jp
__DOC_TARGETS__ += var/doc/advisories/${file}.en
var/doc/advisories/${file}.jp: doc/advisories/${file}.wix
	${FWIX} -n i doc/advisories/${file}.wix > var/doc/advisories/${file}.jp

var/doc/advisories/${file}.en: doc/advisories/${file}.wix
	${FWIX} -L ENGLISH -n i doc/advisories/${file}.wix > var/doc/advisories/${file}.en
.endfor

.for file in ${DOC_RI_SOURCES} ${DOC_RI_EXCEPTIONAL_SOURCES} 
__DOC_TARGETS__ += var/doc/${file}.jp
__DOC_TARGETS__ += var/doc/${file}.en
var/doc/${file}.jp: doc/ri/${file}.wix
	${FWIX} -n i doc/ri/${file}.wix > var/doc/${file}.jp

var/doc/${file}.en: doc/ri/${file}.wix
	${FWIX} -L ENGLISH -n i doc/ri/${file}.wix > var/doc/${file}.en
.endfor

.for file in ${DOC_RI_RAW}
__DOC_TARGETS__ += var/doc/${file}
var/doc/${file}: doc/ri/${file}
	cp -p doc/ri/${file} var/doc/${file}
.endfor


### MAIN ###
__initplaindocbuild__:
	@ echo --plaindoc
	@ test -d var/doc || mkdir var/doc
	@ test -d var/doc/drafts     || mkdir var/doc/drafts
	@ test -d var/doc/drafts/Japanese || mkdir var/doc/drafts/Japanese
	@ test -d var/doc/drafts/English  || mkdir var/doc/drafts/English
	@ test -d var/doc/advisories || mkdir var/doc/advisories
	@ test -d var/doc/Japanese   || mkdir var/doc/Japanese
	@ test -d var/doc/English    || mkdir var/doc/English

plaindocbuild: __initplaindocbuild__ ${__DOC_TARGETS__} __plainbuild_new
	@ echo --plaindoc done.

