#
# $FML: fml.htmldoc.mk,v 1.29 2001/05/26 15:31:52 fukachan Exp $
#

.for file in ${HTML_MISC_SOURCES}
HTML_MISC += var/html/${file}
var/html/${file}: doc/html/${file}
	$(CP) doc/html/${file} ${FML}/var/html/ 
.endfor

# mascot
HTML_MISC += var/html/pictures/index.html
var/html/pictures/index.html: doc/html/pictures/index.html
	@ test -d var/html/pictures || mkdir var/html/pictures
	${CPP} -P -UDIST doc/html/pictures/index.html |\
		${JCONV} > var/html/pictures/index.html

# logo
HTML_MISC += var/html/logo.jpg var/html/pointer.jpg 
var/html/logo.jpg: doc/html/pictures/logo.jpg
	cp -p doc/html/pictures/logo.jpg var/html

var/html/pointer.jpg: doc/html/pictures/pointer.jpg
	cp -p doc/html/pictures/pointer.jpg var/html

# history
HTML_MISC += var/html/p_list.gif
var/html/p_list.gif: doc/html/pictures/p_list.gif
	@ test -d var/html/pictures || mkdir var/html/pictures
	cp -p doc/html/pictures/p_list.gif var/html/p_list.gif

HTML_MISC += var/html/releng.gif
var/html/releng.gif: doc/html/pictures/releng.gif
	@ test -d var/html/pictures || mkdir var/html/pictures
	cp -p doc/html/pictures/releng.gif var/html/releng.gif

HTML_MISC += var/html/logo.jpg
var/html/logo.jpg: doc/html/pictures/logo.jpg
	@ test -d var/html/pictures || mkdir var/html/pictures
	cp -p doc/html/pictures/logo.jpg var/html/logo.jpg

.for file in ${DOC_RI_SOURCES}
__HTML_RI__ += var/html/${file}/index.html
var/html/${file}/index.html: doc/ri/${file}.wix
	test -d var/html/${file} || ${MKDIR} var/html/${file}
	env FML=${FML} $(DOC_GENERATOR) ${file} ri
.endfor


.for file in ${DOC_ADVISORY_SOURCES}
__HTML_RI__ += var/html/advisories/${file}/index.html
var/html/advisories/${file}/index.html: doc/advisories/${file}.wix
	test -d var/html/advisories/${file} || \
		${MKDIR} var/html/advisories/${file}
	env FML=${FML} $(DOC_GENERATOR) ${file} advisories advisories
.endfor


.for file in ${DOC_RI_EXCEPTIONAL_SOURCES}
__HTML_RI__ += var/html/${file}.html
__HTML_RI__ += var/html/${file}-e.html

var/html/${file}.html: doc/ri/${file}.wix var/doc/${file}.jp
	rm -f ${FML}/var/html/${file}.html
	if [ -f ${FML}/doc/html/include.jp/${file}.hdr ] ;\
	then \
	cat ${FML}/doc/html/include.jp/${file}.hdr >\
	${FML}/var/html/${file}.html ;\
	fi
	cat ${FML}/var/doc/${file}.jp >> ${FML}/var/html/${file}.html

var/html/${file}-e.html: doc/ri/${file}.wix var/doc/${file}.en
	rm -f ${FML}/var/html/${file}-e.html
	if [ -f ${FML}/doc/html/include.en/${file}.hdr ] ;\
	then \
	cat ${FML}/doc/html/include.en/${file}.hdr >\
	${FML}/var/html/${file}-e.html ;\
	fi
	cat ${FML}/var/doc/${file}.en >> ${FML}/var/html/${file}-e.html

.endfor


__inithtml__: 
	@ echo --htmlbuild

.for file in ${HTML_REQ_CPP_SOURCES}

__HTML_CPP__ += var/html/${file}.html
__HTML_CPP__ += var/html/${file}-e.html

var/html/${file}.html: doc/html/${file}.html
	$(CPP) -P -DJAPANESE doc/html/${file}.html |\
	$(JCONV) > ${FML}/var/html/${file}.html

var/html/${file}-e.html: doc/html/${file}.html
	$(CPP) -P -UJAPANESE doc/html/${file}.html |\
	$(JCONV) > ${FML}/var/html/${file}-e.html

.endfor

