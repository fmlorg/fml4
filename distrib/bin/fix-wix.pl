#!/usr/local/bin/perl

while(<>) {
    if (/^\s+Last modified:/) {
	print "\n   ".`perl usr/sbin/fml_version.pl -s`;
	# print "\tLast modified: ".`date`;
	next;
    }

    print;
}

1;
