fetch:
	@ if [ -f ${DISTNAME} ]; then \
	echo ignore since ${DISTNAME} already exists ;\
	else \
	echo ${FETCH} ${MASTER_SITE}/${PKGNAME}/${DISTNAME}; \
	${FETCH} ${MASTER_SITE}/${PKGNAME}/${DISTNAME}; \
	fi

link:
.if defined(DIST_NEWNAME)
.if ! exists(${DIST_NEWNAME})
	ln ${DISTNAME} ${DIST_NEWNAME}
.endif
.endif

extract:
.if defined(EXTRACT)
	@ if [ ! -d work ] ; then mkdir work ; fi
	@ ( cd work; $(TAR) zxvf ../${DISTNAME} )
.endif


.if ${PERL_MODULE} == "yes"
compile:
	(cd work/${COMPILE_DIR}; perl Makefile.PL; make)

install:
	(cd work/${COMPILE_DIR}; make install)

clean:
	rm -fr work ${DISTNAME}
.else
compile:

install:

clean:	
.endif

