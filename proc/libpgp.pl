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

    if ($e{'Body'} = ~ /^[\s\n]*$/) {
	&Log("PGPGoodSignatureP Error: no effective mailbody");
	return $auth;
    }
    if (! -x $PGP) {
	&Log("PGPGoodSignatureP Error: \$PGP NOT DEFINED");
	return $auth;
    }

    require 'open2.pl';

    # 2>&1 is required to detect "Good signature"
    &open2(RPGP, WPGP, "$PGP -f 2>&1") || die("$!");
    print WPGP "\n";
    print WPGP $e{'Body'};
    print WPGP "\n";
    close(WPGP);

    while (<RPGP>) {
	$auth = 1 if /Good\s+signature/;
	print STDERR "PGP OUT:$_" if $debug;
    }

    $auth;
}


1;
