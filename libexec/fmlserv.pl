#!/usr/local/bin/perl
#
# Copyright (C) 1996 kfuka@sapporo.iij.ad.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$Rcsid   = 'fmlserv #: Wed, 29 May 96 19:32:37  JST 1996';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# Now for the exist-check (DIR, LIBDIR), "free order is available"
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}

# Fmlserv specific here
$DIR           = $DIR    || '/home/axion/fukachan/work/spool/EXP';
$MAIL_LIST_DIR = $DIR;
$FMLSERV_DIR   = "$DIR/fmlserv";
$LIBDIR	       = $LIBDIR || $DIR;
unshift(@INC, $FMLSERV_DIR);

### MAIN ###
umask(077);			# ATTENTION!

&CheckUGID;

chdir $MAIL_LIST_DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..

&Parse;				# Phase 1(1st pass), pre-parsing here

&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

&FixHeaders(*Envelope);		# Phase 3, fixing fields information

&CheckEnv(*Envelope);		# Phase 4, fixing environment and check loops
				# If an error is found, exit here.

&FmlServ(*Envelope);

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'};# Reply some report if-needed.

exit 0;
### MAIN ENDS ###


##### FmlServ Emulation Codes

sub FmlServ
{
    local(*e) = @_;
    local($eval, $hook);

    # Declare 
    $Envelope{'mode:fmlserv'} = 1;

    # Directory check
    $FMLSERV_DIR || die "Please define \$FMLSERV_DIR\n";
    if (! -d $FMLSERV_DIR) { mkdir($FMLSERV_DIR, 0700);}

    # ML::constructor() for fmlserv@$DOMAIN
    &NewML($FMLSERV_DIR, 'fmlserv', *e);

    # for logggin all log's in fmlserv/log, too
    $FMLSERV_LOGFILE = $LOGFILE;

    # Alloc %ML {list => directory_of_list}
    # checks -d $MAIL_LIST_DIR/* -> %ML (generated from the data)
    &NewMLAA($MAIL_LIST_DIR, *ML);

    # Summary of requested procedures for each ML
    # Envelope{Body} => %ReqInfo (Each ML)
    #                   @ReqInfo (fmlserv commands) 
    &SortRequest(*Envelope, *ReqInfo);

    require 'libfml.pl';# if %ReqInfo;
    
    # Save 'main' NameSpace
    &Save_mainNS;			
    #&Dump_mainNS("$FMLSERV_DIR/tmp/main_name_space") if debug_dump;

    $FMLSERV_DIR = $DIR;	# save $DIR

    foreach $ml (keys %ReqInfo) {
	$DIR  = $ML{$ml};	# reset $DIR for each ML's $DIR
	$cf   = "$DIR/config.ph";
	$proc = $ReqInfo{$ml};

	$PresentML = $ml;	# for logfile

	&Debug("ML\t$ml\nDIR\t$DIR\ncf\t$cf\nprocs\t$proc\n") if $debug;
	
	# Load 'ml' NS from $list/config.ph
	if ($COMPAT_MAJORDOMO) {
	    require 'libcompat_majordomo.pl';
	    &CompatMajordomo;
	}
	else {
	    &NewML($DIR, $ml, *e);
	}

	&Lock;			# LOCK

	chdir $DIR || die $!;

	$e{'message'} .= "\n\n   Requests to $ml:\n";
	$e{'message'} .= $ML_cmds_log{$ml};

	&DoFmlServProc($ml, $proc, *e);

	if ($FML_EXIT_HOOK =~ /mget3_SendingEntry/) {
	    undef $eval;
	    foreach $n ('SendingEntry', 'SendingArchiveEntry') {
		$eval .= sprintf("\@%s'$n = \@main'$n;\n", $ml);
		$eval .= sprintf("%%%s'$n = %%main'$n;\n", $ml);
		$hook .= sprintf("\@main'$n = \@%s'$n;\n", $ml);
		$hook .= sprintf("%%main'$n = %%%s'$n;\n", $ml);
	    }

	    # hook
	    $hook .= qq#&mget3_SendingEntry;\n#;

	    # eval
	    eval($eval); &Log($@) if $@;

	    $FML_EXIT_HOOK =~ s/&mget3_SendingEntry;//g;
	    &mget3_Reset;	# only mget3 routine called..
	}	

	&Unlock;		# UNLOCK

	&RunHooks;		# run-hook for each ML

	undef $FML_EXIT_HOOK;	# unlink each ML hook

	# Reload NS from main'NS
	&ResetNS;

	undef $PresentML;
    }# each MLs

    $FML_EXIT_HOOK = $hook;
    $DIR           = $FMLSERV_DIR; #reset global variable

    chdir $DIR || die $!;

    &NewML($FMLSERV_DIR, 'fmlserv', *e);

    $e{'F:From'} = $MAIL_LIST;	# special case when fmlserv

    # Already '_main' ENVIRONMENT
    # DONE;
}


sub DoFmlServProc
{
    local($ml, $proc, *e) = @_;
    local($sp, $guide_p);

    if (&CheckMember($From_address, $MEMBER_LIST)) {
	&Command($proc);
    }
    else {
	&Debug("ERROR: CheckMember($From_address, $MEMBER_LIST)") if $debug;
	foreach (split(/\n/, $proc)) {
	    if (/^subscribe\s*(.*)/i){ $sp = 1; $addr = $1; next;}
	    if (/^(guide|info)/i) { $guide_p     = $_; next;}
	    $s  = "YOU ARE NOT MEMBER($ml), so NOT PERMIT $proc";
	    &LogWEnv($s, *e);
	}

	### Subscription is an exception.
	if ($sp) {
	    if ($ML_MEMBER_CHECK) {
		&Warn("Subscribe Request from $From_address", &WholeMail);
	    }
	    else {
		&use('utils');
		&Append2(join("\n", %e), "/tmp/ujauja");
		&AutoRegist(*e, $addr);
	    }
	}
	elsif ($guide_p) {
	    &GuideRequest;
	}
    }
}


