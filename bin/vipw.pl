#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("hpf:d:");

$opt_h && die(&USAGE);

$DIR    = $opt_d || $ARGV[0] || $ENV{'PWD'} || '.';

require "$DIR/config.ph" if -f "$DIR/config.ph";

$EDITOR = $ENV{'EDITOR'} || 'vi';
$PASSWD = "$DIR/etc/passwd";

if ($opt_p) {
    $FILE   = $PASSWD;
}
elsif ($opt_f) {
    $FILE   = "$DIR/$opt_f";
}
else {
    $FILE   = "$DIR/config.ph";
}

&Flock;

system("$EDITOR $FILE");

# &EnCryption($PASSWD);

&Funlock;

exit 0;
##################################################################

sub USAGE
{
q#HELP: vipw.pl [-d $DIR] [-p] [-h] [-f file-to-edit] [$DIR(of ML)]
    vipw.pl is an utility to edit 
	e.g.
	    $DIR/config.ph
	    $DIR/etc/passwd
	    ...

    vipw.pl locked the ML and exec $EDITOR(vi if $EDITOR not defined).
    for edit config.ph(default), passwd(-p) or the given file(-f file).
	
#;
}

sub EnCryption
{
    local($f) = @_;

    print STDERR "Making...\n";
    open(IN,  "< $f")     || die("Cannot open $f");
    open(OUT, "> $f.new") || die("Cannot open $f.new");

    while(<IN>) {
	($who, $p) = split;

	# local($salt) = ($uja =~ /^(\S\S)/ && $1);
	# $passwd      = crypt($passwd, $salt);
    }
    close IN;
    close OUT;

    print STDERR "Done.\n";
}

# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    open(LOCK, $SPOOL_DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}

sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}

1;
