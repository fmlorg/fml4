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

$| = 1;

&InitTTY;

print "
0\tend 
1\tProg Mailer e.g. MetaInfo Sendmail (2.0 after) 
2\tPOP Version 
";

$r = &Query("Which one your environment fit?", "0-2", "0|1|2", "0");

if ($r == 0) {
    exit(0);
}
elsif ($r == 1) {
    print "O.K. we assume you use MetaInfo Sendmail (at leaset 2.0 after)\n";
    system "perl sbin\\makefml -V METAINFO install";
}
elsif ($r == 2) {
    print "Starting the installer \"sbin\\makefml\"\n";
    system "perl sbin\\makefml install";
}


exit 0;


sub Query
{
    local($menu, $query, $pat, $default) = @_;
    
    print "Query(debug): ($menu, $query, $pat, $default)\n" if $debug;
    print "\n";

    while (1) {
	#print "menu={$menu} query={$query}\n";
	print "${CurTag}${menu} ($query) [$default] ";
	$cmd = &GetString;
	print "\n";

	if ($cmd =~ /^($pat)$/) { last;}
	if ($cmd =~ /^\s*$/) { $cmd = $default; last;}

	print "$CurTag   *** WARNING! Please input one of ($query) ***\n\n";
    }    

    $cmd;
}


sub gets
{
    local($.);
    $_ = <IN>;
}


sub GetString
{
    local($s);

    $s = &gets;

    # ^D
    if ($s eq "")  { print STDERR "'^D' Trapped.\n"; exit 0;}
    chop $s;

    $s;
}


sub InitTTY
{
    if (-e "/dev/tty") { $console = "/dev/tty";}

    open(IN, "<$console") || open(IN,  "<&STDIN"); # so we don't dingle stdin
    open(OUT,">$console") || open(OUT, ">&STDOUT");# so we don't dongle stdout
    select(OUT); $| = 1; #select(STDOUT); $| = 1;
}


1;
