# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: Makefile,v 1.13 2001/05/12 13:02:34 fukachan Exp $
#

# doc/ri/ sources
DOC_RI_SOURCES += INSTALL
DOC_RI_SOURCES += INSTALL_on_NT4
DOC_RI_SOURCES += INSTALL_on_MacOS_X_Server
DOC_RI_SOURCES += INSTALL INSTALL_on_WIN2000
DOC_RI_SOURCES += INSTALL_with_SENDMAIL
DOC_RI_SOURCES += INSTALL_with_POSTFIX
DOC_RI_SOURCES += INSTALL_with_QMAIL
DOC_RI_SOURCES += INSTALL_with_EXIM
DOC_RI_SOURCES += INSTALL_with_ZMAILER
DOC_RI_SOURCES += INSTALL_CGI

DOC_RI_SOURCES += CHANGES
DOC_RI_SOURCES += CHANGES-3.0.1
DOC_RI_SOURCES += CHANGES-3.0.2
DOC_RI_SOURCES += CHANGES-4.0.1
DOC_RI_SOURCES += CHANGES-4.0.2
DOC_RI_SOURCES += CHANGES-4.0.3

DOC_RI_SOURCES += UPGRADE
DOC_RI_SOURCES += UPGRADE-3.0
DOC_RI_SOURCES += UPGRADE-4.0

DOC_RI_SOURCES += PORTINGS README FEATURES TODO WISH_LIST CHECK_LIST FILES

# exceptional files
DOC_RI_EXCEPTIONAL_SOURCES = RELEASE_NOTES INFO

# raw copy
DOC_RI_RAW     += COPYING


### special rurles
scan:
	@ cvs -n update

update:
	@ cvs update -d -P

clean:
	gar *~
