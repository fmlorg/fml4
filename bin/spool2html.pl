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
# $FML: spool2html.pl,v 2.20.2.2 2001/07/02 21:53:07 fukachan Exp $
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
    use Getopt::Long;
    Getopt::Long::Configure("bundling");
    GetOptions(qw(overwrite! 
		  h v V T H F
		  d=s f=s t=s I=s D=s M=s L=s o=s S=s E=s));

    eval(' chop ($PWD = `pwd`); ');
    $PWD = $ENV{'PWD'} || $PWD || '.'; # '.' is the last resort;)
    $DIR = $opt_D || $PWD;
    $ConfigFile = $opt_f;

    $EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
    push(@INC, $EXEC_DIR) if -d $EXEC_DIR;
    push(@INC, $PWD) if $PWD && (-d $PWD);

    if (! $ConfigFile) {
	print STDERR "FYI: you must need '-f \$DIR/config.ph' option in usual case\n";
	print STDERR "     but O.K. if you know your own business :)\n";
	print STDERR "     spool2html process continues ...\n\n";
    }

    # include search path
    $opt_h && do { &Usage; exit 0;};
    push(@INC, $opt_I) if -d $opt_I;

    local($inc) = $0;
    $inc =~ s#^(\S+)/bin.*$#$1#;
    push(@INC, $inc);

    # @LIBDIR
    push(@LIBDIR, $opt_I);
    push(@LIBDIR, $inc);

    # import modules/
    for (@INC) {
	if (-d "$_/module") {
	    for my $inc (<$_/module/*>) {
		push(@INC, $inc) if -d $inc;
	    }
	}
    }

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

    require 'libloadconfig.pl'; &__LoadConfiguration;
    require $ConfigFile if -f $ConfigFile;
    
    # command line options overwrite variables
    $HTML_INDEX_UNIT = $opt_t || $HTML_INDEX_UNIT || 'day';
    $HTML_DIR        = $opt_d || $HTML_DIR;
    $SPOOL_DIR       = shift @ARGV;
    $verbose         = $opt_v;
    $debug           = $opt_V ? 1 : 0;
    $HTML_THREAD     = defined $HTML_THREAD ? $HTML_THREAD : 1; # $opt_T;
    $Minimum         = $opt_M > 0 ? $opt_M : 1;
    $LastRange       = $opt_L;
    $SleepTime       = $opt_S || 3;
    $HTML_EXPIRE_LIMIT = $opt_E || $HTML_EXPIRE_LIMIT;

    # WARNING;
    -d $SPOOL_DIR || 
	&Die("At least one argument is required for \$SPOOL_DIR");
    -d $HTML_DIR  || &MkDir($HTML_DIR, 0755); # export as public
	# &Die("\$HTML_DIR not exists? FYI: -d \$HTML_DIR REQUIRED");

    ########## library loading ##########
    # loading MIME libraries (prefetch)
    if ($USE_MIME) { require 'libMIME.pl';}

    if ($verbose) { 
	print STDERR "\n";
	for (@INC) { print STDERR "INCLUDE: $_\n";}
    }

    if ($verbose) { 
	print STDERR "\n";
	local($x);
	for $x ('DEFAULT_HTML_FIELD', 'HTML_DATA_CACHE', 'HTML_DATA_THREAD', 
		'HTML_DEFAULT_UMASK', 'HTML_DIR', 'HTML_EXPIRE_LIMIT', 
		'HTML_INDENT_STYLE', 'HTML_INDEX_REVERSE_ORDER', 
		'HTML_INDEX_TITLE', 'HTML_INDEX_UNIT', 
		'HTML_MULTIPART_IMAGE_REF_TYPE', 'HTML_OUTPUT_FILTER', 
		'HTML_STYLESHEET_BASENAME', 'HTML_THREAD', 
		'HTML_THREAD_REF_TYPE', 'HTML_THREAD_SORT_TYPE', 
		'HTML_WRITE_UMASK') {
	    eval "printf STDERR \"%-30s  => \", $x";
	    eval "print STDERR \$${x}";
	    eval "print STDERR \"\\n\"";
	}
    }

    require 'libsynchtml.pl';

    if ($verbose) { 
	print STDERR "\n";
	for (keys %INC) { print STDERR "INCLUDE_LIBRARY: $INC{$_}\n";}
    }

    print STDERR "\n";
}


sub Die
{
    print STDERR "Error: ", $_[0], "\n\n";
    &Usage;
    exit 1;
}


sub _speculate_unixtime
{
    my ($f) = @_;

    use FileHandle;
    eval q{
	use Mail::Header;
	use FML::Date;
    };

    my $fh    = new FileHandle $f;
    my $head  = new Mail::Header $fh;
    my $date  = $head->get('date');
    my $utime = FML::Date::date_to_unixtime($date);

    return ($date, $utime);
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

	# XXX At 4.0-current (4.0.2 - 4.0.3) we change algorithm
	#     to determine Date: for the $id (article).
	# XXX Historically we speculate Date: for the article
	# XXX from the file's stat() information.
	# XXX We get it from the article's Date: directly now.

	# $date  = Mon Jul  2 23:46:46 2001
	# $mtime = 994085206
	($date, $mtime) = &_speculate_unixtime("$SPOOL_DIR/$id");

	# XXX disable stat()
	#  $e{'stat:mtime'} = $mtime = (stat("$SPOOL_DIR/$id"))[9];
	$e{'stat:mtime'} = $mtime;
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

	# declare distribute mode
	$ID = $id;
	$Envelope{'mode:dist'} = 1;

	# reset mtime informatoin since we undef %e above;
	# $Envelope{'stat:mtime'} = (stat("$SPOOL_DIR/$id"))[9]; 
	$Envelope{'stat:mtime'} = $mtime;
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

    $s = q#Usage: spool2html.pl [-hvV] [-D DIR]
                  [-I INC] [-f config.ph] [-d HTML_DIR]
                  [-M minimum] [-S SLEEP_TIME]
                  [-E limit] [-t type]
                  [-t TYPE] SPOOL;
    ;
    -h              this message;
    ;
    -v              verbose;
    -V              debug mode on;
    ;
    -f config.ph    configuration file;
    ;
    -D $DIR         ML HOME directory);
    -d $HTML_DIR    html created directory);
    -I path         include path;
    ;
    -t type         number of day ($HTML_INDEX_UNIT);
    -M number       Minimum (MIN, default 1);
    -L number       process the latest $opt_L files.
                    (hence MIN = MAX - $opt_L);
    ;
    SPOOL           $SPOOL_DIR;
    ;
    For example;
    % chdir /var/spool/ml/elena;
    % /usr/local/fml/bin/spool2html.pl -t month -L 100 -v \\;
       -I /my/hacked/library -d htdocs -f config.ph spool;
    ;#;

    $s =~ s/;//g;
    $s =~ s/\s*$//;
    print "$s\n";
}


sub FixProc
{
local($evalstr) = q#;
sub Log  { print STDERR "LOG> ", @_, "\n";};
sub Mesg { print STDERR "   > ", @_, "\n";};
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
	# XXX '+1' require to sync with "if" condition above.
	# patch from MURASHITA Takuya (fml-support: 7215)
	$try = $seq + 1;
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
sub DEFINE_FIELD_LOOP_CHECKED { 1;}
sub UNDEF_FIELD_LOOP_CHECKED  { 1;}
sub ADD_FIELD     { 1;}
sub DELETE_FIELD  { 1;}
sub COPY_FIELD  { 1;}
sub MOVE_FIELD  { 1;}

# debug
sub PS { $FML = 'spool2html'; system "ps uw|grep spool2html";}

1;
