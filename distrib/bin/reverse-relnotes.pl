#!/usr/local/bin/perl

$/ = "---";

print $/;

for (reverse <>) {
	print ;
}

print "\n";

exit 0;
