# Library of fml.pl 
# Copyright (C) 1995-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


&use('utils');


# WHOIS INTERFACE using local var/log/whoisdb
# return the answer
sub WhoisSearch
{
    local($r, @r, %r, $pat, $host);
    local(*e, *Fld) = @_;

    shift @Fld; shift @Fld;
    while (@Fld) {
	$_ = shift @Fld;
	/^-h/o && ($host = shift @Fld) && next;
	$pat .= $pat ? "|$_" : $_;
    }

    &Whois'Import; #';

    if ($host) {
	&Ipc2Whois(*e, *Fld, *host, *pat);#';
    }
    else {
	&Whois'Search(*pat, *r); #';
	$e{'message'} .= $r;
    }
}


# WHOIS INTERFACE using local var/log/whoisdb
# return the answer
sub WhoisWrite
{
    local(*e) = @_;
    local($encount);

    &use('MIME') if $USE_LIBMIME;
    &Whois'Import; #';
    
    foreach (split(/\n/, $e{'Body'})) {
	/\#\s*iam/i && ($encount++, next);
	$e{'Whois:Body'} .= "$_\n" if $encount;
	print STDERR "W>$_\n" if $encount;
    }
    
    &Whois'Write(*e); #';
}


sub WhoisList
{
    local(*e) = @_;

    &use('MIME') if $USE_LIBMIME;
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
    $ipc{'pat'}    = 'S n a4 x8';
    $ipc{'serve'}  = 'whois';
    $ipc{'proto'}  = 'tcp';

    &Log("whois -h $host: $req");

    ### JCODE and Socket
    &SocketInit;

    require 'jcode.pl';
    eval "&jcode'init;";
    &jcode'convert(*req, 'euc'); #'(trick) -> EUC

    # After code-conversion!
    # '#' is a trick for inetd
    @ipc = ("$req#\n");
    &ipc(*ipc, *r);

    &jcode'convert(*r, 'jis'); #'(trick) -> JIS

    $e{'message'} .= "Whois $host $req $ML_FN\n$r\n";
}


##### WHOIS SPACE #####

package Whois;

$Separator = "\.\n\n";
$Counter   = 0;

@Import = (DEFAULT_WHOIS_SERVER, ML_FN, 
	   WHOIS_DB, WHOIS_HELP_FILE, 
	   DEBUG, debug, DIR, VARLOG_DIR
	   );

@ImportProc = ('Debug', 'Log', 'DecodeMimeStrings', LogWEnv);


sub Import
{ 
    %Whois'Envelope  = %main'Envelope;

    sub Whois'eval { &main'eval(@_);}

    for (@Import) { eval("\$Whois'$_ = \$main'$_;");}
    for (@ImportProc) { eval("sub Whois'$_ { &main'$_(\@_);};");}

    $DEFAULT_WHOIS_SERVER = $DEFAULT_WHOIS_SERVER || 'localhost';
    $WHOIS_DB             = $WHOIS_DB             || "$FP_VARLOG_DIR/whoisdb";
    $WHOIS_HELP_FILE      = $WHOIS_HELP_FILE      || "$DIR/etc/help.whois";
}


sub Write { &Append(@_);}
sub Append
{
    local(*e) = @_;
    local($s) = $e{'Whois:Body'} || $e{'Body'};

    &BackupDB || do {
	&Log("cannot backup \$WHOIS_DB, stop", return 0);
	$e{'message'} .= "Cannot reset Whois Database of $ML_FN\n\n";
    };

    # open $WHOIS_DB
    open(F, ">> $WHOIS_DB") || (&Log("Cannot open $WHOIS_DB"), return 0);
    select(F); $| = 1; select(STDOUT);

    print F "$e{'h:From:'}\n\n";

    # ^. -> ..
    foreach (split(/\n/, $s)) {
	s/^\./\.\./;
	print F "$_\n";
    }

    print F $Separator;     # ATTENTION! $/ = $Separator = ".\n\n";
    close(F);

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

	$addr        || /^(.*)\n/ && ($addr = $1);
	s/$Separator$//g;
	$r{$addr} = $_;
    }
    close(F);

    # SEPARATOR RESET
    $/ = $sep_org;
}


sub List
{
    local($r, @r, %r);
    local(*e) = @_;

    &AllocAllEntry(*e, *r);

    $e{'message'} .= "Entry List submitted to Whois Database of $ML_FN\n\n";
    foreach (keys %r) { $e{'message'} .= "$_\n" if $_;}
}


sub BackupDB
{
    local($r, @r, %r);
    local(*e) = @_;

    &AllocAllEntry(*e, *r);

    $Now = $main'Now;#';
    
    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);
    select(F); $| = 1; select(STDOUT);

    # backup
    open(BAK, ">> $WHOIS_DB.bak") || (&Log("Cannot open $WHOIS_DB.bak"), return 0);
    select(BAK); $| = 1; select(STDOUT);
    print BAK "----- Backup on $Now -----\n";
    while (<F>) {
	print BAK $_;
    }
    close(BAK);

    # set the present entries
    open(NEW, "> $WHOIS_DB") || (&Log("Cannot open $WHOIS_DB.bak"), return 0);
    select(NEW); $| = 1; select(STDOUT);

    while (($k, $v) = each %r) { 
	print NEW $v;
	print NEW $Separator;
    }

    close(NEW);
 
    &Log("Whois::BackupDB succeeds");
    1;
}


1;
