#!/usr/local/bin/perl
#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0L #: Tue, 25 Jun 96 22:10:27 JST 1996';

### Import: fml.pl ###

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
$0 =~ m#(\S+)/(\S+)# && (unshift(@INC, $1)); #for lower task;
unshift(@INC, $DIR); #IMPORTANT @INC ORDER; $DIR, $1(above), $LIBDIR ...;


### Import: fml.pl ENDs ###

########################################################

chdir $DIR || die $!;

&CWhoisInit;
&CWhoisSearch(*e, $WHOIS_SERVER, $Key);

exit 0;

##### libexec/whois.pl Libraries
sub CWhoisInit
{
    $CF = "$DIR/config.ph";

    if (-f $CF) {
	require $CF;
    }
    else {
	##### KEYWORD and Defaults #####
	$HOME               = '/home/beth/fukachan';
	$HIKARI             = '/home/hikari/sapporo/op/tools/whois/bin';
	$HIKARI_VARDB       = '/home/hikari/sapporo/var/db';
	$HIKARI_SPOOL       = '/home/hikari/sapporo/var/mail/apply';
	$CACHE_SEARCH_PROG  = "$HIKARI/scandb.pl";

	%WhoisCacheSpool    = ('apply', $HIKARI_SPOOL);
	%WhoisCacheDB       = ('apply', "$HIKARI_VARDB/applydb");

	$CHMODE             = '#';
	$LOCAL_HELP_KEYWORD = "help$CHMODE";
	$LOCAL_CACHE_SEARCH = "$CHMODE(\\S+)";
	$LOCAL_COMMAND_MODE = "(\\S+)$CHMODE(\\S+)";

	$WHOIS_SERVER       = 'whois.nic.ad.jp';
	$From_address       = 'WHOIS';
	$TIMEOUT            = 5;#20;

	##### KEYWORD and Defaults ENDS #####
    }

    # via /usr/sbin/inetd
    # Generate the key 
    $Key = <STDIN>; 
    chop $Key; 
    chop $Key;

    # Fixing Key
    $Key =~ s/^\s*(.*)\s*$/$1/;

    if ($Key =~ /^$LOCAL_HELP_KEYWORD$/oi || (! $Key) ) { 
	&Cat($HELP_FILE) if $HELP_FILE;
	print &CWhoisUsage;
	exit 0; 
    }

    # libraries
    require '__fml.pl';
    require 'libsmtp.pl';
    require 'libwhois.pl';

    &InitConfig; # fml.pl;

    &eval('&GetPeerInfo;');

    # Variables
    $WHOIS_SERVER = $WHOIS_SERVER || $WHOIS_SERVER;
    $From_address = $PeerAddr     || $From_address;
    undef $PeerAddr;
}


# Derived From fml.pl::Distribute()" Distribute mail to members"
sub CWhoisCache
{
    local(*e) = @_;

    $0 = "--Caching $Key <$FML $LOCKFILE>";
    local($status, $num_rcpt, $s, @Rcpt, $id);


    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    open(IDINC, $SEQUENCE_FILE) || (&Log($!), return);
    $ID = <IDINC>;		# get
    $ID++;			# increment, GLOBAL!
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    ##### ML Distribute Phase 03: Spooling
    # spooling, check dupulication of ID against e.g. file system full
    # not check the return value, ANYWAY DELIVER IT!
    # IF THE SPOOL IS MIME-DECODED, NOT REWRITE %e, so reset %me <- %e;
    if (! -f "$FP_SPOOL_DIR/$ID") {	# not exist
	&Log("ARTICLE $ID");
	&Write3(*e, "$FP_SPOOL_DIR/$ID");
    } 
    else { # if exist, warning and forward againt DISK-FULL;
	&Log("ARTICLE $ID", "ID[$ID] dupulication");
	&Append2("$e{'Hdr'}\n$e{'Body'}", "$FP_VARLOG_DIR/DUP$CurrentTime");
	&Warn("ERROR:ARTICLE ID dupulication", 
	      "Try save > $FP_VARLOG_DIR/DUP$CurrentTime\n$e{'Hdr'}\n$e{'Body'}");
    }
}


sub CWhoisTimeOut
{
    &Log("Caught(SIGALRM)");

    eval shutdown(S, 2);
    &Log($@) if $@;

    &CWhoisSearch(*e, $WHOIS_SERVER, "${CHMODE}${Key}");
}


