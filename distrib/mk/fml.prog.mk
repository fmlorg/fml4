# search ${HOME} also for ~/.fmlmk.conf
.PATH: ${HOME}

.if defined(FMLMK_CONF)
.include "${FMLMK_CONF}"
.endif

__EXPORTS_PROGS__  = SH CC CFLAGS MKDIR RSYNC FETCH TAR INSTALL CP PERL
__EXPORTS_PROGS__ += JCONV ECONV VERSION _FWIX FWIX

SH	 ?= /bin/sh
CC 	 ?= /usr/bin/cc
CFLAGS	 ?= -s -O -DPOSIX
RSYNC    ?= /usr/local/bin/rsync --rsh /usr/local/bin/ssh
FETCH    ?= /usr/bin/ftp
TAR      ?= /usr/bin/tar
INSTALL  ?= /usr/bin/install -c 
CP       ?= /bin/cp -p
PERL     ?= /usr/local/bin/perl
MKDIR    ?= ${PERL} ${FML}/distrib/bin/mkdirhier.pl

# Convert to Japanese/English
JCONV    ?= /usr/local/bin/nkf -j
ECONV    ?= /usr/local/bin/nkf -e

# version up 
VERSION  ?= ${PERL} ${FML}/distrib/bin/version.pl

# fml specific
#
# [fwix]
#     -Z address
#     -S stylesheet
#
_FWIX    ?=  ${PERL} ${FML}/bin/fwix.pl
FWIX     ?=  ${_FWIX} -F -Z fml-bugs@fml.org 
