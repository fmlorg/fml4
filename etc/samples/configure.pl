#!/usr/local/bin/perl

# $Id$

### CHECK COMPAT MODE;
$compat_file = "cf/__compat__";
if (-s $compat_file) {
    $COMPAT = `cat $compat_file`;
    chop $COMPAT;
    $OPTIONS .= " --${COMPAT} ";
}

### PWD;
chop($PWD = `pwd`);

### Config file;
$CONFIG_PH	= "$PWD/config.ph";
if (-f $CONFIG_PH) { 
    require $CONFIG_PH;
}

#whether generationg  --mladdr syntax samples or not
if ($ENV{'MAIL_LIST'} && ($MAIL_LIST ne $ENV{'MAIL_LIST'})) {
    $EFFECTIVE_ARGV = 1;
} 

$MAIL_LIST  = $ENV{'MAIL_LIST'}  if $ENV{'MAIL_LIST'};
$MAINTAINER = $ENV{'MAINTAINER'} if $ENV{'MAINTAINER'};

$ml             = (split(/\@/, $MAIL_LIST))[0];
$MAINTAINER	= (split(/\@/, $MAINTAINER))[0];
$FMLDIR		= $ENV{'FMLDIR'} || $PWD;
$FMLSERVDIR	= $FMLDIR;
$USER		= $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;

# $PWD/../
$FMLSERVDIR =~ s#(\S+)/\S+#$1#;

($a, $d) = split(/@/,$ML);

$EXECDIR        = "$FMLDIR/src";
$MLDIR          = $FMLDIR;
$INCLUDEDIR     = "$FMLDIR/samples";
$SAMPLE_DIR     = 'samples';

-d $SAMPLE_DIR || mkdir($SAMPLE_DIR, 0755);

print STDERR "\nGenerating samples ... \n\n";

foreach (@ARGV) {
    next if /.*~$/;
    s#(\S+)/(\S+)#$dir = $1, $f = $2#e;
    &Conv("$dir/$f", "$SAMPLE_DIR/$f") if $dir && $f;
}

print STDERR "\n";

exit 0;

sub Conv
{
    local($file, $outfile) = @_;

    #printf STDERR "   %-30s => %s\n", $file, $outfile;
    printf "\t\t%-30s\n", $outfile;

    open(FILE, $file);
    open(OUT, "> $outfile") || die $!;
    select(OUT); $| = 1; select(STDOUT);

    while (<FILE>) {
	s/\"/\\\"/g;
	# print STDERR $_;

	if ((!$EFFECTIVE_ARGV) && (!/^#/) ) {
	    s/\-\-mladdr=\S+//i;
	}

	eval "print OUT \"$_\";";
	print STDERR $@ if $@;
    }

    close(OUT);
    close(FILE);
}

1;
