#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
require 'getopts.pl';
&Getopts("dhi:");

@AR = ("reject",
       "auto_symmetric_regist",
       "auto_regist", 
       "auto_asymmetric_regist");

for $handler (@AR) {
    $REJECT_POST_HANDLER = $handler;

    for $handler (@AR) {
	$REJECT_COMMAND_HANDLER = $handler;

	&Emulator;
    }
}


exit 0;

sub Emulator
{
    if ($I++ == $opt_i) {
	print "\$REJECT_POST_HANDLER    = '$REJECT_POST_HANDLER';\n";
	print "\$REJECT_COMMAND_HANDLER = '$REJECT_COMMAND_HANDLER';\n";

	exit 0;
    }
}

1;
