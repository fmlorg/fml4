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
    my ($dir, $x, $msg);

    &Log("MesgLE: key=$key (@argv)") if $debug_mesgle;

    # 1. check whether the message template with the key exists?
    # 1.1. search messages.conf if exists
    my ($file_ld) = "$DIR/messages.${MESSAGE_LANGUAGE}.conf";
    my ($file_li) = "$DIR/messages.conf";
    for my $file ($file_ld, $file_li) {
	if (-f $file) {
	    &Log("MesgLE: search key='$key' in $file") if $debug_mesgle;
	    $msg = &MesgLE::Lookup($key, $file);
	    &Log("MesgLE: key='$key' FOUND") if $msg && $debug_mesgle;
	    &Log("MesgLE: key='$key' NOT FOUND") if (!$msg) && $debug_mesgle;
	}
	else {
	    &Log("MesgLE: $file not exists, ignored") if $debug_mesgle;
	}
    }

    # 1.2. search under $mesg_dir
    if (! $msg) {
	for my $xdir (@LIBDIR) {
	    # e.g. /usr/local/fml/messages/Japanese/
	    $dir = "$xdir/messages/$MESSAGE_LANGUAGE";

	    &Log("MesgLE: mesg_dir=$dir ") if $debug_mesgle;
	    &Log("MesgLE: $dir not exists") if $debug_mesgle && (! -d $dir);
	    next unless -d $dir;

	    &Log("MesgLE: search key='$key' under $dir") if $debug_mesgle;
	    $msg = &MesgLESearchInMessagesDir($key, $dir);
	    last if $msg;
	}
    }

    # We got $msg, message template, now!
    # finally we have $msg template, so translate it into $MESSAGE_LANGUAGE.
    if ($msg) {
	if ($MESSAGE_LANGUAGE eq 'Japanese' || 
	    $MESSAGE_LANGUAGE eq 'English') {
	    return &MesgLETranslate(*e, $msg, $key, @argv);
	}
	else {
	    &Log("MesgLE: language '$MESSAGE_LANGUAGE' is unknown");
	    return undef;
	}
    }
    else {
	&Log("MesgLE: no template for key='$key'");
	return undef;
    }
}


sub MesgLESearchInMessagesDir
{
    my ($key, $dir) = @_;
    my ($file, $msg);

    if ($key =~ /\./) {
	($file) = split(/\./, $key);
    }
    else {
	$file = 'kern'; # if without '.', search file "kern".
    }

    if (-f "$dir/$file") {
	&Log("MesgLE: Lookup key='$key' in $dir/$file") if $debug_mesgle;
	$msg = &MesgLE'Lookup($key, "$dir/$file"); #';
	&Log("MesgLE: found in $dir/$file") if $msg && $debug;
    }
    else {
	&Log("MesgLE: $dir/$file not found") if $debug_mesgle;
    }

    if ($msg) {
	&Log("MesgLE: key='$key' FOUND") if $debug_mesgle;
	return $msg;
    }
    else {
	&Log("MesgLE: key='$key' NOT FOUND") if $debug_mesgle;
	return undef;
    }
}


# @argv may contain Japanese ;-)
sub MesgLETranslate
{
    local(*e, $msg, $key, @argv) = @_;

    if ($MESSAGE_LANGUAGE eq 'Japanese' ||
	$MESSAGE_LANGUAGE eq 'English') {
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
	return undef;
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


package main;

if ($0 eq __FILE__) {
    $| = 1;
    $MESSAGE_LANGUAGE = 'Japanese';
    $DIR = '/var/spool/ml/elena';
    @LIBDIR = ('/usr/local/fml');
    eval 'sub Log { print @_, "\n"; }';

    $debug_mesgle = 1;

    &Log("MesgLE: INC: @LIBDIR ") if $debug_mesgle;

    if (@ARGV) {
	($key, @argv) = @ARGV;
	my ($msg) = &MesgLE(*e, $key, @argv);
	print "--- reply ---\n";
	print $msg, "\n";
    }
    else {
	for my $x ('unlink uja', 'fail', 'auth.ok', 'admin.log log 100') {
	    print ">>> $x\n";
	    my ($key, @argv) = split(/\s+/, $x);
	    my ($msg) = &MesgLE(*e, $key, @argv);
	    print "--- reply ---\n";
	    print $msg, "\n";
	}
    }
}


1;
