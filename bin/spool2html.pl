#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0 Exp #: Wed, 29 May 96 19:32:37  JST 1996';

########## MAIN ##########
&InitS2P;

chdir $DIR || &Die("Can't chdir to $DIR");

### redefine &Log ...
&FixProc;

### Here we go!
$max = &GetMax($SPOOL_DIR);

if ($LastRange) {
    $Minimum = $max - $LastRange > 0 ? $max - $LastRange : 1;
}

### TOO OVERHEADED ;_;
$label = $HTML_DIR;
$label =~ s#.+/(\S+)#$1#;



for ($i = $Minimum; $i <  ($max + 100); $i += 100) {
    print STDERR "fork() [$$] ($i -> ".($i+100).")\n" if $verbose;
    $0 = "spool2html(Parent): $label::Ctl $i -> ". ($i + 100);

    # NT4 perl has no fork() system call;
    if ($CPU_TYPE_MANUFACTURER_OS =~ /windowsnt4/ ||
	$ENV{'OS'} =~ /Windows_NT/) {
	&Ctl($i, $i + 100 < $max ? $i + 100 : $max + 1);
	next;
    }

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

    sleep($SleepTime || 3);
}

if ($opt_F) {
    &SyncHtmlExpire($HTML_DIR, $file, *Envelope);
}

exit 0;


##### LIBRARY #####

sub InitS2P
{
    require 'getopts.pl';
    &Getopts("d:f:ht:I:D:vVTHM:L:o:S:E:F");

    $DIR = $opt_D || $ENV{'PWD'};
    $ConfigFile = $opt_f;

    # include search path
    $opt_h && do { &Usage; exit 0;};
    push(@INC, $opt_I);

    local($inc) = $0;
    $inc =~ s#^(\S+)/bin.*$#$1#;
    push(@INC, $inc);

    # set opt
    for (split(/:/, $opt_o)) { 
	print STDERR "\$${_} = 1;\n" if $verbose;
	if (/(\S+)=(\S+)/) {
	    eval "\${$1} = \"$2\";";
	}
	else {
	    eval "\$${_} = 1;";
	}
    }

    require 'libkern.pl';

    # Libraries
    if (!-f "$DIR/config.ph") {
	&Die("I cannot find $DIR/config.ph!\n"
	     ."\t\$DIR = $DIR may be inappropiate.\n"
	     ."\tPlease define -D ML_HOME_DIR.");
    }

    require $ConfigFile if -f $ConfigFile;

    # command line options overwrite variables
    $HTML_INDEX_UNIT = $opt_t || 'day';
    $HTML_DIR        = $opt_d;
    $SPOOL_DIR       = shift @ARGV;
    $verbose         = $opt_v;
    $debug           = $opt_V ? 1 : 0;
    $HTML_THREAD     = 1; # $opt_T;
    $Minimum         = $opt_M > 0 ? $opt_M : 1;
    $LastRange       = $opt_L;
    $SleepTime       = $opt_S || 3;
    $HTML_EXPIRE_LIMIT = $opt_E;

    # WARNING;
    -d $SPOOL_DIR || 
	&Die("At least one argument is required for \$SPOOL_DIR");
    -d $HTML_DIR  || 
	&MkDir($HTML_DIR);
	# &Die("\$HTML_DIR not exists? FYI: -d \$HTML_DIR REQUIRED");

    ########## library loading ##########
    # loading MIME libraries (prefetch)
    if ($USE_MIME) { require 'libMIME.pl';}

    require 'libsynchtml.pl';
}


sub Die
{
    print STDERR "Error: ", $_[0], "\n\n";
    &Usage;
    exit 1;
}


sub Ctl
{
    local($id) = @_;

    print STDERR "$label::Ctl $_[0] .. $_[1]\n" if $verbose;

    return 0 if $_[0] > $_[1];

    for ($id = $_[0]; $id < $_[1]; $id++ ) {
	print STDERR "${label}::Ctl  $id processing...\n" if $verbose;

	# expired ? 
	next unless -f "$SPOOL_DIR/$id";

	# tricky
	$e{'stat:mtime'} = $mtime = (stat("$SPOOL_DIR/$id"))[9];
	next if &SyncHtmlProbeOnly($HTML_DIR, $id, *e);

	%Envelope = %e = ();

	open(STDIN, "$SPOOL_DIR/$id") || return;

	$0 = "spool2html: $label $id/($_[0] -> $_[1])";

	&SetTime($mtime);
	&Parse;	# close(STDIN) here
	&GetFieldsFromHeader;	# -> %Envelope
	&Fix(*Envelope);

	# emulate Hdr key in &Distribute (for %FieldHash)
	$Envelope{'Hdr'} = $Envelope{'Header'};

	$0 = "spool2html: $label $id/($_[0] -> $_[1])";

	$ID = $id;

	# since undef %e above;
	$Envelope{'stat:mtime'} = (stat("$SPOOL_DIR/$id"))[9]; 
	&SyncHtml($HTML_DIR, $id, *Envelope);

	# &dumpvar('SyncHtml') if $verbose;

	close(STDIN);
    }

    # tricky 
    if (%RequireReGenerateIndex) {
	&SyncHtmlReGenerateIndex($HTML_DIR, $id, *Envelope);
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
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime($mtime))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);

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

    $s = q#Usage: spool2html.pl [-hvV] [-D DIR]
                  [-I INC] [-f config.ph] [-d HTML_DIR]
                  [-M minimum] [-S SLEEP_TIME]
                  [-E limit] [-t type]
                  [-t TYPE] SPOOL;
    ;
    -D    $DIR (ML HOME DIRECTORY)
    ;
    -h    this message;
    -v    verbose;
    -V    debug mode on;
    -d    $HTML_DIR;
    -f    config.ph;
    -t    number of day ($HTML_INDEX_UNIT);
    -M    Minimum (MIN, default 1);
    -L    the number of Last sequence to process (hence MIN = MAX - $opt_L);
    ;
    SPOOL $SPOOL_DIR;
    ;#;

    $s =~ s/;//g;
    $s =~ s/\s*$//;
    print "$s\n";
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

	if ($seq2 > $seq) { $seq = $seq2;}
    }

    $try  = $i;
    $left = int($i/2); 

    do {
	$right = $try;
	$try  = int($try - ($try - $left)/2);
    } while( (! -f "$dir/$try") && ($left < $try));


    ### search
    if ($try) { # continuous 1 .. $seq
	for ( ; ; $try++) { last unless -f "$dir/$try";}
    }
    else { # not continuous ? .. $seq
	$try = $seq;
    }

    # print STDERR "return ($try - 1)\n" if $verbose;
    ($try - 1);
}


# dummy functions agasint the compile errors of config.ph
sub DEFINE_SUBJECT_TAG { 1;}
sub DEFINE_MODE  { 1;}
sub DEFINE_FIELD_FORCED  { 1;}
sub DEFINE_FIELD_ORIGINAL { 1;}
sub DEFINE_FIELD_OF_REPORT_MAIL  { 1;}
sub ADD_FIELD     { 1;}
sub DELETE_FIELD  { 1;}
sub COPY_FIELD  { 1;}
sub MOVE_FIELD  { 1;}

# debug
sub PS { $FML = 'spool2html'; system "ps uw|grep spool2html";}

1;
