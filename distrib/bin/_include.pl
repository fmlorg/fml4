$| = 1;

while (<>) {
    s/^\#\.include\s+(\S+)/&Cat($1)/e;

    print $_;
}

sub Cat
{
    local($in) = @_;

    print "### ---including $_\n";

    open(IN, $in) || (print STDERR "cannot open $in\n", return);
    while (<IN>) {
	print $_;
    }
    close(IN);

    print "### ---end of including $_\n\n";
    "";
}
