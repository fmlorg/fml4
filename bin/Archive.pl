#!/usr/local/bin/perl

$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

chop ($PWD = `pwd`);


require 'getopts.pl';
&Getopts("dhu:A:");

$opt_h && die(&Usage);

$debug       = $opt_d;
$UNIT        = $opt_u || 100;
$ARCHIVE_DIR = "var/archive";
$DIR         = $PWD;

# FIX
$SPOOL_DIR   = "spool";

# eval config.ph (do the force of eval by "do")
if (-f "./config.ph")  { do "./config.ph";}
if (-f $SEQUENCE_FILE) { chop ($MAX_SEQ = `cat $SEQUENCE_FILE`);}

# CLO
unshift(@ARCHIVE_DIR, $opt_A) if $opt_A;

# Preliminary
$i = 1;
$LIMIT = $ARGV[0] || ($UNIT * int ($MAX_SEQ / $UNIT )) || 1000;


# MESSAGE
&Mesg( "Try archive 1 .. $LIMIT by the unit 100");
&Mesg( "DEBUG MODE, DO NOTHING ACTUALLY\nHere is $PWD") if $debug;

# ARCHIVE DIR CHECK
&Mesg( "\$ARCHIVE_DIR\t$ARCHIVE_DIR") if $debug;
&Mesg( "\@ARCHIVE_DIR\t@ARCHIVE_DIR") if $debug;

$ARCHIVE_DIR = @ARCHIVE_DIR ? (shift @ARCHIVE_DIR) : $ARCHIVE_DIR;

&Mesg( "\$ARCHIVE_DIR\t$ARCHIVE_DIR") if $debug;


local($dir) = ".";
foreach (split(/\//, $ARCHIVE_DIR)) {
    next if /^\s*$/;
    $dir .= "/$_";
    -d $dir || do { mkdir($dir, 0700);}
}


while ($i * $UNIT  <= $LIMIT) {
    $counter = 0;
    undef $files;
    $LOWER = $UNIT * ($i - 1) + 1;
    $UPPER = $UNIT * ($i);
    $TAR  =  $UNIT * ($i);
    $i++;
    
    foreach ($LOWER .. $UPPER) {
	if( -f "$SPOOL_DIR/$_") {
	    $files .= "$SPOOL_DIR/$_ "; 
	    $counter++;
	}
    }

    if ($counter > 0) {
	if (-f "$ARCHIVE_DIR/$TAR.tar.gz") {
	    &Mesg( "Exists $ARCHIVE_DIR/$TAR.tar.gz, SO SKIPPED");
	    next;
	}
	else {
	    &Mesg("tar cvf - $files |gzip > $ARCHIVE_DIR/$TAR.tar.gz");
	    system "tar cvf - $files |gzip > $ARCHIVE_DIR/$TAR.tar.gz"; 
	}
    }

}

exit 0;

sub Usage
{
    $0 =~ s#.*/##;
    $_ = qq#;
    $0 [-d] [-h] [unit];

    $0 archives \$SPOOL_DIR in this directory;
    in evaluating ./config.ph.;
    If exists, evaluate and use \$ARCHIV_DIR, \@ARCHIV_DIR and \$SEQUENCE_FILE;

    unit (default 100);

  option:;
    -d debug mode(do nothing actually);
    -h this help;
#;

    s/;//g;
    $_;
}

sub Mesg
{
    local($s) = @_;
    print STDERR "$s\n";
}

1;
