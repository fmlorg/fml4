# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$

sub PGPGoodSignatureP
{
    local(*e) = @_;
    local($auth) = 0;

    &Log("PGPGoodSignatureP") if $debug;

    if ($e{'Body'} =~  /^[\s\n]*$/) {
	&Log("PGPGoodSignatureP Error: no effective mailbody");
	&Mesg(*e, "Mail Body has no PGP Signature");
	return $auth;
    }

    # program exeistence check
    if (! -x $PGP) {
	&Log("PGPGoodSignatureP Error: program \$PGP is NOT DEFINED");
	&Mesg(*e, "PGP Environment Error");
	return $auth;
    }

    # English mode is required
    local($pgp_opts) = "+Language=en";

    # 2>&1 is required to detect "Good signature"
    require 'open2.pl';
    &open2(RPGP, WPGP, "$PGP $pgp_opts -f 2>&1") || &Log("PGP: $!");
    print WPGP "\n";
    print WPGP $e{'Body'};
    print WPGP "\n";
    close(WPGP);

    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/i;
	print STDERR "PGP OUT:$_" if $debug;
    }

    # PGP authenticated
    &Mesg(*e, $auth ? "PGP: Good signature." : "PGP: No good signature.");

    $auth;
}


1;
