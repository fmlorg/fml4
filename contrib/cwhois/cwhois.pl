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
# q$Id$;
$Rcsid   = 'fml 2.1 Experimental';

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

# RETURN HELP FOR "help#" or NULL;
if ($Key =~ /^help${CHMODE}$/oi || (! $Key) ) {
    &Usage;
}
# O.K. Here we go!
else {
    # RUN-HOOKS START HOOK;
    &eval($CWHOIS_START_HOOK, "CWHOIS_START_HOOK");

    if ($USE_CWHOIS_FIRST_CACHE && &CWhoisProbeFirstCache($Key)) {
	&CWhoisSearch(*e, $WHOIS_SERVER, "fcache${CHMODE}${Key}");
    }
    else {
	&CWhoisSearch(*e, $WHOIS_SERVER, $Key) unless $FirstCacheHit;

	# WHEN whois -h server host, append the help of this server
	if ($Key =~ /^help$/i) { print ("\#" x 60); print "\n"; &Usage;}

	# RUN-HOOKS EXIT HOOK
	&eval($CWHOIS_EXIT_HOOK, 'CWHOIS_EXIT_HOOK');
    }
}

exit 0;

##### libexec/whois.pl Libraries
sub CWhoisInit
{
    # default;
    $CHMODE = '#';
    $Set  = '';
    $Mode = 'help';
    $MATCH_THE_LATEST = 1; # show the latest target

    # first cache
    $FIRST_CACHE_DB      = "/var/tmp/cwhois_first_cachedb";
    $FIRST_CACHE_SPOOL   = "/var/tmp";
    $FIRST_CACHE_EXPIRE  = 3600;
    $FIRST_CACHE_TIMEOUT = 5;

    if (-f "$DIR/config.ph") {
	require "$DIR/config.ph";
    }
    else {
	die "Please define \DIR/config.ph (configuration file)\n";
    }

    &GetKey;

    # including libraries
    require 'libkern.pl';		# only subroutines from fml.pl
    require 'libsmtp.pl';
    require 'libwhois.pl';

    &InitConfig;		# the sames as fml.pl;

    &eval('&GetPeerInfo;');	# alternative for From:

    # Variables
    $WHOIS_SERVER = $WHOIS_SERVER || $DEFAULT_WHOIS_SERVER;
    $From_address = $PeerAddr     || $From_address;
    undef $PeerAddr;
}

# <STDIN> -> Key
sub GetKey
{
    local($pat, $key);

    # via /usr/sbin/inetd
    # Generate the key 
    $Key = <STDIN>; 
    chop $Key; 
    chop $Key;

    # securiy check
    local($skey) = $Key;
    $skey =~ s#(\w)/(\w)#$1$2#g;
    if ($skey !~ /^[\#\s\w\-\[\]\?\*\.\,\@\:]+$/) {
	die("YOUR REQUEST IS INSECURE, SO EXIT IMMEDIATELY\n\n");
    }

    # Fixing Key
    $Key =~ s/^\s*(.*)\s*$/$1/;
}


# Caching (spooling) function
# Derived From fml.pl::Distribute()" Distribute mail to members"
sub CWhoisCacheOn
{
    local(*e) = @_;

    $0 = "--Caching $Key <$FML $LOCKFILE>";
    local($status, $num_rcpt, $s, @Rcpt, $id);

    &Flock;			# LOCK!

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

    &CWhoisFirstCacheOn;

    &Funlock;			# UNLOCK!
}


# System call called by SIGARLM
sub CWhoisTimeOut
{
    &Log("Caught(SIGALRM)");

    eval shutdown(S, 2);
    &Log($@) if $@;

    &CWhoisSearch(*e, $WHOIS_SERVER, "${CHMODE}${Key}");
}


# Master Search algorithm classifier
sub CWhoisSearch
{
    local($r, @r, %r, $pat, $all, %db, %spool, $proc, $key);
    local(*e, $host, $pat) = @_;

    if ($pat =~ /^tcp${CHMODE}(\S+)/) { $pat = $1;}

    # first cache
    if ($pat =~ /^fcache${CHMODE}(\S+)$/) { 
	&CWhoisFirstCacheSearch($1);
    }
    # both "proc\#key" and "opt1#opt2#proc#key" are available
    # and "fcache#key" is the first cache search
    elsif ($pat =~ /^(.*)$CHMODE(\S+)$/) { 
	$proc = $1;
	$key  = $2;

	print "CACHE SEARCHING key=$key opt=$proc ... \n\n";
	&CWhoisCacheSearch(*key, *proc, 
			   *CWHOIS_CACHE_DB, *CWHOIS_CACHE_SPOOL);
    }
    # 43/TCP
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

	&eval($CWHOIS_TCP_EXIT_HOOK, "CWHOIS_TCP_EXIT_HOOK:");
	
	&CWhoisCacheOn(*e); # both first and second cache on;
    }

    # special information for the first cache
    if ($proc ne 'local') { $TcpConnectionOK = 1;}
}


