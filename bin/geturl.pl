#!/usr/local/bin/perl

local($req) = (shift @ARGV) || 'http://www.phys.titech.ac.jp/uja/';

$DIR = $TMP_DIR = $ENV{'TMPDIR'} || '.';

$TAR		= "/usr/bin/tar cf -";
$UUENCODE	= "/bin/uuencode";
$RM		= "/bin/rm -fr";
$CP		= "/bin/cp";
$COMPRESS	= "/usr/bin/gzip -c";
$ZCAT		= "/usr/bin/zcat";

# SPECIAL
$UUENCODE = "/bin/cat";

require 'libhref.pl';

&Href($req, *e);

print $e{'message'};

sub Log   { print STDERR " @_ \n";}
sub Debug { &Log(@_);}

1;