sub NewML
{
    local($DIR, $ml, *e) = @_;
    local($cf)  = "$DIR/config.ph";

    print STDERR "NewML::Check($cf)\n" if $debug;

    if (-f $cf) {
	print STDERR "NewML::Load($cf)\n" if $debug;
	&LoadMLNS($cf);		# eval("$DIR/config.ph")
    }
    elsif (! -f $cf) {	# no $MAIL_LIST_DIR/$ml/config.ph
	print STDERR "NewML::SetMLDefaults($DIR, $ml)\n" if $debug;
	&SetMLDefaults($DIR, $ml);
    }

    ### do actions for each $list ###
    # RESET IMPORTANT VARIABLES

    $e{'h:Reply-To:'}             = $e{'Addr2Reply:'};
    $From_address = $e{'h:From:'} = &Conv2mailbox($e{'from:'});

    &GetTime;

    # required settings
    $COMMAND_ONLY_SERVER      = 1;
    $COMMAND_SYNTAX_EXTENSION = 1;

    for ('SPOOL_DIR', 'TMP_DIR', 'VAR_DIR', 'VARLOG_DIR', 'VARRUN_DIR') {
	$s .= "-d \$$_ || mkdir(\$$_, 0700); \$$_ =~ s#$DIR/##g;\n";
	$s .= "\$FP_$_ = \"$DIR/\$$_\";\n"; # FullPath-ed (FP)
    }
    eval($s); &Log("FAIL EVAL \$SPOOL_DIR ...") if $@;
}


sub SetMLDefaults
{
    local($dir, $ml) = @_;

    # $DOMAINNAME, $FQDN should be used of _main NS
    $domain      = $FQDN ? $FQDN : $DOMAINAME;
    $MAIL_LIST   = "$ml\@$domain";
    $ML_FN       = "($ml ML)";
    $XMLNAME     = "X-ML-Name: $ml";
    $XMLCOUNT    = "X-Mail-Count";
    $MAINTAINER  = "fmlserv-admin\@$domain";

    # Directory
    $SPOOL_DIR                     = "spool";
    $TMP_DIR                       = "tmp"; # tmp, after chdir, under DIR
    $VAR_DIR                       = "var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR                    = "var/log";
    $VARRUN_DIR                    = "var/run";

    # files
    $MEMBER_LIST                   = "$DIR/members"; # member list
    $ACTIVE_LIST                   = "$DIR/actives"; # active member list
    $OBJECTIVE_FILE                = "$DIR/objective"; # objective file
    $GUIDE_FILE                    = "$DIR/guide";
    $HELP_FILE                     = "$DIR/help";
    $DENY_FILE                     = "$DIR/deny"; # attention to illegal access
    $WELCOME_FILE                  = "$DIR/guide"; # could be $DIR/welcome
    $LOGFILE                       = "$DIR/log"; # activity log file
    $MGET_LOGFILE                  = "$DIR/log"; # log file for mget routine
    $SMTPLOG                       = "$VARLOG_DIR/_smtplog";
    $SUMMARY_FILE                  = "$DIR/summary"; # article summary file
    $SEQUENCE_FILE                 = "$DIR/seq"; # sequence number file
    $MSEND_RC                      = "$VARLOG_DIR/msendrc";
    $LOCK_FILE                     = "$VARRUN_DIR/lockfile.v7"; # liblock.pl
}

sub NewMLAA
{
    local($dir, *entry) = @_;

    opendir(DIRD, $dir) || die $!;
    foreach(readdir(DIRD)) {
	next if /^\./;
	$entry{$_} = "$dir/$_" if -d "$dir/$_";
    }
    closedir(DIRD);

    if ($debug) {
	while (($key, $value) = each %entry) {
	    print STDERR "ML AssocArray [$key]\t=>\t[$value]\n";
	}
    }
}


# ATTENTION! "cut the first #.. syntax"
sub SortRequest
{
    local(*e, *ML_cmds) = @_;
    local($cmd, $ml, @p, $s, $k, $v);

    foreach ( split(/\n/, $e{'Body'}) ) {
	next if /^\s*$/;	# skip null line
	s/^\#\s*//;		# cut the first #.. syntax
	next if /^\S+=\S+/;	# variable settings, skip

	($cmd, $ml, @p) = split(/\s+/,$_);
	$ml =~ tr/A-Z/a-z/;

	# EXPILICIT ML DETECTED. 
	# $ml is non-nil and the ML exists
	if ($ml && $ML{$ml}) {	
	    # &Log("Request::${ml}::$cmd", (@p ? "(@p)" : ""));
	    $ML_cmds{$ml}     .= "$cmd @p\n";
	    $ML_cmds_log{$ml} .= ">>>> $cmd $ml @p\n";	    
	    &Debug("\$ML_cmds{$ml} = $ML_cmds{$ml}") if $debug;
	}
	# LISTSERV COMPATIBLE: COMMANDS SINCE NO EXPILICIT ML.
	else {
	    last if $_ eq 'quit';
	    last if $_ eq 'end';
	    last if $_ eq 'exit';
	    push(@ML_cmds, $_);
	    &Debug("\@ML_cmds = push [$_]") if $debug;
	}
    }    

    # Match nothing "HELP of LISTSERV COMPATIBLE" not HELP of each ML
    (! @ML_cmds) && (! %ML_cmds) && push(@ML_cmds, 'help');

    if ($debug) {
	while (($k,$v) = each %ML_cmds) { &Debug("[$k]=>\n$v");}
    }
}


