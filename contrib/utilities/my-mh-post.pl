#!/usr/local/bin/perl -- # -*- perl -*-
# Copyright (c) 1995 UKAI,Fumitoshi <ukai@hplj.hpl.hp.com>
# Please obey GNU Public Licence

eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

$mhlibdir = '/usr/local/lib/mh';
$realpost = $mhlibdir . '/post';

$sep = '-+';			# --------

$| = 1;

$filename = $ARGV[$#ARGV];
$filename_orig = $filename . ".orig";

rename($filename, $filename_orig);
unlink($filename);
open(ORIG, $filename_orig) || die "cannot open $filename_orig, $!\n";
open(NEW, ">$filename") || die "cannot open $filename, $!\n";
unlink($filename_orig);

# header
while (<ORIG>) {
    if (/^$sep$/) {
	print NEW "X-Stardate: " . &stardate . "\n";
	print NEW;
	last;
    }
    if (/^x-stardate: /i) {
	next;
    }
    print NEW;
}
# body
while (<ORIG>) {
    print NEW;
}
close(ORIG);
close(NEW);

exec $realpost, @ARGV;
exit(0);

sub stardate {
    local($tm) = time;
    local($issue, $integer, $fraction);

    $fraction = (($tm%17280) * 3125) / 54;
    $integer = int($tm/17280) + 9350;
    $issue = int($integer/10000) - 36;
    $integer %= 10000;

    return sprintf("%ld[%04ld].%06ld", $issue, $integer, $fraction);
}
