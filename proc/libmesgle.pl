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

# @argv may contain Japanese ;-)
sub MesgLE
{
    local(*e, $key, @argv) = @_;
    local($dir) = "messages/$MESSAGE_LANGUAGE";
    local($found, $x, $msg);

    &Log("MesgLE: key=$key (@argv)") if $debug_mesgle;

    # it is default. no translation
    if ($MESSAGE_LANGUAGE eq 'English') { return $NULL;}

    # 0. check whether the message template directory exists?
    for (@LIBDIR) { 
	if (-d "$_/$dir") { 
	    $found = "$_/$dir";
	    last;
	}
    }

    # 1. check whether the message template with the key exists?
    if ($dir = $found) {
	local($file);
	if ($key =~ /\./) {
	    ($file) = split(/\./, $key);
	}
	else {
	    $file = 'kern'; # if without '.', search file "kern".
	}

	if (-f "$dir/$file") {
	    $msg = &MesgLE'Lookup($key, "$dir/$file"); #';
	    &Log("MesgLE: found in $dir/$file") if $msg && $debug;
	}

	if ($msg) {
	    &Log("MesgLE: found in file 'a' o keyword a.b.c.")
		if $debug_mesgle;
	}
	# XXX temporary disable directory search since
	# XXX we may use file.org ...
	elsif (0 && opendir(DIRD, $dir)) {
	    while ($x = readdir(DIRD)) {
		next if $x =~ /^\./;
		$msg = &MesgLE'Lookup($key, "$dir/$x"); #';
		&Log("FYI: MesgLE() use $dir/$x for $key") if $msg;
		&Log("FYI: it is O.K. but ineffective") if $msg;
		last if $msg;
	    }
	    closedir(DIRD);
	}
	else {
	    &Log("MesgLE: FYI: $dir has no entry") if 0;
	    &Log("MesgLE: cannot opendir $dir") if 0;
	    return $NULL;
	}
    }
    else {
	&Log("MesgLE: cannot find $dir in \@LIBDIR");
	return $NULL;
    }

    # 2. now we have $msg template; translate it to $MESSAGE_LANGUAGE
    if ($msg) {
	if ($MESSAGE_LANGUAGE eq 'Japanese') {
	    return &MesgLETranslate(*e, $msg, $key, @argv);
	}
	else {
	    &Log("MesgLE: language '$MESSAGE_LANGUAGE' is unknown");
	    return $NULL;
	}
    }
    else {
	&Log("MesgLE: no template for key='$key'");
	return $NULL;
    }
}


# @argv may contain Japanese ;-)
sub MesgLETranslate
{
    local(*e, $msg, $key, @argv) = @_;

    if ($MESSAGE_LANGUAGE eq 'Japanese') {
	require 'jcode.pl';
	eval "&jcode'init;";	
	&jcode'convert(*msg, 'euc'); #'(trick) -> EUC

	local($x, $t, $i); $i = 0;
	for (@argv) {
	    $t = "_ARG${i}_";
	    $x = $argv[$i];
	    &jcode'convert(*x, 'euc'); #'(trick) -> EUC
	    $msg =~ s/$t/$x/g;
	    $i++;
	}

	&jcode'convert(*msg, 'jis'); #'(trick) -> JIS
    }
    else {
	&Log("MesgLETranslate: language '$MESSAGE_LANGUAGE' is unknown");
	undef $msg;
    }

    $msg =~ s/\n$//;
    $msg;
}


package MesgLE;
###
### [Message template file format]
### key1:
### \s+messages line1
### \s+messages line2
### \s+messages line3
###   ... null line is ignored ...
### key2:

sub MesgLE'Log { &main'Log(@_);}

sub Lookup
{
    local($key, $file) = @_;
    local($found, $mesg);

    undef $mesg;

    if (! -f $file) {
	&Log("ERROR: MesgLE::Lookup no such file $file");
	return $NULL;
    }

    if (open(LE_TMPL, $file)) {
	while (<LE_TMPL>) {
	    # next if /^\s*$/;
	    next if /^\#/;

	    # see [FILE FORMAT] above
	    if (/^${key}:/) { $found = 1; next;}
	    if (/^\S+/)     { $found = 0; next;}

	    if ($found) {
		chop;
		s/^\s//;
		$mesg .= $_."\n";
	    }
	}
	close(LE_TMPL);
    }
    else {
	&Log("ERROR: MesgLE::Lookup cannot open file $file");
	undef $mesg;
    }

    $mesg;
}


sub CacheOn
{
    local(*table, $file, $jcode) = @_;
    my ($key, $mesg);
    local($x);

    require 'jcode.pl';

    if (open(LE_TMPL, $file)) {
	while (<LE_TMPL>) {
	    next if /^\#/;

	    # see [FILE FORMAT] above
	    if (/^(\S+):/) {
		my ($xkey) = $1;

		if ($key) {
		    $table{$key} = $mesg;
		    undef $mesg;
		}

		$key = $xkey; 
	    }
	    else {
		chop;

		$x = $_;
		$x =~ s/^\s//;
		&jcode::convert(*x, $jcode);
		$mesg .= $x . "\n";
	    }
	}
	close(LE_TMPL);
    }
    else {
	&Log("ERROR: MesgLE::CacheOn cannot open file $file");
	undef $mesg;
    }
}


1;
