# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

DOC_RI_SOURCES  = CHANGES CHECK_LIST FILES 
DOC_RI_SOURCES += CHANGES-3-0-maint
DOC_RI_SOURCES += INSTALL INSTALL_on_NT4 INSTALL_on_MacOS_X_Server
DOC_RI_SOURCES += INSTALL_with_SENDMAIL INSTALL_with_POSTFIX
DOC_RI_SOURCES += INSTALL_with_QMAIL INSTALL_with_EXIM
DOC_RI_SOURCES += INSTALL_with_ZMAILER
DOC_RI_SOURCES += PORTINGS README UPGRADE FEATURES TODO UPGRADE-3.0
DOC_RI_SOURCES += INSTALL_CGI
DOC_RI_EXCEPTIONAL_SOURCES = RELEASE_NOTES INFO

# raw copy
DOC_RI_RAW     += COPYING


### special rurles
scan:
	cvs -n update

clean:
	gar *~

UPGRADE-3.0.wix: UPGRADE.wix
	../../distrib/doc/bin/make-UPGRADE-3.0.sh UPGRADE.wix > UPGRADE-3.0.wix
