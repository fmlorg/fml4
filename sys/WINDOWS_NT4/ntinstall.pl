#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

###
### sbin/makefml kicks this ntinstall.pl when "makefml install".
###

# flush
$| = 1;

chop($PWD = `cd`);
$PWD =~ s#\\#/#g;

@DIRS = ("bin", "sbin", "libexec", "cf", "etc", "doc", "var\\html");

#
# print STDERR "Expireing backup failes ... \n";
# &Expire;

$EXEC_DIR   = shift @ARGV;
$EXEC_DIR   =~ s#/#\\#g;

$SYS_DIR    = "$EXEC_DIR\\sys";
$DOC_DIR    = "$EXEC_DIR\\doc";
$DRAFTS_DIR = "$EXEC_DIR\\drafts";

-d $EXEC_DIR   || &MkDirHier($EXEC_DIR, 0755);
-d $SYS_DIR    || &MkDirHier($SYS_DIR, 0755);
-d $DOC_DIR    || &MkDirHier($DOC_DIR, 0755);
-d $DRAFTS_DIR || &MkDirHier($DRAFTS_DIR, 0755);

local($dir);
for $dir (@DIRS) {
    print STDERR "Installing $dir ";
    &RecursiveCopy($dir);
    print STDERR "\n";
}
print STDERR "\n";
print STDERR "Installing perl scripts (*.pl) files ...\n";

# since rm -fr ...
-d $DOC_DIR    || &MkDirHier($DOC_DIR, 0755);
-d $DRAFTS_DIR || &MkDirHier($DRAFTS_DIR, 0755);

&RecursiveCopy("src", ".");
print STDERR "\n";
system "copy src\\* $EXEC_DIR >nul";
-d "$SYS_DIR\\WINDOWS_NT4" || &MkDirHier("$SYS_DIR\\WINDOWS_NT4", 0755);
system "copy sys\\WINDOWS_NT4\\* $SYS_DIR\\WINDOWS_NT4  >nul";

# install drafts/$LANGUAGE/
for $dir ('Japanese', 'English') {
    my ($x) = $DRAFTS_DIR . "/$dir";
    -d $x || &MkDirHier($x, 0755);
    system "copy drafts\\${dir}\\* $DRAFTS_DIR\\${dir} >nul";
}

system "copy sys\\WINDOWS_NT4\\* $EXEC_DIR >nul";
system "copy sbin\\makefml $EXEC_DIR\\makefml >nul";

&Conv("sys\\WINDOWS_NT4\\ntfml.cmd", "$EXEC_DIR\\ntfml.cmd");

print STDERR "Good. Installation is done.\n\n";

print STDERR "--- Please ignore after this (EVEN IF THIS INSTALLER FAILED).\n";
print STDERR "--- New version (test phase)\n";

# get drive?
# if we not get it, it must be needed (really ???)
if ($EXEC_DIR =~ /^(\w:)/) {
    $DRIVE = $1;
}
else {
    $DRIVE = $NULL;
}


$NEW_DIR = "$SYS_DIR\\WINDOWS_NT4\\NEW";

-d $NEW_DIR || &MkDirHier($NEW_DIR, 0755);
&Conv("sys\\WINDOWS_NT4\\new\\ntfml.cmd", "$NEW_DIR\\ntfml.cmd");
&Conv("sys\\WINDOWS_NT4\\new\\ntfmlrm.cmd", "$NEW_DIR\\ntfmlrm.cmd");
&Conv("sys\\WINDOWS_NT4\\new\\autoexnt.bat", "$NEW_DIR\\autoexnt.bat");

exit 0;


