#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

############################################
# Traditional AT&T UNIX ckeck sum utility  #
############################################

# getopt()
require 'getopts.pl';
&Getopts("dh");

for my $f (@ARGV) { 
    my ($crc, $total) = &TraditionalATTUnixCheckSum($f);
    printf "%-10d %5d %s\n", $crc, $total, $f;
    if ($opt_d) {
	&__System("cksum -o 2 $f");
	&__System("cksum -o 1 $f");
	&__System("sum $f");
	&__System("cksum $f");
    }
}

exit 0;

sub __System
{ 
    my ($x) = @_;
    my ($y);
    chop($y = `$x`); 
    printf "%-10d %5d %s (%s)\n", split(/\s+/, $y), $x;
}


# Reference: NetBSD:/usr/src/usr.bin/cksum/sum2.c
#  *** cksum utility is expected to conform to IEEE Std 1003.2-1992 ***
sub TraditionalATTUnixCheckSum
{
    my ($f) = @_;
    my ($crc, $total, $nr);

    $crc = $total = 0;
    if (open($f, $f)) {
	while (($nr = sysread($f, $buf, 1024)) > 0) {
	    my ($i) = 0;
	    $total += $nr;

	    for ($i = 0; $i < $nr; $i++) {
		$r = substr($buf, $i, 1);
		$crc += ord($r);
	    }
	}
	close($f);
	$crc = ($crc & 0xffff) + ($crc >> 16);
	$crc = ($crc & 0xffff) + ($crc >> 16);
    }
    else {
	print STDERR "ERROR: no such file $f\n";
    }

    ($crc, $total);
}


1;
