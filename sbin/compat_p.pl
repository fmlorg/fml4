#!/usr/local/bin/perl

$OS = `$SH ./sbin/os-type 2>&1 |grep -v '\#'`;
chop $OS;

# Compat mode;
$compat = "COMPAT_${OS}";
$compat =~ tr/a-z/A-Z/;

print "$compat\n" if $compat =~ /SOLARIS2/;

exit 0;