########## Name Space Operations ##########

sub Save_mainNS
{
    local($ns) = @_;
    local($key, $val, $eval);
    (*stab) = eval("*_main");

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) {
	    $eval .= "\$org'$key = \$main'$key;\n";
	    $NSS{$key} = 1;
	}
	if (defined @entry) { 
	    $eval .= "\@org'$key = \@main'$key;\n";
	    $NSA{$key} = 1;
	}
	if ($key ne "_$package" && defined %entry) { 
	    $eval .= "\%org'$key = \%main'$key;\n";
	    $NSAA{$key} = 1;
	}
    }

    print $eval if $debug_ns;
    eval($eval); &Log($@) if $@;
}


sub Dump_mainNS
{
    local($outfile) = @_;
    local($key, $val);
    (*stab) = eval("*_main");

    open(OUT, "> $outfile") || die $!;

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) { print OUT "$key\t$entry\n";}
	if (defined @entry) { print OUT "$key\t@entry\n";}
	if ($key ne "_$package" && defined %entry) { 
	    print OUT "$key\t",join(" ", %entry),"\n";
	}
    }

    close(OUT);
}


sub ResetNS
{
    local($eval);

    # undef main NS
    foreach (keys %ML_NSS)  { $eval .= "undef \$main'$_;\n";}
    foreach (keys %ML_NSA)  { $eval .= "undef \@main'$_;\n";}
    foreach (keys %ML_NSAA) { $eval .= "undef \%main'$_;\n";}

    # load main NS from org(saved main) NS
    foreach (keys %NSS)  { $eval .= "\$main'$_ = \$org'$_;\n";}
    foreach (keys %NSA)  { $eval .= "\@main'$_ = \@org'$_;\n";}
    foreach (keys %NSAA) { $eval .= "\%main'$_ = \%org'$_;\n";}

    &Debug($eval) if $debug_ns;
    eval $eval || &Log($@);
}


##################################################################
package ml;

sub main'LoadMLNS
{
    local($file) = @_;
    local($key, $val, $eval);

    # load Variable list(Association List)
    %ml'NSS  = %main'NSS;
    %ml'NSA  = %main'NSA;
    %ml'NSAA = %main'NSAA;
    
    # load original main NameSpace
    foreach (keys %NSS)  { $eval .= "\$ml'$_ = \$main'$_;\n";}
    foreach (keys %NSA)  { $eval .= "\@ml'$_ = \@main'$_;\n";}
    foreach (keys %NSAA) { $eval .= "\%ml'$_ = \%main'$_;\n";}
    eval($eval); &main'Log($@) if $@; #';
    undef $eval;

    # load the presnet directry information (tricky?)
    $ml'DIR = $main'DIR;

    do $file;
    (*stab) = eval("*_ml");

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) { 
	    $eval .= "\$main'$key = \$ml'$key;\n";
	    $ML_NSS{$key} = 1;
	}

	if (defined @key) { 
	    $eval .= "\@main'$key = \@ml'$key;\n";
	    $ML_NSA{$key} = 1;
	}

	if ($key ne "_$package" && defined %key) { 
	    $eval .= "\%main'$key = \%ml'$key;\n";
	    $ML_NSAA{$key} = 1;
	}
    }

    $eval .= "\%main'ML_NSS = \%ml'ML_NSS;\n";
    $eval .= "\%main'ML_NSA = \%ml'ML_NSA;\n";
    $eval .= "\%main'ML_NSAA = \%ml'ML_NSAA;\n";
    
    &Debug($eval) if $debug_ns;
    eval($eval); &main'Log($@) if $@; #';
}


package main;

# Log is special for fmlserv.
sub Log { 
    local($str, $s) = @_;
    local($package, $filename, $line) = caller; # called from where?
    local($status);

    &GetTime;
    $str =~ s/\015\012$//;	# FIX for SMTP
    if ($debug_sendmail_error && ($str =~ /^5\d\d\s/)) {
	$Envelope{'error'} .= "Sendmail Error:\n";
	$Envelope{'error'} .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }
    
    $str = "$filename:$line% $str" if $debug_caller;

    &Append2("$Now $str ($From_address)", $LOGFILE, 0, 1);
    &Append2("$Now    $filename:$line% $s", $LOGFILE, 0, 1) if $s;

    local($ml);
    if ($ml = $PresentML) {
	&Append2("$Now $ml\# $str ($From_address)", $FMLSERV_LOGFILE, 0, 1);
	&Append2("$Now $ml\# $filename:$line% $s", $FMLSERV_LOGFILE, 0, 1) 
	    if $s;
    }

    if ($Envelope{'mode:caller'}) {
	&Append2("$Now ($package, $filename, $line)", $LOGFILE, 0, 1);
	&Debug("$Now ($package, $filename, $line) $LOGFILE, 0, 1");
    }
}

########## 
#
#   ### ATTENTION!: exclude &Log; ###
#
#:include: fml.pl
#:sub LoadConfig SetDefaults BackwardCompat GetTime InitConfig SetOpts
#:sub Logging LogWEnv Log 
#:sub CacheMessageId TimeOut GuideRequest
#:sub Notify ExExec RunHooks FieldsDebug Conv2mailbox GetTime Parsing Parse
#:sub WholeMail eval CheckMember AddressMatch Logging 
#:sub GetFieldsFromHeader
#:sub Opt SetCommandLineOptions LoopBackWarn Lock Unlock Flock Funlock
#:sub Touch Write2 Append2 use Debug InitConfig Warn ChkREUid CheckUGID
#:sub FixHeaders CheckEnv CtlAddr Addr2FQDN CutFQDN SecureP
#:replace
sub Unlock { $USE_FLOCK ? &Funlock : &V7Unlock;}


