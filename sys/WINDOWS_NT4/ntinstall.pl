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

$ARCH_DIR   = "$EXEC_DIR\\arch";
$DOC_DIR    = "$EXEC_DIR\\doc";
$DRAFTS_DIR = "$EXEC_DIR\\drafts";

-d $EXEC_DIR   || mkdir($EXEC_DIR, 0755);
-d $ARCH_DIR   || mkdir($ARCH_DIR, 0755);
-d $DOC_DIR    || mkdir($DOC_DIR, 0755);
-d $DRAFTS_DIR || mkdir($DRAFTS_DIR, 0755);

for (@DIRS) {
    print  "Installing $dir ...\n";
    &RecursiveCopy($_);
}

print "Installing perl scripts (*.pl) files ...\n";

# since rm -fr ...
-d $DOC_DIR    || mkdir($DOC_DIR, 0755);
-d $DRAFTS_DIR || mkdir($DRAFTS_DIR, 0755);

&RecursiveCopy("src", ".");
system "copy src\\* $EXEC_DIR";
-d "$ARCH_DIR\\WINDOWS_NT4" || mkdir("$ARCH_DIR\\WINDOWS_NT4", 0755);
system "copy src\\arch\\*\\WINDOWS_NT4\\*.pl $ARCH_DIR\\WINDOWS_NT4";

system "copy drafts\\* $DRAFTS_DIR";
system "copy sys\\arch\\WINDOWS_NT4\\* $EXEC_DIR";
system "copy sbin\\makefml $EXEC_DIR\\makefml";

&Conv("sys\\arch\\WINDOWS_NT4\\ntfml.cmd", "$EXEC_DIR\\ntfml.cmd");


exit 0;


sub RecursiveCopy
{
    local($dir, $target) = @_;

    # fix
    $target = $dir unless $target;

    -d "$EXEC_DIR/$target" || mkdir("$EXEC_DIR/$target", 0755);

    if (opendir(DIRD, $dir)) {
	for (readdir(DIRD)) {
	    next if /^\./;

	    if (-d "$dir/$_") {
		# print STDERR "directory $dir/$_\n";

		-d "$EXEC_DIR/$target/$_" || mkdir("$EXEC_DIR/$target/$_", 0755);
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
	print STDERR "copy $dir\\* $EXEC_DIR\\$target\n";
	system "del $dir\\*.bak";
	system "copy $dir\\* $EXEC_DIR\\$target";
    }
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


1;
