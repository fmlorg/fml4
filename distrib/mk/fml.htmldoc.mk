.for file in ${HTML_MISC_SOURCES}
HTML_MISC += var/html/${file}
var/html/${file}: doc/html/${file}
	$(CP) doc/html/${file} $(FML)/var/html/ 
.endfor

.for file in ${DOC_RI_SOURCES}
__HTML_RI__ += var/html/${file}/index.html
var/html/${file}/index.html: doc/ri/${file}.wix
	test -d var/html/${file} || ${MKDIR} var/html/${file}
	env FML=${FML} $(DOC_GENERATOR) ${file} ri
.endfor

.for file in ${DOC_RI_EXCEPTIONAL_SOURCES}
__HTML_RI__ += var/html/${file}.html
__HTML_RI__ += var/html/${file}-e.html

var/html/${file}.html: doc/ri/${file}.wix $(FML)/var/doc/${file}.jp
	rm -f $(FML)/var/html/${file}.html
	if [ -f $(FML)/doc/html/include.jp/${file}.hdr ] ;\
	then \
	cat $(FML)/doc/html/include.jp/${file}.hdr >\
	$(FML)/var/html/${file}.html ;\
	fi
	cat $(FML)/var/doc/${file}.jp >> $(FML)/var/html/${file}.html

var/html/${file}-e.html: doc/ri/${file}.wix $(FML)/var/doc/${file}.en
	rm -f $(FML)/var/html/${file}-e.html
	if [ -f $(FML)/doc/html/include.en/${file}.hdr ] ;\
	then \
	cat $(FML)/doc/html/include.en/${file}.hdr >\
	$(FML)/var/html/${file}-e.html ;\
	fi
	cat $(FML)/var/doc/${file}.en >> $(FML)/var/html/${file}-e.html

.endfor


__inithtml__: 
	@ echo --htmlbuild

var/html/index.html: doc/html/index.html
	$(CPP) -P -DJAPANESE doc/html/index.html |\
	$(JCONV) > $(FML)/var/html/index.html

var/html/index-e.html: doc/html/index.html
	$(CPP) -P -UJAPANESE doc/html/index.html \
	> $(FML)/var/html/index-e.html

var/html/op/index.html: doc/smm/*wix
	test -d var/html/op || mkdir var/html/op
	test -h var/html/op-jp || ln -s var/html/op var/html/op-jp
	${FIX_WIX} doc/smm/op.wix |\
	${FWIX} -L JAPANESE -T op -m html -D var/html/op -d doc/smm

var/html/op-e/index.html: doc/smm/*wix
	test -d var/html/op-e || mkdir var/html/op-e
	test -h var/html/op-en || ln -s var/html/op-e var/html/op-en
	${FIX_WIX} doc/smm/op.wix |\
	${FWIX} -L ENGLISH -T op -m html -D var/html/op-e -d doc/smm

### main ###
htmlbuild: __inithtml__ ${HTML_MISC} ${__HTML_RI__} ${HTML_SMM}
	@ echo ${HTML_MISC} ${__HTML_RI__} ${HTML_SMM}
	@ echo --htmlbuild done.
