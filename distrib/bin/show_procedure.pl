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
require 'getopts.pl';
&Getopts("dh");

require 'proc/libfml.pl';

&InitProcedure;

for $k (sort keys  %Procedure) {
    printf "%-20s %s\n", $k, $v if $k !~ /\#/;
}