sub SetDefaults
{
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)
    $Envelope{'mode:uip'}   = '';    # default UserInterfaceProgram is nil.;
    $Envelope{'mode:req:guide'} = 0; # not member && guide request only

    %SEVERE_ADDR_CHECK_DOMAINS = ('or.jp', +1);
    $REJECT_ADDR = 'root|postmaster|MAILER-DAEMON|msgs|nobody';
    $SKIP_FIELDS = 'Received|Return-Receipt-To';
    $MAIL_LIST   = 'dev.null@domain.uja';
    $MAINTAINER  = 'dev.null-admin@domain.uja';

    @HdrFieldsOrder = 
	('Return-Path', 'Date', 'From', 'Subject', 'Sender',
	 'To', 'Reply-To', 'Errors-To', 'Cc', 'Posted',
	 ':body:', 'Message-Id', ':any:', ':XMLNAME:', 
	 ':XMLCOUNT:', 'X-MLServer',
	 'mime-version', 'content-type', 'content-transfer-encoding',
	 'XRef', 'X-Stardate', 'X-Ml-Info', 
	 'References', 'In-Reply-To', 'Precedence', 'Lines');
}


sub BackwardCompat
{
    if (! @DenyProcedure) { @DenyProcedure = ('library');}
    if (! @NEWSYSLOG_FILES) { 
	@NEWSYSLOG_FILES = 
	    ("$MSEND_RC.bak", "$MEMBER_LIST.bak", "$ACTIVE_LIST.bak");
    }
    push(@ARCHIVE_DIR, @StoredSpool_DIR); # FIX INCLUDE PATH
    $STRIP_BRACKETS        = 1 if $SUBJECT_HML_FORM;
    $SENDFILE_NO_FILECHECK = 1 if $SUN_OS_413;
    $USE_MIME              = 1 if $USE_LIBMIME;
    $USE_ERRORS_TO         = 1 if $AGAINST_NIFTY;
    if ($NO_USE_CC) { &Log("Please change \@HdrFieldsOrder in config.ph");}
    $Permit{'ShellMatchSearch'} = 1 if $SECURITY_LEVEL <= 1; #default=2[1.4d]
    $Permit{'ra:req:passwd'}    = 1 if $REMOTE_ADMINISTRATION_REQUIRE_PASSWORD;
    $Permit{'ra:req:passwd'}    = 1 if $REMORE_AUTH || $REMOTE_AUTH;
}


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
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


