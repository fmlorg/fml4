#!/usr/local/bin/perl
#
# Copyright (C) 1994-1995 sha@harl.hitachi.co.jp
# modified by fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see COPYING)

# Custumize
$NowDir     = "/var/spool/fml";
$SpoolDir   = "$NowDir/spool";
$Summary    = "$NowDir/summary";
$SummaryBak = "$NowDir/summary.bak";

#####
opendir(DIRHANDLE, $SpoolDir) || die("Cannot open $SpoolDir");
@allfiles = grep(!/^\./, readdir(DIRHANDLE));
close DIRHANDLE;
$strfiles = ":" . join(":",@allfiles) . ":";

print STDERR $strfiles,"\n" if $debug;

####
if(rename($Summary, $SummaryBak)) {
    open(FROMSUM,"< $SummaryBak") || die "Can't open \"$SummaryBak\" file.";
    open(TOSUM,"> $Summary")      || die "Can't open \"$Summary\" file.";
}else {
    die("Cannot rename $Summary\n");
}

while (<FROMSUM>){
    next if /^D /;
    $str = $_;
    $str =~ s#\d\d/\d\d/\d\d \d\d:\d\d:\d\d \[(.*):.*\] .*\n$#:$1:#;
    if ( index($strfiles, $str, 0) >= 0 ){ # the file exists
	print TOSUM $_;
	print STDERR $_ if $debug;
    }
    else {                              # the file doesn't exist
	print TOSUM "D $_";
	print STDERR "D $_" if $debug;
    }
}

close TOSUM, FROMSUM;
exit 0;
