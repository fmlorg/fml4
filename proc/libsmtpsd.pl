package sd;

sub Log 
{
    &main'Log(@_); #';
}

sub main'SDInit #';
{
    local(*list) = @_;
    local($tmp_dir, $dir);

    $tmp_dir  = $main'FP_TMP_DIR; #';
    $dir      = $main'DIR; #';
    $SD_TMP   = "$tmp_dir/sd$$";
    $SD_CACHE = "$dir/sd.cache";

    if (open(OUTLIST, "| sort > $SD_TMP")) {
	select(OUTLIST); $| = 1; select(STDOUT);
    }
    else {
	&Log("SDInit: $!");
	return 0;
    }

    # file list
    for (@list) {
	open(LIST, $_) || do { &Log("SDInit: cannot open $_"); next;};
	while (<LIST>) {
	    chop;
	    next if /^\#/;
	    next if /s=|m=/;

	    ($addr, $domain) = split(/\@/, $_);
	    $domain =~ tr/A-Z/a-z/;
	    @rev = split(//, $domain);
	    @rev = reverse @rev;
	    $rev = join("", @rev);

	    print OUTLIST "$rev\t$_\n";
	}
	close(LIST);
    } 
    close(OUTLIST);

    ### cache out
    if (open(OUTLIST, "> $SD_CACHE")) {
	select(OUTLIST); $| = 1; select(STDOUT);
    }
    else {
	&Log("SDInit: $!");
	return 0;
    }

    open(LIST, $SD_TMP) || do { &Log("SDInit: cannot open $SD_TMP"); next;};
    while (<LIST>) {
	chop;
	($domain, $_) = split(/\s+/, $_);

	print OUTLIST "$_\n";
    }

    close(OUTLIST);
    close(LIST);

    unlink $SD_TMP;

    # save list
    @ORG_LIST = @list;
    @list = ($SD_CACHE);
}


sub main'SDFin #';
{
    local(*list) = @_;

    unlink $SD_CACHE;
    @list = @ORG_LIST;
}


1;
