#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
# $NetBSD$
# $FML$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");

&Init;

while (<>) {
    next if /^\#/;

    if (/^sub SecureP/) { $in = 1;}
    if (/^\}/)          { $in = 0;}

    if ($in) {
	if (/(\$[A-Z\_][A-Za-z\_]+)/) {
	    print "SECURE:", $1, "\n" if $debug;
	    $SECURE{ $1 } = 1;
	}
    }

    if (/(\$[A-Z\_][A-Za-z\_]+)/) {
	$VAR{ $1 } = $1;
    }
}


for (sort keys %VAR) {
    print $_, "\n" unless $SECURE{ $_ };
}


exit 0;


sub Init
{
    %SECURE = (
	       '$NULL' => 1,
	       '$SIG'  => 1,

	       '$DOMAIN' => 1,
	       '$FQDN' => 1,
	       '$LANGUAGE' => 1,
	       '$ML_DIR' => 1,
	       '$EXEC_DIR' => 1,

	       '$CGI_AUTHDB_DIR' => 1,
	       '$HOW_TO_UPDATE_ALIAS' => 1,
	       '$MTA' => 1,
	       '$REAL_CGI_PATH' => 1,
	       '$SSL_REQUIRE_SSL' => 1,

	       # config.ph
	       '$ADMIN_MEMBER_LIST' => 1,
	       '$MEMBER_LIST' => 1,

	       # 
	       '$CFVersion'      => 1,
	       '$ControlThrough' => 1,
	       '$ErrorString'    => 1,
	       '$HTDOCS_TEMPLATE_DIR' => 1,
	       '$DIR' => 1,
	       '$CONFIG_DIR' => 1,
	       '$MESG_FILE' => 1,
	       '$MESSAGE_LANGUAGE' => 1,
	       '$VERSION' => 1, 
	       '$VERSION_FILE' => 1, 
	       '$MAKE_FML' => 1, 
	       '$GETBUFLEN' => 1, 

	       # 
	       '$CGI_CF' => 1, 
	       '$CGI_PATH' => 1, 
	       '$CGI_CONF' => 1, 

	       '$WWW_CONF_DIR' => 1, 
	       '$WWW_DIR' => 1, 
	       '$ACTION' => 1, 
	       '$OPTION' => 1, 
	       );
}


1;
