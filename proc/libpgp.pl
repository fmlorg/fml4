# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

local(%PGP);

sub LoadPGPConfig
{
    my ($path, $opt) = @_;

    # PGP2 definition
    if ($PGP_VERSION == 2 || (!$PGP_VERSION)) {
	%PGP = (
		"pgp -kv"     => "$path/pgp $opt -kv",      # view key
		"pgp -f -ka"  => "$path/pgp $opt -f -ka",   # addkey

		"pgp -f"      => "$path/pgp $opt -f",       # -f: stdout
		"pgp -o"      => "$path/pgp $opt -o",       # -o out

		"pgp -f -sea" => "$path/pgp $opt -f -sea",  # sign/encrypt
		);

    }
    # PGP5 definition
    elsif ($PGP_VERSION == 5) {
	$opt .= " +NoBatchInvalidKeys=0 +batchmode=1 +ArmorLines=0";
	%PGP = (
		"pgp -kv"     => "$path/pgpk $opt -l",       # view key
		"pgp -f -ka"  => "$path/pgpk $opt -a",       # addkey

		"pgp -f"      => "$path/pgpv $opt -f",       # -f: stdout
		"pgp -o"      => "$path/pgpv $opt -o",       # -o out

		"pgpv"        => "$path/pgpv $opt",          # -o out
		"pgpe"        => "$path/pgpe $opt",          # -o out
		"pgps"        => "$path/pgps $opt",          # -o out
		"pgpk"        => "$path/pgpk $opt",          # -o out

		"pgp -f -sea" => "$path/pgpe $opt -f -s -a", # sign/encrypt
		);
    }
}


sub PGPGoodSignatureP
{
    local(*e, $no_reply) = @_;
    local($auth) = 0;

    &Log("PGPGoodSignatureP") if $debug || $debug_pgp;

    &_PGPInit(*e) || return 0;

    # 2>&1 is required to detect "Good signature"
    require 'open2.pl';
    &Log("pgp input size=". length($e{'Body'})) if $debug_pgp;
    &Log("run $PGP{'pgp -f'} 2>&1") if $debug || $debug_pgp;
    &open2(RPGP, WPGP, "$PGP{'pgp -f'} 2>&1") || &Log("PGP: $!");
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $e{'Body'};
    close(WPGP);

    &Log("pgp input size=". length($e{'Body'})) if $debug_pgp;
    &Log("<RPGP>") if $debug_pgp;
    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/i;
	chop;
	print STDERR "PGP OUT:", $_, "\n" if $debug;
	&Log("PGP OUT:$_") if $debug || $debug_pgp;
    }
    close(RPGP);

    if ($debug_pgp) {
	&Log("open2() end");
	&Log($auth ? "PGP: Good signature." : "PGP: No good signature.");
    }

    # PGP authenticated
    if (! $no_reply) {
	&Mesg(*e, $auth ? "PGP: Good signature." : "PGP: No good signature.");
	&Mesg(*e, $NULL, 'pgp.incorrect_signature') unless $auth;
    }

    &Log("ERROR: PGP no good signature.") unless $auth;

    $auth;
}


sub PGPDecodeAndEncode
{
    local(*e) = @_;

    &Log("PGPDecodeAndEncode sets in") if $debug || $debug_pgp;
    &PGPDecode(*e, 1);

    # buffer replacement
    $e{'OriginalBody'} = $e{'Body'};
    $e{'Body'}         = $e{'pgp:encbuf'};
}


# PGP Decoding
# We set a decrypted mail body in $Envelope{'pgp:buf'}.
sub PGPDecode
{
    local(*e, $encode) = @_;
    local($buf, $pgp_buf);

    # separator
    local($bs, $es);
    $bs = '-----BEGIN PGP MESSAGE-----';
    $es = '-----END PGP MESSAGE-----';

    &_PGPInit(*e) || return 0;

    # check each line and PGP Blocks
    my ($c) = 0;
    for (split(/\n/, $e{'Body'})) {
	if (/^$bs/ .. /^$es/) {
	    $pgp_buf .= $_."\n";
	}
	else {
	    $e{'pgp:buf'}    .= $_."\n";
	    $e{'pgp:encbuf'} .= $_."\n";
	}

	# pgp decode
	if (/^$es/) {
	    $c++;
	    if (! $pgp_buf) {
		&Log("Error: PGPDecode: empty PGP block");
	    }

	    my ($buf) = &DoPGPDecode($pgp_buf);
	    undef $pgp_buf; # reset buffer

	    $e{'pgp:buf'}    .= $buf;
	    $e{'pgp:encbuf'} .= &DoPGPEncode($buf) if $encode;
	}
    }

    if ($c == 0) {
	&Log("Error: PGPDecode: cannot find PGP block(s) to decode");
    } 
}

