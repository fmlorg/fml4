#!/usr/local/bin/perl
#
# Copyright (C) 1993-2002 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2002 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: fml.pl,v 2.124.2.12 2002/08/10 09:25:59 fukachan Exp $

$Rcsid   = 'fml 4.0';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
    -d $_   && push(@LIBDIR, $_);
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
$0 =~ m#^(.*)/(.*)# && do { unshift(@INC, $1); unshift(@LIBDIR, $1);};
unshift(@INC, $DIR); #IMPORTANT @INC ORDER; $DIR, $1(above), $LIBDIR ...;

#################### MAIN ####################

&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# Load config.ph, initialize conf, date,...

&Parse;				# Phase 1, pre-parsing here
&GetFieldsFromHeader;		# Phase 2, extract fields
&FixHeaderFields(*Envelope);	# Phase 3, fixing fields information
&CheckCurrentProc(*Envelope);	# Phase 4, check the current proc
				# (e.g. mail loop).
				# If an error is found, exit here.
				# We lock for Message-ID cache
				# even if $DO_NOTHING = 1;

&Lock;				# Lock!
&ReloadMySelf;

if ($USE_LOG_MAIL) { &use('logmail'); &MailCacheDir;}

if (! &MailLoopP) {
    &CacheMessageId(*Envelope);
    &RunStartHooks;		# run hooks
    &ModeBifurcate(*Envelope);	# Main Procedure
    &RunEndHooks;		# run hooks
}

&Unlock;			# UnLock!

&RunExitHooks;			# run hooks after unlocking

&Notify() if $Envelope{'message'} || $Envelope{'error'};
				# some report or error message if needed.
				# should be here for e.g., mget, ...

&ExecNewProcess;		# start new process execution (if defined)

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

####### Section: Main Mode Bifurcation

# NOT $Envelope{'mode:ctladdr'} IS IMPORTANT;
# mode:ctladdr >> mode:distribute, mode:distribute*
# Changed a lot at 2.1 DELTA
sub ModeBifurcate
{
    local($command_mode, $member_p, $compat_hml); 

    # Do nothing. Tricky. Please ignore 
    if ($DO_NOTHING) { return 0;}

    # DataBase Access Probe()
    # return ASAP if database server is inaccessible.
    if ($USE_DATABASE) {
	&use('databases');

	# try to probe server
	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, 'member_p', {'address' => $From_address});
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc); 
	if ($mib{'error'}) {
	    &Mesg(*Envelope, 'database error occurs', 'configuration_error');
	    return 0; # return ASAP
	}
    }

    # member ot not?
    &AdjustActiveAndMemberLists;
    $member_p = &MailListMemberP($From_address);
    $member_p = 1 if $Envelope{"trap:+"};
    $Envelope{'mode:stranger'} = 1 unless $member_p;

    # chaddr is available from new address if old to "chaddr" is a member;
    # hml compatible case (not default)
    if (!$member_p && $Envelope{'mode:uip:chaddr'}) {
	&use('utils');
	if (&ChAddrModeOK($Envelope{'mode:uip:chaddr'})) {
	    $Envelope{'mode:uip'} = $member_p = 1;
	}
    }
    # hml compatible case (not default)
    elsif ($CHADDR_AUTH_TYPE eq 'confirmation' && 
	   $Envelope{'mode:uip:chaddr-confirm'}) {
	$Envelope{'mode:uip'} = 1;
    }

    # fml 0.x - fml 2.1gamma compat (not default)
    $compat_hml = &CompatFMLv1P;

    # default
    $REJECT_POST_HANDLER    = $REJECT_POST_HANDLER    || 'Reject';
    $REJECT_COMMAND_HANDLER = $REJECT_COMMAND_HANDLER || 'Reject';

    %RejectHandler = ("reject",      "RejectHandler",
		      "auto_regist", "AutoRegistHandler",
		      "autoregist",  "AutoRegistHandler",
		      "ignore",      "IgnoreHandler",

		      "auto_subscribe", "AutoRegistHandler",
		      "auto_asymmetric_regist", "AutoRegistHandler",
		      );
    if ($debug) {
	&Log("ModeBifurcate: \$PERMIT_POST_FROM    $PERMIT_POST_FROM");
	&Log("ModeBifurcate: \$PERMIT_COMMAND_FROM $PERMIT_COMMAND_FROM");
	&Log("ModeBifurcate: artype   $AUTO_REGISTRATION_TYPE");
	&Log("ModeBifurcate: key      $AUTO_REGISTRATION_KEYWORD");
	&Log("ModeBifurcate: member_p $member_p");
    }

    ### 00.01 Run Hooks 
    if ($MODE_BIFURCATE_HOOK) {
	&eval($MODE_BIFURCATE_HOOK, "MODE_BIFURCATE_HOOK");
    }

    ### 01: compat_hml mode
    if ($compat_hml) {
	&Log("compat_hml mode") if $debug;

	if (!$Envelope{"compat:cf2:post_directive"} &&
	    ($Envelope{'mode:req:guide'} || $Envelope{'req:guide'})) {
	    &GuideRequest(*Envelope);	# Guide Request from anyone
	    return;	# end;
	}

	local($ca) = &CutFQDN($CONTROL_ADDRESS);
	# Default LOAD_LIBRARY SHOULD NOT BE OVERWRITTEN!
	if ($Envelope{'mode:uip'} && 
	    ($Envelope{'trap:rcpt_fields'} =~ /$ca/i)) {
	    $command_mode = 1;
	}
    } 


    ### 02: determine command mode or not
    if ($Envelope{'mode:ctladdr'} || $COMMAND_ONLY_SERVER) {
	&Log("\$command_mode = 1;") if $debug;
	$command_mode = 1;
    }
    # BACKWARD COMPATIBLE 
    # when trap the mail body's "# command" syntax but without --ctladdr
    # at this switch already "!$Envelope{'mode:ctladdr'}" is true
    # but post=* is exception
    elsif ($compat_hml && $Envelope{'mode:uip'}) {
	&Log("backward && uip => command_mode on") if $debug;
	$command_mode = 1;
    }

    # post=* mode and !"ctladdr mode" disables commands
    if (!$Envelope{"mode:ctladdr"} && 
	$Envelope{"compat:cf2:post_directive"}) { 
	&Log("02 undef \$command_mode = $command_mode;") if $debug;
	undef $command_mode;
    }

    &Log("03 \$command_mode = $command_mode;") if $debug;

    # initialize Information
    &GenInfo;

    ### 03: Bifurcate by Condition
    # Do nothing. Tricky. Please ignore 
    if ($DO_NOTHING) {
	return 0;	
    }
    # command mode?
    elsif ($command_mode) {
	$Envelope{'pcb:mode'} = 'command'; # process control block

	# NOT PERMIT COMMAND WHEN MAIL SIZE IS OVER LIMIT.
	if ($Envelope{'trap:mail_size_overflow'}) {
	    &Log("ModeBifurcate: ignore too bit mail in command mode");
	    return $NULL;
	}

	
        if ($PERMIT_COMMAND_FROM eq "anyone") {
	    require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
	    &Command() if $ForceKickOffCommand;
	}
	elsif ($PERMIT_COMMAND_FROM eq "members_only" ||
	       $PERMIT_COMMAND_FROM eq "members"
	       ) {
	    if ($member_p) {
		if ($Envelope{'mode:req:unsubscribe-confirm'}) {
		    undef $LOAD_LIBRARY;
		    require 'libfml.pl';
		    &Command($Envelope{'buf:req:unsubscribe-confirm'});
		}
		else {
		    require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
		    &Command() if $ForceKickOffCommand;
		}
	    }
	    # not member and ignore the mail
	    elsif ((! $member_p) && ($REJECT_COMMAND_HANDLER eq "ignore")) {
		&Log("ignore request from not member");
	    }
	    # chaddr-confirm
	    elsif ((! $member_p) && $Envelope{'mode:req:chaddr-confirm'}) {
		&use('trap');
		&Trap__ChaddrConfirm(*Envelope);
	    }
	    # chaddr
	    elsif ((! $member_p) && $Envelope{'mode:req:chaddr'}) {
		&use('trap');
		&Trap__ChaddrRequest(*Envelope);
	    }
	    # we should return reply for "guide" request from even "stranger";
	    elsif ((! $member_p) &&
		   ($Envelope{'mode:req:guide'} || $Envelope{'req:guide'})) {
		&GuideRequest(*Envelope);
	    }
	    # MANUAL REGISTRATION REQUEST WITH CONFIRMATION (subscribe)
	    elsif ((! $member_p) && $Envelope{'mode:req:subscribe'} &&
		   &NonAutoRegistrableP) {
		&Log("manual subscribe request");
		&use('confirm');
		
		&ManualRegistConfirm(*Envelope, 'subscribe',
				     $Envelope{'buf:req:subscribe'});
	    }
	    # MANUAL REGISTRATION REQUEST WITH CONFIRMATION (confirm)
	    elsif ((! $member_p) && $Envelope{'mode:req:confirm'} &&
		   &NonAutoRegistrableP) {
		&Log("manual subscribe confirmed");
		&use('confirm');
		&ManualRegistConfirm(*Envelope, 'confirm',
				     $Envelope{'buf:req:confirm'});
	    }
	    else {
		$fp = $RejectHandler{$REJECT_COMMAND_HANDLER}||"RejectHandler";
		&$fp(*Envelope);
	    }
	}
	elsif ($PERMIT_COMMAND_FROM eq "moderator") { # dummay ?
	    &use('moderated');
	    $Envelope{'mode:moderator:command'} = 1;
	    &ModeratedDelivery(*Envelope); # Moderated: check Approval;
	}
	else {
	    &Log("ERROR: \$PERMIT_COMMAND_FROM is unknown type.");
	}
    }
    # distribute
    else {
	$Envelope{'pcb:mode'} = 'distribute'; # process control block

        if ($PERMIT_POST_FROM eq "anyone") {
	    &Distribute(*Envelope, 'permit from anyone');
	}
	elsif ($PERMIT_POST_FROM eq "members_only" ||
	       $PERMIT_POST_FROM eq "members"
	       ) {
	    if ($member_p) {
		&Distribute(*Envelope, 'permit from members_only');
	    }
	    else {
		$fp = $RejectHandler{$REJECT_POST_HANDLER}||"RejectHandler";
		&$fp(*Envelope);
	    }
	}
	elsif ($PERMIT_POST_FROM eq "moderator") {
	    &use('moderated');
	    &ModeratedDelivery(*Envelope); # Moderated: check Approval;
	}
	else {
	    &Log("ERROR: \$PERMIT_POST_FROM is unknown type.");
	}

	# to ensure the unique Date: (since the smallest unit is second).
	if ($DATE_TYPE =~ /distribute-date/) { sleep 1;}
    }

    &LogFileNewSyslog if $LOGFILE_NEWSYSLOG_LIMIT; # log file turn over
}

####### Section: Main Functions
#
# Configuration Files: evalucation order
#
# 1 site_init      site default
# 2 <ML>/config.ph each ML configurations
# 3 sitedef        force site-own-rules to overwrite ML configrations 
#
sub LoadConfig
{
    # configuration file for each ML
    if (-e "$DIR/config.ph" && ((stat("$DIR/config.ph"))[4] != $<)) { 
	print STDERR "\nFYI: include's owner != config.ph's owner, O.K.?\n\n";
    }

    # 3.0B new loading configuration
    # XXX &__LoadConfiguration('__KERN__'); for main routine: fml.pl, libkern
    # XXX &__LoadConfiguration;             for other tools: bin/* ...
    require 'libloadconfig.pl'; &__LoadConfiguration('__KERN__');

    require 'libsmtp.pl';		# a library using smtp

    # load MIME handling functions for convenience
    if ($LANGUAGE eq 'Japanese') { require 'libMIME.pl';}

    # if mode:some is set, load the default configuration of the mode
    for (keys %Envelope) { 
	/^mode:(\S+)/ && $Envelope{$_} && do { &DEFINE_MODE($1);};
    }
}

sub SetDefaults
{
    $NULL                   = '';    # useful constant :D
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)
    $Envelope{'mode:uip'}   = '';    # default UserInterfaceProgram is nil.;
    $Envelope{'mode:req:guide'} = 0; # not member && guide request only

    $LOCKFILE = "$$ $DIR";	# (variable name is historical, not meaning)

    { # DNS AutoConfigure to set FQDN and DOMAINNAME; 
	local(@n, $hostname, $list);
	chop($hostname = `hostname`); # beth or beth.domain may be possible
	$FQDN = $hostname;
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";
	@n    = split(/\./, $hostname); $hostname = $n[0]; # beth.dom -> beth
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";

	for (split(/\s+/, $list)) { /^$hostname\.\w+/ && ($FQDN = $_);}
	$FQDN       =~ s/\.$//; # for e.g. NWS3865
	$DOMAINNAME = $FQDN;
	$DOMAINNAME =~ s/^$hostname\.//;
    }

    # Architecture Dependence;
    $UNISTD = $HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = $HAS_GETGRENT = 1;
    
    # REQUIRED AS DEFAULTS
    %SEVERE_ADDR_CHECK_DOMAINS = ('or.jp', +1, 'ne.jp', +1);
    $REJECT_ADDR  = 'root|postmaster|MAILER-DAEMON|msgs|nobody';
    $REJECT_ADDR .= '|majordomo|listserv|listproc';
    $REJECT_ADDR .= '|\S+\-subscribe|\S+\-unsubscribe|\S+\-help';
    $SKIP_FIELDS  = 'Received|Return-Receipt-To';
    $ADD_URL_INFO = $ML_MEMBER_CHECK = $CHECK_MESSAGE_ID = $USE_FLOCK = 1;
    $NOTIFY_MAIL_SIZE_OVERFLOW = 1;
    $CHADDR_CONFIRMATION_KEYWORD = 'chaddr-confirm';
    $UNSUBSCRIBE_CONFIRMATION_KEYWORD = 'unsubscribe-confirm';

    # Envelope Filter
    $FILTER_ATTR_REJECT_NULL_BODY = $FILTER_ATTR_REJECT_ONE_LINE_BODY = 1;
    $FILTER_ATTR_REJECT_INVALID_COMMAND = 1;

    ### default distribution and command mode
    $PERMIT_POST_FROM    = $PERMIT_COMMAND_FROM    = "members_only";
    $REJECT_POST_HANDLER = $REJECT_COMMAND_HANDLER = "reject";

    ### fmlserv compat code; (e.g. a bit for umask and permissions ctrl)
    if (-d "$DIR/../fmlserv") { # tricky ;-)
	$USE_FML_WITH_FMLSERV = 1; 
	$GID = (stat("$DIR/../fmlserv"))[5];
    }

    ### Security; default security level (mainly backward compat)
    undef %Permit;

    @DenyProcedure = ('library');
    @HdrFieldsOrder =	# rfc822; fields = ...; Resent-* are ignored;
	('Return-Path', 'Received',
	 'Delivered-To',  # for postfix, qmail
	 'Date', 'Posted', 'X-Posted', 'X-Original-Date',
	 'From', 'Reply-To', 'Subject', 'Sender', 
	 'To', 'Cc', 'Errors-To', 'Message-Id', 'In-Reply-To', 
	 'References', 'Keywords', 'Comments', 'Encrypted',
	 ':XMLNAME:', ':XMLCOUNT:', 'X-MLServer', 
	 'XRef', 'X-Stardate', 'X-ML-Info', 
	 'X-Mailer', 'X-Dispatcher', 'X-Newsreader', 'User-Agent',
	 'Mail-Followup-To',	# I-D now?
	 ':body:', ':any:', 
	 'X-Authentication-Warning',
	 'Mime-Version', 'Content-Type', 'Content-Transfer-Encoding',
	 'Content-ID', 'Content-Description', # RFC2045
	 'Precedence', 'Lines');
    
    # Content Filtering Handler for MIME
    @MailContentHandler = ();	# Default: No filter
}

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
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
    $CurrentTime  = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
    $PCurrentTime = sprintf("%04d%02d%02d%02d%02d%02d", 
			    1900 + $year, $mon + 1, $mday, $hour, $min, $sec);
}

