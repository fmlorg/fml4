while (<>) {

    $i = 3;
    while ($i-- > 0) {
	if (/(\$Config\{(\S+)\})/g) {
	    $var = $1;
	    print $var, "\n";
	    s/$var//;
	}
    }
}
