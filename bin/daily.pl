#!/usr/local/bin/perl

# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= ($id =~ /Id: (\S+),v\s+(\S+)\s+/ && "$1 $2");

&Init;

print "Daily Report ($rcsid)\n";

for (@ARGV) {
    &SearchInterests($_);
}

if ($Report) {
    print "\n".("=" x 60)."\n";
    print $Report;
}

exit 0;

sub Init
{
    require 'getopts.pl';
    &Getopts("f:dh");

    $debug = $opt_d;
    ($Patfile = $opt_f) || die("Please define the pattern table to ignore\n");


    local($mday,$mon,$year,$wday) = (localtime(time - 3600*24))[3..6];
    $Date = sprintf("%2d/%02d/%02d", $year, $mon + 1, $mday);
    print STDERR "Date: $Date\n" if $debug;

    open(F, $Patfile) || die ("cannot open $Patfile\n");
    while (<F>) {
	chop;
	$pat .= "next if /$_/o;\n";
    }
    close(F);

    $eval = qq!
	while (<STDIN>) {
	    next unless m#^$Date#;
	    $pat;

	    &Title unless \$Count;
	    \$Count++;
	    print \$_;
	    
	}
    !;
}

sub SearchInterests
{
    local($file) = @_;

    open(STDIN, $file) || return;

    undef $Count;
    print STDERR $eval if $debug;
    eval $eval;

    if (! $Count) {
	$Report .= "$file\thas No Possible Item of Interest\n\n";
    }
}

sub Title
{
    print "\nPossible Items of Interest ($file)\n";
    print '-' x 60;
    print "\n\n";
}

1;
