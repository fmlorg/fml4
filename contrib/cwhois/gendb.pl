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

### Import: fml.pl
$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0 Internal #: Wed, 29 May 96 19:32:37  JST 1996';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);
$0 =~ m#(\S+)/(\S+)# && (unshift(@INC, $1)); #for lower task;


##### MAIN #####
&SetOpts;
&GenDB;
exit 0;
###### MAIN ENDS #####

### Search Function is a reference to this function
### So, you can customize this in any way as you feel so good.
### EXAMPLE #####
# 
# return matched strings
sub CacheOn
{
    local(*hdr, *body) = @_;
    local($s, $nic);

    $DISCARD_HDR_PAT  = 'Subject:.*uja';
    $DISCARD_BODY_PAT = 'c.\s+\[Project\]\s+.*';

    # 822 unfolding
    $hdr  =~ s/\n\s+/\n/g;
    $body =~ s/\n\s+/\n/g;

    for (split(/\n/, $hdr)) {
	return 0 if /^($DISCARD_HDR_PAT)/i;
	$nic++ if /^From:.*nic.net/i;
    }

    return unless $nic;

    for (split(/\n/, $body)) {
	return 0 if /^($DISCARD_BODY_PAT)/i;

	if (/ matched_pattern /) {
	    $s .= "$1 ";
	}

	/\[wanted_pattern\]\s+(.*)/ && ($s .= "$1 ");
    }

    while ($s =~ s/\s+/ /g) { 1;}
    $s;
}


############################################################
############################################################
############################################################

sub GenDBInit
{
    $|    = 1;

    require $CF if -f $CF;

    $init = 1 if $INIT || $_cf{'opt:i'};
    $NKF  = $NKF || &search_path('nkf') || '/usr/local/bin/nkf';
    -f $NKF || die("nkf($NKF) is undefined! Please define it!\n");
}


sub GenDB
{
    local($max, $seq);

    &GenDBInit;

    $seq = &GetDBLastSeq($DIR);
    $max = &GetMax($DIR);

    print STDERR "$seq <= $max ? &DoScanNewFiles($DIR);\n" if $debug;

    if ($seq < $max) {
	&DoScanNewFiles($DIR, $seq, $max);
	&DBAppend("$max:");
    }
    else {
	print STDERR "DO NOTHING($seq >= $max)\n";
    }
}


sub GetMax
{
    local($dir) = @_;
    opendir(DIRD, $dir) || die $!;
    local($file);

    foreach (readdir(DIRD)) { # order is mixed?
	next if /^\./o;
	next unless /^\d+$/;
	$max = $max > $_ ? $max : $_;
    }

    $max;
}


sub DoScanNewFiles
{
    local($dir, $seq, $max) = @_;
    local($file);

    opendir(DIRD, $dir) || die $!;

    # O.K. I know the max sequence now.
    foreach $file ($seq .. $max) {
	undef $r;
	undef $hdr;
	undef $body;

	$f = "$dir/$file";
	next unless -f $f;

	open(F, (-e $NKF ? "$NKF -e $f|" : $f)) || next;
	while (<F>) {
	    if (1 .. /^$/) { $hdr .= $_;} else { $body .= $_;}
	}

	$prog = $CACHE_PROG || 'CacheOn';
	$r = &$prog(*hdr, *body);
	&DBAppend("$file: $r") if $r;
    }
}

sub DBAppend
{
    local($s) = @_;

    print "$s\n" if $Envelope{'mode:diff'};

    open(APP, ">> $DB") || &Log($!);
    select(APP); $| = 1; select(STDOUT);
    print APP "$s\n" if $s;
    close(APP);

    1;
}


sub GetDBLastSeq
{
    return 1 if ! -f $DB;

    # lseek() may fail ;_; (e.g. JLE)
    open(IN, "tail -3 $DB|") || die $!;
    while (<IN>) { /^(\d+):/ && ($seq = $1);}
    close(IN);

    print STDERR "LAST: $seq ($DB)\n" if $debug;

    $seq;
}


############################################################

### Import: fml-current/cf/config 
sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};

    foreach $dir (split(/:/, $path)) { 
	if (-f "$dir/$f") { return "$dir/$f";}
    }

    "";
}

### Import: fml.pl
# Getopt
sub Opt { push(@SetOpts, @_);}
    
# Setting CommandLineOptions after include config.ph
sub SetOpts
{
    for (@SetOpts) {
	if (/^\-\-(force|fh):(\S+)=(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"fh:$h:"} = $3;
	}
	elsif (/^\-\-(original|org|oh):(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"oh:$h:"} = 1;
	}
	elsif (/^\-\-(\S+)=(\S+)/) {
	    eval("\$$1 = '$2';"); next;
	}
	elsif (/^\-\-(\S+)/) {
	    local($_) = $1;
	    /^[a-z0-9]+$/ ? ($Envelope{"mode:$_"} = 1) : eval("\$$_ = 1;"); 
	    /^permit:([a-z0-9:]+)$/ && ($Permit{$1} = 1); # set %Permit;
	    next;
	}

	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }
   
}

# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}

sub Log { 
    local(@c) = caller; 
    print STDERR "LOG(@c)>@_\n";
}


1;
