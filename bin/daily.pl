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

local($id);
$id = q$Id$;
$rcsid .= ($id =~ /Id: (\S+),v\s+(\S+)\s+/ && "$1 $2");

&Init;

print "Daily Report ($rcsid):\n";

for (@ARGV) { &SearchInterests($_);}

if ($Report) {
    print "\n".("=" x 60)."\n";
    print $Report;
}

exit 0;

sub Init
{
    local($prev);

    $| = 1;

    require 'getopts.pl';
    &Getopts("f:dhp:t:");

    # help
    if ($opt_h) { &Usage; exit 0;}

    $debug = $opt_d;
    $prev  = $opt_p || 1;
    $TrapPatFile = $opt_t;
    ($PatFile = $opt_f) ||
	die("no -f file:\nPlease define the pattern table to ignore\n");

    local($mday,$mon,$year,$wday) = (localtime(time - 3600*24*$prev))[3..6];
    $Date = sprintf("%2d/%02d/%02d", $year, $mon + 1, $mday);
    print STDERR "Date: $Date\n" if $debug;

    open(F, $PatFile) || die ("cannot open $PatFile\n");
    while (<F>) {
	next if /^\#/;
	next if /^\s*$/;
	chop;

	$pat .= "next if /$_/o;\n";
    }
    close(F);

    if ($TrapPatFile) {
	open(F, $TrapPatFile) || die ("cannot open $TrapPatFile\n");
	while (<F>) {
	    next if /^\#/;
	    next if /^\s*$/;
	    chop;

	    $trap_pat .= "\$TrapBuf .= '-- '.\$_ if /$_/o;\n";
	}
	close(F);
    }

    $eval = qq!
	while (<STDIN>) {
	    next unless m#^$Date#;

	    $trap_pat;

	    $pat;

	    &Title unless \$Count;
	    \$Count++;
	    \$Buf .= \$_;
	    
	}
    !;
}

sub SearchInterests
{
    local($file) = @_;
    local($w);
    local($Buf, $TrapBuf);

    open(STDIN, $file) || return;

    undef $Count;
    print STDERR $eval if $debug;
    eval($eval);
    print STDERR $@ if $@;

    if ($TrapBuf) {
	$TrapBuf =~ s/$Date\s+//g;
	print "-- Possible Items of Special Interest ($file)\n";
	print $TrapBuf;
	print "\n";
    }

    $Buf =~ s/$Date\s+//g;
    print $Buf;

    # Be silent if nothing matches.
    # if (! $Count) {
    # $Report .= 
    # sprintf("%-20s\thas No Possible Item of Interest\n\n", $file);
    # }
}

sub Title
{
    print "\n$Date Possible Items of Interest ($file)\n";
    print '-' x 60;
    print "\n\n";
}

sub Usage
{
    print <<EOF;
daily.pl [-hd] [-f patfile] [-t trap_patfile] [-p days]

-h        this message
-d        debug mode

-f file   pattern file to ignore
-t file   pattern file to trap (evaluated before ignore list)
-p days   scan at which day (default is 1, that is "yesterday")
EOF
}

1;
