#!/usr/local/bin/perl

&mhgetopt;

open(F, $FILE) || die("cannot open $FILE;$!\n");

while(<F>) {
    /mconf/i && $ok++;

    if (/^(\S+):/ && (!/^\$/) && (!/^MSend:/) && (!/^AL:/)) {
	if ($ok) {
	    $r .= '*' x 60;
	    $r .= "\n\n\t\t[ $ML ]\n\n";
	    $r .= $s;
	    $s{$ML}.= "$m\n";
	}
	undef $s;
	undef $m;
	undef $ok;

	$ML = $1;
	next;
    };
    
    /^MSend:/ && (s/^MSend:/\t/, $m .= $_);
    /JST/     && ($m .= "\t$_");

    $s .= $_;
}
close(F);

print "*** Brief Summary ***\n";
foreach (keys %s) {
    print "\n$_:\n";
    print $s{$_};
}
print "\n\n*** Summary ***\n";
print $r;

if ($truncate) {
    truncate($FILE, 0);
}
else {
    print STDERR "$FILE not zero\'d\n";
}

exit 0;

sub mhgetopt 
{
    local(@b);

    # DEFAULT
    $truncate = 0;
    $FILE     = 'STDIN';
    $folder   = $DEFAULT_FOLDER;

    while($_ = shift @ARGV) {
	if (/^\+(\S+)$/) {
	    $folder = $1;
	}
	elsif (/^\-file$/) {
	    $FILE = shift @ARGV;
	}
	elsif (/^\-truncate$/) {
	    $truncate = 1;
	}
	elsif (/^\-notruncate$/) {
	    $truncate = 0;
	}
	else {
	    push(@b, @_);
	}
    }

    @ARGV = @b;
}

1;
