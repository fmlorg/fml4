#-*- perl -*-
# Copyright (C) 1993-1999,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libkernsubr2.pl,v 2.10 2001/09/24 12:44:41 fukachan Exp $
#

use vars qw($debug $PeerAddr);
use vars qw($MIME_CONVERT_WHOLEMAIL); # for debug. see doc/Japanese/internals/


sub __ExecNewProcess
{
    my ($s);

    if ($s = $FML_EXIT_PROG) {
	print STDERR "\nmain::exec $s\n\n" if $debug;
	$0 = "${FML}: Run Hooks(prog) <$MyProcessInfo>";
	exec $s || do { &Log("cannot exec $s");}
    }
}

sub __SpawnProcess
{
    my ($p) = @_;
    $0 = "${FML}: Spawn Process <$MyProcessInfo>";

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
    my ($family, $port, $addr);

    unless (defined ($addr = getpeername(STDIN))) {
	&Log("cannot getpeername()");
	return '';
    }

    ($family, $port, $addr) = unpack($STRUCT_SOCKADDR, $addr);
    my ($clientaddr) = gethostbyaddr($addr, 2);

    unless (defined($clientaddr)) {
	$clientaddr = sprintf("%d.%d.%d.%d", unpack('C4', $addr));
    }
    $PeerAddr = $clientaddr;
}


sub EmulRFC2369
{
    my ($args) = @_;
    my $addr  = $args->{ 'addr' };
    my $trap  = $args->{ 'trap' };
    my $rcsid = $args->{ 'rcsid' };

    if ($Envelope{'mode:stranger'} && $PERMIT_POST_FROM ne 'anyone') {
	my $subscribe = $LIST_SUBSCRIBE ||
		"<mailto:$addr?body=${trap}subscribe>";
	&DefineDefaultField("List-Subscribe", $subscribe);
    }
    else {
	my ($software, $post, $owner, $help, $unsubscribe);
	my $id = $MAIL_LIST; $id =~ s/\@/./g;

	$id       = $LIST_ID       || $id;
	$software = $LIST_SOFTWARE || $rcsid;
	$post     = $LIST_POST     || "<mailto:$MAIL_LIST>";
	$owner    = $LIST_OWNER    || "<mailto:$MAINTAINER>";
	$help     = $LIST_HELP     || "<mailto:$CONTROL_ADDRESS?body=help>";
	$unsubscribe = $LIST_UNSUBSCRIBE ||
	    "<mailto:$CONTROL_ADDRESS?body=unsubscribe>";

	&DefineDefaultField("List-ID",          $id);
	&DefineDefaultField("List-Software",    $software);
	&DefineDefaultField("List-Post",        $post);
	&DefineDefaultField("List-Owner",       $owner);
	&DefineDefaultField("List-Help",        $help);
	&DefineDefaultField("List-Unsubscribe", $unsubscribe);
    }

}


sub DefineDefaultField
{
    my ($f) = $_[0];
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


###
### KernSubr::Sectoin: Message (obsolete functions)
###

sub __WholeMail
{
    $_ = "\n";

    if ($MIME_CONVERT_WHOLEMAIL) { 
	&use('MIME'); 
	$_ .= &DecodeMimeStrings($Envelope{'Header'});
    }

    $_ .= "\n".$Envelope{'Header'}."\n".$Envelope{'Body'};
    s/\n/\n   /g; # against ">From ";
    
    my $title = $Envelope{"tmp:ws"} || "Original mail as follows";
    "\n$title:\n$_\n";
}


sub __ForwMail
{
    my ($s) = $Envelope{'Header'};
    $s =~ s/^From\s+.*\n//;

    $_  = "\n------- Forwarded Message\n\n";
    $_ .= $s."\n".$Envelope{'Body'};
    $_ .= "\n\n------- End of Forwarded Message\n";

    $_;
}


1;