# using the temporary file.
# so this should be only applied to clear-singed text.
sub PGPDecode2
{
    local($buf) = @_;
    my($auth, $dcbuf);
    my($tmpf) = "$FP_TMP_DIR/pgp$$";

    &Log("PGPDecode2 sets in") if $debug || $debug_pgp;

    # load open2
    require 'open2.pl';

    # PGP Signature Check
    &Log("run $PGP{'pgp -f'} 2>&1") if $debug || $debug_pgp;
    &Log("pgp input size=". length($buf)) if $debug_pgp;
    &open2(RPGP, WPGP, "$PGP{'pgp -f'} 2>&1") || &Log("PGPDecode2: $!");
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $buf;
    close(WPGP);

    $auth = 0;
    while (<RPGP>) { $auth = 1 if /Good\s+signature/i;}
    close(RPGP);

    if (! $auth) {
	&Log("Error: PGPDecode2: cannot find good PGP signature");
    }

    # 2>&1 is required to detect "Good signature"
    &Log("run $PGP{'pgp -o'} $tmpf") if $debug || $debug_pgp;
    &Log("pgp input size=". length($buf)) if $debug_pgp;
    open(WPGP, "|$PGP{'pgp -o'} $tmpf")||&Log("PGPDecode2: $!");
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $buf;
    close(WPGP);

    open(RPGP, $tmpf) || &Log("PGPDecodeAndSave: cannot open $tmpf");
    while (<RPGP>) {
	$dcbuf .= $_;
	print STDERR "PGP (decode and save) OUT:$_" if $debug;
    }
    close(RPGP);

    unlink $tmpf || &Log("PGPDecode2: cannot unlink $tmpf");;

    &Log("ERROR: PGP no good signature.") unless $auth;

    $dcbuf;
}


sub DoPGPDecode
{
    local($buf) = @_;
    local($auth, $dcbuf);

    &Log("DoPGPDecode sets in") if $debug || $debug_pgp;

    # load open2
    require 'open2.pl';

    # PGP Signature Check
    &Log("run $PGP{'pgp -f'} 2>&1") if $debug || $debug_pgp;
    &open2(RPGP, WPGP, "$PGP{'pgp -f'} 2>&1") || &Log("PGPDecode: $!");
    &Log("pgp input size=". length($buf)) if $debug_pgp;
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $buf;
    close(WPGP);

    $auth = 0;
    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/i;
    }
    close(RPGP);

    if (! $auth) {
	&Log("Error: DoPGPDecode: cannot find good PGP signature");
    }

    # 2>&1 is required to detect "Good signature"
    &Log("run $PGP{'pgp -f'} 2>/dev/null") if $debug || $debug_pgp;
    &Log("pgp input size=". length($buf)) if $debug_pgp;
    &open2(RPGP, WPGP, "$PGP{'pgp -f'} 2>/dev/null")||&Log("PGPDecode: $!");
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $buf;
    close(WPGP);

    while (<RPGP>) {
	$dcbuf .= $_;
	print STDERR "PGP OUT:$_" if $debug;
    }
    close(RPGP);

    &Log("ERROR: PGP no good signature.") unless $auth;
    &Log("ERROR: decoded buffer is empty") unless $dcbuf;

    $dcbuf;
}


