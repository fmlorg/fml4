#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
# require 'getopts.pl';
# &Getopts("dh");

$REPL = q%$CONFIG_DIR = '/usr/local/fml/.fml'; # __MAKEFML_AUTO_REPLACED_HERE__
# $debug_lock = 1;
%;

while (<>) {
    s/^\$CONFIG_DIR.*/$REPL/;
    print;
}

exit 0;
