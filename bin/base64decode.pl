#!/usr/local/bin/perl
#
# Copyright (C) 1993-1999,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

use vars qw($opt_d $opt_I $opt_o);

require 'getopts.pl';
&Getopts("dI:o:");

undef $/;

my $outfile = defined $opt_o ? $opt_o : undef;

# reset @INC
my $libdir  = $0; 
$libdir =~ s/base64decode.pl//; 
push(@INC, "$libdir/../");

if ($opt_I) {
    for (split(/:/, $opt_I)) { push(@INC, $_);}
}


# load after @INC modified
require 'mimer.pl';


#
# conversion
#

use IO::File;
my $fh = new IO::File;

if (defined $fh) {
    if ($outfile) {
	$fh->open("> $outfile");
    }
    else {
	$fh = \*STDOUT;
    }

    binmode($fh);
    while (sysread(STDIN, $_, 1024)) { 
	print $fh &bodydecode($_);
    }
    print $fh &bdeflush;
}

1;
