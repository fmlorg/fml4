#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$


### Import: fml.pl
$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0 Internal #: Wed, 29 May 96 19:32:37  JST 1996';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

##### MAIN #####
if ($0 eq __FILE__) {
    &ScanARGV;
    &ScanDB(*key, *proc, *WHOIS_CACHE_DB, *WHOIS_CACHE_SPOOL);
    exit 0;
}

###### MAIN ENDS #####


sub ScanARGV
{
    for (@ARGV) {
	if (/^\-\-local/)      { $CWhoisOpt{'db:local'} = 1; next;}
	if (/^\-\-reverse/)    { $CWhoisOpt{'order:reverse'} = 1; next;}
	if (/^\-\-historical/) { $CWhoisOpt{'order:historical'} = 1; next;}

	if (/^(\S+)=(\S+)/) {
	    $KEY   = $1;
	    $VALUE = $2;
	    if ($KEY eq 'KEY') { $key = $VALUE;}
	    if ($KEY =~ m#^/#) { 
		$Cache{$VALUE} = $DIR;
	    }
	}
    }
}


# %cache 
#      KEY_DB => KEY_SPOOL
#
# DB FILE is "\d+: KEYWORDS", \d+ is the article number of spool
#
# SYNTAX
#   KEY   = key1:key2:...
#   SPOOL = spool1:spool2:...
#     are available
#
# return *entry
sub ScanDBSetEntry
{
    local(*entry, *key, *proc, *db, *spool) = @_;
    local($spool, $db, @s, @d);
 
    @d = split(/:/, $db{$proc});
    @s = split(/:/, $spool{$proc});

    do {
	$spool = shift @s;
	$db    = shift @d;

	print "open(F, $db);\n" if $debug;

	open(F, $db) || (print "Cannot ScanDB::open($db)\n" , next);
	while (<F>) { 
	    if (/^(\d+):.*$key.*/i) {
		push(@entry, "$spool/$1") if -f "$spool/$1";
		print "push(\@entry, $spool/$1);\n" if $debug;
	    }
	}
	close(F);
    }
    while (@d && @s);
}


sub ScanDB
{
    local(*key, *proc, *db, *spool, *misc) = @_;
    local(@entry);

    # set *entry
    &ScanDBSetEntry(*entry, *key, *proc, *db, *spool);

    # sort by date @entry
    @entry = sort bydate @entry;
    $count = scalar(@entry);

    if (@entry) {
	print "\n\n";
	print "*" x 55, "\n";

	if (! $CWhoisOpt{'db:reverse'}) {
	    print "*****  ATTENTION!! CACHE YIELDS THESE DATA!       *****\n";
	    print "*****  PLEASE VERIFY THE LATEST INFORMATION, TOO  *****\n";
	}

	print "\n       matched file";
	print ($count > 1 ? "s are $count" : " is 1") . ".\n";

	if ($CWhoisOpt{'order:reverse'}) {
	    print "       listed in the reverse historical order\n";
	    print "       (the latest file is the first below).\n";

	}
	elsif ($CWhoisOpt{'order:historical'}) {
	    print "       listed in the historical order.\n";
	}

	print "\n\n";
	# print "*" x 50, "\n";	print "*" x 50, "\n";

	foreach (@entry) {
	    &GetTime($_);
	    print "*" x 55, "\nFILE:$_\nTIME:$MailDate\n\n";
	    &BodyCat($_);
	}
    }
    else {
	print "NOTHING HAS BEEN MATCHED\n";
    }
}


sub GetTime
{
    local($f) = @_;

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = 
	(localtime((stat($f))[9]))[0..6];
	
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);
}


sub bydate { (stat($b))[9] <=> (stat($a))[9];}


sub BodyCat
{
    local($file) = @_;
    open(IN,  $file) || (&Log("Cat($file) $!"), return);
    while (<IN>) { if (1 .. /^$/) { ;} else { print STDOUT $_;}}
    close(IN); 
}


### Import: fml-current/cf/config 
sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};

    foreach $dir (split(/:/, $path)) { 
	if (-f "$dir/$f") { return "$dir/$f";}
    }

    "";
}

### Import: fml.pl
# Getopt
sub Opt { push(@SetOpts, @_);}
    
# Setting CommandLineOptions after include config.ph
sub ScanDBSetOpts
{
    for (@SetOpts) { 
	/^\-\-MLADDR=(\S+)/i && (&use("mladdr"), &MLAddr($1));
	/^\-\-([a-z0-9]+)$/  && (&use("modedef"), &ModeDef($1));
    }

    for (@SetOpts) {
	if (/^\-\-(force|fh):(\S+)=(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"fh:$h:"} = $3;
	}
	elsif (/^\-\-(original|org|oh):(\S+)/) { # "foreced header";
	    $h = $2; $h =~ tr/A-Z/a-z/; $Envelope{"oh:$h:"} = 1;
	}
	elsif (/^\-\-(\S+)=(\S+)/) {
	    eval("\$$1 = '$2';"); next;
	}
	elsif (/^\-\-(\S+)/) {
	    local($_) = $1;
	    /^[a-z0-9]+$/ ? ($Envelope{"mode:$_"} = 1) : eval("\$$_ = 1;"); 
	    /^permit:([a-z0-9:]+)$/ && ($Permit{$1} = 1); # set %Permit;
	    next;
	}

	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }
   
}

# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}

sub Log { 
    local(@c) = caller; 
    print STDERR "LOG(@c)>@_\n";
}


1;