# real PGP encoding engine
sub DoPGPEncode
{
    local($buf) = @_;
    local($whom, $encbuf);
    local($tmpbuf) = "$FP_TMP_DIR/pgp:tmpbuf";

    my ($bs, $es);
    $bs = '-----BEGIN PGP MESSAGE-----';
    $es = '-----END PGP MESSAGE-----';

    if (! $buf) { 
	&Log("PGPEncode: empty input");
	return;
    }

    &Log("DoPGPEncode sets in ") if $debug || $debug_pgp;

    &_PGPInit(*e) || return 0;

    # pgp scan to find myself, 
    # so PLEASE ATTENTION "DO NOT SEND IT TO MYSELF";
    $count = &_PGPScan(*e, *whom) || 0;

    &Log("scan PGP keyrings: $count keys found");

    # 2>&1 is required to detect "Good signature"
    require 'open2.pl';
    if ($PGP_VERSION == 5) {
	&Log("run $PGP{'pgpe'} $whom -fsa") if $debug || $debug_pgp;
	&open2(RPGP, WPGP, "$PGP{'pgpe'} $whom -fsa 2>&1") ||
	    &Log("PGPEncode: $!");
    }
    else {
	&Log("run $PGP{'pgp -f -sea'} $whom 2>$tmpbuf") if $debug || $debug_pgp;
	&open2(RPGP, WPGP, "$PGP{'pgp -f -sea'} $whom 2>$tmpbuf") || 
	    &Log("PGPEncode: $!");
    }
    &Log("pgp input size=". length($buf)) if $debug_pgp;
    select(WPGP); $| = 1; select(STDOUT);
    print WPGP $buf;
    close(WPGP);

    # gobble encrypted data from stdout
    if ($PGP_VERSION == 2) {
	my ($found) = 0;
	while (<RPGP>) {
	    $found = 1 if /$bs/;
	    $encbuf .= $_ if $found;
	    $found = 0 if /$es/;
	}

	# error buffer
	if (-s $tmpbuf) {
	    open(EPGP, $tmpbuf) || &Log("PGPEncode: $!");
	    while (<EPGP>) { 
		$found = 1 if /$bs/;
		$e{'pgp:errbuf'} .= $_;
		$encbuf .= $_ if $found;
		$found = 0 if /$es/;
	    }
	    close(EPGP);
	}
	else {
	    &Log("empty error buffer") if $debug_pgp;
	}
    }
    elsif ($PGP_VERSION == 5) {
	my ($found) = 0;
	while (<RPGP>) {
	    $found = 1 if /$bs/;
	    $encbuf          .= $_ if $found;
	    $e{'pgp:errbuf'} .= $_ unless $found;
	    $found = 0 if /$es/;
	}
    }

    unlink $tmpbuf;

    close(RPGP); # XXX close open2()
    &Log("ERROR: encoded buffer is empty") unless $encbuf;

    $encbuf;
}


# PGPEncode: PGP encoding engine
# PGPDecode set $Envelope{'pgp:buf'} as a decrypted mail body.
# PGPEncode assumes it, encode it and rewrite $Envelope{'Body'};
sub PGPEncode
{
    local(*e) = @_;

    ### replacement
    # buffer replacement
    $e{'OriginalBody'} = $e{'Body'};
    $e{'Body'}         = &DoPGPEncode($e{'pgp:buf'});
}


sub _PGPScan
{
    local(*e, *whom) = @_;
    local($count, $in);

    &Log("_PGPScan sets in") if $debug || $debug_pgp;

    # 2>&1 is required to detect "Good signature"
    &Log("run $PGP{'pgp -kv'} 2>&1|") if $debug || $debug_pgp;
    if ($PGP_VERSION == 5) {
	open(RPGP, "$PGP{'pgp -kv'} |") || &Log("PGP: $!");
    }
    else {
	open(RPGP, "$PGP{'pgp -kv'} 2>&1|") || &Log("PGP: $!");
    }

    while (<RPGP>) {
	$in = 1 if m#Type\s+Bits/KeyID\s+Date\s+User ID#;
	$in = 1 if m#Type\s+Bits\s+KeyID\s+Created#;

	if ($in && /([a-z0-9]\S+\@[-a-z0-9\.]+)/i) {
	    if ($PGP_VERSION == 5) {
		$whom .= " -r $1 ";
	    }
	    else {
		$whom .= " $1 ";
	    }
	    $count++;
	}

	print STDERR "PGP SCAN:$_" if $debug || $debug_pgp;
    }
    close(RPGP);

    $count;
}


sub _PGPUserExistP
{
    local(*e, $user) = @_;
    local($count, $in);

    # 2>&1 is required to detect "Good signature"
    open(RPGP, "$PGP{'pgp -kv'} 2>&1|") || &Log("PGP: $!");
    while (<RPGP>) {
	$in = 1 if m#Type\s+Bits/KeyID\s+Date\s+User ID#;

	if ($in && /([a-z0-9]\S+\@[-a-z0-9\.]+)/i) {
	    return 1 if $user eq $1;
	}
    }
    close(RPGP);

    &Log("PGP: no such user $user");

    0;
}


sub _PGPEncryptedMailBodyP
{
    local(*e) = @_;
    $e{'Body'} =~ /\-\-\-\-\-BEGIN PGP MESSAGE\-\-\-\-\-/ ? 1 : 0;
}