sub InitConfig
{
    &SetDefaults;
    &LoadConfig;

    # XXX SetDefaults but works after &__LoadConfiguration, so defined here.
    # 3.0.1 compatible with 3.0's "From: $MAIL_LIST" rejection
    # disabled by fukachan (2000/06/19), PR8220 pointed out by MURASHITA Takuya
    # &DEFINE_FIELD_LOOP_CHECKED('from');

    # $FML for process table readability
    eval q{ use File::Basename;};
    unless ($@) {
	$ExecDir = dirname($0);
	$FML     = basename($0);
    }
    else {
	if ($0 =~ m%^(.*)/(.*)%) { $ExecDir = $1; $FML = $2;}
    }

    # fml 4.0 modules
    unshift(@INC, "$ExecDir/module/fml-devel");
    unshift(@INC, "$ExecDir/module/CPAN");
    unshift(@INC, "$ExecDir/module/Japanese");
    unshift(@INC, "$ExecDir/module");
    unshift(@INC, $LIBDIR) if $LIBDIR;
    unshift(@INC, $DIR);

    # a little configuration before the action
    if (defined $FML_UMASK) {
	$UMASK = $FML_UMASK;
    }
    elsif (defined $UMASK) {
	;
    }
    elsif ($USE_FML_WITH_FMLSERV) {
	$UMASK = 007; # rw-rw----
    }
    else {
	$UMASK = 077; # rw-------
    }

    umask($UMASK);
    defined $DEFAULT_DIR_MODE || ($DEFAULT_DIR_MODE = ($UMASK & 0777) ^ 0777);

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER! \$MAIL_LIST == \$MAINTAINER, STOP!");
	exit 0;
    }

    # set architechture if not defined
    if (! $COMPA_ARCH) {
	if ($CPU_TYPE_MANUFACTURER_OS =~ /(sysv4|solaris2)/i) {
	    $COMPAT_ARCH = "SOLARIS2";
	}
	elsif ($CPU_TYPE_MANUFACTURER_OS =~ /windowsnt4$/i) {
	    $COMPAT_ARCH = "WINDOWS_NT4";
	}
    }

    ### Options
    &SetOpts;

    # load architecture dependent default 
    # here for command line options --COMPAT_ARCH
    if ($COMPAT_ARCH)  { require "sys/$COMPAT_ARCH/depend.pl";}

    if ($DUMPVAR) { require 'dumpvar.pl'; &dumpvar('main');}
    if ($debug)   { require 'libdebug.pl';}
    if ($Opt{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

    # COMPATIBILITY
    if ($COMPAT_CF1 || ($CFVersion < 2))   { &use('compat_cf1');}
    if ($CFVersion < 3) { &use('compat_cf2');}
    if ($COMPAT_FML15) { &use('compat_cf1'); &use('compat_fml15');}
    if (!$TZone) { $TZone = '+0900';} # TIME ZONE

    &GetTime;			        # Time, (may be for compatible codes)

    push(@MAIL_LIST_ALIASES, @PLAY_TO);
    unshift(@ARCHIVE_DIR, $ARCHIVE_DIR);

    ### Initialize DIR's and FILE's of the ML server
    # FullPath-ed (FP)
    local($s);
    for (SPOOL_DIR,TMP_DIR,VAR_DIR,VARLOG_DIR,VARRUN_DIR,VARDB_DIR) {
	&eval("\$s = \$$_; \$s =~ s#\$DIR/##g; \$s =~ s#$DIR/##g;");
	&eval("\$FP_$_ = \"$DIR/\$s\";");
	&eval("\$$_ =~ s#\$DIR/##g; \$$_ =~ s#\$DIR/##g;");
	&eval("-d \$$_||&Mkdir(\$$_);");
    }

    if ($USE_DATABASE) {
	for ($LOGFILE, $MGET_LOGFILE, 
	     $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	    -f $_ || &Touch($_);
	}	
    }
    else {
	for ($LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	     $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	    -f $_ || &Touch($_);
	}	
    }

    ### CFVersion 3
    ### DEFINE INTERNAL FLAG FOR THE USE $DIR/members or $DIR/actives ?
    ### $ML_MEMBER_CHECK is internal variable to indicate file relation
    local($touch) = "${ACTIVE_LIST}_is_dummy_when_auto_regist";
    if (&AutoRegistrableP) {
	$ML_MEMBER_CHECK = 0;	# backward
	if (&NotUseSeparateListP) {
	    &Touch($touch) if ! -f $touch;
	}
	else {
	    unlink $touch if -f $touch;
	}
    }
    else {
	-f $ACTIVE_LIST || &Touch($ACTIVE_LIST);
	unlink $touch if -f $touch;
    }

    if ($SUBJECT_TAG_TYPE) { 
	&use("tagdef");
	&SubjectTagDef($SUBJECT_TAG_TYPE);
    }
    ### END CFVersion 3

    ### misc 
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$VARRUN_DIR/msgidcache";#important;
    $LOG_MAILBODY_CKSUM = $LOG_MAILBODY_CKSUM || "$VARRUN_DIR/bodycksumcache";
    $REJECT_ADDR_LIST = $REJECT_ADDR_LIST || "$DIR/spamlist";
    $FML .= "[".(split(/\@/, $MAIL_LIST))[0]."]"; # For tracing Process Table

    # initialize some arrays; if auto-regist is clear here, we reset;
    &AdjustActiveAndMemberLists;
    
    # since variables are defined in config.ph;
    @NEWSYSLOG_FILES =	@NEWSYSLOG_FILES ||
	("$MSEND_RC.bak", "$MEMBER_LIST.bak", "$ACTIVE_LIST.bak");

    # struct sockaddr { ;}
    $STRUCT_SOCKADDR = $STRUCT_SOCKADDR || "S n a4 x8";
    
    # &BackwardCompat;
    &DEFINE_MODE('expire')  if $USE_EXPIRE;  # 2.1 release built-in expire
    &DEFINE_MODE('archive') if $USE_ARCHIVE; # 2.1 release built-in archive;
    &DEFINE_MODE('html')    if $AUTO_HTML_GEN;

    # command trap keywrod : '# ' ; in default, we not use it.
    # XXX: "# command" is internal represention
    # XXX: it is historical, so remove '# command' part if exist and possible.
    $Envelope{'trap:ctk'} = &CompatFMLv1P ? '# ' : '';
    
    # signal handling
    $SIG{'ALRM'} = 'Tick';
    $SIG{'INT'}  = $SIG{'QUIT'} = $SIG{'TERM'} = 'SignalLog';
    
    # MIME Content Handler(include backword compatible)
    if ($AGAINST_HTML_MAIL ||
	$HTML_MAIL_DEFAULT_HANDLER eq 'strip') {
	&ADD_CONTENT_HANDLER('multipart/.*', 'text/plain', 'allow');
	&ADD_CONTENT_HANDLER('multipart/.*', '.*/.*',      'strip');
	&ADD_CONTENT_HANDLER('text/plain',   '.*/.*',      'allow');
	&ADD_CONTENT_HANDLER('!MIME',        '.*/.*',      'allow');
    } elsif ($HTML_MAIL_DEFAULT_HANDLER eq 'reject') {
	&ADD_CONTENT_HANDLER('multipart/.*', 'text/plain', 'allow');
	&ADD_CONTENT_HANDLER('multipart/.*', '.*/.*',      'reject');
	&ADD_CONTENT_HANDLER('text/plain',   '.*/.*',      'allow');
	&ADD_CONTENT_HANDLER('!MIME',        '.*/.*',      'allow');
    }

    # For example, $LOGFILE_SUFFIX = ".%C%y";
    if ($LOGFILE_SUFFIX) {
	use POSIX;
	$LOGFILE .= strftime($LOGFILE_SUFFIX, localtime(time));
    }
}

# one pass to cut out the header and the body
sub Parsing { &Parse;}
sub Parse
{
    $0 = "${FML}: Parsing header and body <$LOCKFILE>";
    local($bufsiz, $buf, $p, $maxbufsiz, $in_header);

    $maxbufsiz = &ATOI($INCOMING_MAIL_SIZE_LIMIT) if $INCOMING_MAIL_SIZE_LIMIT;

    undef $Envelope{'Body'};
    $in_header = 1; # firstly header comes.
    while ($p = sysread(STDIN, $_, 1024)) {
	$bufsiz += $p; 

	if ($INCOMING_MAIL_SIZE_LIMIT && ($bufsiz > $maxbufsiz)) {
	    $Envelope{'trap:mail_size_overflow'} = 1;
	    last;
	}

	$Envelope{'Body'} .= $_;

	if ($in_header) {
	    # separator between header and body is found!
	    if (($p = index($Envelope{'Body'}, "\n\n", 0)) > 0) {
		$Envelope{'Header'} = substr($Envelope{'Body'}, 0, $p + 1);
		$Envelope{'Body'}   = substr($Envelope{'Body'}, $p + 2);
		$in_header = 0;
	    }
	}
    }

    # oops, header only mail ?! (2000/05/31 by fukachan)
    if ($in_header) {
	$Envelope{'Header'} = $Envelope{'Body'};
	undef $Envelope{'Body'};
    }

    # Really? but check "what happen if no input is given?".
    if ($bufsiz == 0) {
	&Log("read 0 bytes, stop");
	exit(0);
    }
    $Envelope{'tmp:bufsiz'} = $bufsiz;

    # hold size info at process control block
    $Envelope{ _pcb }->{ incoming_message }->{ total_read_size } = $bufsiz;
}

# Phase 2 extract several fields 
sub GetFieldsFromHeader
{
    local($field, $value, @hdr, %hf);
    local($s);

    $0 = "${FML}: GetFieldsFromHeader <$LOCKFILE>";

    # To ensure non exsistence
    for (split(/\|/, $SKIP_FIELDS)) { &DELETE_FIELD($_);}

    # pass all fields through
    if ($SUPERFLUOUS_HEADERS || $PASS_ALL_FIELDS_IN_HEADER) { 
	$hdr_entry = join("|", @HdrFieldsOrder);
    }

    ### Header Fields Extraction
    $s = $Envelope{'Header'}."\n";
    $* = 0;			# match one line
    if ($s =~ /^From\s+(\S+)/i) {
	# XXX NO REACH HERE (1999/10/27 by fukachan)
	# $Envelope{'UnixFrom'} = $UnixFrom = $1;
	$s =~ s/^From\s+.*//i;
    }

    $s = "\n".$s;		# tricky
    if ($ALLOW_WRONG_LINES_IN_HEADER){
	$s =~ s/(?<=\n)(?=:|[^\s:]+\s)/X-Wrong-Lines: /sg;
    }
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.
    $s =~ s/^\n*//;		# remove the first null lines;

    @hdr = split(/\n\n/, $s);
    while (@hdr) {
	$_ = $field = shift @hdr;
	last if /^[\s\n]*$/;	# null field must be end
	$value = shift @hdr;	# not cut the first spaces of $value

	print STDERR "FIELD>$field<\n     >$value<\n" if $debug;

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/;
	$hf{$field} = 1;
	$Envelope{$field} .= $Envelope{$field} ? "\n${_}$value" : $value;

	# e.g. ONLY multiple Received: are possible.
	# "Cc: ..\n Cc: ..\n" also may exist
	$Envelope{"h:$field"} .= 
	    $Envelope{"h:$field"} ? "\n${_}$value" : $value;

	next if /^($SKIP_FIELDS):/i;

	# hold fields without in use_fields if $SUPERFLUOUS_HEADERS is 1.
	if ($SUPERFLUOUS_HEADERS || $PASS_ALL_FIELDS_IN_HEADER) {
	    next if /^($hdr_entry)/i; # :\w+: not match
	    $Envelope{'Hdr2add'} .= "${_}$value\n";
	}
    }

    ### Anyway set all the fields (96/09/24) ###
    local($f, $fc, $k, $v, $x);
    while (($k, $v) = each %hf) {
	$_ = &FieldCapitalize($k);
 	$Envelope{"h:$_"} = $Envelope{"h:$k"};
    }

    ### fix Unix From
    if (! $Envelope{'UnixFrom'}) { # == !$UnixFrom
	$UnixFrom = $Envelope{'h:return-path:'} || $Envelope{'h:From:'} ||
	    "postmaster\@$FQDN";
	$UnixFrom = $Unix_From = $Envelope{'UnixFrom'} = 
	    &Conv2mailbox($UnixFrom, *Envelope);
    }
}

# LATTER PART is to fix extracts
# Set variables to need special effects 
sub FixHeaderFields
{
    local(*e) = @_;
    local($addr);

    ### MIME: IF USE_LIBMIME && MIME-detected;
    if ($USE_MIME && $e{'Header'} =~ /=\?ISO\-2022\-JP\?/io) {
	$e{'MIME'}= 1;
    }

    ### $MAIL_LIST Aliases 
    $addr = "$e{'h:recent-to:'}, $e{'h:to:'}. $e{'h:cc:'}";
    for (@MAIL_LIST_ALIASES) {
	next unless $_;
        if ($addr =~ /$_/i) { $MAIL_LIST = $_;}
    }

    $e{'h:Return-Path:'} = "<$MAINTAINER>";        # needed?
    $e{'h:Precedence:'}  = $PRECEDENCE || 'list';
    # $e{'h:Lines:'}     = $e{'nlines'}; now in CheckCurrentProc (97/12/07)

    # Date: field type definition
    if ($DATE_TYPE eq 'original-date') {
	$e{'h:Date:'} = $e{'h:date:'};
    }
    elsif ($DATE_TYPE eq 'received-date+x-posted') {
	$e{'h:Date:'}     = $MailDate;
	$e{'h:X-Posted:'} = $e{'h:date:'} || $e{'h:Date:'};
    }
    elsif ($DATE_TYPE eq 'received-date+x-original-date') {
	$e{'h:Date:'}     = $MailDate;
	$e{'h:X-Original-Date:'} = $e{'h:date:'} || $e{'h:Date:'};
    }
    elsif (($DATE_TYPE eq 'received-date') ||
	   ($DATE_TYPE eq 'received-date+posted') ||
	   (!$DATE_TYPE)) { # default (backward)
	$e{'h:Date:'}   = $MailDate;
	$e{'h:Posted:'} = $e{'h:date:'} || $e{'h:Date:'};
    }

    # Some Fields need to "Extract the user@domain part"
    # Addr2Reply: is used to pass to sendmail as the recipient
    $From_address        = &Conv2mailbox($e{'h:from:'}, *e);
    $e{'macro:x'}        = $e{'tmp:x'}; 
    &Log("Gecos [$e{'macro:x'}]") if $debug;

    # XXX should we nuke $COMMAND_RETURN_ADDR_POLICY ?
    if ($COMMAND_RETURN_ADDR_POLICY eq 'from' ||
	$MESSAGE_RETURN_ADDR_POLICY eq 'from') {
	$e{'Addr2Reply:'} = $From_address;
    }
    else { # $MESSAGE_RETURN_ADDR_POLICY eq 'reply-to'
	$e{'Addr2Reply:'} = &Conv2mailbox($e{'h:reply-to:'},*e)||$From_address;
    }

    # KAKUSHI(SECRET) OPTION :) (UNDER DEVELOPMENT)
    # use Return-Path: as the sender for authentication
    if ($SENDER_AUTH_TYPE eq 'strict-envelope-from') {
	$_ = &Conv2mailbox($Envelope{'h:return-path:'}, *e);
	if ($_) {
	    $From_address = $_;
	}
	else {
	    &Log("\$SENDER_AUTH_TYPE eq 'strict-envelope-from'");
	    &Log("INVALID Return-Path:<$_>");
	    &Mesg(*e, "YOU ARE NOT A MEMBER!");
	    &Mesg(*e, $NULL, 'not_member');
	    $DO_NOTHING = 1;
	}

    }
    elsif ($SENDER_AUTH_TYPE eq 'envelope-from-or-from') {
	for ($UnixFrom, $From_address) {
	    &MailListMemberP($_) && ($From_address = $_, last);
	}
    }

    # To: $MAIL_LIST for readability;
    # &RewriteField(*e, 'Cc') unless $NOT_REWRITE_CC;
    if ($REWRITE_TO < 0) { 
	; # pass through for the use of this flag when $CFVersion < 3.;
    }
    elsif ($CFVersion < 3.1) { # 3.1 is 2.1A#8 (1997/10/14) 
	$REWRITE_TO = $NOT_REWRITE_TO ? 0 : 1; # 2.1 release default;
    }
    
    &Log("REWRITE_TO $REWRITE_TO") if $debug;
    if ($REWRITE_TO == 2) {
	$e{'h:To:'} = "$MAIL_LIST $ML_FN"; # force the original To: to pass
    }
    elsif ($REWRITE_TO == 1) {
	# To: $MALI_LIST, plus original To: ...
	$e{'h:To:'} = "$MAIL_LIST $ML_FN";
	&RewriteField(*e, 'To');
    }
    elsif ((!$REWRITE_TO) || $REWRITE_TO < 0) {
	; # do nothing, pass through
    }

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) (THIS IS REQUIED ANY TIME, ISN'T IT? but...)
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if ($_ = $e{'h:Subject:'}) {
	if ($STRIP_BRACKETS || 
	    $SUBJECT_FREE_FORM_REGEXP || $SUBJECT_HML_FORM) {
	    if ($e{'MIME'}) { # against cc:mail ;_;
		&use('MIME'); 
		&StripMIMESubject(*e);
	    }
	    else { # e.g. Subject: [Elena:003] E.. U so ...;
		print STDERR "IN: $_\n" if $debug;
		$e{'h:Subject:'} = &StripBracket($_);
		print STDERR "OUT: $e{'h:Subject:'}\n" if $debug;
	    }
	} 
	# Even if pass through, always strip of Re:* 
	else {
	    $e{'h:Subject:'} = &CutOffRe($_);
	}
    }

    # Obsolete Errors-to:, against e.g. BBS like a nifty
    if ($USE_ERRORS_TO) {
	$e{'h:Errors-To:'} = $ERRORS_TO || $MAINTAINER;
    }
    else { # delete obsolete fields;
	&DELETE_FIELD('Errors-To');
    }

    # Set Control-Address for reply, notify and message
    $e{'CtlAddr:'} = &CtlAddr;

    ### USER MACROS: &COPY_FIELD(old, new);
    local($old, $new);
    while (($old,$new) = each %HdrFieldCopy) {
	&Debug("COPY_FIELD: \$e{\"h: $old => $new\"}") if $debug;
	$e{"h:$new:"} = $e{"h:$old:"};
	$e{"h:$new:"} =~ s/\n$old:/\n$new:/gi;
    }
}

sub FieldCapitalize
{	
    local($_) =  @_;
    s/^(\w)/ $x = $1, $x =~ tr%a-z%A-Z%, $x/e;
    s/(\-\w)/$x = $1, $x =~ tr%a-z%A-Z%, $x/eg;
    $_ =~ s/^X-ML-/X-ML-/i; # X-ML- is an exception. to avoid dup of X-M{L,;}
    $_;
}

sub StripBracket
{
    local($_) = @_;
    local($pat);

    if ($SUBJECT_FREE_FORM_REGEXP) {
	$pat = $SUBJECT_FREE_FORM_REGEXP;
    }
    else { # default;
	# pessimistic ?
	if (! $BRACKET) { ($BRACKET) = split(/\@/, $MAIL_LIST);}

	$pat = "\\[$BRACKET:\\d+\\]";
    }

    # cut out all the e.g. [BRACKET:\d] form;
    s/$pat//g;

    $_ = &CutOffRe($_);
}

sub CutOffRe
{
    local($_) = @_;
    local($pattern);

              #  Re: Re2:   Re[2]:     Re(2):     Re^2:    Re*2:
    $pattern  = 'Re:|Re\d+:|Re\[\d+\]:|Re\(\d+\):|Re\^\d+:|Re\*\d+:';
    s/^(\s*($pattern)\s*)+/Re: /oi;

    if ($LANGUAGE eq 'Japanese') { 
	require("module/$LANGUAGE/liblangdep.pl");
	$_ = &Japanese'CutOffReReRe($_);
    }

    $_;
}

sub CheckCurrentProc
{
    local(*e, $ccp_mode) = @_;
    
    # log
    &Log("read $e{'tmp:bufsiz'} bytes") if $debug_fml_org;
    undef $e{'tmp:bufsiz'};

    ### SubSection: Log socket connection info
    &eval("&use('kernsubr2'); &GetPeerInfo;") if $LOG_CONNECTION;

    ### SubSection: Check Body Contents (For Command Mode)
    local($limit, $p, $buf, $boundary, $nclines, $cc);

    ### SubSection: MIME info
    # MIME skip mode; against automatic-MIME-encapsulated fool MUA
    if ($e{'h:content-type:'} =~ /boundary=\"(.*)\"/i ||
	$e{'h:content-type:'} =~ /boundary=\s*(\S+)/i) {
	$boundary = $1;
	$boundary = "--$boundary";
	$e{'MIME:boundary'} = $boundary;
    }
    elsif ($e{'h:content-type:'} =~ /multipart/i) {
	&Log("cannot get boundary string of Content-Type");
	&Log("Content-Type: $e{'h:content-type:'}");
    }

    ### SubSection: Check command in mail body
    # the range to scan
    $limit =  $GUIDE_CHECK_LIMIT > $COMMAND_CHECK_LIMIT ? 
	$GUIDE_CHECK_LIMIT  : $COMMAND_CHECK_LIMIT;

    ## QMAIL command hook
    ## dot-qmail(5) ~alias/.uja-default emulates uja-help@domain ("-> #help")
    if ($USE_DOT_QMAIL_EXT && 
	(!&AddressMatch($MAIL_LIST, $ENV{'RECIPIENT'}))) { 
	&Log("sets in dot-qmail-ext") if $debug_qmail;
	&use('qmail'); 
	&DotQmailExt(*Envelope);
    }

    # search the location of $limit's "\n";
    $limit += 10; # against MIME
    $p = 0;
    while ($limit-- > 0) { 
	if (index($e{'Body'}, "\n", $p + 1) > 0) {
	    $p = index($e{'Body'}, "\n", $p + 1);
	}
	else {
	    last;
	}
    }
    # +1 for the last "\n";
    $buf = substr($e{'Body'}, 0, $p > 0 ? $p+1 : 1024);

    # check only the first $limit lines.
    local($found, $mime_skip);
    for (split(/\n/, $buf)) {
	print STDERR "INPUT BUF> $_\n" if $debug;

	# subscribe trap
	# XXX: "# command" is internal represention
	# XXX: remove '# command' part if exist
	if (/^(\s*|\#\s*)$CONFIRMATION_SUBSCRIBE\s+/i) {
	    $e{'mode:req:subscribe'} = 1;
	    $e{'buf:req:subscribe'} .= $_."\n";
	}

	if ($CHADDR_AUTH_TYPE eq 'confirmation' &&
	    (/^(\s*|\#\s*)$CHADDR_KEYWORD\s+/i)) {
	    $e{'mode:req:chaddr'} = 1;
	    $e{'buf:req:chaddr'} .= $_."\n";
	}

	# chaddr-confirm trap (may be with citatin e.g. ">")
	if ($CHADDR_AUTH_TYPE eq 'confirmation' &&
	    /$CHADDR_CONFIRMATION_KEYWORD\s+\S+/i) {
	    $e{'mode:req:chaddr-confirm'} = 1;
	    $e{'buf:req:chaddr-confirm'} .= $_."\n";
	}
	# confirm trap (may be with citatin e.g. ">")
	elsif (/$CONFIRMATION_KEYWORD\s+\S+/i) {
	    $e{'mode:req:confirm'} = 1;
	    $e{'buf:req:confirm'} .= $_."\n";
	}

	# unsubscribe-confirm ID
	if (/($UNSUBSCRIBE_CONFIRMATION_KEYWORD\s+\S+.*)/i) {
	    $e{'buf:req:unsubscribe-confirm'} .= $1."\n";
	    $e{'mode:req:unsubscribe-confirm'} = 1;
	}

	if ($boundary) { # if MIME skip mode;
	    if ($_ eq $boundary) { $found++; $mime_skip++; next;}
	    if (/^Content-Type:/i && $mime_skip) { next;}
	    # skip the null line after the first MIME separator
	    if ($mime_skip) { $mime_skip = 0; next;} 
	}

	# skip before the first MIME boundary
	next if $boundary && !$found;

	$cc++;
	print STDERR " SCAN BUF> $_ ($cc line)\n\n" if $debug;

	# DO NOT "skip useless checks (2.23?)"
	# which we uses in the "guide" request check from a stranger.
	# if (! $e{'trap:ctk'}) {
	#    print STDERR "  -skip fml rel. 1 compatible scan\n" if $debug;
	#    next;
	# }

	# Guide Request from the unknown
	if ($GUIDE_CHECK_LIMIT-- > 0) { 
	    $e{'mode:req:guide'} = 1 if /^\#\s*$GUIDE_KEYWORD\s*$/i;

	    # accept 'guide' under --ctladdr;
	    $e{'mode:req:guide'} = 1
		if $e{'mode:ctladdr'} && /^\s*$GUIDE_KEYWORD\s*$/i;
	}

	# Command or not is checked within the first 3 lines.
	# '# help\s*' is OK. '# guide"JAPANESE"' & '# JAPANESE' is NOT!
	# BUT CANNOT JUDGE '# guide "JAPANESE CHARS"' SYNTAX;-);
	if ($COMMAND_CHECK_LIMIT-- > 0) { 
	    $e{'mode:uip'} = 'on'    if /^\#\s*[\w\-]+\s|^\#\s*[\w\-]+$/;
	    $e{'mode:uip:chaddr'} = $_ 
		if /^\#\s*($CHADDR_KEYWORD)\s+/i;
	    $e{'mode:uip:chaddr-confirm'} = $_ 
		if /^\#\s*($CHADDR_CONFIRMATION_KEYWORD)\s+/i;
	}

	$nclines++ if /^\#/o;    # the number of command lines
    }

    ### close(STDIN); # close(STDIN) prevents open2, really?

    $e{'nlines'}  = ($e{'Body'} =~ tr/\n/\n/);
    $e{'nclines'} = $nclines;
    $e{'size'}    = $bufsiz;
    $e{'h:Lines:'} = $e{'nlines'};

    ### SubSection: special trap
    return 0 if $CheckCurrentProcUpperPartOnly;
    return 0 if $ccp_mode eq 'upper_part_only';

    ### SubSection: MailBody Size
    if ($e{'trap:mail_size_overflow'}) {
	&use('error');
	&NotifyMailSizeOverFlow(*e);

	if ($ANNOUNCE_MAIL_SIZE_OVERFLOW) {
	    &AnnounceMailSizeOver(*e); # call &Distribute;
	}
	else {
	    $DO_NOTHING = 1;
	    return $NULL;
	}
    }

    # Against a lot of mails for MIME partial, e.g. Outlook
    # Content-Type: message/partial; number=1; total=6; ...
    if ($e{'h:content-type:'} =~ /\/partial\s*;/ && 
	$INCOMING_MAIL_SIZE_LIMIT) {
	local($n, $total, $bufsiz);

	$e{'h:content-type:'} =~ s/number=(\d+)/$n = $1/e;
	$e{'h:content-type:'} =~ s/total=(\d+)/$total = $1/e;
	$bufsiz = length($Envelope{'Body'}) * $total;

	if ($bufsiz > &ATOI($INCOMING_MAIL_SIZE_LIMIT)) {
	    &Log("reject for too large size mail");
	    &Log("partial message's <$n/$total> total mail size seems too large");
	    &Log("evaluated whole size $bufsiz > \$INCOMING_MAIL_SIZE_LIMIT[$INCOMING_MAIL_SIZE_LIMIT]");

	    # WARNING in n ==1 partial case.
	    if ($n == 1 && $NOTIFY_MAIL_SIZE_OVERFLOW) {
		&use('error');
                &NotifyMailSizeOverFlow(*e);
	    } 

	    if ($n == 1 && $ANNOUNCE_MAIL_SIZE_OVERFLOW) {
		&use('error');
		&AnnounceMailSizeOver(*e); # call &Distribute;
	    }
	    else {
		$DO_NOTHING = 1;
	    }
	}
	else {
	    &Log("partial message but the whole size seems enough small")
		if $debug;
	}
    }

    ### SubSection: Access Control based on address
    ## WE SHOULD REJCECT "CANNOT IDENTIFIED AS PERSONAL" ADDRESSES;
    ##   In addition, we check another atack possibility;
    ##      e.g. majorodmo,listproc,list-subscribe <-> fml-ctl 
    if ($REJECT_ADDR && $From_address =~ /^($REJECT_ADDR)\@(\S+)/i) {
	local($addr, $domain) = ($1, $2);
	&Log("reject mail from $addr\@$domain");
	&WarnE("reject mail from $addr\@$domain", 
	       "reject mail from $addr\@$domain\n");
	$DO_NOTHING = 1;
	return 0;
    }

    # XXX reject all "From: MAIL_LIST" mails (3.0)
    # XXX fix for 3.0.1
    # XXX controllable by %LOOP_CHECKED_HDR_FIELD.
    if (%LOOP_CHECKED_HDR_FIELD) {
	my($f, $v);

	for $f (keys %LOOP_CHECKED_HDR_FIELD) {
	    next unless $LOOP_CHECKED_HDR_FIELD{$f};
	    if ($v = $e{"h:${f}:"}) {
		$v = &Conv2mailbox($v);
		if (&LoopBackWarn($v)) {
		    &Log("$f: <$v> may cause loop. rejected");
		    &WarnE("reject mail $f:<$v>",
			   "rejected since '$f' header\n".
			   "may cause mail loop.\n".
			   "${f}: ".
			   $e{"h:${f}:"}.
			   "\n");
		    $DO_NOTHING = 1;
		    return 0;
		}
	    }
	}
    }

    ## security level (?)
    while (($k, $v) = each %SEVERE_ADDR_CHECK_DOMAINS) {
	print STDERR "/$k/ && ADDR_CHECK_MAX += $v\n" if $debug; 
	($From_address =~ /$k/) && ($ADDR_CHECK_MAX += $v);
    }

    # AGAINST SPAM MAILS
    if (-f $REJECT_ADDR_LIST) {
	if (&RejectAddrP($From_address) ||
	    &RejectAddrP($UnixFrom)) {
	    $s="Reject spammers: UnixFrom=[$UnixFrom], From=[$From_address]";
	    &WarnE("Spam mail from a spammer is rejected $ML_FN",
		  "Reject Spammers:\n".
		  "   UnixFrom\t$UnixFrom\n   From\t\t$From_address\n");
	    &Log($s);
	    $DO_NOTHING = 1;
	    return 0;
	}
    }

    ### SubSection: misc
    ### For CommandMode Check(see the main routine in this flie)
    $e{'trap:rcpt_fields'}  = $e{'h:to:'} || $e{'h:apparently-to:'};
    $e{'trap:rcpt_fields'} .= ", $e{'h:Cc:'}, ";
    $e{'trap:rcpt_fields'}  =~ s/\n(\s+)/$1/g;

    # SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS && $e{'h:Subject:'}) {
	local($_) = $e{'h:Subject:'};
	s/^\s*//;

	$e{'mode:req:guide'}++ if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	$e{'mode:uip'} = 'on'  if /^\#\s*[\w\-]+\s|^\#\s*[\w\-]+$/;
	$e{'mode:req:guide'}++          
	    if $COMMAND_ONLY_SERVER && /^\s*$GUIDE_KEYWORD\s*$/i;
	$e{'mode:uip'} = 'on' 
	    if $COMMAND_ONLY_SERVER && /^\s*[\w\-]+\s|^\s*[\w\-]+$/;
    }    

    # ? for --distribute, here and again in &MLMemberCheck; 
    &AdjustActiveAndMemberLists;

    ### SubSection: debug info dump
    if ($debug) { &eval(&FieldsDebug, 'FieldsDebug');}

    ### SubSection: Mail Loop Check
    ## LOOP CHECK PHASE 1: Message-Id
    if ($CHECK_MESSAGE_ID && &DupMessageIdP) { exit 0;}

    ## LOOP CHECK PHASE 2
    # now before flock();
    if ((! $NOT_USE_UNIX_FROM_LOOP_CHECK) && 
	&AddressMatch($UnixFrom, $MAINTAINER)) {
	&Log("WARNING: UNIX FROM Loop[$UnixFrom == $MAINTAINER]");
	&WarnE("WARNING: UNIX FROM Loop",
	      "UNIX FROM[$UnixFrom] == MAINTAINER[$MAINTAINER]\n\n");
	exit 0;
    }

    ### SubSection: Address Test Mode; (Become Test Mode)
    if ($Opt{"opt:b"} eq 't') { 
	$DO_NOTHING = 1; &Log("Address Test Mode:Do nothing");
    } 

    ### SubSection: Crosspost emulation
    # Check crosspost in To: and Cc:
    if ($USE_CROSSPOST) { &use('crosspost');}
}

# We REWRITED To: to "To: MAIL_LIST" FOR MORE READABILITY;
# Check the To: and overwrite it;
# if To: has $MAIL_LIST, ok++; IF NOT, add $MAIL_LIST to To:
sub RewriteField
{
    local(*e, $ruleset) = @_;
    local($f) = 'RuleSetTo' if $ruleset eq 'To';
    $f ? &$f(*e) : &Log("RewriteField: unknown ruleset $ruleset");
}

# 2000/11/17 version is modified to use Mail::Address.pm 
# based on the patch by OGAWA Kunihiko <kuni@edit.ne.jp>
sub RuleSetTo
{
    local(*e) = @_;
    local($ok, $match, $addr, $x_addr, $ml, $buf, $to);
    local(@ml) = ($MAIL_LIST, @MAIL_LIST_ALIASES); # PLAY_TO Trick;

    eval "require Mail::Address; Mail::Address->import();";

    # if fails, call fml 3.0 compatible routine.
    if ($@ ne '') {
	&Log("WARN: Mail::Address.pm not works well");
	&Log("disable RuleSetTo function");
	return $NULL;
    }

    # search $MALI_LIST (+ aliases) contained in To: ?
    $to = $e{'h:to:'};
    $to =~ s/\s*To: /, /gi;
    for $addr (Mail::Address->parse($to)) {
	$x_addr = $addr->format;
	$addr   = $addr->address;
	$match  = 0;

	# match one of $MALI_LIST ?
	for $ml (@ml) { 
	    # ignore $MALI_LIST (or aliases) addresses to avoid noisy To;)
	    if (&AddressMatch($addr, $ml)) { $ok++; $match = 1;}
	}

	# IF NOT match one of $MAIL_LIST,
	# gobble not $MALI_LIST address to $buf
	if (! $match) {
	    $buf .= $buf ? ", ". $addr : $addr;
	    &Log("RuleSetTo: buf = {$buf}") if $debug;
	}
    }

    if ($buf) {
	$e{'h:To:'} .= $e{'h:To:'} ? "\n\t,".$buf : $buf;
    }
}

# Expand mailbox in RFC822
# From_address is user@domain syntax for e.g. member check, logging, commands
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
#
# macro:x is moved to FixHeaderFields (97/05/07 fukui@sonic.nm.fujitsu.co.jp)
#
# 2000/11/17 version is modified to use Mail::Address.pm 
# based on the patch by OGAWA Kunihiko <kuni@edit.ne.jp>
sub Conv2mailbox
{
    local($mb, *e) = @_;	# original string
    local($addr);

    eval "require Mail::Address; Mail::Address->import();";

    # if fails, call fml 3.0 compatible routine.
    if ($@ ne '') {
	&Log($@);
	&Log("WARN: Mail::Address.pm not works well");
	return &__Conv2mailbox30($mb, *e);
    }

    # NULL is given, return NULL
    ($mb =~ /^\s*$/) && (return $NULL);

    ($addr) =  (Mail::Address->parse($mb))[0];
    return $NULL unless $addr;

    $e{'tmp:x'} = $addr->phrase . $addr->comment;
    return $addr->address;
}

sub __Conv2mailbox30
{
    local($mb, *e) = @_;	# original string

    # return NULL if addr does not contain @. ?
    # return $NULL unless $mb =~ /\@/;

    # $mb = &Strip822Comments($mb);

    # NULL is given, return NULL
    ($mb =~ /^\s*$/) && (return $NULL);

    # RFC822 unfolding and cut the first SPACE|HTAB;
    $mb =~ s/\n(\s+)/$1/g;
    $mb =~ s/^\s*//;

    # Hayakawa Aoi <Aoi@aoi.chan.panic>
    if ($mb =~ /^\s*(.*)\s*<(\S+)>.*$/io) { $e{'tmp:x'} = $1; return $2;}

    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
    if ($mb =~ /^\s*(\S+)\s*\((.*)\)$/io || $mb =~ /^\s*(\S+)\s*(.*)$/io) {
	$e{'tmp:x'} = $2, return $1;	
    }

    # Aoi@aoi.chan.panic
    return $mb;
}	

# When just guide request from unknown person, return the guide only
# change reply-to: for convenience
sub GuideRequest
{
    local(*e) = @_;
    local($ap);

    if ($debug) { @c=caller; &Log("GuideRequest called from $c[2]");}

    &Log("Guide request");

    $e{'GH:Reply-To:'} = $e{'CtlAddr:'}; 
    &SendFile($e{'Addr2Reply:'}, "Guide $ML_FN", $GUIDE_FILE);
}

# MAIL_LIST == CONTROL_ADDRESS or !CONTROL_ADDRESS ?
# ATTENTION! 
#   if cf == 3, !$CONTROL_ADDRESS IS JUST "distribute only"
#   if cf  < 2, !$CONTROL_ADDRESS => Command($MAIL_LIST==$CONTROL_ADDRESS)
sub CompatFMLv1P
{
    local($ml) = split(/\@/, $MAIL_LIST); 
    local($ca) = split(/\@/, $CONTROL_ADDRESS);

    if ($CFVersion < 3) { return &CF2CompatFMLv1P($ca, $ml);}

    # Version 3, criterion is only "MAIL_LIST == CONTROL_ADDRESS"
    $ml eq $ca && return 1;
    $MAIL_LIST eq $CONTROL_ADDRESS && return 1;

    # Version 3, compat mode for before FML 2.1 
    $MAIL_LIST_ACCEPT_COMMAND && return 1;

    0;
}

# Distribute mail to members (fml.pl -> libdist.pl)
sub Distribute
{
    local(*e, $mode, $compat_hml) = @_;
    local($ml) = (split(/\@/, $MAIL_LIST))[0];

    # Japanese specific: convert hankaku to zenkaku
    if ($USE_HANKAKU_CONVERTER) {
	if ($LANGUAGE eq 'Japanese') { 
	    require("module/$LANGUAGE/libhankaku2zenkaku.pl");
	    eval &FixJapaneseMDChars(*e);
	    &Log($@) if $@;
	}
    }

    # Filtering mail body from members but not check other cases
    # e.g. null body subscribe request in "no-keyword" case
    if ($USE_DISTRIBUTE_FILTER) {
	&EnvelopeFilter(*e, 'distribute');
	return $NULL if $DO_NOTHING;
    }

    # check duplication baesd on mailbody MD5 cksum cache
    if ($CHECK_MAILBODY_CKSUM) {
	&use('cksum');

	if (&CheckMailBodyCKSUM(*e)) {
	    # looped !
	    $DO_NOTHING = 1;
	    return $NULL;
	}
	else {
	    # not looped ! O.K. now cache on for the future
	    &CacheMailBodyCksum(*e);
	}
    }

    # Cut off multipart or reject by mail's Content-Type handler
    # The existence of $AGAINST_HTML_MAIL and $HTML_MAIL_DEFUALT_HANDLER
    # are backward compatible.
    if (@MailContentHandler > 0) {
	&use('disthack'); 
    	my ($status) = &ContentHandler(*e);
	if ($status eq 'reject') { return $NULL;}
    }

    # Security: Mail Traffic Information
    if ($USE_MTI) { 
	&use('mti'); 
	&MTICache(*e, 'distribute');
	return $NULL if &MTIError(*e);
    }

    if ($debug) { @c = caller; &Log("Distritute called from $c[2] ");}

    if ($mode eq 'permit from members_only') {
	$Rcsid .= "; post only (only members can post)";
    }
    elsif ($mode eq 'permit from anyone') {
	$Rcsid .= "; post only (anyone can post)"; 
    }
    elsif ($mode eq 'permit from moderator') {
	$Rcsid =~ s/^(.*)(\#\d+:\s+.*)/$1."(moderated mode)".$2/e;
	undef $e{'h:approval:'}; # delete the passwd entry;
	undef $e{'h:Approval:'}; # delete the passwd entry;
    }
    ### NOT REMOVE FOR BACKWARD?
    else {
	$Rcsid .= "; post + commands (members only)"; # default ;
    }

    if ($MAIL_LIST eq $CONTROL_ADDRESS) {
        $Rcsid =~ s/post only (from.*)/post $1 + commands/;
    }


    # Dabasase access: dump recipients
    if ($USE_DATABASE) {
	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, 'dump_active_list');
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc);
	&Log("fail to dump active list") if $mib{'error'};
	return $NULL if  $mib{'error'};

	# tricky but effective 
	# we push cache file to recipient lists, so that
	# @ACTIVE_LIST = ($ACTIVE_LIST, $mib{'_cache_file'});
	push(@ACTIVE_LIST, $mib{'_cache_file'}) if -f $mib{'_cache_file'};
	&Log("ACTIVE = ( @ACTIVE_LIST )") if $debug;
    }

    require 'libdist.pl';
    &DoDistribute(*e);	
}

sub RunStartHooks
{
    $0 = "${FML}: RunStartHooks <$LOCKFILE>";

    # additional before action
    $START_HOOK && &eval($START_HOOK, 'Start hook');

    for (keys %FmlStartHook) {
	print STDERR "Run StartHook $_ -> $FmlStartHook{$_}\n" if $debug;
	next unless $FmlStartHook{$_};
	$0 = "${FML}: Run FmlStartHook [$_] <$LOCKFILE>";
	&eval($FmlStartHook{$_}, "Run FmlStartHook [$_]");
    }
}

sub RunEndHooks
{
    $0 = "${FML}: RunEndHooks <$LOCKFILE>";

    # additional before action
    $END_HOOK && &eval($END_HOOK, 'END_HOOK');

    for (keys %FmlEndHook) {
	print STDERR "Run EndHook $_ -> $FmlEndHook{$_}\n" if $debug;
	next unless $FmlEndHook{$_};
	$0 = "${FML}: Run FmlEndHook [$_] <$LOCKFILE>";
	&eval($FmlEndHook{$_}, "Run FmlEndHook [$_]");
    }
}

# Lastly exec to be exceptional process
sub ExExec { &RunHooks(@_);}
sub RunExitHooks
{
    local($s);
    $0 = "${FML}: RunExitHooks <$LOCKFILE>";

    # FIX COMPATIBILITY
    $FML_EXIT_HOOK .= $_PCB{'hook', 'str'};

    if ($s = $FML_EXIT_HOOK) {
	print STDERR "\nmain::eval >$s<\n\n" if $debug;
	$0 = "${FML}: Run Hooks(eval) <$LOCKFILE>";
	&eval($s, 'Run Hooks:');
    }
    
    for (keys %FmlExitHook) {
	print STDERR "Run hooks $_ -> $FmlExitHook{$_}\n" if $debug;
	next unless $FmlExitHook{$_};
	$0 = "${FML}: Run FmlExitHook [$_] <$LOCKFILE>";
	&eval($FmlExitHook{$_}, "Run FmlExitHook [$_]");
    }
}

sub ExecNewProcess
{
    $0 = "${FML}: Run New Process <$LOCKFILE>";
    $FML_EXIT_PROG .= $_PCB{'hook', 'prog'};
    if ($FML_EXIT_PROG) { &use('kernsubr2'); &__ExecNewProcess;}
}

sub SpawnProcess
{
    local(@xargv) = @_; &use('kernsubr2'); &__SpawnProcess(@xargv);
}

####### Section: Member Check
# fix array list;
#
# files to check for the authentication 96/09/17
# @MEMBER_LIST = ($MEMBER_LIST) unless @MEMBER_LIST;
sub AdjustActiveAndMemberLists
{
    local($f, $status);

    if ($status = &AutoRegistrableP) {
	# automatic asymmetric registration
	# XXX: fml 2.x auto_asymmetric_regist fakes "only member list".
	if ($status eq "auto_asymmetric_regist") {
	    $FILE_TO_REGIST = $FILE_TO_REGIST || $ACTIVE_LIST;
	    &Touch($FILE_TO_REGIST) unless -f $FILE_TO_REGIST;
	}
	# XXX: fml 2.x auto_regist uses only member file.
	# XXX: fml 3.x auto_subscribe uses actives and members.
	elsif (&NotUseSeparateListP) {
	    # XXX: this block is always true in 2.x but false in 3.x.
	    $ACTIVE_LIST = $MEMBER_LIST;
	    for (@MEMBER_LIST) {
		grep(/$_/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $_);
	    }
	}
    }

    grep(/$MEMBER_LIST/, @MEMBER_LIST) || push(@MEMBER_LIST, $MEMBER_LIST);
    grep(/$ACTIVE_LIST/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $ACTIVE_LIST);

    if (($f = $FILE_TO_REGIST) && -f $FILE_TO_REGIST) {
	grep(/$f/, @MEMBER_LIST) || push(@MEMBER_LIST, $f);
	grep(/$f/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $f);
    }
    elsif (-f $FILE_TO_REGIST) {
	&Log("ERROR: \$FILE_TO_REGIST NOT EXIST");
    }

    # ONLY IF EXIST ALREADY, add the admin list (if not, noisy errors...;-)
    if (($f = $ADMIN_MEMBER_LIST) && -f $ADMIN_MEMBER_LIST) {
	grep(/$f/, @MEMBER_LIST) || push(@MEMBER_LIST, $f);
    }
}

# if found, return the non-null file name;
sub DoMailListMemberP
{
    local($addr, $type) = @_;
    local($file, @file, %file);

    # DataBase Access
    if ($USE_DATABASE) {
	&use('databases');

	my ($action) = $type eq 'm' ? 'member_p' : 'active_p';

	# try to access database to verify the server is alive
	# and try to verify the address is member or not.
	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, $action, {'address' => $addr});
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc);

       # if search fails for $MEMBER_LIST,
       if ( !$mib{'_result'} && ($type eq 'm')) {
           # retry search in $ADMIN_MEMBER_LIST
           my (%xmib, %result, %misc, $error);
           &DataBaseMIBPrepare(\%xmib,'admin_member_p',{'address' => $addr});
           &DataBaseCtl(\%Envelope, \%xmib, \%result, \%misc);

           # search fails for both $MEMBER_LIST and $ADMIN_MEMBER_LIST
           if ($xmib{'error'}) {
               return 0;
           }
           else {
               $mib{ _result } = $xmib{ _result };
           }
       }
       # if search fails for $ACTIVE_LIST, return here ASAP.
       elsif ($mib{'error'}) {
           return 0;
       }

	$Envelope{'database:cache:$action'} = 1 if $mib{'_result'};

	return $mib{'_result'};
    }
    # XXX  not reach here when you use $USE_DATABASE

    $SubstiteForMemberListP = 1;

    @file = $type eq 'm' ? @MEMBER_LIST : @ACTIVE_LIST;

    for $file (@file) {
	next unless -f $file;
	next if $file{$file}; $file{$file} = 1; # uniq 

	# prohibit ordinary people operations (but should permit probing only)
	# NOT CHECK OUTSIDE "amctl" procedures in &Command;
	# WITHIN "amctl"
	# check also $ADMIN_MEMBER_LIST if IN ADMIN MODE
	# ignore     $ADMIN_MEMBER_LIST if NOT IN ADMIN MODE
	if ($e{'mode:in_amctl'} &&            # in "amctl" library
	    ($file eq $ADMIN_MEMBER_LIST) &&
	    (! $e{'mode:admin'})) {           # called NOT in ADMIN MODE
	    next;
	}

	if ($debug && -f $file) {
	    &Debug("   DoMailListMemberP(\n\t$addr\n\tin $file);\n");
	}

	if (-f $file && &Lookup($addr, $file)) {
	    &Debug("+++Hit: $addr in $file") if $debug;
	    $SubstiteForMemberListP = 0;
	    return $file;
	}
    }
    $SubstiteForMemberListP = 0;

    if ($IDENTIFY_MIGRATING_DOMAIN) {
	# avoid recursive call under libmgrdom.pl
	return $NULL if $Envelope{'mode:in_mgrdom'};
	&use('mgrdom');
	&MgrdomConsider($addr, $type);
    }
    else {
	$NULL;
    }
}

