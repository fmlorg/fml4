#!/usr/local/bin/perl

push(@INC, ".");
require 'proc/libkern.pl';
require 'kern/libenvf.pl';

print &EUCCompare('���ˤ� ������', '��') ? "match" : "no match";
print "\n";
print "--------\n";
print &EUCCompare('���ˤ� ������', '��') ? "match" : "no match";
print "\n";

exit 0;