sub CWhoisSearch
{
    local($r, @r, %r, $pat, $all);
    local(*e, $host, $pat) = @_;

    # we ask only in English!
    $WHOIS_JCODE_P = 0;

    if ($pat =~ /^$LOCAL_CACHE_SEARCH$/) {
	$key = $1;
	print "CACHE SEARCHING key=$key ... \n\n";
	&CWhoisCacheSearch($key);
    }
    elsif ($pat =~ /^$LOCAL_COMMAND_MODE/) { # "proc#key"
	$proc = $1; 
	$key  = $2;
	print "CACHE SEARCHING key=$key (proc=$proc) ... \n\n";
	&CWhoisCacheSearch($key, $proc);
    }
    else {
	# Signal handling WHEN IPC
	$SIG{'ALRM'} = 'CWhoisTimeOut';
	eval alarm($TIMEOUT);
	die($@) if $@;

	&Whois'Import; #';

	&Ipc2Whois(*e, *Fld, *host, *pat);#';

	$e{'Body'} = $e{'message'};
	$e{'Body'} =~ s/\($ML_FN\)//g;
	print "$e{'Body'}\n";
	&CWhoisCache(*e);
    }
}


sub CWhoisCacheSearch
{
    local($key, @proc) = @_;
    local($proc);

    undef $debug;
    undef %Cache; # reset %Cache(global varialbe);

    foreach $proc (@proc) {
	# NOT request of specific ML? e.g. --KEY=apply 
	if (! $WhoisCacheSpool{$proc}) { $proc = $KEY;}

	if ($proc =~ /^debug$/i) { $debug++; next;}
	if ($proc =~ /^(rev|reverse)$/i) { 
	    $REVERSE_ORDER__; next;
	}
	if ($proc =~ /^(normal|historical)$/i) { 
	    $HISTORICAL_ORDER++;
	}

	if ($WhoisCacheSpool{$proc}) {
	    @spool = split(/:/, $WhoisCacheSpool{$proc});
	    @db    = split(/:/, $WhoisCacheDB{$proc});
	    do {
		$spool = shift @spool;
		$db    = shift @db;
		$Cache{$db} = $spool;
		print "\$CacheSpool{$db} $spool\n" if $debug;
	    }
	    while (@db && @spool);
	}
    }

    print "CacheSearch key=$key proc=$proc" if $debug;
    &Log("CacheSearch key=$key proc=$proc");
    eval "require '$CACHE_SEARCH_PROG';";
    &Log($@) if $@;
    print STDERR $@ if $@;
}


sub CWhoisUsage
{
    local($rcsid) = $Rcsid;
    $rcsid =~ s/fml/Caching whois server \#fml/;

    local(@db) = keys %WhoisCacheDB;

    $s = qq!;
    % whois -h WHOIS-SERVER key;
    ;
    e.g.;
    whois -h WHOIS-SERVER key;
    whois -h WHOIS-SERVER opt1#opt2#key;
    ;
    Default:; query to $WHOIS_SERVER with a key
	if the request fails, search key in the local cache;
    ;
    help    help from whois.nic.ad.jp;
    help#   help from this server;
    ;
    key       keyword;
    local#key local search;
    #key      local search;
    opt#key   local search with "opt";
    ;
    e.g. whois -h WHOIS-SERVER opt1#opt2#key
    ;
    [available options];
    ;
    local        local search mode (NOT FROM whois.nic.ad.jp);
    debug        debug mode;
    rev          in the reverse histrical order;
    reverse      in the reverse histrical order;
    normal       in the histrical order;
    historical   in the histrical order;
    ;
    [available specifc ML Databases];
    @db
    ;
    ;
    $rcsid;
    Copyright (C) 1993-1996 fukachan\@phys.titech.ac.jp;
    Copyright (C) 1996      fukachan\@sapporo.iij.ad.jp;
    Please obey GNU Public License;
    If you find a bug, please send it to fml-bugs\@phys.titech.ac.jp;
!;

    $s =~ s/;//g;
    "$s\n";
}



##### Import: fml.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

sub Cat
{
    local($file) = @_;
    open(IN,  $file) || (&Log("Cat($file) $!"), return);
    while (<IN>) { print STDOUT $_;}
    close(IN); 
}

1;