sub MailListMemberP { return &DoMailListMemberP(@_, 'm');}
sub MailListActiveP { return &DoMailListMemberP(@_, 'a');}

sub MailListAdminMemberP
{ 
    my ($addr) = @_;

    # DataBase Access
    if ($USE_DATABASE) {
	&use('databases');

	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, 'admin_member_p', {'address' => $addr});
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc); 
       if ($mib{'error'}) { return 0;}

	$Envelope{'database:cache:admin_member_p'} = 1 if $mib{'_result'};

	return $mib{'_result'};
    }
    else {
	&Lookup($addr, $ADMIN_MEMBER_LIST);
    }
}

sub NonAutoRegistrableP { ! &AutoRegistrableP;}
sub AutoRegistrableP
{
    if ($REJECT_POST_HANDLER =~ /auto\S+regist/ &&
	 $REJECT_COMMAND_HANDLER eq 'auto_asymmetric_regist') {
	&Log("These HANDLER configuration may not work well");
    }

    if ($Envelope{'mode:ctladdr'} && 
	($REJECT_POST_HANDLER    eq 'auto_asymmetric_regist' ||
	 $REJECT_COMMAND_HANDLER eq 'auto_asymmetric_regist')) {
	"auto_asymmetric_regist";
    }
    elsif ($Envelope{'mode:ctladdr'} && 
	($REJECT_POST_HANDLER    eq 'auto_subscribe' ||
	 $REJECT_COMMAND_HANDLER eq 'auto_subscribe')) {
	"auto_subscribe";
    }
    elsif ($REJECT_COMMAND_HANDLER =~ /auto_regist/i ||
	   $REJECT_COMMAND_HANDLER =~ /auto_subscribe/i ||
	   $REJECT_COMMAND_HANDLER =~ /autoregist/i) {
	$REJECT_COMMAND_HANDLER;
    }
    elsif ($REJECT_POST_HANDLER =~ /auto_regist/i ||
	   $REJECT_POST_HANDLER =~ /auto_subscribe/i ||
	   $REJECT_POST_HANDLER =~ /autoregist/i) {
	   $REJECT_POST_HANDLER;
    }
    else {
	0;
    }
}

