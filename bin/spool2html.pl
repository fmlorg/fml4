#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0 Exp #: Wed, 29 May 96 19:32:37  JST 1996';

######################################################################

require 'getopts.pl';
&Getopts("d:f:ht:I:D:");


$opt_h && do { &Usage; exit 0;};
$HTTP_INDEX_UNIT = $opt_t || 'day';
$DIR             = $opt_D || $ENV{'PWD'};
$HTTP_DIR        = $opt_d;
$SPOOL_DIR       = shift;
$CF              = $opt_f; 
push(@INC, $opt_I);

########## MAIN ##########
### WARNING;
-d $SPOOL_DIR || die("At least one argument is required for \$SPOOL_DIR\n");
-d $HTTP_DIR  || die("-d \$HTTP_DIR REQUIRED\n");

### Libraries
require $CF if -f $CF;
require '__fml.pl';
require 'libsynchtml.pl';

### redefine &Log ...
&FixProc;

### Here we go!
$MAX = &GetMax($SPOOL_DIR);

### TOO OVERHEADED ;_;
for $id (1 .. $MAX) {
    next unless -f "$SPOOL_DIR/$id";

    # tricky
    $e{'stat:mtime'} = (stat("$SPOOL_DIR/$id"))[9];
    next if &SyncHtmlProbeOnly($HTTP_DIR, $id, *e);

    undef %e;

    open(STDIN, "$SPOOL_DIR/$id") || return;

    &Parse;
    &GetFieldsFromHeader;
    &FixHeaders(*e);

    $e{'stat:mtime'} = (stat("$SPOOL_DIR/$id"))[9]; # since undef %e above;
    &SyncHtml($HTTP_DIR, $id, *e);
}

exit 0;


##### LIBRARY #####
sub Usage
{
    local($s);

    $s = q#;
    spool2html.pl [-h] [-I INC] [-f config.ph] [-d HTTP_DIR] [-t TYPE] SPOOL;
    ;
    -h    this message;
    -d    $HTTP_DIR;
    -f    config.ph;
    -t    number of day ($HTTP_INDEX_UNIT);
    ;
    SPOOL $SPOOL_DIR;
    ;#;

    $s =~ s/;//g;

    print "$s\n\n";
}

sub FixProc
{
local($evalstr) = q#;
sub Log  { print STDERR "@_\n";};
sub Mesg { print STDERR "@_\n";};
;#;

eval($evalstr);
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


1;
