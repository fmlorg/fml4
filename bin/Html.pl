#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# Now for the exist-check (DIR, LIBDIR), "free order is available"
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || '/home/axion/fukachan/work/spool/EXP';
$LIBDIR	= $LIBDIR || $DIR;


#################### MAIN ####################
# including libraries
require 'config.ph';		# configuration file for each ML
eval("require 'sitedef.ph';");  # common defs over ML's

chdir $DIR || die "Can't chdir to $DIR\n";

&use('synchtml');

&SyncHtml($HTML_DIR || $HTTP_DIR || $SPOOL_DIR, $ID, *Envelope);

exit 0;

### LIBRARY

sub Log     { print STDERR "LOG>  @_\n";}
sub Debug   { print STDERR "LOG>  @_\n";}

# append $s >> $file
# $w   if 1 { open "w"} else { open "a"}(DEFAULT)
# $nor "set $nor"(NOReturn)
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2
{
    local($s, $f, $w, $nor) = @_;

    if (! open(APP, $w ? "> $f": ">> $f")) {
	local($r) = -f $f ? "cannot open $f" : "$f not exists";
	$nor ? (print STDERR "$r\n") : &Log($r);
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP $s . ($nonl ? "" : "\n") if $s;
    close(APP);

    1;
}

# Getopt
sub Opt 
{ 
    local($_) = @_;

    /^\-sync/      && ($Proc = 'Sync') && return;
    /^\-fix/       && ($Proc = 'GenDir')  && return;
    /^\-init/      && ($Proc = 'GenDir')  && return;
    /^\-d/         && ($debug = 1)     && return;
    /^\-[sr](\S+)/ && ($ReadDir = $1);
}

# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}

1;
