#!/usr/local/bin/perl

$ID = `perl usr/sbin/fml_version.pl -s`;

while(<>) {
    if (/^\s+Last modified:/) {
	print "\n   $ID";
	print STDERR "\t---replaced -> $ID \n";
	# print "\tLast modified: ".`date`;
	next;
    }

    print;
}

1;
