#!/usr/local/bin/perl
#
# $Id$;
#

&SetConversionTable;

print "\n" if $debug;

while (sysread(STDIN, $_, 1)) { 

    if ($E2jkHash{$_}) {
	$buf  = $_;
	$cord = $E2jkHash{$_};
	$info = "Hash Hit";
    }
    elsif (ord($_) & 0x80) {
	$buf .= $_;
	$cord .= sprintf("%02d", (ord($_) & 0x7f) - 0x20);

	sysread(STDIN, $_, 1);
	$cord .= sprintf("%02d", (ord($_) & 0x7f) - 0x20);

	$buf .= $_;
	$info = "(ON 0x80)";
    }
    elsif ($_ eq ' ') {
	$buf .= $_;
	$cord = '0101';
    }
    elsif ($_ =~ /^[A-Za-z0-9]+$/) {
	$buf .= $_;
	$cord = sprintf("03%02d", ( ord($_) - 0x20) );
	$info = "(1 byte > 0x20)";
    }
    

    print "$buf\t#$cord\t$info\n" if $debug;
    print "#$cord" if $cord;
    $buf = $info = $cord = "";  
}

print "\n";


sub SetConversionTable
{
    %E2jkHash = (
	      '.',	'0105',
	      '-',	'0128',
	      '(',	'0142',
	      ')',	'0143',
	      '%',	'0183'
    );
}

1;