sub NotUseSeparateListP { ! &UseSeparateListP;}
sub UseSeparateListP
{
    local($x) = &AutoRegistrableP;

    if ($debug_fml30 == 1) { 
	&Log("AutoRegistrableP = $x"); $debug_fml30++;
    }

    if ($x eq 'auto_subscribe' || (! $x)) {
	1;
    }
    else {
	0;
    }
}

# canonicalize address for database storing 
# since we search it in case sensitive mode.
# preserve case in localpart but not in domain part
sub TrivialRewrite
{
    my ($addr) = @_;
    my ($local, $domain) = split(/\@/, $addr);
    $domain =~ tr/A-Z/a-z/;
    $local. '@'. $domain;
}

sub AutoRegistHandler
{
    if ($debug) { @c = caller; &Log("AutoRegistHandler called from $c[2]");}

    &use('amctl');
    &AutoRegist(*Envelope);
}

sub RejectHandler
{
    if ($debug) { @c = caller; &Log("RejectHandler called from $c[2]");}

    &Log("Rejected: \"From:\" field is not member");
    &WarnE("NOT MEMBER article from $From_address $ML_FN", 
	   "NOT MEMBER article from $From_address\n\n");
    if (-f $DENY_FILE) {
	&SendFile($From_address, 
		  "You $From_address are not member $ML_FN", $DENY_FILE);
    }
    else {
	&Mesg(*Envelope, 'you are not member.', 'info.reject');
    }
}

