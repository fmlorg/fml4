#!/usr/local/bin/perl

eval 'exec perl -S $0 ${1+"$@"}'
	if $running_under_some_shell;

$AGE_OF1 = 1;

require "find.pl";

# Traverse desired filesystems

&find('var/db');

exit;

sub wanted {
    (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
    -f _ &&
    (-M _ > $AGE_OF1) && 
    print("$name\n");
}

