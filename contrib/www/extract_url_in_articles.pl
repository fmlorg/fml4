require 'getopts.pl';
&Getopts("hHd");

$debug = $opt_d;

$/ = "\n\n";
$\ = "\n";

while (<>) {
    next if /Return-Path:/ && /X-MLServer:/i; # header

    # cut the 'not \243'[\241-\376]
    s/[\241-\242\244-\376][\241-\376]//g;

    if (/\w\@\w|Email/i) { # must be a signature (may be)
	print STDERR "SKIP: MATCH [$&] for <$_>\n" if $debug;
	next;
    }

    $buf = $_;

    if (m#http://([\w\-\_\#/\.\~\%\&\=\+]+)#) {
	$_ = $1;
	print STDERR "CANDIDATE\t$_\n";

	s/index\.htm$//i;
	s/index\.html$//i;

	local($host, @x) = split(/\//, $_);
	next if $host !~ /\./; # not normal domain;

	$e{$_} = $_;

	if (! m#/#) { 
	    $_ = "$_/"; 
	    $e{$_}     = $_;
	    $buf{$_}  .= $buf;
	}
    }
}

foreach (keys %e) {
    next if $e{$_} && $e{"$_/"};
    print $e{$_};
}

exit 0;
