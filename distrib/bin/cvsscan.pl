#!/usr/local/bin/perl
#
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

require 'getopts.pl';
&Getopts("df:");


$| = 1;

if ($opt_f) {
    @list = split(/[\s\n]+/, `cat $opt_f`);
    print STDERR "cvsscan: cvs status @list\n";
    open(CVS, "cvs status @list|") || die($!);
}
else {
    open(CVS, "cvs status @ARGV|") || die($!);
}

while (<CVS>) {
    # Repository revision:      1.2     /cvsroot/fml/README,v

    if (/Repository revision:/) {
	s/.*Repository revision://;
	s#/cvsroot/fml/##;
	s#,v##g;
	@x = split;
	printf "%-30s   %s\n", $x[1], $x[0];
    }
}
