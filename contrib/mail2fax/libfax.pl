#!/usr/local/bin/perl
#
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


if ($0 eq __FILE__) {
    require 'getopts.pl';
    &Getopts("dr:f:h");

    &InitSendFax;
    &SendFax(*e, $opt_r, $opt_f);
    
    print "$e{'message'}\n" if $e{'message'};

    exit 0;
}
else {
    &InitSendFax;

    $subject = $Envelope{'h:subject:'};
    $address = $Envelope{'Addr2Reply:'};

    $subject =~ s/\s*//g;
    $address =~ s/\s*//g;

    &SendFax(*Envelope, $subject, $address);

    &Mesg(*Envelope, "---------- sending contents ----------");
    &Mesg(*Envelope, $Envelope{'Body'});
    &Mesg(*Envelope, "---------- end of sending contents ---");
}



sub InitSendFax
{
    local($a2ps_opt) = "-a4 -ns -nb -no -nt -j1.2 -p";

    # directory
    $TMP_DIR   = $FP_TMP_DIR || $TMP_DIR || "/tmp";

    # prog
    $FORMATTER = $FORMATTER || "/usr/local/mail2fax/a2ps $a2ps_opt";
    $SENDFAX   = $SENDFAX   || "/usr/local/bin/sendfax -m -n -D -R ";


    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    &Open(IDINC, $SEQUENCE_FILE) || return; # test
    $ID = &GetFirstLineFromFile($SEQUENCE_FILE);
    $ID++;			# increment, GLOBAL!

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    # wait for sync against duplicated ID for slow IO or broken calls
    {
	local($newid, $waitc);
	while (1) {
	    $newid = &GetFirstLineFromFile($SEQUENCE_FILE);
	    last if $newid == $ID;
	    last if $waitc++ > 10;
	    sleep 1;
	}
	&Log("FYI: $waitc secs for SEQUENCE_FILE SYNC") if $waitc > 1;
    }
}


sub SendFax
{
    local(*e, $faxnumber, $notify_address) = @_;
    local($tmp) = "$TMP_DIR/outgoing-$ID.ps";
    local($s);

    $s .= "$faxnumber";
    $s .= " from $notify_address" if $From_address ne $notify_address;

    &Log($s);

    if ($faxnumber !~ /^[\+0-9][\-\.\(\)0-9]+$/) {
	&Log("Syntax Error: faxnumber $faxnumber");
	$e{'message'} .= "Error: FAX NUMBER SYNTAX ERROR\n";
    }

    if ($notify_address !~ /^([\w\d\-\.]+\@[\w\d\-\.]+)$/) {
	&Log("Syntax Error: return address $notify_address");
	$e{'message'} .= "Error: Email Address SYNTAX ERROR\n";
    }

    if ($From_address =~ /fukachan/i) {
	$e{'message'} .= "\nExpanded form:\n\n";
	$e{'message'} .= "   $FORMATTER > $tmp\n\n";
	$e{'message'} .= "   $SENDFAX -d $faxnumber -f $notify_address\n\n";
    }

    # generate postscript tmporary files
    open(TMP, "|$FORMATTER > $tmp") || die($!);
    select(TMP); $| = 1; select(STDOUT);

    if ($e{'Body'}) {
	print TMP $e{'Body'};
    }
    else {
	while (<>) { print TMP $_;}
    }

    close(TMP);

    system "sync;sync;sync";
    sleep 3;

    # sending fax
    open(SENDFAX, "|$SENDFAX -d $faxnumber -f $notify_address") || die($!);
    select(SENDFAX); $| = 1; select(STDOUT);

    open(TMP, $tmp) || die($!);
    while (<TMP>) {
	print SENDFAX $_;
    }
    close(TMP);
    close(SENDFAX);

    unlink $tmp;
}


1;
