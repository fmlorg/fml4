#!/usr/local/bin/perl

$UNISTD = 0;

for my $dir (@ARGV) {
	printf "%s umask=%04o\n", $dir, umask if $debug;
	$status = &MkDirHier($dir, 0777);
	die("status $status") unless $status;
}

exit 0;

sub MkDirHier
{
    local($pat) = $UNISTD ? '/|$' : '\\\\|/|$';

    while ($_[0] =~ m:$pat:g) {
	    printf "--mkdir <%s\t%s\t%s>\n", $`, $&, $' if $debug;

	if ($` ne "" && !-d $`) {
	    printf "mkdir(%s, %04o)\n", $`, $_[1] if $debug;
	    mkdir($`, $_[1]) || do { 
		&Log("cannot mkdir $`: $!"); 
		return 0;
	    };
	}
    }

    1;
}

sub Log
{
    print STDERR "LOG> @_\n";
}
