.for file in ${DOC_DEVEL_INDEX}
__HTML_EXAMPLES__ += var/html/devel/${file}
.endfor

.for file in ${DOC_DEVEL_SOURCES}
__HTML_EXAMPLES__ += var/html/devel/${file}
var/html/devel/${file}: doc/devel/${file}
	${CP} doc/devel/${file} var/html/devel/${file}
.endfor

var/html/devel/index.html: doc/devel/index.html
	@ test -d var/html/devel || mkdir var/html/devel
	${JCONV} doc/devel/index.html > var/html/devel/index.html

var/html/devel/index-e.html: doc/devel/index-e.html
	@ test -d var/html/devel || mkdir var/html/devel
	${ECONV} doc/devel/index-e.html > var/html/devel/index-e.html