# we should determine the mode since 
# the format is "options#key "
# and "opt1#opt2#proc#key" is also available
#      $proc          $key part
#
sub CWhoisCacheSearch
{
    local($set, $k);
    local(*key, *proc, *db, *spool) = @_;
    
    # Define ($set == Database-name) (subset in all the set)
    # %KeySetClass
    # AddressSet -> /\d+\.\d+.../ 
    # domain and host differs but "last" call ends it
    # before the difference detected
    $k = $key;
    $k =~ s/.*$CHMODE//; #extract key from opt#key FORM
    while (($class, $pat) = each %KeySetClass) {
	# print "$k =~ /^($pat)\$/\n";
	$k =~ /^($pat)$/i && ($keyclass = $class);
    }


    # extract options or sets declarations if exists;
    foreach (split(/\#/, $proc)) { # local is a trick
	print "Parsed Key Opt[$_](\$key=$key)\n" if $debug;

	# NOT request of specific ML? e.g. --KEY=apply 
	$spool{$_} && ($set = $_);

	/^fcache/         && ($set = 'fcache', next);
	/^debug/i         && ($debug++, next);
	/^history/i       && (undef $MATCH_THE_LATEST, next);
	/^all/i           && (undef $MATCH_THE_LATEST, next);
	/^(rev|reverse)/i && ($CWhoisOpt{'order:reverse'} = 1, next);
	/^(normal|historical)/i && ($CWhoisOpt{'order:historical'} = 1, next);
    }


    # which subset we should do search?
    # KEY Class "is the second match"
    # e.g.
    # UJA.ORG    -> domain class 
    # ip#UJA.ORG -> all the ip data search (explicitly defined case)
    # 
    $set = $set || $keyclass || $CWHOIS_DEFAULT_SET || 'local';

    print "CacheSearch key=$key set=$set\n" if $debug;

    &Log("CacheSearch key=$key set=$set");

    eval($CWHOIS_CACHE_SEARCH_HOOK) if $CWHOIS_CACHE_SEARCH_HOOK;
    &Log($@) if $@;

    ### SHOULD BE PREPARED INDEPENDENTLY FROM THE WHOIS SERVER
    if ($CWHOIS_SEARCH_PROG) { 
	require $CWHOIS_SEARCH_PROG;
	&ScanDB(*key, *set, *db, *spool, *misc);
    }
    else {
	print "\n\$CWHOIS_SEARCH_PROG NOT DEFINED.\nCANNOT LOCAL SCAN\n\n";
    }

    &Log($@) if $@;
    print $@ if $@; # whois reply including logs > STDOUT
}

sub Usage { -f $CWHOIS_HELP_FILE ? &Cat($CWHOIS_HELP_FILE) : &CWhoisUsage;}

sub CWhoisUsage
{
    local($rcsid) = $Rcsid;
    $rcsid =~ s/fml/Caching whois server \#fml/;

    local(@db) = keys %CWHOIS_CACHE_DB;

    $s = qq!;
    Caching Whois Server HELP (FOR YOUR HELP);
    ;
    % whois -h $FQDN key;
    ;
    e.g.;
    whois -h $FQDN key;
    whois -h $FQDN opt1#opt2#key;
    ;
    Default:; query to $WHOIS_SERVER with the "key"
	if the request fails, search "key" in the local cache;
    ;
    [available commands]
    ;
    help    help from whois.nic.ad.jp;
    help#   help from this server;
    ;
    key       "key" is a keyword you would like to ask;
    local#key local search for the "key";
    #key      local search for the "key";
    opt#key   local search with "opt";
    ;
    available opt are as follows:;
    [available specifc ML Databases];
    @db
    ;
    [other "opt"];
    ;
    all          show all the cached data for the "key";
    local        local search mode (NOT FROM $WHOIS_SERVER);
    debug        debug mode on;
    rev          in the reverse histrical order;
    reverse      in the reverse histrical order;
    normal       in the histrical order;
    historical   in the histrical order;
    ;
    ;
    $Rcsid;
    Copyright (C) 1993-1996 fukachan\@phys.titech.ac.jp;
    Copyright (C) 1996-1997 fukachan\@sapporo.iij.ad.jp;
    fml is free software distributed under the terms of the GNU General;
    Public License. see the file COPYING for more details.;
    ;
    If you find a bug, please send it to fml-bugs\@ffs.fml.org;
!;

    $s =~ s/;//g;
    print "$s\n";
}

sub CWhoisCacheGiveUp
{
    print "I've been able to Cache On. Give up it.\n";
}


##### FIRST CACHE #####
#
# Caching Spool is the same as the local cache
# BUT 
# the use of the first cache is determined by WITHIN the LATEST LIMIT OR NOT

# Cache on using the present time
sub CWhoisFirstCacheOn
{
    local($now)  = time;
    &Append2("UT${now}:", $FIRST_CACHE_DB);
    &Append2("$ID: $Key ", $FIRST_CACHE_DB);
}


sub CWhoisProbeFirstCache
{
    local($k) = @_;
    local($now)       = time - $FIRST_CACHE_EXPIRE;
    local($cache_hit) = 0;
    local($ok);

    return 0 if $k =~ /^tcp${CHMODE}/; # tcp#keyword is an exception;

    open(DB, $FIRST_CACHE_DB) || return;
    while (<DB>) {
	chop;

	if (/UT(\d+):/) {
	    next if $ok;
	    $ok = 1 if $1 > $now;
	}

	next unless $ok;

	if (/\s$k\s/i) { $cache_hit = 1; last;}
    }
    close(DB);

    $cache_hit;
}


sub CWhoisFirstCacheSearch
{
    local(%db, %spool, $proc);
    local($key) = @_;

    print "\n[$Key] HIT IN THE FIRST CACHE (within $FIRST_CACHE_EXPIRE sec.)\n";
    print "   TRY \"tcp#$Key\" to query $WHOIS_SERVER DIRECTLY NOW.\n\n";

    $key    = " $key ";
    %db     = ('fcache', $FIRST_CACHE_DB);
    %spool  = ('fcache', $FIRST_CACHE_SPOOL);
    $proc   = "fcache";

    &CWhoisCacheSearch(*key, *proc, *db, *spool);
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

# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $LOCK_SH                       = 1;
    $LOCK_EX                       = 2;
    $LOCK_NB                       = 4;
    $LOCK_UN                       = 8;

    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    $SIG{'ALRM'} = 'CWhoisCacheGiveUp';

    eval alarm(10); # cache writing timeout
    open(LOCK, $DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}

sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}

1;
