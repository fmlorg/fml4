#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("dB:D:U:R:");

$dir       = $opt_D || "var/db/$db";
$url_base  = $opt_U || die("Please define URL_BASE");
$href_repl = $opt_R; 

-d $dir || mkdir($dir, 0755);
for (@ARGV) { &Split($_);}

exit 0;


sub Split
{
    local($f) = @_;

    open(F, $f) || die $!;

    $n =  $f;
    $n =~ s#.*/##;
    $url = $n;
    $n =~ s/\.html$//i;
    
    while (<F>) {
	last if /^\s+INDEX\s+$/;

	if ($href_repl && /href=/i) {
	    s/(href=\")/$1$href_repl/i;
	}

	if (/NAME=\"(\S+)\"/) {
	    $title = $file = $1;
	    $title =~ s/C/Chapter /;
	    $title =~ s/S/ Section /;
	}

	if ($file && 
	    ($cur_file ne $file)) {
	    print W "</BODY>\n";
	    print W "</HTML>\n";
	    close(W);

	    print STDERR "$dir/${n}-$file.html\n";
	    open(W, "> $dir/${n}-$file.html") || die $!;
	    select(W); $| = 1; select(STDOUT);

	    print W "<HTML>\n<HEAD>\n";
	    print W "<TITLE>$title</TITLE>\n\n";
	    print W "</HEAD>\n\n";
	    print W "<BODY BGCOLOR=\"\#E6E6FA\">\n";
	    print W "[$title]\n<BR>\n";
	    print W "<A HREF=$url_base/$url>\n";
	    print W "=&gt; The whole of this chapter</A>\n";
	    print W "<BR>\n<HR>\n";

	    $cur_file = $file;
	}

	print W $_;
    }

    close(F);
}

1;
