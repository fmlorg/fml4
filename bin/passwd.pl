#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");
$rcsid  .= 'Current';

require 'getopts.pl';
&Getopts("p:hdiI:");

$opt_h && die(&Usage);
@ARGV  || die(&Usage);

$debug++ if $opt_d;
$init++  if $opt_i;

push(@INC, 'proc');
push(@INC, $opt_I);

# push $FML/bin, $FML 
$0 =~ m#^(.*)/(.*)#     && do { unshift(@INC, $1), unshift(@LIBDIR, $1);};
$0 =~ m#^(.*)/bin/(.*)# && do { unshift(@INC, $1), unshift(@LIBDIR, $1);};

require 'libcrypt.pl';

&Log("Force to change password ...");

$PASSWD_FILE = $opt_p || 'etc/passwd';
$to          = shift;
$p           = shift;

while (!$to || !$p) {
    if (! $to) {
	print "Address: ";
	chop($to = <STDIN>);
    }
    else {
	print "Address: $to\n";
    }

    if (! $p) {
	# no echo
	system "stty", "-echo";

	print "Password: ";
	chop($p = <STDIN>);
	print "\n";

	system "stty", "echo";
    }

    if (!$to || !$p) {
	&Warn("Error: Please input NOT NULL Address and Password.");
    }
}


if (!-f $PASSWD_FILE) { open(P, ">>$PASSWD_FILE"); close(P);}

($to && $p) || die("incorrect arguments?\n".&Usage);

&Log("&ChangePasswd($PASSWD_FILE, $to, $p)") if $debug;

if ( &ChangePasswd($PASSWD_FILE, $to, $p, $init) ) {
    &Log("O.K.");
}
else {
    &Log("fail.");    
}

exit 0;

##### library #####
sub Usage
{
    local($s) = q#;
    passwd.pl [-i] [-p password-file] user password;
    -i initialize password for the "user" as "password"; 
    -p alternative $PASSWD_FILE (default etc/passwd);

#;
$s =~ s/;//g;
$s;
}

sub Log { print STDERR "   @_\n";}

sub SRand
{
    local($i) = time;
    $i = (($i & 0xff) << 8) | (($i >> 8) & 0xff) | 1;
    srand($i + $$); 
}

1;
