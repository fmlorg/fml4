# Library of fml.pl 
# Copyright (C) 1994-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


# $Id$;

&Ftpmail_00 if $LOAD_LIBRARY eq 'libftpmail.pl';

sub Ftpmail_00
{
    require 'libfop.pl';
    require 'libftp.pl';
    &Ftp(*Envelope);
}

1;
