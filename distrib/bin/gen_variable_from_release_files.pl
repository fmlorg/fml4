#!/usr/local/bin/perl

$OFF = 1;

while(<>) {
    next if /^\s*$/;
    chop;

    if($OFF && /=/) {
	print "eval $_; export $_;\n";
	next;
    }

    undef $OFF if /^\w+:/;

    if (/^(\w+):/) {
	print "\\\"; export $VARNAME;\n\n" if $counter;
	print "\n\neval $1=\\\" ";
	$VARNAME = $1;
	next;
    }

    print "$_ ";
    $counter++;
}

print "\\\"; export $VARNAME;\n\n" if $counter;
exit 0;
