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

# Options; e.g. English mode is required
local($PgpOpts);

sub PGPGoodSignatureP
{
    local(*e) = @_;
    local($auth) = 0;

    &Log("PGPGoodSignatureP") if $debug;

    &PgpInit(*e) || return 0;

    # 2>&1 is required to detect "Good signature"
    require 'open2.pl';
    &open2(RPGP, WPGP, "$PGP $PgpOpts -f 2>&1") || &Log("PGP: $!");
    print WPGP $e{'Body'};
    close(WPGP);

    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/i;
	print STDERR "PGP OUT:$_" if $debug;
    }
    close(RPGP);

    # PGP authenticated
    &Mesg(*e, $auth ? "PGP: Good signature." : "PGP: No good signature.");

    &Log("Error: PGP no good signature.") unless $auth;

    $auth;
}


sub PGPDecodeAndEncode
{
    local(*e) = @_;
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

    &Log("PGPDecode") if $debug;

    &PgpInit(*e) || return 0;

    # check each line and PGP Blocks
    for (split(/\n/, $e{'Body'})) {
	if (/^$bs/ .. /^$es/) {
	    $pgp_buf .= "$_\n";
	}
	else {
	    $e{'pgp:buf'}    .= "$_\n";
	    $e{'pgp:encbuf'} .= "$_\n";
	}

	# pgp decode
	if (/^$es/) {
	    $_ = &DoPGPDecode($pgp_buf);
	    undef $pgp_buf;
	    $e{'pgp:buf'}    .= $_;
	    $e{'pgp:encbuf'} .= &DoPGPEncode($_) if $encode;
	}
    }
}


sub DoPGPDecode
{
    local($buf) = @_;
    local($auth, $dcbuf);

    # load open2
    require 'open2.pl';

    # PGP Signature Check
    &open2(RPGP, WPGP, "$PGP $PgpOpts -f 2>&1") || &Log("PGPDecode: $!");
    print WPGP $buf;
    close(WPGP);

    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/i;
    }
    close(RPGP);

    # 2>&1 is required to detect "Good signature"
    &open2(RPGP, WPGP, "$PGP $PgpOpts -f 2>/dev/null")||&Log("PGPDecode: $!");
    print WPGP $buf;
    close(WPGP);

    while (<RPGP>) {
	$dcbuf .= $_;
	print STDERR "PGP OUT:$_" if $debug;
    }
    close(RPGP);

    &Log("Error: PGP no good signature.") unless $auth;

    $dcbuf;
}


# real PGP encoding engine
sub DoPGPEncode
{
    local($buf) = @_;
    local($whom, $encbuf);
    local($tmpbuf) = "$FP_TMP_DIR/pgp:tmpbuf";

    &Log("DoPGPEncode") if $debug;

    &PgpInit(*e) || return 0;

    # pgp scan to find myself, 
    # so PLEASE ATTENTION "DO NOT SEND IT TO MYSELF";
    $count = &PgpScan(*e, *whom) || 0;

    &Log("scan PGP keyrings: $count keys found");

    # 2>&1 is required to detect "Good signature"
    require 'open2.pl';
    &open2(RPGP, WPGP, "$PGP $PgpOpts -f -sea $whom 2>$tmpbuf") || 
	&Log("PGPEncode: $!");
    print WPGP $buf;
    close(WPGP);

    while (<RPGP>) { $encbuf .= $_;}
    close(RPGP);

    open(EPGP, $tmpbuf) || &Log("PGPEncode: $!");
    while (<EPGP>) { $e{'pgp:errbuf'} .= $_;}
    close(EPGP);
    unlink $tmpbuf;

    $encbuf;
}


# PGPEncode: PGP encoding engine
# PGPDecode set $Envelope{'pgp:buf'} as a decrypted mail body.
# PGPEncode assumes it, encode it and rewrite $Envelope{'Body'};
sub PGPEncode
{
    local(*e) = @_;

    &Log("PGPEncode") if $debug;

    ### replacement
    # buffer replacement
    $e{'OriginalBody'} = $e{'Body'};
    $e{'Body'}         = &DoPGPEncode($e{'pgp:buf'});
}