sub InitConfig
{
    &SetDefaults;
    &LoadConfig;

    # a little configuration before the action
    umask (077);			# rw-------

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER! \$MAIL_LIST = \$MAINTAINER, STOP!");
	exit 0;
    }

    ### Options
    &SetOpts;
    if ($_cf{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

    &GetTime;			        # Time

    # COMPATIBILITY
    if ($COMPAT_CF1 || ($CFVersion < 2))   { &use('compat_cf1');}
    if ($COMPAT_FML15) { &use('compat_cf1'); &use('compat_fml15');}

    # spelling miss
    (defined $AUTO_REGISTERD_UNDELIVER_P) &&
	($AUTO_REGISTERED_UNDELIVER_P = $AUTO_REGISTERD_UNDELIVER_P);

    ### Initialize DIR's and FILE's of the ML server
    local($s);
    for ('SPOOL_DIR', 'TMP_DIR', 'VAR_DIR', 'VARLOG_DIR', 'VARRUN_DIR') {
	$s .= "-d \$$_ || mkdir(\$$_, 0700); \$$_ =~ s#$DIR/##g;\n";
	$s .= "\$FP_$_ = \"$DIR/\$$_\";\n"; # FullPath-ed (FP)
    }
    eval($s) || &Log("FAIL EVAL \$SPOOL_DIR ...");

    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    # Turn Over log file (against too big)
    if ((stat($LOG_MESSAGE_ID))[7] > 25*100) { # once per about 100 mails.
	&use('newsyslog');
	&NewSyslog'TurnOverW0($LOG_MESSAGE_ID);#';
    }

    # EMERGENCY CODE against LOOP
    if (-f "$FP_VARRUN_DIR/emerg.stop") { $DO_NOTHING = 1;}

    ### misc 
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # For tracing Process Table

    &BackwardCompat;

    # signal handling
    $SIG{'ALRM'} = 'TimeOut';
    $SIG{'USR1'} = 'Caller';
}


# Setting CommandLineOptions after include config.ph
sub SetOpts
{
    for (@SetOpts) { /^\-\-MLADDR=(\S+)/i && (&use("mladdr"), &MLAddr($1));}

    for (@SetOpts) {
	if (/^\-\-(\S+)=(\S+)/) {
	    eval("\$$1 = '$2';"); next;
	}
	elsif (/^\-\-(\S+)/) {
	    local($_) = $1;
	    /^[a-z0-9]+$/  ? ($Envelope{"mode:$_"} = 1) : eval("\$$_ = 1;"); 
	    /^permit:([a-z0-9:]+)$/ && ($Permit{$1} = 1); # set %Permit;
	    next;
	}

	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }

    if ($DUMPVAR) { require 'dumpvar.pl'; &dumpvar('main');}
}




# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub LogWEnv { local($s, *e) = @_; &Log($s); $e{'message'} .= "$s\n";}
sub Log { 
    local($str, $s) = @_;
    local($package, $filename, $line) = caller; # called from where?
    local($status);
    
    &GetTime;
    $str =~ s/\015\012$//;	# FIX for SMTP
    if ($debug_sendmail_error && ($str =~ /^5\d\d\s/)) {
	$Envelope{'error'} .= "Sendmail Error:\n";
	$Envelope{'error'} .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }
    
    $str = "$filename:$line% $str" if $debug_caller;

    &Append2("$Now $str ($From_address)", $LOGFILE, 0, 1);
    &Append2("$Now    $filename:$line% $s", $LOGFILE, 0, 1) if $s;

    if ($Envelope{'mode:caller'}) {
	&Append2("$Now ($package, $filename, $line)", $LOGFILE, 0, 1);
	&Debug("$Now ($package, $filename, $line) $LOGFILE, 0, 1");
    }
}


# If O.K., record the Message-Id to the file $LOG_MESSAGE_ID);
# message-id cache should be done for the mail with the real action
sub CacheMessageId
{
    local($id) = $Envelope{'h:Message-Id:'};
    $id        =~ /\s*\<(\S+)\>\s*/;
    &Append2($id, $LOG_MESSAGE_ID);
}



# Do FQDN of the given Address 1. $addr is set and has @, 2. MALI_LIST
sub Addr2FQDN { $_[0] ? ($_[0] =~ /\@/ ? $_[0] : $_[0]."\@$FQDN") : $MAIL_LIST;}
sub CutFQDN   { $_[0] =~ /(\S+)\@(\S+)/ ? $1 : $_[0];}


# Security 
sub SecureP 
{ 
    local($s) = @_;

    $s =~ s#(\w)/(\w)#$1$2#g; # permit "a/b" form

    if ($s =~ /^[\#\s\w\-\[\]\?\*\.\,\@\:]+$/) {
	1;
    }
    else {
	&use('utils'), &SecWarn(@_); 
	0;
    }
}


# When just guide request from unknown person, return the guide only
# change reply-to: for convenience
sub GuideRequest
{
    &Log("Guide request from a stranger");
    $Envelope{'h:Reply-To:'} = $Envelope{'h:reply-to:'} || $Envelope{'CtlAddr:'}; 
    &SendFile($Envelope{'Addr2Reply:'}, "Guide $ML_FN", $GUIDE_FILE);
}


# Notification of the mail on warnigs, errors ... 
sub Notify
{
    # refer to the original(NOT h:Reply-To:);
    local($to)   = $Envelope{'message:h:to'} || $Envelope{'Addr2Reply:'};
    local(@to)   = split(/\s+/, $Envelope{'message:h:@to'});
    local($s)    = $Envelope{'message:h:subject'} || "fml Status report $ML_FN";
    local($proc) = $PROC_GEN_INFO || 'GenInfo';
    $GOOD_BYE_PHRASE = $GOOD_BYE_PHRASE  || "\tBe seeing you!   ";
    
    if ($Envelope{'message'}) {
	$Envelope{'message'} .= "\n$GOOD_BYE_PHRASE $FACE_MARK\n";
	&use('utils');
	$Envelope{'trailer'}  = &$proc;
	&Sendmail($to, $s, $Envelope{'message'}, @to);
    }

    if ($Envelope{'error'}) {
	&Warn("Fml System Error Message $ML_FN", $Envelope{'error'}. &WholeMail);
    }
}



# Lastly exec to be exceptional process
sub ExExec { &RunHooks(@_);}
sub RunHooks
{
    local($s);
    $0  = "--Run Hooks <$FML $LOCKFILE>";

    # FIX COMPATIBILITY
    $FML_EXIT_HOOK .= $_cf{'hook', 'str'};
    $FML_EXIT_PROG .= $_cf{'hook', 'prog'};

    if ($s = $FML_EXIT_HOOK) {
	print STDERR "\nmain::eval >$s<\n\n" if $debug;
	$0  = "--Run Hooks(eval) <$FML $LOCKFILE>";
	&eval($s, 'Run Hooks:');
    }

    if ($s = $FML_EXIT_PROG) {
	print STDERR "\nmain::exec $s\n\n" if $debug;
	$0  = "--Run Hooks(prog) <$FML $LOCKFILE>";
	exec $s;
	&Log("cannot exec $s");	# must be not reached;
    }
}


# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
Mailing List:        $MAIL_LIST
UNIX FROM:           $Envelope{'UnixFrom'}
From(Original):      $Envelope{'from:'}
From_address:        $From_address
Original Subject:    $Envelope{'subject:'}
To:                  $Envelope{'mode:chk'}
Reply-To:            $Envelope{'h:Reply-To:'}

DIR:                 $DIR
LIBDIR:              $LIBDIR
MEMBER_LIST:         $MEMBER_LIST
ACTIVE_LIST:         $ACTIVE_LIST

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip:              $Envelope{'mode:uip'}

Another Header:     >$Envelope{'Hdr2add'}<
	
LOAD_LIBRARY:        $LOAD_LIBRARY

"#;

"print STDERR $s";
}


# Expand mailbox in RFC822
# From_address is user@domain syntax for e.g. member check, logging, commands
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
# 
sub Conv2mailbox
{
    local($mb, *e) = @_;	# original string

    # $mb = &Strip822Comments($mb);

    # NULL is given, return NULL
    ($mb =~ /^\s*$/) && (return $NULL);

    # RFC822 unfolding
    $mb =~ s/\n(\s+)/$1/g;

    # Hayakawa Aoi <Aoi@aoi.chan.panic>
    if ($mb =~ /^\s*(.*)\s*<(\S+)>.*$/io) { $e{'macro:x'} = $1, return $2;}

    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
    if ($mb =~ /^\s*(\S+)\s*\((.*)\)$/io || $mb =~ /^\s*(\S+)\s*(.*)$/io) {
	$e{'macro:x'} = $2, return $1;	
    }

    # Aoi@aoi.chan.panic
    return $mb;
}	


sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
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



# one pass to cut out the header and the body
sub Parsing { &Parse;}
sub Parse
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($nlines, $nclines);

    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    $Envelope{'Header'} .= $_ unless /^$/o;
	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:req:guide'} = 1 if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	    }

	    # Command or not is checked within the first 3 lines.
	    # '# help\s*' is OK. '# guide"JAPANESE"' & '# JAPANESE' is NOT!
	    # BUT CANNOT JUDGE '# guide "JAPANESE CHARS"' SYNTAX;-);
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:uip'} = 'on'    if /^\#\s*\w+\s|^\#\s*\w+$/;
		$Envelope{'mode:uip:chaddr'}=$_ if /^\#\s*$CHADDR_KEYWORD\s+/i;
	    }

	    $Envelope{'Body'} .= $_; # save the body
	    $nlines++;               # the number of bodylines
	    $nclines++ if /^\#/o;    # the number of command lines
	}
    }# END OF WHILE LOOP;

    $Envelope{'nlines'}  = $nlines;
    $Envelope{'nclines'} = $nclines;
}


