#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$


#########################################################################
### Configrations ###

$WWW_HOME = $ENV{'WWW_HOME'};
$DIR      = $FP_TMP_DIR = $TMP_DIR = ($ENV{'TMPDIR'} || '.');

$debug          = 1;
$debug_caller   = 1;

$LOGFILE = "$DIR/geturllog";

$LIBRARY_TO_OVERWRITE = q#;
sub Log     { print STDERR "LOG>@_\n";};
sub Mesg    { local(*e, $s) = @_; print STDERR "LOG>$s\n";};
sub Debug   { &Log(@_);};
sub LogWEnv { &Log(@_);};
#;

#########################################################################


&Init;

$req      = shift @ARGV || $WWW_HOME;
$outfile  = shift @ARGV;

$tmpf = &GetUrl;

if ($opt_p) {
    &ProbeUrl;
}
else {
    &OutPutFile($tmpf);
}

unlink $tmpf;
exit 0;



#########################################################################


sub Init
{
    require 'getopts.pl';
    &Getopts("C:H:cdp");

    $debug = 1 if $opt_d;
    $cache = 1 if $opt_c;

    # overwrite
    $Contents = $opt_C if $opt_C;
    $HeadFile = $opt_H if $opt_H;

    if ($Contents) {
	$Compare = 1;
	$HeadFile = ".${Contents}.head" unless $HeadFile;
    }

    ### Target machine hack;
    push(@INC, $ENV{'FML'});
    push(@INC, $ENV{'FMLLIB'});

    require 'libkern.pl';
    require 'libsmtp.pl';
    require 'libhref.pl';


    eval $LIBRARY_TO_OVERWRITE;
    print STDERR $@ if $@;
}


sub ProbeUrl
{
    $e{"special:probehttp"} = 1;
    $e{'special:geturl'} = 1; # Retrieve

    &HRef($req, *e);

    $tmpf = $e{'special:geturl'};
    undef $e{'special:geturl'};

    system "cat $tmpf";
    unlink $tmpf;
}

sub GetUrl
{
    if ($outfile) {
	if (-f $outfile) { die("$outfile already exists, exit!\n");}
	if ($outfile eq '-') { $UseStdout = 1;}
    } 
    else {
	if ($req =~ m#/$#) { 
	    $req .= "index.html"; 
	}
	if ($req =~ m#\S+/(\S+)#) {
	    $outfile = $1;
	}
    }


    $e{'special:geturl'} = 1; # Retrieve

    &HRef($req, *e);

    $tmpf = $e{'special:geturl'};
    undef $e{'special:geturl'};

    $tmpf;
}


sub OutPutFile
{
    local($tmpf) = @_;

    ### $tmpf -> $outfile
    open(IN, $tmpf) || die("< $tmpf: $!\n");

    if (! $UseStdout) {
	open(STDOUT, "> $outfile") || die("> $outfile: $!\n");
    }
    else {
	&Log("> STDOUT");
    }

    select(STDOUT); $| = 1;

    while (sysread(IN, $_, 4096)) { print $_;}

    close(STDOUT);
    close(IN);

    &Log("$tmpf -> ".($outfile || 'STDOUT'));
}


1;