sub PgpScan
{
    local(*e, *whom) = @_;
    local($count, $in);

    # 2>&1 is required to detect "Good signature"
    open(RPGP, "$PGP $PgpOpts -kv 2>&1|") || &Log("PGP: $!");
    while (<RPGP>) {
	$in = 1 if m#Type\s+Bits/KeyID\s+Date\s+User ID#;

	if ($in && /<(\S+\@\S+)>/) {
	    $whom .= " $1 ";
	    $count++;
	}
    }
    close(RPGP);

    $count;
}


sub PgpUserExistP
{
    local(*e, $user) = @_;
    local($count, $in);

    # 2>&1 is required to detect "Good signature"
    open(RPGP, "$PGP $PgpOpts -kv 2>&1|") || &Log("PGP: $!");
    while (<RPGP>) {
	$in = 1 if m#Type\s+Bits/KeyID\s+Date\s+User ID#;

	if ($in && /<(\S+\@\S+)>/) {
	    return 1 if $user eq $1;
	}
    }
    close(RPGP);

    0;
}


sub PgpEncryptedMailBodyP
{
    local(*e) = @_;
    $e{'Body'} =~ /\-\-\-\-\-BEGIN PGP MESSAGE\-\-\-\-\-/ ? 1 : 0;
}


sub PgpInit
{
    local(*e) = @_;

    # Set Language for easy analize by fml.
    $PgpOpts = "+Language=en";

    if ($e{'Body'} =~  /^[\s\n]*$/) {
	&Log("PGPGoodSignatureP Error: no effective mailbody");
	&Mesg(*e, "Mail Body has no PGP Signature");
	return 0;
    }

    # program exeistence check
    if (! -x $PGP) {
	&Log("PGPGoodSignatureP Error: program \$PGP is NOT DEFINED");
	&Mesg(*e, "PGP Environment Error");
	return 0;
    }

    $ENV{'PGPPATH'} = $PGP_PATH;

    1;
}


##### Administrator Commands 
sub PGP
{
    local($proc, *Fld, *opt, *e) = @_; 
    local($cmd, @argv);

    if ($Fld =~ /pgp\s+(.*)/) {
	($cmd, @argv) = split(/\s+/, $1);
    } 

    &Log("$proc $cmd @argv");

    &PgpInit(*e) || return 0;

    ### switch
    if ($cmd eq '-ka') {
	require 'open2.pl';
	&open2(RPGP, WPGP, "$PGP $PgpOpts -f -ka") || 
	    &Log("PGP: $!");

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
	if (&PgpUserExistP($argv[0])) {
	    &DoPgp(*e, "$PGP $PgpOpts $cmd $argv[0]");
	}
	else {
	    &Log("Error: such a user does not exist");
	    &Mesg(*e, "Error: such a user does not exist");
	}
    }
    elsif ($cmd eq '-h'   || 
	   $cmd eq '-kx'  || 
	   $cmd eq '-kxa' ||
	   $cmd eq '-kv'  || 
	   $cmd eq '-kvv' || 
	   $cmd eq '-kvc' ||
	   $cmd eq '-kc') {
	&DoPgp(*e, "$PGP $PgpOpts -a -f $cmd");
    }
    elsif ($cmd eq '-ks' || 
	   $cmd eq '-ke' ||
	   $cmd eq '-kg' ) {
	&Log("\"pgp $cmd @argv\" disabled by FML");
	&Mesg(*e, "\"pgp $cmd @argv\" disabled by FML");
	&Mesg(*e, "Please \"pgp $cmd @argv\" on this host NOT by mail.");
    }
    else {
	&Log("doing \"pgp $cmd @argv\" not supported by FML");
	&Mesg(*e, "doing \"pgp $cmd @argv\" not supported by FML");
    }

}


sub DoPgp
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
