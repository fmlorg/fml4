#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: gen_summary.pl,v 2.7 2001/11/28 14:13:42 fukachan Exp $
#

$rcsid   = q$Id$;

######################################################################

require 'getopts.pl';
&Getopts("d:f:ht:I:D:vVTHM:L:o:m:B");

eval(' chop ($PWD = `pwd`); ');
$PWD = $ENV{'PWD'} || $PWD || '.'; # '.' is the last resort;)

$opt_h && do { &Usage; exit 0;};
$HTML_INDEX_UNIT = $opt_t || 'day';
$DIR             = $opt_D || $PWD;
$HTTP_DIR        = $opt_d;
$SPOOL_DIR       = shift;
$ConfigFile      = $opt_f;
$verbose         = $opt_v;
$debug           = $opt_V;
$HTML_THREAD     = 1; # $opt_T;
$Minimum         = $opt_M > 0 ? $opt_M : 1;
$LastRange       = $opt_L;
$NoBracket       = $opt_B;

push(@INC, split(/:/,$opt_I));
$EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
push(@INC, $EXEC_DIR) if -d $EXEC_DIR;
push(@INC, $PWD) if -d $PWD;

# gen_summary extension
$USE_MIME        = $opt_m;

# set opt
for (split(/:/, $opt_o)) { 
    print STDERR "\$${_} = 1;\n" if $verbose;
    eval "\$${_} = 1;";
}

########## MAIN ##########
### WARNING;
-d $SPOOL_DIR || die("At least one argument is required for \$SPOOL_DIR\n");


### Libraries
require 'libloadconfig.pl'; &__LoadConfiguration;
require $ConfigFile if -f $ConfigFile;
require 'libkern.pl';

### redefine &Log ...
&FixProc;

### Here we go!
$max = &GetMax($SPOOL_DIR);

### gen_summary hack
&InitGenSummary;

if ($LastRange) {
    $Minimum = $max - $LastRange > 0 ? $max - $LastRange : 1;
}

for ($i = $Minimum; $i <  ($max + 100); $i += 100) {
    print STDERR "fork() [$$] ($i -> ".($i+100).")\n" if $verbose;
    $0 = "gen_summary(Parent): $label::Ctl $i -> ". ($i + 100);

    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	&Ctl($i, $i + 100 < $max ? $i + 100 : $max + 1);
	exit(0);
    }

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }

    sleep 1;
}

exit 0;


##### LIBRARY #####

sub InitGenSummary
{
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    $month = 1;
    for (@Month) { $Month{$_} = $month++;}

    # h:date -> Now 
    # Date: Fri, 28 Mar 97 01:31:00 +0900
    # 97/03/19 12:16:01 [1:fukachan@sappor] 
    # $DatePat = '(?:\w\w\w,\s)?(\d\d)\s(\w\w\w)\s(\d+)\s(\d\d):(\d\d):(\d\d)';
    # 01/11.27 fml-help: 01254
    $DatePat = '(?:\w\w\w,\s)?(\d\d?)\s(\w\w\w)\s(\d+)\s(\d\d):(\d\d):(\d\d)';
}

