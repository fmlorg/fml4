#!/usr/local/bin/perl

require 'libhref.pl';

$DIR     = $TMP_DIR    = $ENV{'TMPDIR'} || '.';
$req     = shift @ARGV || 'http://www.phys.titech.ac.jp/uja/';
$outfile = shift @ARGV;
$debug   = 1;

if ($outfile) {
    -f $outfile && die("$outfile already exists, exit!\n");
    ($outfile eq '-') && ($STDOUT = 1);
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

if (! $STDOUT) {
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
sub Debug   { &Log(@_);}
sub LogWEnv { &Log(@_);}

1;
