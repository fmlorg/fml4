# Library of fml.pl 
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");


# WHOIS INTERFACE using IPC
# return the answer
sub Whois
{
    local($sharp, $_, @who) = @_;
    local($REQUEST, $h);

    if (! /whois/oi) { 
	&Log($_." is not implemented"); 
	return "Sorry, $_ is not implemented";
    }
 
    # Parsing
    foreach (@who) { 
	/^-h/ && (undef $h, next);
	$h || ($h = $_, next); 
	$REQUEST .= " $_";
    }

    # IPC
    $ipc{'host'}   = ($host || $DEFAULT_WHOIS_SERVER);
    $ipc{'pat'}    = 'S n a4 x8';
    $ipc{'serve'}  = 'whois';
    $ipc{'proto'}  = 'tcp';

    &Log("whois -h $host: $REQUEST");

    # Go!
    require 'jcode.pl';
    &jcode'convert(*REQUEST, 'euc'); #'(trick) -> EUC

    # After code-conversion!
    # '#' is a trick for inetd
    @ipc = ("$REQUEST#\n");
    local($r) = &ipc(*ipc);

    &jcode'convert(*r, 'jis'); #'(trick) -> JIS

    "Whois $host $REQUEST $ML_FN\n$r\n";
}



# WHOIS INTERFACE using local var/log/whoisdb
# return the answer
sub LocalWhois
{
    local(@who) = @_;
    local($req, $h, $r);

    # Parsing
    foreach (@who) { 
	/^-h/ && (undef $h, next);
	$h || ($h = $_, next); 
	$req .= " $_";
    }

    "Whois $host $req $ML_FN\n$r\n";
}



#############################################################
####################### WHOIS LIBRARY #######################
#############################################################
sub WhoisWrite
{
    local($s) = @_;

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);
    print F "$From_address\n$Original_From_address\n$s\n";
    print F "\.\n\n";     # ATTENTION! $/ = ".\n\n";
    close(FILE);

    1;
}


sub WhoisHelp
{
    if (open(F, $WHOIS_HELP_FILE)) {
	$r .= <F>;
	close(F);
    }
    else {
	$r = "whois -h host pattern\n";
    }

    $r;
}


sub WhoisSearch
{
    local($pat, $ALL) = @_;
    local($r, $from);

    # SEPARATOR CHANGE
    local($sep) = $/;
    $/ = ".\n\n";

    # open $WHOIS_DB
    open(F, $WHOIS_DB) || (&Log("Cannot open $WHOIS_DB"), return 0);

    while (<F>) {
	chop;	chop;	chop;

	# GET FIRST ENTRY to avoid the duplication
	($from) = (/^(.*)\n/);
	s/^(.*)\n//;
	$addr{$from} = $_;
    }
    close(F);

    if ($ALL) {
	foreach(keys %addr) { 
	    next if /^\s*$/;

	    $r .= ('*' x60);
	    $r .= "\nEmail address: $_\n---\n";
	    $r .= $addr{$_};
	    $r .= "\n";
	}
    }
    elsif ($pat =~ /\s*help\s*/i) {
	$r .= &WhoisHelp;
    } 
    else {
	# CODE IS NOT OPTIMIZED for security reasons
	foreach(keys %addr) { 
	    next if /^\s*$/;
	    $r .= $addr{$_} if /$pat/;
	}
    }

    # SEPARATOR RESET
    $/ = $sep;

    $r;
}


### DEBUG
if ($0 eq __FILE__) {
    $debug = 1;

    $WHOIS_DB = "/home/axion/fukachan/work/spool/EXP/lib/whois/whoisdb";
    $WHOIS_HELP_FILE = "/home/axion/fukachan/work/spool/EXP/lib/whois/help";

    print STDERR &WhoisSearch(@ARGV);
    print STDERR "\n";
}

1;
