#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid   = 'fml 2.0 Exp #: Wed, 29 May 96 19:32:37  JST 1996';

######################################################################

require 'getopts.pl';
&Getopts("d:f:ht:I:D:vTH");


$opt_h && do { &Usage; exit 0;};
$HTML_INDEX_UNIT = $opt_t || 'day';
$DIR             = $opt_D || $ENV{'PWD'};
$HTTP_DIR        = $opt_d;
$SPOOL_DIR       = shift;
$ConfigFile      = $opt_f;
$debug_v         = $opt_v;
$HTML_THREAD     = $opt_T;
$USE_MIME        = $opt_H;
push(@INC, $opt_I);

########## MAIN ##########
### WARNING;
-d $SPOOL_DIR || die("At least one argument is required for \$SPOOL_DIR\n");
-d $HTTP_DIR  || die("-d \$HTTP_DIR REQUIRED\n");

### Libraries
require $ConfigFile if -f $ConfigFile;
require 'libkern.pl';
require 'libsynchtml.pl';
require '_dumpvar.pl' if $opt_v;

sub PS { $FML = 'spool2html'; system "ps uw|grep spool2html";}

### redefine &Log ...
&FixProc;

### Here we go!
$max = &GetMax($SPOOL_DIR);

### TOO OVERHEADED ;_;
$label = $HTTP_DIR;
$label =~ s#.+/(\S+)#$1#;

for ($i = 1; $i <  ($max + 100); $i += 100) {
    print STDERR "fork() [$$] ($i -> ".($i+100).")\n";
    $0 = "spool2html(Parent): $label::Ctl $i -> ". ($i + 100);

    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	&Ctl($i, $i + 100 < $max ? $i + 100 : $max + 1);
	exit(0);
    }

    sleep 3;

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}

exit 0;


##### LIBRARY #####

sub Ctl
{
    local($id);

    print STDERR "$label::Ctl $_[0] .. $_[1]\n";

    for ($id = $_[0]; $id < $_[1]; $id++ ) {
	print STDERR "$label::Ctl  $id processing...\n";

	next unless -f "$SPOOL_DIR/$id";

	# tricky
	$e{'stat:mtime'} = $mtime = (stat("$SPOOL_DIR/$id"))[9];
	next if &SyncHtmlProbeOnly($HTTP_DIR, $id, *e);

	%Envelope = %e = ();

	open(STDIN, "$SPOOL_DIR/$id") || return;

	$0 = "spool2html: $label $_[0] -> $_[1]";

	&SetTime($mtime);
	&Parse;
	&GetFieldsFromHeader;	# -> %Envelope
	&Fix(*Envelope);

	$0 = "spool2html: $label $_[0] -> $_[1]";

	$ID = $id;

	# since undef %e above;
	$Envelope{'stat:mtime'} = (stat("$SPOOL_DIR/$id"))[9]; 
	&SyncHtml($HTTP_DIR, $id, *Envelope);

	&dumpvar('SyncHtml') if $debug_v;
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
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
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

    $s = q#;
    spool2html.pl [-h] [-I INC] [-f config.ph] [-d HTTP_DIR] [-t TYPE] SPOOL;
    ;
    -h    this message;
    -d    $HTTP_DIR;
    -f    config.ph;
    -t    number of day ($HTML_INDEX_UNIT);
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
    local($i, $try, $right);

    for ($i = 1; ; $i *= 2) { last unless -f "$dir/$i";}

    $try  = $i;
    $left = int($i/2); 

    do {
	$right = $try;
	$try  = int($try - ($try - $left)/2);
    } while( (! -f "$dir/$try") && ($left < $try));

    for ( ; ; $try++) { last unless -f "$dir/$try";}

    ($try - 1);
}


1;
