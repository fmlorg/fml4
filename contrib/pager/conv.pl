require 'getopts.pl';
&Getopts("d:k:");

$kuten = $opt_k || 1;

while (<>) {
    chop;
    $i++;

    s/\(\s+"(\S+)"/$char = $1/e;

    printf "%02d%02d\t%s\n", $kuten, $i, $char if !/;/;
}
