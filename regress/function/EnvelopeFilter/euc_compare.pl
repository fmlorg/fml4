#!/usr/local/bin/perl

push(@INC, ".");
require 'proc/libkern.pl';
require 'kern/libenvf.pl';

print &EUCCompare('うにゃ じゃらん', 'に') ? "match" : "no match";
print "\n";
print "--------\n";
print &EUCCompare('うにゃ じゃらん', 'じ') ? "match" : "no match";
print "\n";

exit 0;