var/html/advisories/index.html: doc/advisories/index.html
	$(CPP) -P -DJAPANESE doc/advisories/index.html |\
	$(JCONV) > ${FML}/var/html/advisories/index.html

var/html/advisories/index-e.html: doc/advisories/index-e.html
	$(CPP) -P -UJAPANESE doc/advisories/index-e.html \
	> ${FML}/var/html/advisories/index-e.html

${TMP_DIR}/WHATS_NEW.wix: CHANGES
	rm -f ${TMP_DIR}/WHATS_NEW.wix
	echo '.HTML_PRE'  >> ${TMP_DIR}/WHATS_NEW.wix
	grep -v -e ------- CHANGES >> ${TMP_DIR}/WHATS_NEW.wix || echo ""
	echo '.~HTML_PRE'  >> ${TMP_DIR}/WHATS_NEW.wix

var/html/WHATS_NEW/index.html: ${TMP_DIR}/WHATS_NEW.wix
	${JCONV} ${TMP_DIR}/WHATS_NEW.wix |\
	${FWIX} -L JAPANESE -T WHATS_NEW -m html -D var/html/WHATS_NEW

var/html/WHATS_NEW-e/index.html: ${TMP_DIR}/WHATS_NEW.wix
	${PERL} distrib/bin/remove_japanese_line.pl ${TMP_DIR}/WHATS_NEW.wix |\
	${FWIX} -L ENGLISH -T WHATS_NEW-e -m html -D var/html/WHATS_NEW-e

__htmlbuild__ += var/html/messages-list.ja.txt
var/html/messages-list.ja.txt: messages/Japanese/MANIFEST.Japanese
	${JCONV} messages/Japanese/MANIFEST.Japanese \
		> var/html/messages-list.ja.txt


.for file in ${DOC_RI_RAW}
__HTML_RI__ += var/html/${file}
var/html/${file}: doc/ri/${file}
	cp -p doc/ri/${file} var/html/${file}
.endfor

#
.for file in ${DOC_MULTIVIEW_HTML}
__HTML_MULTIVIEW__ += var/html/${file}.html
__HTML_MULTIVIEW__ += var/html/${file}.ja.html
__HTML_MULTIVIEW__ += var/html/${file}.en.html
__HTML_MULTIVIEW__ += var/html/${file}-j.html
__HTML_MULTIVIEW__ += var/html/${file}-e.html

var/html/${file}.html: doc/html/${file}.ja.html
	${JCONV} doc/html/${file}.ja.html > var/html/${file}.html

var/html/${file}.ja.html: doc/html/${file}.ja.html
	${JCONV} doc/html/${file}.ja.html > var/html/${file}.ja.html

var/html/${file}-j.html: doc/html/${file}.ja.html
	${JCONV} doc/html/${file}.ja.html > var/html/${file}-j.html

var/html/${file}.en.html: doc/html/${file}.en.html
	${JCONV} doc/html/${file}.en.html > var/html/${file}.en.html

var/html/${file}-e.html: doc/html/${file}.en.html
	${JCONV} doc/html/${file}.en.html > var/html/${file}-e.html

.endfor


var/html/fml.css: doc/html/fml.css
	cp -p doc/html/fml.css var/html/fml.css

### main ###
.include "distrib/mk/fml.cf.mk"
.include "distrib/mk/fml.ref.mk"
__htmlbuild__ += __inithtml__
__htmlbuild__ += var/html/fml.css
__htmlbuild__ += ${HTML_MISC} 
__htmlbuild__ += ${__HTML_RI__} 
__htmlbuild__ += ${HTML_SMM} 
__htmlbuild__ += ${__HTML_CPP__}
__htmlbuild__ += ${__HTML_EXAMPLES__}
__htmlbuild__ += ${__HTML_TUTORIAL__}
__htmlbuild__ += ${__HTML_MANIFEST__}
__htmlbuild__ += ${__HTML_MULTIVIEW__}
__htmlbuild__ += var/html/WHATS_NEW/index.html var/html/WHATS_NEW-e/index.html

htmlbuild: ${__htmlbuild__}
	@ echo ""
#	@ echo ${HTML_MISC} ${__HTML_RI__} ${HTML_SMM}
#	@ apply echo ${__HTML_TUTORIAL__}
	@ echo --htmlbuild done.
	@ echo ""