sub Ctl
{
    local($id) = @_;

    print STDERR "$label::Ctl $_[0] .. $_[1]\n" if $verbose;

    return 0 if $_[0] > $_[1];

    for ($id = $_[0]; $id < $_[1]; $id++ ) {
	print STDERR "$label::Ctl  $id processing...\n" if $verbose;

	next unless -f "$SPOOL_DIR/$id";

	%Envelope = %e = ();

	open(STDIN, "$SPOOL_DIR/$id") || return;

	$0 = "gen_summary: $label $id/($_[0] -> $_[1])";

	&Parse;
	&GetFieldsFromHeader;	# -> %Envelope
	&Fix(*Envelope);
	$0 = "gen_summary: $label $id/($_[0] -> $_[1])";

	$ID = $id;

	########### summary ##########
	# save summary and put log
	$s = $Envelope{'h:subject:'};
	$s =~ s/\n(\s+)/$1/g;

	# from
	$from = &Conv2mailbox($Envelope{'h:from:'}, *e);
	
	# MIME decoding. 
	# If other fields are required to decode, add them here.
	# c.f. RFC1522	2. Syntax of encoded-words
	if ($USE_MIME) { require 'libMIME.pl'; $s = &DecodeMimeStrings($s);}

	# fml-support: 02007
	$s =~ s/^\s*//; # required???

        # fml-help: 01251
        if ($NoBracket){ $s =~ s/\[($BRACKET)*[:,\s]*[\d+]*\]\s+//; }

	# Date -> Now
	# Date: Fri, 28 Mar 1997 01:31:00 +0900
	# $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
	# $year % 100, $mon + 1, $mday, $hour, $min, $sec);
	if ($Envelope{"h:date:"} =~ /$DatePat/) {
	     $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
			    $3 % 100, $Month{$2}, $1, $4, $5, $6);
	}

	printf "%s [%d:%s] %s\n", $Now, $ID, substr($from, 0, 15), $s;
    }
}


sub Fix
{
    local(*e) = @_;

    $From_address        = &Conv2mailbox($e{'h:from:'}, *e);

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) (THIS IS REQUIED ANY TIME, ISN'T IT? but...)
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if ($_ = $e{'h:Subject:'}) {
	#while (s/\s*Re:\s*Re:\s*/Re: /gi) { ;} # $_ == Subject ENSURED here;

	if ($STRIP_BRACKETS || 
	    $SUBJECT_HML_FORM || $SUBJECT_FREE_FORM_REGEXP) {
	    if ($e{'MIME'}) { # against cc:mail ;_;
		&use('MIME'); 
		&StripMIMESubject(*e);
	    }
	    else { # e.g. Subject: [Elena:003] E.. U so ...;
		$e{'h:Subject:'} = &StripBracket($_);
	    }
	} 
    }
}


sub SetTime
{
    local($mtime) = @_;

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, 
			$isdst ? $TZONE_DST : $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);

}


sub Usage
{
    local($s);

    $s = q#;
    gen_summary.pl [-h] [-I INC] [-f config.ph] [-m] SPOOL;
    ;
    -h    this message;
    -f    config.ph;
    -m    use mime conversion;
    -L    the number of Last sequence to process (hence MIN = MAX - $opt_L);
    -B    strip bracket
    ;
    SPOOL $SPOOL_DIR;
    ;#;

    $s =~ s/;//g;

    print "$s\n\n";
}

sub FixProc
{
local($evalstr) = q#;
sub Log  { print STDERR "@_\n";};
sub Mesg { print STDERR "@_\n";};
;#;

eval($evalstr);
}

sub GetMax
{				
    local($dir) = @_;
    local($i, $try, $right, $seq, $p, $sep2);

    # anyway try prescan;
    for ($p = 1; $p < (1 << 16); $p *= 2) { $seq = $p if -f "$dir/$p";}
    $seq *= 2;

    for ($i = 1; ; $i *= 2) { last unless -f "$dir/$i";}

    # e.g. right for expired directry;
    if ($i < $seq) { $i = $seq + 1;}

    # checks sequence file
    if (-f "$dir/../seq") {
	open(SEQ, "$dir/../seq");
	chop($seq2 = <SEQ>);

	print STDERR "if ($seq2 > $seq) { \$seq = $seq2;}\n";

	if ($seq2 > $seq) { $seq = $seq2;}
    }

    $try  = $i;
    $left = int($i/2); 

    do {
	$right = $try;
	$try  = int($try - ($try - $left)/2);
    } while( (! -f "$dir/$try") && ($left < $try));

    for ( ; ; $try++) { last unless -f "$dir/$try";}

    # print STDERR "return ($try - 1)\n" if $verbose;
    ($try - 1);
}


1;
