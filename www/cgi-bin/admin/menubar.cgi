#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


### AUTOMATICALLY REPLACED by makefml (Sun, 9 Mar 97 19:57:48 )
$CONFIG_DIR = ''; # __MAKEFML_AUTO_REPLACED_HERE__

# fml system configuration
require "$CONFIG_DIR/system";
push(@INC, "$EXEC_DIR/www/lib");
require 'libcgi_kern.pl';


### MAIN ###
&Init;
&GetBuffer(*Config);

&ShowHeader;

if ($ErrorString) { &Exit($ErrorString);}


if ($Config{'LANGUAGE'} eq 'Japanese') {
    &Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/menubar.html");
}
elsif ($Config{'LANGUAGE'} eq 'English') {
    &Convert("$HTDOCS_TEMPLATE_DIR/English/admin/menubar.html");
}
else {
    if ($LANGUAGE eq 'Japanese') {
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/menubar.html");
    }    
    else {
	&Convert("$HTDOCS_TEMPLATE_DIR/English/admin/menubar.html");
    }
}

if ($ErrorString) { &Exit($ErrorString);}

exit 0;
