$/ = "\n\n";
$\ = "\n";

while (<>) {
    next if /Return-Path:/ && /X-MLServer:/i; # header

    next if /\w\@\w/;
    next if /Email/i;

    if (m#http://([\w\-\_\#/\.\~\%\&\=\+]+)#) {
	$_ = $1;
	s/index\.htm$//i;
	s/index\.html$//i;

	local($host, @x) = split(/\//, $_);
	next if $host !~ /\./; # not normal domain;

	$e{$_} = $_;

	if (! m#/#) { 
	    $_ = "$_/"; 
	    $e{$_}    = $_;
	}
    }
}

foreach (keys %e) {
    next if $e{$_} && $e{"$_/"};
    print $e{$_};
}

exit 0;
