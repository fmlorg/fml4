#!/usr/local/bin/perl -- # -*- perl -*-

# Copyright (C) 1994-1995 ukai@hplj.hpl.hp.com 
# Please obey GNU Public Licence(see COPYING)

sub usage {
    print STDERR "usage: $0 [-help]\n";
    exit 0
}

if ($#ARGV >= 0 && $ARGV[0] =~ m/^-h/) {
    &usage;
}

foreach $i (sort {$a <=> $b} <[0-9]*>) {
    $msg{$i} = &scan($i);
}

foreach $msg (keys %msg) {
    print $msg{$msg} . "\n";
    open(M, $msg) || die "cannot open $msg, $!\n";
    while (<M>) {
	if (/^From /) {
	    s/^/>/;
	}
	print;
    }
    close(M);
    print;
}
exit 0;

sub scan {
    local($i) = @_;
    local($from, $day, $mday, $mon, $year, $time, $tz);

    open(M, $i) || die "cannot open $i, $!\n";
    while (<M>) {
	last if (/^$/);
	if (/^\s+(.*)/) {
	    $header{"\L$h\E"} .= $c;
	    next;
	} 
	($h, $c) = m/^(.[^:]*):\s*(.*)$/;
	$header{"\L$h\E"} = $c;
    }
    close(M);
    if (defined($header{'return-path'})) {
	$from = $header{'return-path'};
    } else {
	$from = $header{'from'};
	$from =~ s/.*(<[^>]+>).*/\1/;
	$from =~ s/(.*)\(.*\)/\1/;
    }
    ($day, $mday, $mon, $year, $time, $tz) = split(/[,\s]+/,$header{'date'});
    if ($year < 100) {
	$year += 1900;
    }
    return "From $from  $day $mon $mday $time $year";
}
