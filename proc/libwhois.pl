# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


&use('utils');


# WHOIS INTERFACE using local var/log/whoisdb
# return the answer
sub WhoisSearch
{
    local($r, @r, %r, $pat, $host, $all);
    local(*e, *Fld) = @_;

    shift @Fld; shift @Fld;
    while (@Fld) {
	$_ = shift @Fld;
	/^\-h/o && ($host = shift @Fld) && next;
	/^\-a/o && ($all = 1) && next;
	$pat .= $pat ? "|$_" : $_;
    }

    &Whois'Import; #';

    if ($host) {
	&Ipc2Whois(*e, *Fld, *host, *pat);#';
    }
    elsif ($all) {
	&Whois'ShowAllEntry(*e, *r); #';
    }
    else {
	&Whois'Search(*pat, *r); #';
	&Mesg(*e, $r);
    }
}


# WHOIS INTERFACE using local var/log/whoisdb
# return the answer
sub WhoisWrite
{
    local(*e) = @_;
    local($encount, $i);

    &use('MIME') if $USE_MIME;
    &Whois'Import; #';

    $i = 0;
    for (split(/\n/, $e{'tmp:mailbody'})) {
	$i++;

	# skip until "iam" command line number
	next if $i <= $e{'tmp:line_number'};

	$e{'whois:buf'} .= "$_\n";
	$encount++;

	print STDERR "WHOIS>$_\n"  if $debug_whois && $encount;
    }

    if (! $encount) {	# encount == 1 if the body has "iam".
	&Mesg(*e, "   Hmm.. your self-introduction is not in it, isn't it?");
	&Mesg(*e, "   FML removes your entry.");
	$e{'Whois:addr:remove'} = $From_address;
	# return;
    }

    &Whois'Write(*e); #';
}


sub WhoisList
{
    local(*e) = @_;

    &use('MIME') if $USE_MIME;
    &Whois'Import; #';    
    &Whois'List(*e); #';
}


# WHOIS INTERFACE using IPC
# return the answer
sub Ipc2Whois
{
    local(*e, *Fld, *host, *req) = @_;
    local(@ipc, $r, @r, %r);

    # IPC
    $ipc{'host'}   = $host || $DEFAULT_WHOIS_SERVER || 'localhost';
    $ipc{'pat'}    = $STRUCT_SOCKADDR;
    $ipc{'serve'}  = 'whois';
    $ipc{'proto'}  = 'tcp';

    &Log("whois -h $host [$req]");

    ### JCODE and Socket
    &SocketInit;

    if ($WHOIS_JCODE_P) {
	require 'jcode.pl';
	eval "&jcode'init;";
	&jcode'convert(*req, 'euc'); #'(trick) -> EUC

	# After code-conversion!
	# '#' is a trick for inetd
	@ipc = ("$req\n\n");
	&ipc(*ipc, *r);

	&jcode'convert(*r, 'jis'); #'(trick) -> JIS
    }
    else {
	@ipc = ("$req\n\n");
	&ipc(*ipc, *r);
    }

    &Mesg(*e, "Whois -h $host $req $ML_FN");
    &Mesg(*e, $r);
}


##### WHOIS SPACE #####

package Whois;

$Separator = "\n\.\n\n";
$Counter   = 0;

@Import = (DEFAULT_WHOIS_SERVER, ML_FN, 
	   WHOIS_DB, WHOIS_HELP_FILE, 
	   DEBUG, 'debug', DIR, VARLOG_DIR
	   );

@ImportProc = ('Debug', 'Log', 'DecodeMimeStrings', LogWEnv, Touch, Mesg, AddressMatch);


sub Import
{ 
    %Whois'Envelope  = %main'Envelope;

    sub Whois'eval { &main'eval(@_);}

    for (@Import) { eval("\$Whois'$_ = \$main'$_;");}
    for (@ImportProc) { eval("sub Whois'$_ { &main'$_(\@_);};");}

    $DEFAULT_WHOIS_SERVER = $DEFAULT_WHOIS_SERVER || 'localhost';
    $WHOIS_DB             = $WHOIS_DB             || "$FP_VARLOG_DIR/whoisdb";
    $WHOIS_HELP_FILE      = $WHOIS_HELP_FILE      || "$DIR/etc/help.whois";

    # if no var/log/whoisdb
    &Touch($WHOIS_DB) if ! -f $WHOIS_DB;
}


