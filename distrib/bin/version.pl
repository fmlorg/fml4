#!/usr/local/bin/perl

$version_file = $ARGV[0] || './version';

if (-f $version_file) {
    $version = `cat $version_file`;
    chop $version;
}
else {
    $version = 0;
}

print STDERR "version.pl: $version -> ";

$version++;

print STDERR "$version\n";

open(F, ">$version_file") || die "Cannot increment SEQUENCE\n";
print F $version."\n";
close(F);

exit 0;

1;
