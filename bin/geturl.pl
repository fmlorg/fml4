#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

### Library
$LIBRARY_TO_OVERWRITE = q#
sub Log     { print STDERR "LOG>@_\n";}
sub Mesg    { local(*e, $s) = @_; print STDERR "LOG>$s\n";}
sub Debug   { &Log(@_);}
sub LogWEnv { &Log(@_);}
#;

# Target machine hack;
push(@INC, $ENV{'FML'});
push(@INC, "$ENV{'FML'}/proc");

require 'libkern.pl';
require 'libsmtp.pl';
require 'libhref.pl';
eval $LIBRARY_TO_OVERWRITE;
print STDERR $@ if $@;

$DIR     = $FP_TMP_DIR = $TMP_DIR = ($ENV{'TMPDIR'} || '.');
$req     = shift @ARGV || 'http://asuka.sapporo.iij.ad.jp/staff/fukachan/';
$outfile = shift @ARGV;

$debug          = 1;
$debug_caller   = 1;

$LOGFILE = "$DIR/geturllog";

if ($outfile) {
    if (-f $outfile) { die("$outfile already exists, exit!\n");}
    if ($outfile eq '-') { $UseStdout = 1;}
} 
else {
    #if ($req !~ /(peg|htm)$/ && $req !~ m#/$#) { $req .= "/index.html";}
    if ($req =~ m#/$#) { $req .= "index.html";}
    ($req =~ m@\S+/(\S+)@) && ($outfile = $1);
}


##### Retrieve
$e{'special:geturl'} = 1;

&HRef($req, *e);

$tmpf = $e{'special:geturl'};
undef $e{'special:geturl'};

##### $tmpf -> $outfile
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
unlink $tmpf;

exit 0;

1;
