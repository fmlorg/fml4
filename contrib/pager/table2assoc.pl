while (<>){
    next unless /^\d/;

    ($n, $c) = split;

    print "\t'$c', '$n',\n";

}
