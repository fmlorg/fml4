#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


push(@INC, $ENV{'FML'});
push(@INC, "$ENV{'FML'}/proc");

require 'libsmtp.pl';
require 'libhref.pl';

$DIR     = $FP_TMP_DIR = $TMP_DIR = ($ENV{'TMPDIR'} || '.');
$req     = shift @ARGV || 'http://www.phys.titech.ac.jp/uja/';
$outfile = shift @ARGV;
$debug   = 1;

if ($outfile) {
    if (-f $outfile) { die("$outfile already exists, exit!\n");}
    if ($outfile eq '-') { $UseStdout = 1;}
} 
else {
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


### Library
sub Log     { print STDERR "LOG>@_\n";}
sub Mesg    { local(*e, $s) = @_; print STDERR "LOG>$s\n";}
sub Debug   { &Log(@_);}
sub LogWEnv { &Log(@_);}

1;
