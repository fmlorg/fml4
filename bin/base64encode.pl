#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("dI:");

if ($opt_I) {
    for (split(/:/, $opt_I)) { push(@INC, $_);}
}

require 'mimew20alpha.pl';

undef $/;
$body = <>;
print &bodyencode($body);
print &benflush;

1;
