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
#

sub __ExecNewProcess
{
    local($s);
    $0 = "$FML: Run New Process <$LOCKFILE>";

    $FML_EXIT_PROG .= $_cf{'hook', 'prog'};

    if ($s = $FML_EXIT_PROG) {
	print STDERR "\nmain::exec $s\n\n" if $debug;
	$0 = "$FML: Run Hooks(prog) <$LOCKFILE>";
	exec $s || do { &Log("cannot exec $s");}
    }
}

sub __SpawnProcess
{
    local($p) = @_;
    $0 = "$FML: Spawn Process <$LOCKFILE>";

    $p =~ s/^\s*\|\s*//;

    if (open(PROC, "| $p")) {
	select(PROC); $| = 1; select(STDOUT);

	print PROC $Envelope{'Hdr'};
	print PROC "\n";
	print PROC $Envelope{'Body'};

	close(PROC);
    }
    else {
	&Log("cannot execute $p");
    }
}

sub GetPeerInfo
{
    local($family, $port, $addr);
    local($clientaddr);

    $addr = getpeername(STDIN);

    if (! $addr) {
	&Log("cannot getpeername()");
	return;
    }

    ($family, $port, $addr) = unpack($STRUCT_SOCKADDR, $addr);
    ($clientaddr) = gethostbyaddr($addr, 2);

    if (! defined($clientaddr)) {
	$clientaddr = sprintf("%d.%d.%d.%d", unpack('C4', $addr));
    }
    $PeerAddr = $clientaddr;
}


sub EmulRFC2369
{
    if ($Envelope{'mode:stranger'}) {
	&DefineDefaultField("List-Subscribe", 
			    "<mailto:$addr?body=${trap}subscribe>");
    }
    else {
	&DefineDefaultField("List-Help", 
			    "<mailto:$addr?body=${trap}help>");
	&DefineDefaultField("List-Unsubscribe", 
			    "<mailto:$addr?body=${trap}unsubscribe>");
    }

}


sub DefineDefaultField
{
    local($f) = $_[0];
    $f =~ tr/A-Z/a-z/;

    # not overwrite
    if ($Envelope{"h:$f"}) {
	;
    }
    else {
	&DEFINE_FIELD_FORCED(@_);
	&DEFINE_FIELD_OF_REPORT_MAIL(@_);
    }
}


1;