sub RecursiveCopy
{
    local($dir, $target) = @_;

    # fix
    $target = $dir unless $target;

    -d "$EXEC_DIR/$target" || &MkDirHier("$EXEC_DIR/$target", 0755);

    if (opendir(DIRD, $dir)) {
	for (readdir(DIRD)) {
	    next if /^\./;

	    if (-d "$dir/$_") {
		# print STDERR "directory $dir/$_\n";

		-d "$EXEC_DIR/$target/$_" || &MkDirHier("$EXEC_DIR/$target/$_", 0755);
		&RecursiveCopy("$dir\\$_", "$target\\$_");
	    }
	    elsif (-f "$dir/$_") {
		# print STDERR "file      $dir/$_\n";
	    }
	    else {
		# print STDERR "N         $dir/$_\n";
	    }
	}
	closedir(DIRD);

	$dir =~ s#/#\\#g;

	my (@f) = <$dir\\*.bak>;
	if (@f) {
	    print STDERR "del $dir\\*.bak\n" if $debug_nt;
	    system "del $dir\\*.bak";
	    print STDERR "\nfail to del $dir\\*.bak\n" if $?;
	}

	my (@f) = <$dir\\*>;
	if (@f) {
	    my ($found) = 0;
	    for (@f) { -f $_ && $found++;}
	    if ($found) {
		print STDERR ".";
		print STDERR "copy $dir\\* $EXEC_DIR\\$target\n" if $debug_nt;
		system "copy $dir\\* $EXEC_DIR\\$target >nul";
		print STDERR "\nfail to copy $dir\\* $EXEC_DIR\\$target\n"
		    if $?;
	    }
	}
    }
}


sub MkDirHier
{
    local($pat) = $UNISTD ? '/|$' : '\\\\|/|$'; # on UNIX or NT4

    while ($_[0] =~ m:$pat:g) {
	next if (!$UNISTD) && $` =~ /^[A-Za-z]:$/; # ignore drive letter on NT4

	if ($` ne "" && !-d $`) {
	    mkdir($`, $_[1] || 0777) || do {
		&Log("cannot mkdir $`: $!"); 
		return 0;
	    };
	}
    }

    1;
}


sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};
    local(@path) = split(/:/, $path);

    # too pesimistic?
    for ("/usr/local/bin", "/usr/share/bin", 
	 "/usr/contrib/bin", "/usr/gnu/bin", 
	 "/usr/bin", "/bin", "/usr/gnu/bin", "/usr/ucb",
	 # NT Extention
	 "/perl5/bin", 
	 "c:\\perl\\bin", "d:\\perl\\bin", "e:\\perl\\bin"
	 ) {
	push(@path, $_);
    }

    for (@path) { if (-f "$_/$f") { return "$_/$f";}}
}


sub Conv
{
    local($example, $out) = @_;
    local($uid, $gid, $format);

    $PERL_PROG = &search_path('perl.exe');
    $PERL_PROG =~ s#/#\\#g;

    open(EXAMPLE, $example)  || (&Warn("cannot open $example"), return 0);
    open(CF, "> $out")       ||  (&Warn("cannot open $out"), return 0);
    select(CF); $| = 1; select(STDOUT);
    
    print STDERR "\tGenerating $out\n";

    while (<EXAMPLE>) {
	s/_PERL_/$PERL_PROG/g;
	s/_EXEC_DIR_/$EXEC_DIR/g;
	s/_ML_DIR_/$ML_DIR/g;
	s/_ML_/$ml/g;
	s/_DOMAIN_/$DOMAIN/g;
	s/_FQDN_/$FQDN/g;
	s/_USER_/$USER/g;
	s/_OPTIONS_/$opts/g;
	s/_CPU_TYPE_MANUFACTURER_OS_/$CPU_TYPE_MANUFACTURER_OS/g;
	s/_STRUCT_SOCKADDR_/$STRUCT_SOCKADDR/g;
	s/XXUID/$uid/g;
	s/XXGID/$gid/g;

	# NT version only
	s/_DRIVE_/$DRIVE/g;

	print CF $_;
    }

    close(EXAMPLE);
    close(CF);
}


sub Warn
{
    print STDERR "Warn: @_\n";
}


sub Expire
{
    require "find.pl";

    # Traverse desired filesystems
    &find('.');

    print STDERR "\nDone.\n\n";
}


sub wanted 
{
    /^.*\.(b0|bak)$/ && do {
	print("$name ");
	unlink $name;
    };
}


sub Log
{
    print STDERR "Log> @_\n";
}


1;
