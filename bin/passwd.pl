#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");
$rcsid  .= 'Current';

require 'getopts.pl';
&Getopts("p:hdi");

$opt_h && die(&Usage);
$debug++ if $opt_d;
$init++  if $opt_i;

push(@INC, 'proc');
require 'libcrypt.pl';

&Log("Force to change password ...");

$PASSWD_FILE = $opt_p || 'etc/passwd';
$to          = shift;
$p           = shift;

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
    passwd.pl [-i] [-p password-file] username new-password;
    -i initialize;
    -p alternative $PASSWD_FILE (default etc/passwd);

#;
$s =~ s/;//g;
$s;
}

sub Log { print STDERR "   @_\n";}

1;
