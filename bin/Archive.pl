#!/usr/local/bin/perl

####### CONFIG #######

$UNIT = 100;
$ARCHIVE_DIR = "old";
$SPOOL_DIR     = "spool";

####### CONFIG #######

# LIB
require 'getopts.pl';
&Getopts("d");

# Pre
$i = 1;
$LIMIT = $ARGV[0];

# MESSAGE
print STDERR "Try archive 1 .. $LIMIT by unit 100\n";
print STDERR "DEBUG MODE\n" if $opt_d;
print STDERR "$PWD\n" if $opt_d;

#MAIN
if(!-d $ARCHIVE_DIR)     { mkdir($ARCHIVE_DIR,0700);}

while ($i * $UNIT  <= $LIMIT) {
    $counter = 0;
    $files = "";
    $LOWER = $UNIT * ($i - 1) + 1;
    $UPPER = $UNIT * ($i);
    $TAR  =  $UNIT * ($i);
    $i++;
    
    foreach($LOWER..$UPPER) {
	if( -f "$SPOOL_DIR/$_") {
	    $files .= "$SPOOL_DIR/$_ "; 
	    $counter++;
	}
    }

    if($counter > 0) {
	print STDERR "tar cvf - $files |gzip> $ARCHIVE_DIR/$TAR.tar.gz\n";

	if( -f "$ARCHIVE_DIR/$TAR.tar.gz") {
		print STDERR "Exists $ARCHIVE_DIR/$TAR.tar.gz, so Skip\n";
		next;
	}

	if( -f "$ARCHIVE_DIR/$TAR.gz") {
		print STDERR "Exists $ARCHIVE_DIR/$TAR.gz, so Skip\n";
		next;
	}

	system "tar cvf - $files |gzip> $ARCHIVE_DIR/$TAR.tar.gz\n" 
	    unless $opt_d;
    }

}

exit 0;
