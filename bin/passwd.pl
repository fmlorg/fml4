#!/usr/local/bin/perl

# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");
$rcsid  .= 'Current';

require 'getopts.pl';
&Getopts("p:hd");

$opt_h && die(&Usage);
$debug++ if $opt_d;

require 'libcrypt.pl';

print STDERR "Force to change password ... \n";

$PASSWD_FILE = $opt_p || 'etc/passwd';
$to          = shift;
$p           = shift;

($to && $p) || die("incorrect arguments?\n".&Usage);

print STDERR "&ChangePasswd($PASSWD_FILE, $to, $p)\n" if $debug;

if ( &ChangePasswd($PASSWD_FILE, $to, $p) ) {
    print STDERR "O.K.\n";    
}
else {
    print STDERR "fail.\n";    
}

exit 0;

##### library #####
sub Usage
{
q#
passwd.pl [-p password-file] username new-password
#;
}

sub Log
{
    print STDERR "LOG: @_\n";
}

1;
