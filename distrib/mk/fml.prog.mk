SH	  = /bin/sh
CC 	  = /usr/bin/cc
CFLAGS	  = -s -O -DPOSIX
MKDIR     = mkdirhier
RSYNC     = rsync --rsh ssh
FETCH     = /usr/bin/ftp
TAR       = /usr/bin/tar
INSTALL   = /usr/bin/install -c 

# Convert to Japanese/English
JCONV     = nkf -j
ECONV     = nkf -e

# version up 
VERSION   = $(FML)/distrib/bin/version.pl

# fml specific
#
# [fwix]
#     -Z address
#     -S stylesheet
#
FWIX      =  $(FML)/bin/fwix.pl -F -Z fml-bugs@fml.org 