# Recreation of the whole mail for error infomation
sub WholeMail   
{ 
    local($b) = "--$MailDate--\n";
    local($c) = "Content-Type: message/rfc822\n";
    $Envelope{'r:MIME'} .= "MIME-Version: 1.0\n";
    $Envelope{'r:MIME'} .= "Content-type: multipart/mixed; boundary=\"$d\"\n";
    $_ = $Envelope{'Header'}."\n".$Envelope{'Body'};
    "\n\nOriginal Mail as follows:\n\n$b$c\n$_\n$b\n";
}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}


# CheckMember(address, file)
# return 1 if a given address is authentified as member's
#
# performance test example 1 (100 times for 158 entries == 15800)
# fastest case
# old 1.880u 0.160s 0:02.04 100.0% 74+34k 0+1io 0pf+0w
# new 1.160u 0.160s 0:01.39 94.9% 73+36k 0+1io 0pf+0w
# slowest case
# old 20.170u 1.520s 0:22.76 95.2% 74+34k 0+1io 0pf+0w
# new 9.050u  0.190s 0:09.90 93.3% 74+36k 0+1io 0pf+0w
#
# the actual performance is the average between values above 
# but the new version is stable performance
#
sub CheckMember
{
    local($address, $file) = @_;
    local($addr) = split(/\@/, $address);
    local($has_special_char);
    
    # MUST BE ONLY * ? () [] but we enhance the category -> shell sc
    if ($addr =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	$has_special_char = 1; 
    }

    open(FILE, $file) || return 0;

  getline: while (<FILE>) {
      chop; 

      $ML_MEMBER_CHECK || do { /^\#\s*(.*)/ && ($_ = $1);};

      next getline if /^\#/o;	# strip comments
      next getline if /^\s*$/o; # skip null line
      /^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

      # member nocheck(for nocheck but not add mode)
      # fixed by yasushi@pier.fuji-ric.co.jp 95/03/10
      # $ENCOUNTER_PLUS             by fukachan@phys 95/08
      # $Envelope{'mode:anyone:ok'} by fukachan@phys 95/10/04
      if (/^\+/o) { 
	  $Envelope{'mode:anyoneok'} = 1;
	  close(FILE); 
	  return 1;
      }

      # for high performance(Firstly special character check)
      if (! $has_special_char) { next getline unless /^$addr/i;}

      # This searching algorithm must require about N/2, not tuned,
      if (1 == &AddressMatch($_, $address)) {
	  close(FILE);
	  return 1;
      }
  }# end of while loop;

    close(FILE);
    return 0;
}


# sub AddressMatching($addr1, $addr2)
# return 1 given addresses are matched at the accuracy of 4 fields
sub AddressMatching { &AddressMatch(@_);}
sub AddressMatch
{
    local($addr1, $addr2) = @_;

    # canonicalize to lower case
    $addr1 =~ y/A-Z/a-z/;
    $addr2 =~ y/A-Z/a-z/;

    # try exact match. must return here in a lot of cases.
    if ($addr1 eq $addr2) {
	&Debug("\tAddr::match { Exact Match;}") if $debug;
	return 1;
    }

    # for further investigation, parse account and host
    local($acct1, $addr1) = split(/@/, $addr1);
    local($acct2, $addr2) = split(/@/, $addr2);

    # At first, account is the same or not?;    
    if ($acct1 ne $acct2) { return 0;}

    # Get an array "jp.ac.titech.phys" for "fukachan@phys.titech.ac.jp"
    local(@d1) = reverse split(/\./, $addr1);
    local(@d2) = reverse split(/\./, $addr2);

    # Check only "jp.ac.titech" part( = 3)(default)
    # If you like to strict the address check, 
    # change $ADDR_CHECK_MAX = e.g. 4, 5 ...
    local($i);
    while ($d1[$i] && $d2[$i] && ($d1[$i] eq $d2[$i])) { $i++;}

    &Debug("\tAddr::match { $i >= ($ADDR_CHECK_MAX || 3);}") if $debug;

    ($i >= ($ADDR_CHECK_MAX || 3));
}



# Phase 2 extract several fields 
sub GetFieldsFromHeader
{
    local($field, $contents, @Hdr, $Message_Id, $u);

    $0 = "--GetFieldsFromHeader <$FML $LOCKFILE>";

    ### IF WITHOUT UNIX FROM e.g. for slocal bug??? 
    if (! ($Envelope{'Header'} =~ /^From\s+\S+/i)) {
	$u = $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;
	$Envelope{'Header'} = "From $u $MailDate\n".$Envelope{'Header'};
    }

    ### MIME: IF USE_LIBMIME && MIME-detected;
    $Envelope{'MIME'}= 1 if $Envelope{'Header'} =~ /ISO\-2022\-JP/o && $USE_MIME;

    ### Get @Hdr;
    local($s) = $Envelope{'Header'}."\n";
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.

    # misc
    if ($SUPERFLUOUS_HEADERS) { $hdr_entry = join("|", @HdrFieldsOrder);}

    ### Parsing main routines
    for (@Hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {

	print STDERR "FIELD:          >$field<\n" if $debug;

        # UNIX FROM is special: 1995/06/01 check UNIX FROM against loop and bounce
	/^From\s+(\S+)/i && ($Envelope{'UnixFrom'} = $Unix_From = $1, next);
	
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^\s*$/o;		# if null, skip. must be mistakes.

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/;
	$Envelope{$field} .= ($Envelope{"h:$field"} = $contents);

	next if /^($SKIP_FIELDS):/i;

	# hold fields without in use_fields if $SUPERFLUOUS_HEADERS is 1.
	if ($SUPERFLUOUS_HEADERS) {
	    next if /^($hdr_entry)/i; # :\w+: not match
	    $Envelope{'Hdr2add'} .= "$_ $contents\n";
	}
    }# FOR;

}


# Getopt
sub Opt { push(@SetOpts, @_);}
    


# Check Looping 
# return 1 if loopback
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;
    local($ml);

    foreach $ml ($MAIL_LIST, $CONTROL_ADDRESS, @PLAY_TO) {
	next if $ml =~ /^\s*$/oi;	# for null control addresses
	if (&AddressMatch($to, $ml)) {
	    &Debug("AddressMatch($to, $ml)") if $debug;
	    &Log("Loop Back Warning: ", "$to eq $ml");
	    &Warn("Loop Back Warning: [$to eq $ml] $ML_FN", &WholeMail);
	    return 1;
	}
    }

    0;
}


# Strange "Check flock() OK?" mechanism???
sub Lock { $USE_FLOCK ? &Flock : (&use('lock'), &V7Lock);}


sub LoadConfig
{
    # configuration file for each ML
    for (@INC) { -f "$_/config.ph" && (require('config.ph'), last);}

    eval("require 'sitedef.ph';");      # common defs over ML's
    require 'libsmtp.pl';		# a library using smtp
}


sub Touch  { &Append2("", $_[0]);}


sub Write2 { &Append2(@_, 1);}


# append $s >> $file
# $w   if 1 { open "w"} else { open "a"}(DEFAULT)
# $nor "set $nor"(NOReturn)
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2
{
    local($s, $f, $w, $nor) = @_;
    local(@info) = caller;
    print STDERR "Append2: @info \n" if $debug_caller && (!-f $f);

    if (! open(APP, $w ? "> $f": ">> $f")) { 
	local($r) = -f $f ? "cannot open $f" : "$f not exists";
	$nor ? (print STDERR "$r\n") : &Log($r);
	$Envelope{'mode:caller'} = 1;
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP "$s\n" if $s;
    close(APP);

    1;
}


# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}


sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $debug_message;
}


sub InitConfig
{
    &SetDefaults;
    &LoadConfig;

    # a little configuration before the action
    umask (077);			# rw-------

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER! \$MAIL_LIST = \$MAINTAINER, STOP!");
	exit 0;
    }

    ### Options
    &SetOpts;
    if ($_cf{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

    &GetTime;			        # Time

    # COMPATIBILITY
    if ($COMPAT_CF1 || ($CFVersion < 2))   { &use('compat_cf1');}
    if ($COMPAT_FML15) { &use('compat_cf1'); &use('compat_fml15');}

    # spelling miss
    (defined $AUTO_REGISTERD_UNDELIVER_P) &&
	($AUTO_REGISTERED_UNDELIVER_P = $AUTO_REGISTERD_UNDELIVER_P);

    ### Initialize DIR's and FILE's of the ML server
    local($s);
    for ('SPOOL_DIR', 'TMP_DIR', 'VAR_DIR', 'VARLOG_DIR', 'VARRUN_DIR') {
	$s .= "-d \$$_ || mkdir(\$$_, 0700); \$$_ =~ s#$DIR/##g;\n";
	$s .= "\$FP_$_ = \"$DIR/\$$_\";\n"; # FullPath-ed (FP)
    }
    eval($s) || &Log("FAIL EVAL \$SPOOL_DIR ...");

    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    # Turn Over log file (against too big)
    if ((stat($LOG_MESSAGE_ID))[7] > 25*100) { # once per about 100 mails.
	&use('newsyslog');
	&NewSyslog'TurnOverW0($LOG_MESSAGE_ID);#';
    }

    # EMERGENCY CODE against LOOP
    if (-f "$FP_VARRUN_DIR/emerg.stop") { $DO_NOTHING = 1;}

    ### misc 
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # For tracing Process Table

    &BackwardCompat;

    # signal handling
    $SIG{'ALRM'} = 'TimeOut';
    $SIG{'USR1'} = 'Caller';
}


# Warning to Maintainer
sub Warn { &Sendmail($MAINTAINER, $_[0], $_[1]);}



# Check uid == euid && gid == egid
sub CheckUGID
{
    print STDERR "\nsetuid is not set $< != $>\n\n" if $< != $>;
    print STDERR "\nsetgid is not set $( != $)\n\n" if $( ne $);
}


# LATTER PART is to fix extracts
sub FixHeaders
{
    local(*e) = @_;

    ### Set variables
    $e{'h:Return-Path:'} = "<$MAINTAINER>";        # needed?
    $e{'h:Date:'}        = $MailDate;
    $e{'h:From:'}        = $e{'h:from:'};	   # original from
    $e{'h:Sender:'}      = $e{'h:sender:'};        # orignal
    $e{'h:To:'}          = "$MAIL_LIST $ML_FN";    # rewrite To:
    $e{'h:Cc:'}          = $e{'h:cc:'};     
    $e{'h:Message-Id:'}  = $e{'h:message-id:'}; 
    $e{'h:Posted:'}      = $e{'h:date:'} || $MailDate;
    $e{'h:Precedence:'}  = $PRECEDENCE || 'list';
    $e{'h:Lines:'}       = $e{'nlines'};
    $e{'h:References:'}  = $e{'h:references:'};       
    $e{'h:In-Reply-To:'} = $e{'h:in-reply-to:'};     
    $e{'h:Subject:'}     = $e{'h:subject:'};       # anyway save

    # Some Fields need to "Extract the user@domain part"
    # $e{'h:Reply-To:'} is "reply-to-user"@domain FORM
    $From_address        = &Conv2mailbox($e{'h:from:'}, *e);
    $e{'h:Reply-To:'}    = $e{'h:reply-to:'}; # &Conv2mailbox($e{'h:reply-to:'});
    $e{'Addr2Reply:'}    = $e{'h:Reply-To:'} || $From_address;

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) 
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if (($_ = $e{'h:Subject:'}) && 
	($STRIP_BRACKETS || $SUBJECT_HML_FORM || $SUBJECT_FREE_FORM_REGEXP)) {
	if ($e{'MIME'}) { # against cc:mail ;_;
	    &use('MIME'); 
	    &StripMIMESubject(*e);
	}
	else {
	    local($r)  = 10;	# recursive limit against infinite loop

	    # e.g. Subject: [Elena:003] E.. U so ...
	    $pat = $SUBJECT_HML_FORM ? "\\[$BRACKET:\\d+\\]" : $SUBJECT_FREE_FORM_REGEXP;
	    s/$pat\s*//g;

	    #'/gi' is required for RE: Re: re: format are available
	    while (s/Re:\s*Re:\s*/Re: /gi && $r-- > 0) { ;}

	    $e{'h:Subject:'} = $_;
	}
    } 

    # Obsolete Errors-to:, against e.g. BBS like a nifty
    if ($USE_ERRORS_TO || $AGAINST_NIFTY) {
	$e{'h:Errors-To:'} = $e{'h:errors-to:'} || $ERRORS_TO || $MAINTAINER;
    }

    # Set Control-Address for reply, notify and message
    $e{'CtlAddr:'} = &CtlAddr;
}


sub CheckEnv
{
    local(*e) = @_;

    ### For CommandMode Check(see the main routine in this flie)
    $e{'mode:chk'}  = $e{'h:to:'} || $e{'h:apparently-to:'};
    $e{'mode:chk'} .= ", $e{'h:Cc:'}, ";
    $e{'mode:chk'}  =~ s/\n(\s+)/$1/g;

    # Correction. $e{'mode:req:guide'} is used only for unknown ones.
    if ($e{'mode:req:guide'} && &CheckMember($From_address, $MEMBER_LIST)) {
	undef $e{'mode:req:guide'}, $e{'mode:uip'} = 'on';
    }

    ### SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS && $e{'h:Subject:'}) {
	local($_) = $e{'h:Subject:'};

	$e{'mode:req:guide'}++            if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	$Envelope{'mode:uip'} = 'on' if /^\#\s*\w+\s|^\#\s*\w+$/;

	$e{'mode:req:guide'}++          
	    if $COMMAND_ONLY_SERVER && /^\s*$GUIDE_KEYWORD\s*$/i;
	$Envelope{'mode:uip'} = 'on' 
	    if $COMMAND_ONLY_SERVER && /^\s*\w+\s|^\s*\w+$/;
    }    
    
    ### DEBUG 
    $debug && &eval(&FieldsDebug, 'FieldsDebug');
    
    ###### LOOP CHECK PHASE 1: Message-ID
    ($Message_Id) = ($e{'h:Message-Id:'} =~ /\s*\<(\S+)\>\s*/);

    if ($CHECK_MESSAGE_ID && &CheckMember($Message_Id, $LOG_MESSAGE_ID)) {
	&Log("WARNING: Message ID Loop");
	&Warn("WARNING: Message ID Loop", &WholeMail);
	exit 0;
    }

    ###### LOOP CHECK PHASE 2
    # now before flock();
    if ((! $NOT_USE_UNIX_FROM_LOOP_CHECK) && 
	&AddressMatch($Unix_From, $MAINTAINER)) {
	&Log("WARNING: UNIX FROM Loop[$Unix_From == $MAINTAINER]");
	&Warn("WARNING: UNIX FROM Loop",
	      "UNIX FROM[$Unix_From] == MAINTAINER[$MAINTAINER]\n\n".
	      &WholeMail);
	exit 0;
    }

    ### Address Test Mode; (Become Test Mode)
    if ($_cf{"opt:b"} eq 't') { 
	$DO_NOTHING = 1; &Log("Address Test Mode:Do nothing");
    } 
}


# which address to use a COMMAND control.
sub CtlAddr { &Addr2FQDN($CONTROL_ADDRESS);}


# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    eval alarm(3600);
    open(LOCK, $FP_SPOOL_DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}


sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}


sub TimeOut
{
    &Warn("TimeOut: $MailDate ($From_address) $ML_FN", &WholeMail);    
    &Log("Caught ARLM Signal, forward the mail to the maintainer and exit");
    sleep 3;
    kill 9, $$;
}



1;
