#!/usr/local/bin/perl

$FILE = $ARGV[0] || $ENV{'FML'}."/var/doc/op.jp";

open(F, $FILE)||die($!);

while(<F>) {
	print "\n",$_ if /^[A-Z]+\s+/;
	print if /^\d{1,2}\s+\S+/;
	last if /^\S+\s+Appendix/;
}

close(F);
