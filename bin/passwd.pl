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

1;
