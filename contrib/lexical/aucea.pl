#!/usr/local/bin/perl
#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");


&AuceaInterface'DoAucea(*Envelope); #';


package AuceaInterface;

sub DoAucea
{
    local(*e) = @_;

    $Aucea'debug = $debug = 0; #';

    $AUCEA_CF              = $main'AUCEA_CF;
    $AUCEA_SYSCALL_LIBRARY = $main'AUCEA_SYSCALL_LIBRARY;

    &Init;

    # Set %CF
    &ReadCF; 

    # Set %Buf
    if ($0 eq __FILE__) {
	&GetDataFromFile;
    }
    else {
	&GetDataFromEnvelope(*e);
    }

    # Analize;
    &Analize(*e);

    ##### REPORT #####
    if ($0 eq __FILE__) {
	for (Error, Warn, Report, Trace) {
	    print "\n--- $_ ---\n";
	    print $Result{$_};
	    print "\n";
	}
    }
    else {
	for (Error, Warn, Report, Trace) {
	    $e{'message'} .= "\n--- $_ ---\n";
	    $e{'message'} .= $Result{$_};
	    $e{'message'} .= "\n";
	}
    }
}

### Libraries ###


sub Analize 
{ 
    local(*e) = @_;

    &Aucea'Aucea(*e, *Buf, *CF, *Result);#';
}

sub Usage
{
    local($usage);
    $usage = qq#;
    aucea.pl [-h] [-l library] [-f cf] file;
    ;
    \t-h\tthis help;
    \t-l\tAUCEA_SYSCALL_LIBRARY;
    \t-f\tAUCEA_CF;
    ;\n#;

    $usage =~ s/;//g;
    $usage;
}

sub Init
{
    $| = 1;

    require 'getopts.pl';
    &Getopts("f:hl:d");

    if ($opt_h) { print &Usage; exit 0;};

    $Aucea'debug  = $debug = $opt_d;
    $AuceaLibrary = $opt_l || $AUCEA_SYSCALL_LIBRARY || "libAuceaSyscall.pl";

    require 'libAuceaCF.pl';
    require 'libAucea.pl';

    package Syscall;    
    require $AuceaInterface'AuceaLibrary;#';
    package main;
}

sub ReadCF
{
    local($file) = $opt_f || $AUCEA_CF;

    ### Convert Ccnfig Entries to One Lined;
    # &PrintSep if $debug;
    &CF'Onelined(*CFBuffer, *file); #';

    # print $CFBuffer if $debug;

    ###  
    # &PrintSep if $debug;
    &CF'SetEachDataType(*CFBuffer, *CF);#';
}

sub GetDataFromFile
{
    ###  GET BUFFER FROM ...;
    &GetBuffer(*Buf);		# set data as $Buffer

    ### Set %Buf (key=datatype value=buffer-of-the-datatype);
    # &PrintSep if $debug;
    &CF'GetEachDataBuffer(*Buf, *CF);#';
}

sub GetDataFromEnvelope
{
    local(*e) = @_;

    $Buf = $e{'Body'};#';

    ### Set %Buf (key=datatype value=buffer-of-the-datatype);
    &CF'GetEachDataBuffer(*Buf, *CF);#';
}

sub GetBuffer 
{ 
    local(*Buf) = @_; 
    while (<>) { $Buf .= $_;}
}

# for debug info;
sub PrintSep 
{
    local($sep) = @_; 
    $sep = $sep ? $sep : '-';
    print $sep x60, "\n";
}

1;