sub _PGPInit
{
    local(*e) = @_;
    my ($path);

    $PGP_VERSION = 2 unless $PGP_VERSION;

    if ($e{'Body'} =~  /^[\s\n]*$/) {
	&Log("ERROR: PGPInit: no effective mailbody");
	&Mesg(*e, "Mail Body has no PGP Signature", 'pgp.no_signature');
	return 0;
    }

    # program exeistence check
    # default pgp2 anyway (2000/06/01 by fukachan)
    if ($PGP_VERSION == 2) {
	if (! $PGP) {
	    &Log("ERROR: PGPInit: program \$PGP is not defined");
	    &Mesg(*e, "ERROR: verify PGP environment", 'pgp.env.error');
	    $PGPError = 'pgp program not defiend';
	    return 0;
	}
	elsif (&DiagPrograms('PGP')) {
	    ; # O.K.
	}
	else {
	    &Log("ERROR: PGPInit: \$PGP is not found");
	    &Mesg(*e, "ERROR: verify PGP environment", 'pgp.env.error');
	    $PGPError = 'pgp program not found';
	    return 0;
	}

	$path = $PGP;
	$path =~ s@/[^/]+$@@;
    }
    elsif ($PGP_VERSION == 5) {
	my $prog;
	for $prog ($PGPE, $PGPS, $PGPV, $PGPK) {
	    if (! $prog) {
		&Log("ERROR: PGPInit: a program of pgp5 is not defined");
		&Mesg(*e, "ERROR: verify PGP environment", 'pgp.env.error');
		$PGPError = 'pgp program not defiend';
		return 0;
	    }
	    elsif (-x $prog) {
	    	; # O.K.
	    }
	    else {
		&Log("ERROR: PGPInit: \$PGP is not found");
		&Mesg(*e, "ERROR: verify PGP environment", 'pgp.env.error');
		$PGPError = 'pgp program not found';
		return 0;
	    }
	}	

	$path = $PGPK;
	$path =~ s@/[^/]+$@@;
    }
    elsif ($PGP_VERSION == 6) {
	&Log("PGP 6 is not implemented");
    }
    else {
	$PGPError = 'unknown pgp version';
	return;
    }

    $ENV{'PGPPATH'} = $PGP_PATH;

    # Set Language for easy analize by fml.
    &LoadPGPConfig($path, "+Language=en");

    1;
}


##### Administrator Commands 
# defualt / backward compatible
sub PGP
{
    &PGP2(@_);
}

sub PGP2
{
    local($proc, *Fld, *e, *opt) = @_; 
    local($cmd, @argv);

    if ($Fld =~ /pgp\s+(.*)/) {
	($cmd, @argv) = split(/\s+/, $1);
    } 

    &Log("$proc $cmd @argv");

    &_PGPInit(*e) || return 0;

    ### switch
    if ($cmd eq '-ka') {
	require 'open2.pl';
	&open2(RPGP, WPGP, "$PGP{'pgp -f'} -ka") || 
	    &Log("PGP: $!");
	select(WPGP); $| = 1; select(STDOUT);
	print WPGP $e{'Body'};
	close(WPGP);

	while (<RPGP>) {
	    chop;
	    s/^(Key ring:).*/$1 \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/;
	    &Mesg(*e, $_);
	}
	close(RPGP);
    }
    elsif ($cmd eq '-kr' || $cmd eq '-krs') {
	if (&_PGPUserExistP($argv[0])) {
	    &Do_PGP2(*e, "$PGP $cmd $argv[0]");
	}
	else {
	    &Log("ERROR: no such user found");
	    &Mesg(*e, "ERROR: no such user found");
	    &Mesg(*e, $NULL, 'no_such_member');
	}
    }
    elsif ($cmd eq '-h'   || 
	   $cmd eq '-kx'  || 
	   $cmd eq '-kxa' ||
	   $cmd eq '-kv'  || 
	   $cmd eq '-kvv' || 
	   $cmd eq '-kvc' ||
	   $cmd eq '-kc') {
	&Do_PGP2(*e, "$PGP -a -f $cmd");
    }
    elsif ($cmd eq '-ks' || 
	   $cmd eq '-ke' ||
	   $cmd eq '-kg' ) {
	&Log("\"pgp $cmd @argv\" disabled by FML");
	my($s);
	$s .= "\"pgp $cmd @argv\" disabled by FML\n";
	$s .= "Please \"pgp $cmd @argv\" on this host NOT by mail.";
	&Mesg(*e, $s, 'pgp.cmd.disabled');
    }
    else {
	&Log("doing \"pgp $cmd @argv\" not supported by FML");
	&Mesg(*e, "doing \"pgp $cmd @argv\" not supported by FML", 
	      'pgp.cmd.not_supported');
    }

}


sub Do_PGP2
{
    local(*e, $command) = @_;

    if (open(RPGP, "$command 2>&1|")) {
	while (<RPGP>) {
	    chop;
	    s/^(Key ring:).*/$1 \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/;
	    &Mesg(*e, $_);
	}
	close(RPGP);
    }
    else {
	&Log("PGP::Error exec $command", $!);
	0;
    }
}


1;
