#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("c:qn");
$file = $ARGV[0];
$query = 1 if $opt_q;

while (<>) {
    if (/Id:\s*(\S+\.p.),v\s+([\d\.]+)/) { 
	if ($opt_n) {
	    print $2;
	}
	else {
	    printf "%-30s\t%-10s\n", $file, $2;
	}

	last;
    }
}

exit 0;