sub IgnoreHandler
{
    &Log("Ignored: \"From:\" field is not member");
    &WarnE("Ignored NOT MEMBER article from $From_address $ML_FN", 
	   "Ignored NOT MEMBER article from $From_address");
}

# Lookup(key, file); return 1 if the "key" is found in the "file".
# e.g. Lookup(addr, member-list-file)
# return 1 if a given address is authenticated as member's (found in the file).
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
# but the new version provides stable performance.
#
sub CheckMember { &Lookup(@_);}
sub Lookup
{
    local($address, $file) = @_;
    local($addr, $has_special_char, $auto_registrable);

    # mode
    $auto_registrable = &AutoRegistrableP;

    # more severe check;
    $address =~ s/^\s*//;
    if ($address =~ /\@/) { # RFC822 addrspec
	($addr) = split(/\@/, $address);
    }
    else { # not addrspec, arbitrary string
	$addr = substr($address, 0, 8);
    }
    
    # MUST BE ONLY * ? () [] but we enhance the category -> shell sc
    # add + (+ed user) 1998/11/08
    if ($addr =~ /[\+\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	$has_special_char = 1; 
    }

    open(LOOKUP_TABLE, $file) || do {
	&Log("LookUp: cannot open $file");
	return 0;
    };
  getline: while (<LOOKUP_TABLE>) {
      chop; 

      if ($auto_registrable || $SubstiteForMemberListP) { 
	  /^\#\s*(.*)/ && ($_ = $1);
      }

      next getline if /^\#/o;	# strip comments
      next getline if /^\s*$/o; # skip null line
      /^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

      # member nocheck(for nocheck but not add mode)
      # fixed by yasushi@pier.fuji-ric.co.jp 95/03/10
      # $ENCOUNTER_PLUS             by fukachan@phys 95/08
      # $Envelope{'mode:anyone:ok'} by fukachan@phys 95/10/04
      # $Envelope{'trap:+'}         by fukachan@sapporo 97/06/28
      if (/^\+\s*$/o) { 
	  &Debug("encounter + [$_]") if $debug;
	  $Envelope{'trap:+'} = 1;
	  close(LOOKUP_TABLE);
	  return 1;
      }

      # for high performance(Firstly special character check)
      if (! $has_special_char) { next getline unless /^$addr/i;}

      # This searching algorithm must require about N/2, not tuned,
      if (1 == &AddressMatch($_, $address)) {
	  close(LOOKUP_TABLE);
	  return 1;
      }
  }# end of while loop;

    close(LOOKUP_TABLE);
    return 0;
}

# for convenience
sub ExactAddressMatch
{ 
    local($addr1, $addr2) = @_;
    &SaveACL;
    $ADDR_CHECK_MAX = 100; 
    local($r) = &AddressMatch($addr1, $addr2);
    &RetACL;
    $r;
}

# sub AddressMatching($addr1, $addr2)
# return 1 given addresses are matched at the accuracy of 4 fields
sub AddressMatching { &AddressMatch(@_);}
sub AddressMatch
{
    local($addr1, $addr2) = @_;

    &Debug("   AddressMatch($addr1, $addr2)".
	   " [\$ADDR_CHECK_MAX=$ADDR_CHECK_MAX]\n") if $debug_addrmatch;

    # canonicalize to lower case
    $addr1 =~ y/A-Z/a-z/;
    $addr2 =~ y/A-Z/a-z/;

    # try exact match. must return here in a lot of cases.
    if ($addr1 eq $addr2) {
	if ($debug) {
	    &Debug("   AddressMatch($addr1, $addr2) => exact match");
	    &Log("AddressMatch($addr1, $addr2) => exact match");
	}
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
    local($i, $m) = (0, 0);
    while ($d1[$i] && $d2[$i] && ($d1[$i] eq $d2[$i])) { $i++;}

    $m = ($ADDR_CHECK_MAX > 0) ? $ADDR_CHECK_MAX : 3;

    if ($debug) {
	&Debug("   AddressMatch($acct1\@$addr1, $acct2\@$addr2) => ".
	       (($i >= $m) ? "match" : "not match").
	       " [$i >= $m ? y : n]");
	&Log("AddressMatch($acct1\@$addr1, $acct2\@$addr2) => ".
	     (($i >= $m) ? "match" : "not match"));
	&Log("AddressMatch: $i >= $m ? match : not match");
    }

    ($i >= $m) ? 1 : 0;
}

sub LowerDomain
{
    my ($addr) = @_;
    my (@addr) = split(/\@/, $addr);

    if ($DATABASE_DRIVER_ATTRIBUTES =~ /always_lower_domain/) {
	$addr[1] =~ tr/A-Z/a-z/;
	return $addr[0].'@'.$addr[1];
    }
    else {
	return $addr;
    }
}

####### Section: Info
# Recreation of the whole mail for error infomation
sub WholeMail { 
    local(@xargv) = @_; &use('kernsubr2'); &__WholeMail(@xargv);
}

sub ForwMail {
    local(@xargv) = @_; &use('kernsubr2'); &__ForwMail(@xargv);
}

sub Translate
{
    local(*e, $s, $mesgle_key, @mesgle_argv) = @_;
    if ($MESSAGE_LANGUAGE && $mesgle_key) {
	&use('mesgle');
	&MesgLE(*e, $mesgle_key, @mesgle_argv);
    }
    else { $NULL;}
}

# &Mesg(*e, );
# $mesgle == Message Languae Extension
sub Mesg 
{ 
    local(*e, $s, $mesgle_key, @mesgle_argv) = @_;

    if ($MESSAGE_LANGUAGE && $mesgle_key) {
	&Debug("MesgLE:try to translate key <$mesgle_key>") if $debug;
	&use('mesgle');
	$s = &MesgLE(*e, $mesgle_key, @mesgle_argv) || $s;
    }

    # if $s is null, return just now! (DUMMY_OPS may be useful)
    return unless $s;

    $e{'message'} .= "$s\n";
    $MesgBuf .= "$s\n";

    # dup to admins
    $e{'message:to:admin'} .= "$s\n" if $e{'mode:notify_to_admin_also'};
}

# no real data copy but 
# enable flag to mail body forwarding in Smtp() via Notify().
sub MesgMailBodyCopyOn
{
    &Mesg(*e, "Original mail as follows:\n");
    $Envelope{'message:ebuf2socket'} = 1;
}

sub MesgSetBreakPoint { undef $MesgBuf;} 
sub MesgGetABP { $MesgBuf;}	# After Break Point

# Forwarded and Warned to Maintainer;
sub Warn { &Forw(@_);}
sub Forw { &Sendmail($MAINTAINER, $_[0], $_[1]);}
sub WarnFile
{ 
    local($subject, $file, $preamble, $trailor) = @_;
    local($to, @file);

    @file = $file; undef $file;
    @to   = ($MAINTAINER);
    $Envelope{'preamble'} = $preamble;
    &NeonSendFile(*to, *subject,*file);
    undef $Envelope{'preamble'};
}

# Warn() with direct buffer copy from %Envelope to Socket
# and with "mh forwarding" separators (added in smtp library).
sub WarnF
{
    $Envelope{'ctl:smtp:forw:ebuf2socket'} = 1;
    &WarnE(@_);
    $Envelope{'ctl:smtp:forw:ebuf2socket'} = 0;
}

# Extended Warn() with direct buffer copy from %Envelope to Socket
sub WarnE
{
    local($subject, $body, $preamble, $trailor) = @_;
    local($title);

    $Envelope{'preamble'} = $preamble;

    $title = $Envelope{"tmp:ws"} || "Original mail as follows";
    $title = "\n$title:\n\n";

    $Envelope{'ctl:smtp:ebuf2socket'} = 1;
    &Sendmail($MAINTAINER, $subject, $body.$title);
    $Envelope{'ctl:smtp:ebuf2socket'} = 0;

    undef $Envelope{'preamble'};
}

sub Notify
{
    local(@xargv) = @_; 
    if ($debug) { my (@c) = caller; Log( "Notify: $c[1] $c[2]" ) ; }
    &use('kernsubr'); &__Notify(@xargv);
}

sub EnableReportForw2Admin
{ 
    local(*e) = @_; $e{'mode:notify_to_admin_also'} = 1;
}

sub DisableReportForw2Admin
{ 
    local(*e) = @_; $e{'mode:notify_to_admin_also'} = 0;
}

##
## Negative Cache Wrapper()'s
##
# wrap &Mesg() with negative cache
sub CMesg
{
    local($msgkey, $howold, *e, $s, $mesgle_key, @mesgle_argv) = @_;
    if (&OutOfNegativeCacheP($msgkey, $howold)) {
	&Mesg(*e, $s, $mesgle_key, @mesgle_argv);
    }
}

# wrap &Warn() with negative cache
sub CWarn
{
    local($msgkey, $howold, $subject, $body) = @_;
    if (&OutOfNegativeCacheP($msgkey, $howold)) {
	&Warn($subject, $body);
    }
}

sub OutOfNegativeCacheP
{
    local($msgkey, $howold) = @_;
    local($dir) = "$VAR_DIR/mesgcache";
    local($cf)  = "$dir/$msgkey";
    local($x);

    -d $dir || &Mkdir($dir);

    if (-f $cf) {
	$x = time - (stat($cf))[9]; # how lod  
	if ($x < $howold) { 
	    print STDERR "ignore now ($count, $x $howold)\n" if $debug;
	    return 0; # in negative cache
	}
    }

    &Touch($cf);

    1;
}

# Generate additional information for command mail reply.
# return the STRING
sub GenInfo
{
    local($s, $c, $d, $del);
    local($message, $has_ctladdr_p, $addr, $trap);

    # initialize variables
    $del     = ('*' x 60);

    # if has control-address
    if ($CONTROL_ADDRESS) {
	$addr = $Envelope{'CtlAddr:'};
	$has_ctladdr_p = 1;
    }
    # if !control-address but MAIL_LIST==CONTROL_ADDRESS
    elsif ((! $CONTROL_ADDRESS) && &CompatFMLv1P) { 
	$addr = $MAIL_LIST;
	$has_ctladdr_p = 1;
    }
    elsif ((! $CONTROL_ADDRESS) && $MAIL_LIST_ACCEPT_COMMAND) {
	$addr = $MAIL_LIST;
	$has_ctladdr_p = 1;
    }

    # help style;
    $message = $Envelope{"mode:fmlserv"} ? "help": "$Envelope{'trap:ctk'}help";
    if ($MAIL_LIST =~ /^(fmlserv|majordomo|listserv)/i) {
	$trap = '';
    }
    else {
	$trap = &CompatFMLv1P ? '#' : '';
    }

    $s .= "\n$del\n";

    # URL Extentions
    if ($ADD_URL_INFO) {
	if ($Envelope{'mode:stranger'}) {
	    $URLInfo = ";\n\t<mailto:$MAINTAINER>";
	    $URLComInfo = &GenXMLInfo;
	}
	# not stranger and has ctladdr (From: is a member).
	elsif ($has_ctladdr_p) {
	    $s .= "\n";
	    $s .= "       Help: <mailto:$addr?body=${trap}help>\n";
	    $s .= "Unsubscribe: <mailto:$addr?body=${trap}unsubscribe>\n";
	    $s .= "\n";

	    $URLInfo = ";\n\thelp=<mailto:$addr?body=${trap}help>";
	    $URLComInfo = &GenXMLInfo;
	}
	# not stranger and has no ctladdr (From: is a member).
	else {
	    $URLInfo = ";\n\t<mailto:$MAINTAINER>";
	}
    }

    # RFC2369; Proposed Standard (so fml optional)
    if ($USE_RFC2369) { &use('kernsubr2'); &EmulRFC2369;}

    $s .= "If you have any questions or problems,\n";
    $s .= "   please contact $MAINTAINER\n";

    if (! $Envelope{'mode:stranger'} && $has_ctladdr_p) { # a member
	$s .= "       or \n";
	$s .= "   send e-mail with the body \"$message\"(without quotes) to\n";
	$s .= "      $addr\n";
	$s .= "      (here is the automatic reply, so more preferable)\n\n";
	$s .= "e.g. on a Unix Machine\n";
	$s .= "(shell prompt)\% echo \"$message\" |Mail $addr";
    }

    $s .= "\n\n$del\n";

    $s;
}


sub GenXMLInfo
{
    if ($X_ML_INFO_MESSAGE) { 
	$X_ML_INFO_MESSAGE;
    }
    elsif ($Envelope{'mode:stranger'} ||
	   (!$CONTROL_ADDRESS && 
	      $PERMIT_POST_FROM =~ /^(anyone|members_only)$/)) {
	"If you have a question,\n\tplease contact $MAINTAINER".
	    ";\n\t<mailto:$MAINTAINER>";
    }
    else {
	"If you have a question, send e-mail with the body\n".
	    "\t\"". $Envelope{'trap:ctk'}.
		"help\" (without quotes) to the address ". &CtlAddr .
		$URLInfo;
    }
}

####### Section: IO
# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub LogWEnv { local($s, *e) = @_; &Log($s); $e{'message'} .= "$s\n";}

sub Log 
{ 
    local($str, $s) = @_;
    local($package, $filename, $line) = caller; # called from where?
    local($from) = $PeerAddr ? "$From_address[$PeerAddr]" : $From_address;
    local($error);

    &GetTime;

    $str =~ s/\015\012$//; # FIX for SMTP (cut \015(^M));

    if ($debug_smtp && ($str =~ /^5\d\d\s/)) {
	$error .= "Sendmail ERROR:\n";
	$error .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }

    $str = "$filename:$line% $str" if $debug_caller;

    # existence and append(open system call check)
    if (-f $LOGFILE && open(APP, ">> $LOGFILE")) {
	&Append2("$Now $str ($from)", $LOGFILE);
	&Append2("$Now    $filename:$line% $s", $LOGFILE) if $s;
    }
    else {
	print STDERR "$Now ($package, $filename, $line) $LOGFILE\n";
	print STDERR "$Now $str ($from)\n\t$s\n";
    }

    $Envelope{'error'} .= $error if $error;

    print STDERR "*** $str; $s;\n" if $debug;
}

# $mode: see open(2) 
sub __Write30
{
    local(*e, *s, *f, $mode, $envelope_hash_key) = @_;
    local($status);
    
    if ($mode eq "O_APPEND") {
	$status = open(WRITE2_OUT, ">> $f");
    }
    else {
	$status = open(WRITE2_OUT, "> $f");
    }

    if ($status) {
	select(WRITE2_OUT); $| = 1; select(STDOUT);

	# XXX Caution: "\n" handling differs.
	if ($envelope_hash_key) {
	    print WRITE2_OUT $e{$envelope_hash_key};
	}
	else {
	    print WRITE2_OUT $s, "\n";
	}
	close(WRITE2_OUT);

	1;
    }
    else {
	0;
    }
}

sub HashValueAppend
{
    local(*e, $key, $f) = @_;

    &__Write30(*e, *NULL, *f, "O_APPEND", $key) || do {
	local(@caller) = caller;
	print STDERR "HashValueAppend(@_)::Error caller=<@caller>\n";
    };
}

# append $s >> $file
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2 
{ 
    local($s, $f, $o_append) = @_;

    ($s && &__Write30(*NULL, *s, *f, "O_APPEND")) || do {
	local(@caller) = caller;
	print STDERR "Append2(@_)::Error caller=<@caller>\n";
    };
}

sub Write2
{
    local($s, $f, $o_append) = @_;

    if ($o_append) {
	return &Append2(@_);
    }
    elsif ($s && &__Write30(*NULL, *s, *f, "O_RWONLY")) {
	;
    }
    else {
	local(@caller) = caller;
	print STDERR "Write2(@_)::Error caller=<@caller>\n";
	return 0;
    };

    1;
}

sub Touch  { open(APP, ">>$_[0]"); close(APP); chown $<, $GID, $_[0] if $GID;}

sub Write3
{
    local(@xargv) = @_; &use('kernsubr'); &__Write3(@xargv);    
}

sub GetFirstLineFromFile 
{ 
    if (open(GFLFF, $_[0])) {
	chop($_ = <GFLFF>);
	close(GFLFF);
	$_;
    }
    else {
	return $NULL; 
    }
}

# $id = IncrementCounter(file, modulus)
sub IncrementCounter
{
    my ($f, $modulus) = @_;
    my ($id) = 0;

    # return cached id (against duplicated calls within one thread).
    $IncrementCounterCalled{$f}++;
    return $IncrementCounter{$f} if $IncrementCounterCached{$f};

    &Touch($f) unless -f $f;
    if (-f $f) {
	$id = &GetFirstLineFromFile($f);
	$id++;
	if ($modulus > 0) { $id = $id % $modulus;}
	if (open($f, "> ${f}.$$.new")) { 
	    select($f); $| = 1; select(STDOUT);
	    print $f $id, "\n"; 
	    close($f);
	    rename("${f}.$$.new", $f);
	}
    }
    $IncrementCounter{$f}       = $id; # (0 .. modulus-unit)
    $IncrementCounterCached{$f} = 1;
    $id;
}

# For Example, 
# $pp = $p = 0;
# while (1) { 
#   $p = &GetLinePtrFromHash(*Envelope, "Body", $pp);
#   print substr($Envelope{'Body'}, $pp, $p-$pp+1);
#   last if $p < 0; 
#   $pp = $p + 1;
# }
sub GetLinePtrFromHash
{
    local(*e, $key, $ptr) = @_;
    index($e{$key}, "\n", $ptr);
}

# For example,
# ($p, $pb, $pe) = &GetBlockPtrFromHash(*Envelope, 'Body', $b, $pp);
# last if $p < 0;
# print substr($Envelope{'Body'}, $pb, $pe - $pb);
sub GetBlockPtrFromHash
{
    local(*e, $key, $b, $ptr) = @_;
    local($p, $pb, $pe);
    $p  = &GetPtrFromHash(*e, 'Body', $b, $ptr);
    $pb = &GetPtrFromHash(*e, 'Body', "\n\n", $p + 1);
    $pe = &GetPtrFromHash(*e, 'Body', $b, $pb + 1);
    ($p, $pb + 2, $pe)
}

sub GetPtrFromHash
{
    local(*e, $key, $pat, $ptr) = @_;
    index($e{$key}, $pat, $ptr);
}

# useful for "Read Open"
sub Open
{
    if ((!-f $_[1]) || $_[1] eq '') {
	local(@c) = caller; local($c) = "$c[1],$c[2]"; $c =~ s#^\S+/##;
	if (! -f $_[1])  { &Log("${c}::Open $_[1] NOT FOUND");}
	if ($_[1] eq '') { &Log("${c}::Open $_[1] IS NULL; NOT DEFINED");}
	return 0;
    }
    open($_[0], $_[1]) || do { 
	local(@c) = caller; local($c) = "$c[1],$c[2]"; $c =~ s#^\S+/##;
	&Log("$c::Open failed $_[1]"); return 0;
    };
}

sub Copy
{
    local($in, $out) = @_;
    local($mode) = (stat($in))[2];
    open(COPYIN,  $in)      || (&Log("ERROR: Copy::In [$!]"), return 0);
    open(COPYOUT, "> $out") || (&Log("ERROR: Copy::Out [$!]"), return 0);
    select(COPYOUT); $| = 1; select(STDOUT);
    chmod $mode, $out;
    while (sysread(COPYIN, $_, 4096)) { print COPYOUT $_;}
    close(COPYOUT);
    close(COPYIN); 
    1;
}

# checks the executable "prog" in "prog option".
sub ProgExecuteP
{
    local($prog) = @_;

    $prog || return 0; # no input

    ($prog) = (split(/\s+/, $prog))[0];
    -x $prog ? 1 : 0;
}

# check fundamental programs existence
sub DiagPrograms
{
    my (@prog) = @_;
    my ($x, $bad);

    if ($UNISTD) {
	for $x (@prog) {
	    &ProgExecuteP( ${ $x } ) || do {
		$bad++;
		&Log("ERROR: program \$${x} is not defined");
	    };
        }
    }

    $bad ? 0 : 1; # if bad, return 0; 
}

# mainly search e.g. "sendmail"
sub SearchPath
{
    local($prog, @path) = @_;
    for ("/usr/sbin", "/usr/lib", @path) {
	if (-e "$_/$prog" && -x "$_/$prog") { return "$_/$prog";}
    }
}

sub SearchFileInLIBDIR
{
    for (@LIBDIR) { 
	&Debug("SearchFileInLIBDIR: <$_>/$_[0]") if $debug;
	if (-f "$_/$_[0]") { return "$_/$_[0]";}
    }
    $NULL;
}

sub SearchFileInINC
{
    for (@INC) { if (-f "$_/$_[0]") { return "$_/$_[0]";}}
    $NULL;
}

sub GetFirstMultipartBlock
{
    local(*e) = @_;

    if ($e{'MIME:boundary'}) {
	($p, $pb, $pe) = 
	    &GetBlockPtrFromHash(*e, 'Body', $e{'MIME:boundary'}, 0);	
	if ($pb > 0 && $pe > 0) { 
	    substr($e{'Body'}, $pb, $pe - $pb);
	}
	else {
	    &Log("GetFirstMultipartBlock: invalid MIME/multipart message");
	    $NULL;
	}
    }
    else {
	&Log("GetFirstMultipartBlock: invalid MIME/multipart message");
	$NULL;
    }
}

####### Section: Utilities
# we suppose &Uniq(*array)'s "array" is enough small.
sub Uniq
{
    local(*q) = @_;
    local(%p, @p);
    for (@q) { next if $p{$_}; $p{$_} = $_; push(@p, $_);}
    @q = @p;
}

# $pat is included in $list (A:B:C:... syntax)
sub ListIncludePatP
{
    local($pat, $list) = @_;
    for (split(/:/, $list)) { return 1 if $pat eq $_;}
    0;
}

sub DebugLog
{
    local($s) = @_;
    local($f) = $DEBUG_LOGFILE || $LOGFILE.".debug";
    &GetTime;
    &Append2("$Now $s", $f);
}

sub Debug 
{ 
    print STDERR "$_[0]\n";
    &Mesg(*Envelope, "\nDEBUG $_[0]") if $debug_message;
    &DebugLog($_[0]) if $debug > 1;
}

sub ABS { $_[0] < 0 ? - $_[0] : $_[0];}

sub ATOI 
{
    if ($_[0] eq '') {
	return $NULL;
    }
    elsif ($_[0] =~ /^(\d+)$/i) {
	$_[0];
    }
    elsif ($_[0] =~ /^(\d+)M$/i) {
	 $1 * 1024 * 1024;
    }
    elsif ($_[0] =~ /^(\d+)K$/i) {
	$1 * 1024;
    }
    else {	
	&Log("ATOI: $_[0] is unknown type");
    }
}

# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}
sub Use { require "lib$_[0].pl";}

# &UseModule("Japanese", "langdep");
sub UseModule { require "module/$_[0]/lib$_[1].pl";}

sub MkDir { &Mkdir(@_);}
sub Mkdir
{
    if ($_[1] ne '') { return &MkDirHier($_[0], $_[1]);}
    &MkDirHier($_[0], $DEFAULT_DIR_MODE || 0700);
    if ($USE_FML_WITH_FMLSERV && $SPOOL_DIR eq $_[0]) { chmod 0750, $_[0];}
    if ($USE_FML_WITH_FMLSERV && $GID) { chown $<, $GID, $_[0];}
}

sub MkDirHier
{
    local($pat) = $UNISTD ? '/|$' : '\\\\|/|$'; # on UNIX or NT4

    while ($_[0] =~ m:$pat:go) {
	next if (!$UNISTD) && $` =~ /^[A-Za-z]:$/; # ignore drive letter on NT4

	if ($` ne "" && !-d $`) {
	    mkdir($`, $_[1] || 0777) || do { 
		&Log("cannot mkdir $`: $!"); 
		return 0;
	    };
	}
    }

    1;
}

# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}

sub PerlModuleExistP
{
    local($pm) = @_;
    if ($] !~ /^5\./) { &Log("ERROR: using $pm requires perl 5"); return 0;}
    eval("use $pm");
    if ($@) { &Log("${pm}.pm NOT FOUND; Please install ${pm}.pm"); return 0;}
    1;
}

# Getopt
sub Opt { push(@SetOpts, @_);}
    
# Setting CommandLineOptions after include config.ph
sub SetOpts
{
    # should pararelly define ...
    for (@SetOpts) { 
	/^\-\-MLADDR=(\S+)/i && (&use("mladdr"),  &MLAddr($1));
	if (/^\-\-([_a-z0-9]+)$/||/^\-\-([_a-z0-9]+=\S+)$/) {&DEFINE_MODE($1);}
    }

    for (@SetOpts) {
	if (/^\-\-(force|fh):(\S+)=(\S+)/) { # "foreced header";
	    &DEFINE_FIELD_FORCED($2, $3); next;
	}
	elsif (/^\-\-(original|org|oh):(\S+)/) { # "foreced header";
	    &DEFINE_FIELD_ORIGINAL($2); next;
	}
	elsif (/^\-\-([_A-Z0-9]+)=(\S+)/) { # USER DEFINED VARIABLES
	    eval("\$$1 = '$2';"); next;
	}
	elsif (/^\-\-(\S+)/) {	# backward mode definition is moved above
	    local($_) = $1;
	    /^[_a-z0-9]+$/ || eval("\$${_} = 1;"); 
	    /^permit:([a-z0-9:]+)$/ && ($Permit{$1} = 1); # set %Permit;
	    next;
	}

	/^\-(\S)/      && ($Opt{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($Opt{"opt:$1"} = $2);

	/^\-d(\d+)/    && ($debug = $1)        && next;
	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }
}

sub GenMessageId
{
    &GetTime;
    $GenMessageId = $GenMessageId++ ? $GenMessageId : 'AAA';
    "<${CurrentTime}.FML${GenMessageId}". $$ .".$MAIL_LIST>";
}
    
# which address to use a COMMAND control.
sub CtlAddr { &Addr2FQDN($CONTROL_ADDRESS);}

# Do FQDN of the given Address 1. $addr is set and has @, 2. MAIL_LIST
sub Addr2FQDN { $_[0]? ($_[0] =~ /\@/ ? $_[0]: $_[0]."\@$FQDN") : $MAIL_LIST;}
sub CutFQDN   { $_[0] =~ /^(\S+)\@\S+/ ? $1 : $_[0];}

sub SRand
{
    local($i) = time;
    $i = (($i & 0xff) << 8) | (($i >> 8) & 0xff) | 1;
    srand($i + $$); 
}

# Reference: NetBSD:/usr/src/usr.bin/cksum/sum2.c
#  *** cksum utility is expected to conform to IEEE Std 1003.2-1992 ***
sub TraditionalATTUnixCheckSum
{
    my ($f) = @_;
    my ($crc, $total, $nr);

    $crc = $total = 0;
    if (open($f, $f)) {
	while (($nr = sysread($f, $buf, 1024)) > 0) {
	    my ($i) = 0;
	    $total += $nr;

	    for ($i = 0; $i < $nr; $i++) {
		$r = substr($buf, $i, 1);
		$crc += ord($r);
	    }
	}
	close($f);
	$crc = ($crc & 0xffff) + ($crc >> 16);
	$crc = ($crc & 0xffff) + ($crc >> 16);
    }
    else {
	print STDERR "ERROR: no such file $f\n";
    }

    ($crc, $total);
}

sub LogFileNewSyslog
{
    $LOGFILE_NEWSYSLOG_LIMIT = &ATOI($LOGFILE_NEWSYSLOG_LIMIT);
    if ($LOGFILE_NEWSYSLOG_LIMIT) {
	if ((stat($LOGFILE))[7] > $LOGFILE_NEWSYSLOG_LIMIT) {
	    require 'libnewsyslog.pl'; 
	    &NewSyslog($LOGFILE);
	    &Touch($LOGFILE);
	}
    }
}

sub CacheTurnOver
{
    local($file, $size_limit) = @_;

    if ((stat($file))[7] > $size_limit) {
	&use('newsyslog');
	&NewSyslog'TurnOverW0($file);#';
	&Touch($file);
    }
}

sub DBCtl
{
    &use('db');
    &FML_SYS_DBCtl(@_);
}

####### Section: Security 
# anyway alias now (1998/05/03)
# If sent back directly, X-ML-Info: exists and must contains e.g. $MAIL_LIST .
sub MailLoopP
{
    if ($Envelope{'h:x-ml-info:'}) {
	if ($Envelope{'h:x-ml-info:'} =~ /contact $MAINTAINER/i ||
	    $Envelope{'h:x-ml-info:'} =~ /(address\s+|mailto:)$MAIL_LIST/i ||
	    $Envelope{'h:x-ml-info:'} =~ /(address\s+|mailto:)$CONTROL_ADDRESS/i) {
	    &Log("Loop Alert: dup X-ML-Info:");
	    &WarnE("Loop Alert: dup X-ML-Info: $ML_FN", 
		   "fml <$MAIL_LIST> has detected a loop condition so that\n"
		   ."input mail has already our ML X-ML-Info: field.\n\n");
	    return 1;
	}
    }

    &DupMessageIdP;
}

sub SearchDupKey
{
    local($key, $file) = @_;
    local($status, $i);

    # 1. scan current and 
    if (-f $file) { 
	$status = &Lookup($key, $file);
    }
    return $status if $status;

    # 2. scan all available caches
    for $i (0 .. $NEWSYSLOG_MAX) {
	if ($status) {
	    last; # end if non null $status is returned.
	}
	elsif (-f "$file.$i") {
	    $status = &Lookup($key, "$file.$i");
	}
    }

    $status;
}

# If O.K., record the Message-Id to the file $LOG_MESSAGE_ID);
# message-id cache should be done for mails in action
sub CacheMessageId
{
    local(*e, $msgid) = @_;
    local($id);

    # canonicalize
    $id = $msgid || $e{'h:Message-Id:'};
    $id || (&Log("Invalid Message-Id:<$id>"), return $NULL);
    $id =~ s/[\<\>]//g;
    $id =~ s/^\s+//;

    if ($CachedMessageID{$id}) {
	&Log("CacheMessageId: warning: duplicated input") if $debug_loop;
	return 0;
    }

    # Turn Over log file (against too big);
    # The default value is evaluated as "once per about 100 mails".
    &CacheTurnOver($LOG_MESSAGE_ID, 
		   $MESSAGE_ID_CACHE_BUFSIZE || 60*100);

    $CachedMessageID{$id} = 1;
    &Append2($id." \# pid=$$", $LOG_MESSAGE_ID);
}

sub DupMessageIdP
{
    local($status, $mid);

    # no check -> "return not looped"
    $CHECK_MESSAGE_ID || return 0;

    local($mid) = $Envelope{'h:Message-Id:'};
    $mid =~ s/[\<\>]//g; 
    $mid =~ s/^\s+//;

    &Debug("DupMessageIdP::($mid, $LOG_MESSAGE_ID)") if $debug;

    $status = &SearchDupKey($mid, $LOG_MESSAGE_ID);

    if ($status) {
	&Debug("\tDupMessageIdP::(DUPLICATED == LOOPED)") if $debug;
	local($s) = "Duplicated Message-ID";
	&Log("Loop Alert: $s");
	&WarnE("Loop Alert: $s $ML_FN", "$s in <$MAIL_LIST>.\n\n");
	1;
    }
    else {
	&Debug("\tDupMessageIdP::(OK NOT LOOPED)") if $debug;
	0;
    }
}

# if the addr to reply is O.K., return value is 1;
sub CheckAddr2Reply
{
    local(*e, @addr_list) = @_;
    local($addr, $m);
    my (@caller) = caller;

    ### 01: check recipients == myself?
    for $addr (@addr_list) {
	if (&LoopBackWarn($addr)) {
	    &Log("Notify: ERROR: the mail is not sent to $addr",
		 "since the addr to reply == ML or ML-Ctl-Addr");
	    &Log(@caller);
	    $m .= "\nNotify: ERROR: the mail is not sent to [$addr]\n";
	    $m .= "since the addr to reply == ML or ML-Ctl-Addr.\n";
	    $m .= "-" x60; $m .= "\n";
	}
	else {
	    print STDERR "CheckAddr2Reply 01: OK\t$addr\n" if $debug;
	}
    }

    ### 02: check the recipents
    for $addr (@addr_list) {
	if ($addr =~ /^($REJECT_ADDR)\@/i) {
	    $m .= "\nNotify: ERROR: the mail should not be sent to [$addr]\n";
	    $m .= "since the addr is not-personal or other agent softwares\n";
	    $m .= "-" x60; $m .= "\n";
	}
	else {
	    print STDERR "CheckAddr2Reply 02: OK\t$addr\n" if $debug;
	}
    }    

    # if anything happens, append the information;
    if ($m) {
	# append the original message and forwarding to the maintainer;
	$m .= "=" x60; $m .= "\n";
	$m .= "Original 'message' to send to the user:\n\n". $e{'message'};
	$m .= "=" x60; $m .= "\n";

	# message for the maintainer;
	$e{'error'} .= $m;
    }

    $m ? 0 : 1;	# if O.K., return 1;
}

# Check uid == euid && gid == egid
sub CheckUGID
{
    print STDERR "\nsetuid is not set $< != $>\n\n" if $< != $>;
    print STDERR "\nsetgid is not set $( != $)\n\n" if $( ne $);
    # die("YOU SHOULD NOT RUN fml AS ROOT NOR DAEMON\n") if $< == 0 || $< == 1;
}

sub GetGID { (getgrnam($_[0]))[2];}

sub InSecureP { (! &SecureP(@_));}

sub SecureP {
    local(@xargv) = @_; &use('kernsubr'); &__SecureP(@xargv);
}

sub ValidAddrSpecP
{
    ($_[0] !~ /\s|\033\$[\@B]|\033\([BJ]/ && 
     $_[0] =~ /^[\0-\177]+\@[\0-\177]+$/) ? 1 : 0;
}

# Check Looping 
# return 1 if loopback
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;
    local($a);
    local(@c) = caller;

    for $a ($MAIL_LIST, $CONTROL_ADDRESS, @MAIL_LIST_ALIASES, 
	    "fmlserv\@$DOMAINNAME", "majordomo\@$DOMAINNAME", 
	    "listserv\@$DOMAINNAME", "mead\@$DOMAINNAME") {

	next if $a =~ /^\s*$/oi;	# for null control addresses
	if (&AddressMatch($to, $a)) {
	    &Debug("AddressMatch($to, $a)") if $debug;
	    &Log("Loop Back Warning: ", "$to eq $a");
	    &Log("called from @c");
	    &WarnE("Loop Back Warning: [$to eq $a] $ML_FN", 
		   "Loop Back Warning: [$to eq $a]");
	    return 1;
	}
    }

    0;
}

sub RejectAddrP { 
    local(@xargv) = @_; &use('kernsubr'); &__RejectAddrP(@xargv);
}    

sub EnvelopeFilter {
    local(@xargv) = @_; &use('envf'); &__EnvelopeFilter(@xargv);
}

# QUOTA
sub CheckResourceLimit
{
    local(*e, $mode) = @_;

    if ($mode eq 'member') { 
	&use('amctl'); return &MemberLimitP(*e);
    }
    elsif ($mode eq 'mti:distribute:max_traffic') { 
	&MTIProbe(*MTI, $From_address, 'distribute:max_traffic');
    }
    elsif ($mode eq 'mti:command:max_traffic') { 
	&MTIProbe(*MTI, $From_address, 'command:max_traffic');
    }
}

####### Section: Macros for the use of user-side-definition (config.ph) 
### moved to "libloadconfig.pl"

####### Section: misc

# "get ID by auto-increment" for user 
sub GET_ID_AUTOINC
{
    local($f) = @_; 

    if (-f $f) { # Get the present ID
	local($id) = &GetFirstLineFromFile($f);
	$id++; 
	&Write2($id, $f);
	$id;
    }
    else {
	&Log("GET_ID_AUTOINC: cannot open $f");
	0;
    }
}

# Get Next MIME Multipart Block
sub GetNextMPBPtr
{
    local(*e, $ptr) = @_;
    local($pTop, $pEndHeader, $pBottom, $xbuf);
    
    if ($e{'MIME:boundary'}) {
	$pTop       = index($e{'Body'}, $e{'MIME:boundary'}, $ptr);
	$pEndHeader = index($e{'Body'}, "\n\n", $pTop);
	$pBottom    = index($e{'Body'}, $e{'MIME:boundary'}, $pEndHeader);
	($pTop, $pEndHeader, $pBottom);
    } else {
	&Log("GetNextMPBPtr: no MIME boundary definition");
	();
    }
}

# Get Next MIME Multipart Block
sub GetNextMultipartBlock
{
    local(*e, $ptr) = @_;
    local($pTop, $pEndHeader, $pBottom, $xbuf);
    
    if ($e{'MIME:boundary'}) {
	$pTop       = index($e{'Body'}, $e{'MIME:boundary'}, $ptr);
	$pEndHeader = index($e{'Body'}, "\n\n", $pTop);
	$pBottom    = index($e{'Body'}, $e{'MIME:boundary'}, $pEndHeader);

	if ($pEndHeader > 0 && $pBottom > 0) { 
	    $xhdr = substr($e{'Body'}, $pTop, $pEndHeader - $pTop);
	    $xbuf = substr($e{'Body'}, $pEndHeader, $pBottom - $pEndHeader);
	    ($xhdr, $xbuf, $pBottom)
	} else {
	    $NULL;
	}
    } else {
	&Log("GetNextMultipartBlock: no MIME boundary definition");
	$NULL;
    }
}

####### Section: Switch
sub SaveACL { $ProcCtlBlock{"main:ADDR_CHECK_MAX"} = $ADDR_CHECK_MAX;}
sub RetACL  { $ADDR_CHECK_MAX = $ProcCtlBlock{"main:ADDR_CHECK_MAX"};}

####### Section: Event Handling Functions
sub SignalLog 
{ 
    local($sig) = @_; 
    &Log("Caught SIG$sig, shutting down");
    sleep 1;
    exit(1);
}

# Strange "Check flock() OK?" mechanism???
# fml.pl exits under all cases after 12 hours (IT IS TOO LONG)!
sub Lock   
{ 
    &SetEvent($TimeOut{'dead'} || 43200, 'TimeOut') if $HAS_ALARM;

    # $LockQueueId is of mean under main locked phase
    # "mget" runs after $LockQueueId is cleared.
    $LockQueueId = &SetEvent($TimeOut{'lock'} || $TimeOut{'flock'} || 3600, 
			     'TimeOut') if $HAS_ALARM;
    $USE_FLOCK ? &Flock   : (&use('lock'), &V7Lock);
}

# for installer ?
sub ReloadMySelf
{
    # If myself is changed after exec'ed, reload it again.
    if ((-M __FILE__) < 0) {
	&Log("FYI: reload myself against installation");
	for ("libkern.pl", keys %INC) {
	    next unless /^lib\S+\.pl$|\/lib\S+\.pl$/;
	    delete $INC{$_};
	    &Log("reload $_ agasin against installation") if $debug;
	    require $_;
	}
    }
}

sub Unlock 
{ 
    $USE_FLOCK ? &Funlock : &V7Unlock;

    # $LockQueueId is of mean under main locked phase
    if ($LockQueueId) { &ClearEvent($LockQueueId);}
}

# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    local($min,$hour,$mday,$mon) = 
	(localtime(time + ($TimeOut{'flock'} || 3600)))[1..4];
    local($ut) = sprintf("%02d/%02d %02d:%02d", $mon + 1, $mday, $hour, $min);

    $FlockFile = $FlockFile ||
	(open(LOCK,$FP_SPOOL_DIR) ? $FP_SPOOL_DIR : "$DIR/config.ph");

    $0 = "${FML}: Locked(flock) until $ut <$LOCKFILE>";

    # spool is also a file!
    if (! open(LOCK, $FlockFile)) {
	&Log("Flock:Cannot open FlockFile[$FlockFile]"); 
	die("Flock:Cannot open FlockFile[$FlockFile]"); 
    }
    flock(LOCK, $LOCK_EX);
}

sub Funlock 
{
    $0 = "${FML}: Unlock <$LOCKFILE>";

    flock(LOCK, $LOCK_UN);
    close(LOCK); # unlock,close <kizu@ics.es.osaka-u.ac.jp>
}

# do not anything except for logging since now the fatal error case.
sub TimeOut
{
    &GetTime;
    $0 = "${FML}: TimeOut $Now <$LOCKFILE>";

    # Now we may be not able to connect socket, isn't it?
    # &WarnE("TimeOut: $MailDate ($From_address) $ML_FN", $NULL);
    &Log("TimeOut[$$]: Caught SIGALRM, timeout");

    if ($TimeOutCalled++) {
	kill 9, $$;
    }
    else {
	$TimeOutCalled++;
	exit(0);
    }
}

sub SetEvent
{
    local($interval, $fp)  = @_;
    local($id, $now, $qp, $prev_qp);

    $now = time; # the current time;

    $id  = $EventQueue++ + 1; # unique identifier

    if ($interval < 60) {
	&Log("SetEvent: input interval[$interval] is too short. reset to 60");
	$interval = $interval < 60 ? 60 : $interval;
    }

    # the first reference is a dummy (without $fp);
    if ($id == 1) {
	$EventQueue{"time:${id}"} = $now;
	$EventQueue{"next:${id}"} = $id + 1;
	$id  = $EventQueue++ + 1; # unique identifier
    }

    # search the event queue for correct position; 
    # here search all entries;
    for ($qp = $EventQueue{"next:1"}, $prev_qp = 1; 
	 $qp ne ""; $qp = $EventQueue{"next:${qp}"}) {
	if ($EventQueue{"time:$qp"} >= $now + $interval) { last;}
	$prev_qp = $qp;
    }

    $EventQueue{"time:${id}"}  = $now + $interval;
    $EventQueue{"debug:${id}"} = $interval if $debug;
    $EventQueue{"fp:${id}"}    = $fp;

    # "next:id = null" if the next link does not exist.
    $EventQueue{"next:${prev_qp}"} = $id; # pointed to the current id;
    $EventQueue{"next:${id}"}      = $qp != $id ? $qp : ""; 

    &Tick; # tick(0);

    $id; # return the identifier;
}

sub ClearEvent
{
    local($id)  = @_;
    local($now, $qp, $prev_qp);

    # search the event queue for correct position;
    # here search all entries;
    for ($qp = $EventQueue{"next:1"};
	 $qp ne ""; 
	 $qp = $EventQueue{"next:${qp}"}) {

	if ($qp == $id) {
	    $EventQueue{"next:$prev_qp"} = $EventQueue{"next:$qp"};
	    &Debug("---ClearEvent: qp=$id fp=$EventQueue{\"fp:${id}\"}")
		if $debug;
	    &Log("ClearEvent: qp=$EventQueue{\"fp:$id\"}") if $debug_tick;
	    undef $EventQueue{"fp:$id"};
	    last;
	}
	$prev_qp = $qp;
    }
}

# ### ATTENTION! alarm(3) may conflict sleep(3); ###
# alarm(3) do actions as long as if needed;
# Plural functions may be done at the same time;
# but it is responsible Tick();
sub Tick
{
    local($cur, $fp, $qp);

    &GetTime; $0 = "${FML}: Tick $Now <$LOCKFILE>";

    return unless $HAS_ALARM;

    print STDERR "===Tick called\n" if $debug;

    alarm(0); # before we sets in the routine, reset the current alarm; 
    $cur = time;

    # scan all entries and do the function (if time < the current_time);
    # so $qp (queue pointer) is set to the last action (< curret time)
    for ($qp = $EventQueue{"next:1"};
	 $EventQueue{"time:$qp"} <= $cur; 
	 $qp = $EventQueue{"next:${qp}"}) {

	$fp = $EventQueue{"fp:$qp"};
	next unless $fp;

	# $EventQueue{time:$qp} and alarm(3) time may be at the same time!
	undef $EventQueue{"fp:$qp"};
	&Log("Tick[$$]: run fp=$fp");
	eval("&$fp;");
	&Log($@) if $@;

	alarm(0);
	$cur = time;
    }

    $SIG{'ALRM'} = 'Tick'; 

    # info
    &Debug("\tnow\tqp=$qp fp=$EventQueue{\"fp:${qp}\"}") if $debug;

    # find the next $qp defined function pointer (time > cur_time)
    # skip null functions since the functions has been expireed.
    # *1 ignore $qp=0 case.
    for (; $qp && !$EventQueue{"fp:${qp}"}; $qp = $EventQueue{"next:${qp}"}) {
	;
    }
    &Debug("\tfinally\tqp=$qp fp=$EventQueue{\"fp:${qp}\"}") if $debug;

    $cur = $EventQueue{"time:${qp}"} - time;
    $cur = $cur > 0 ? $cur : 3;
    alarm($cur); # considering context switching;

    &Log("Tick[$$]::alarm($cur)") if $debug_tick;
    if ($debug) {
	&OutputEventQueue;
	&Debug("\tnow set alarm($cur) for the queue id $qp");
	&Debug("\tfp = $qp->$EventQueue{\"fp:${qp}\"}") if $debug_tick;
    }

    if ($debug_tick) {
	for ($qp = 1; $qp ne ""; $qp = $EventQueue{"next:${qp}"}) {
	    $cur = $EventQueue{"time:${qp}"} - time;
	    if ($cur >= 0) { # the future events list
		&Log(sprintf("  when=%-5d qp=%-2d link->%-2d fp=%s", 
			     $cur,
			     $qp, 
			     $EventQueue{"next:$qp"}, 
			     $EventQueue{"fp:$qp"}));
	    }
	}
    }
}

1;
