#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
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

    if ($debug) {
	&Mesg(*Envelope, "\n---------- sending contents ----------");
	&Mesg(*Envelope, $Envelope{'Body'});
	&Mesg(*Envelope, "---------- sending contents ends ----------");
    }
}



sub InitSendFax
{
    # directory
    $TMP_DIR   = $TMP_DIR || "/tmp";

    # prog
    $FORMATTER = $FORMATTER || "/usr/local/bin/a2ps -nt -ns -nh -p ";
    $SENDFAX   = $SENDFAX   || "/usr/local/bin/sendfax -n -D -R ";
}


sub SendFax
{
    local(*e, $faxnumber, $notify_address) = @_;
    local($tmp) = "$TMP_DIR/faxserv$$";

    if ($faxnumber !~ /^[\+0-9][\-\.\(\)0-9]+$/) {
	$e{'message'} .= "Error: FAX NUMBER SYNTAX ERROR\n";
    }

    if ($notify_address !~ /^([\w\d\-\.]+\@[\w\d\-\.]+)$/) {
	$e{'message'} .= "Error: Email Address SYNTAX ERROR\n";
    }

    $e{'message'} .= 
	"Expanded form:\n$SENDFAX -d $faxnumber -f $notify_address\n";

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
