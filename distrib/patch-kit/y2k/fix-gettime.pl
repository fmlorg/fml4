#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");


$Template = q!
    # fix-gettime.pl adds the following y2k safe time.
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);
!;


while (<>) {
    if (/^sub GetTime/)    { $found++;}
    if (/^sub InitConfig/) { $p_found++;}

    # very old fml does not have &GetTime() but &InitConfig sets up time.
    if ($p_found) {
	if (/\$Now\s*=\s*sprintf/) { $found++}
    }

    if (/^\}/ && $found) {
	print $Template;
	$p_found = $found = 0;
    }

    print;
}


exit 0;