sub Write { &Append(@_);}
sub Append
{
    local(*e) = @_;
    local($s) = $e{'whois:buf'} || $e{'Body'};

    &BackupDB(*e) || do {
	&Log("cannot backup \$WHOIS_DB, stop", return 0);
	&Mesg(*e, "Cannot reset Whois Database of $ML_FN\n");
    };

    if ($addr = $e{'Whois:addr:remove'}) {
	&Log("whois: addr=$addr append return");
	return;
    }


    # open $WHOIS_DB
    open(F, ">> $WHOIS_DB") || (&Log("Cannot open $WHOIS_DB"), return 0);
    select(F); $| = 1; select(STDOUT);

    print F "$e{'h:From:'}\n\n";
    &Mesg(*e, "Your data is registered");
    &Mesg(*e, "in the ML($ML_FN) whois database as following:\n");
    &Mesg(*e, "$e{'h:From:'}\n");

    # ^. -> ..
    foreach (split(/\n/, $s)) {
	s/^\./\.\./;
	print F "$_\n";
	&Mesg(*e, "$_");
    }

    print F $Separator;     # ATTENTION! $/ = $Separator = ".\n\n";
    close(F);

    &Mesg(*e, "\n");
    &Mesg(*e, "--End of the submitted entry\n");

    1;
}


sub Help
{
    local($r);
    open(F, $WHOIS_HELP_FILE) && ($r = <F>) && close(F);
    $r || "whois [-h host] pattern\n";
}


sub Search
{
    local(*pat, *r) = @_;
    local($from, $match_entry);
    $match_entry = 0;

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || do {
	&Log("Cannot open $WHOIS_DB"); 
	$r = "Cannot open the Whois Database\n"; 
	return 0;
    };

    # SEPARATOR CHANGE; *** AFTER return value ***
    local($sep_org) = $/;
    $/ = $Separator;

    # CODE IS NOT OPTIMIZED for security reasons
    while (<F>) {
	next if /^\s*$/;

	($from) = split(/\n\n/, $_);

	if (/$pat/) {# ($from =~ /$pat/) matches only Address space
	    $match_entry++;

	    /(\S+\@\S+)/ && ($addr = $1);
	    $addr        || /^(.*)\n/ && ($addr = $1);
	    s/$Separator$//g;

	    undef $r{$addr};	# delete if matched entry exists;
	    foreach (split(/\n/, $_)) {
		s/^\.\./\./;
		$r{$addr} .= "$_\n";
	    }

	} 
    }
    close(F);

    # SEPARATOR RESET
    $/ = $sep_org;

    if ($match_entry == 0) {
	$r .= "\n\tNO MATCHED ENTRY\n";	
	&Log("Whois::Search no matches /$pat/");
    }
    else {
	while (($k, $v) = each %r) { 
	    $Counter++;
	    $r .= ('*' x 30)."\nMatched Entry[$Counter]> $k\n\n$v\n";
	}
	&Log("Whois::Search $Counter matched for /$pat/");
    }
}


sub AllocAllEntry
{
    local(*e, *r) = @_;

    # SEPARATOR CHANGE;
    local($sep_org) = $/;
    $/ = $Separator;

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);

    # CODE IS NOT OPTIMIZED for security reasons
    while (<F>) {
	next if /^\s*$/;

	($from) = split(/\n\n/, $_);
	($from =~ /(\S+\@\S+)/) && ($addr = $1);
	$addr = &main'Conv2mailbox($1, *e); #';

	$addr        || /^(.*)\n/ && ($addr = $1);
	s/$Separator$//g;
	$r{$addr} = $_;
    }
    close(F);

    # SEPARATOR RESET
    $/ = $sep_org;
}


sub ShowAllEntry
{
    local(*e, *r) = @_; #';

    &AllocAllEntry(*e, *r);
    while (($k, $v) = each %r) { 
	$Counter++;
	$r .= ('*' x 30)."\nMatched Entry[$Counter]> $k\n\n$v\n";
    }

    &Mesg(*e, $r);
}


sub List
{
    local($r, @r, %r);
    local(*e) = @_;

    &AllocAllEntry(*e, *r);

    &Mesg(*e, "Entry List submitted to Whois Database of $ML_FN\n");
    foreach (keys %r) { &Mesg(*e, "$_") if $_;}
}


sub BackupDB
{
    local($r, @r, %r, $addr);
    local(*e) = @_;

    &AllocAllEntry(*e, *r);

    $Now = $main'Now;#';

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);
    select(F); $| = 1; select(STDOUT);

    # backup
    open(BAK, "> $WHOIS_DB.bak") || 
	(&Log("Cannot open $WHOIS_DB.bak"), return 0);
    select(BAK); $| = 1; select(STDOUT);
    print BAK "----- Backup on $Now -----\n";
    while (<F>) { print BAK $_;}
    close(BAK);

    # set the present entries
    open(NEW, "> $WHOIS_DB") || (&Log("Cannot open $WHOIS_DB"), return 0);
    select(NEW); $| = 1; select(STDOUT);

    $addr = $e{'Whois:addr:remove'};

    while (($k, $v) = each %r) {
	if (&AddressMatch($addr, $k)) {
	    &Log("whois: remove $k entry");
	    next;
	}

	print NEW $v;
	print NEW $Separator;
    }

    close(NEW);
 
    &Log("Whois::BackupDB succeeds");
    1;
}


1;
