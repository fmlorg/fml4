#!/usr/local/bin/perl
#-*- perl -*-
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
&Getopts("df:haM:L:");

$debug  = $opt_d ? 1 : 0;
$TRLIST = $opt_f || die("Please define -f translation-table-file\n");

$MAKEFML = $opt_M;
$ML      = $opt_L;

&GetList;

for (@ARGV) { 
    -f $_ && &Translate($_);
}

exit 0;


sub GetList
{
    open(LIST, $TRLIST) || die("cannot open $TRLIST");
    while(<LIST>) {
	next if /^\#/;
	next if /^\s*$/;
	($a, $b) = split;
	$TransTable{$a} = $b;

	$CACHE_TABLE .= $CACHE_TABLE ? "|$a" : $a;
    }
    close(LIST);
}


# [for 1268 lines file]
# if cache table is not used (with -a)
#   29.786u 0.099s 0:35.84 83.3% 0+0k 0+10io 0pf+0w
# if used (with -a)
#    6.409u 0.059s 0:07.05 91.4% 0+0k 0+12io 0pf+0w
# if used without -a
#    5.331u 0.049s 0:05.38 99.8% 0+0k 0+11io 0pf+0w
#
sub Translate
{
    local($f) = @_;
    local($buf, $backup, $x, $max_lines, $unit);

    open(IN, $f) || die("cannot open $f");
    while (<IN>) { $max_lines++;}
    close(IN);
    if ($max_lines == 0) {
	return;
    }
    else {
	$unit = int($max_lines/10);
    }

    print STDERR "Translating $f ...\n";

    $backup = $f."backup";
    &Copy($f, $backup);

    open(IN, $f) || die("cannot open $f");
    open(OUT, "> $f.trnew") || die("cannot open $f");

    while (<IN>) {
	$buf = $_;

	if (/$CACHE_TABLE/i) {
	    $x = $&;
	    $buf =~ s/$x/$TransTable{$x}/gi;

	    if ($opt_a) { 
		for $key (keys %TransTable) {
		    $buf =~ s/$key/$TransTable{$key}/gi;
		}
	    }
	}

	print OUT $buf;

	if (($unit > 1) && ($. % $unit == 0)) {
	    print STDERR " ", int(100 * $./$max_lines + 1), "\%";
	}
    }

    close(OUT);
    close(IN);

    if (rename($f, "$f.trbak") && rename("$f.trnew", $f)) {
	print STDERR "\tdone.\n";
	print STDERR "backup is $f.trbak\n";
	unlink $backup;
    }
    else {
	print STDERR "something error occurs\n";
	print STDERR "Please make $f from backup $backup\n";
    }

    print STDERR "\n";
}


sub Copy
{
    open(COPYIN,  $_[0])     || (&Log("Error: Copy::In [$!]"), return 0);
    open(COPYOUT, "> $_[1]") || (&Log("Error: Copy::Out [$!]"), return 0);
    select(COPYOUT); $| = 1; select(STDOUT); 
    while (sysread(COPYIN, $_, 4096)) { print COPYOUT $_;}
    close(COPYOUT);
    close(COPYIN); 
    1;
}


sub Log
{
    print STDERR @_, "\n";
}


1;
