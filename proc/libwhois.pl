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
    local(*r, *pat, *host);
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
    local(@ipc, *r);

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

    $DEFAULT_WHOIS_SERVER = $DEFAULT_WHOIS_SERVER || 'localshot';
    $WHOIS_DB             = $WHOIS_DB             || "$VARLOG_DIR/whoisdb";
    $WHOIS_HELP_FILE      = $WHOIS_HELP_FILE      || "$DIR/etc/help.whois";
}


sub Write { &Append(@_);}
sub Append
{
    local(*e) = @_;

    # open $WHOIS_DB
    open(F, ">> $WHOIS_DB") || (&Log("Cannot open $WHOIS_DB"), return 0);
    print F "$e{'h:From:'}\n\n";
    print F ($e{'Whois:Body'} || $e{'Body'});
    print F $Separator;     # ATTENTION! $/ = $Separator = ".\n\n";
    close(F);

    1;
}


sub Help
{
    local($r);
    open(F, $WHOIS_HELP_FILE) && ($r = <F>) && close(F);
    $r || "whois -h host pattern\n";
}


sub Search
{
    local(*pat, *r) = @_;

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
	next     if /^\s*$/;

	if (/$pat/) {
	    /(\S+\@\S+)/ && ($addr = $1);
	    $addr        || /^(.*)\n/ && ($addr = $1);
	    s/$Separator$//g;

	    $r{$addr} = $_;
	} 
    }
    close(F);

    while (($k, $v) = each %r) { 
	$Counter++;
	$r .= ('*' x 30)."\nMatched Entry[$Counter]> $k\n\n$v\n";
    }

    # SEPARATOR RESET
    $/ = $sep_org;
}


sub List
{
    local(*r);
    local(*e) = @_;

    # SEPARATOR CHANGE;
    local($sep_org) = $/;
    $/ = $Separator;

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);

    # CODE IS NOT OPTIMIZED for security reasons
    while (<F>) {
	next if /^\s*$/;

	/(\S+\@\S+)/ && ($addr = $1);
	$addr        || /^(.*)\n/ && ($addr = $1);
	s/$Separator$//g;
	$r{$addr} = $_;
    }
    close(F);

    # SEPARATOR RESET
    $/ = $sep_org;

    $e{'message'} .= "Entry List submitted to Whois Database of $ML_FN\n\n";
    foreach (keys %r) { $e{'message'} .= "$_\n" if $_;}
}


1;
