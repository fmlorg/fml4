#!/usr/local/bin/perl

$re_euc_c  = '[\241-\376][\241-\376]';

while (<>) {
    next if /$re_euc_c/;
    print;
}

exit 0;
