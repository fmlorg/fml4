#!/usr/local/bin/perl
#
# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
$Rcsid   = 'fml 2.2';

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
}

&Unlock;			# UnLock!

&RunHooks;			# run hooks after unlocking

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

    # member ot not?
    &AdjustActiveAndMemberLists;
    $member_p = &MailListMemberP($From_address);
    $member_p = 1 if $Envelope{"trap:+"};
    $Envelope{'mode:stranger'} = 1 unless $member_p;

    # chaddr is available from new address if old to "chaddr" is a member;
    if (!$member_p && $Envelope{'mode:uip:chaddr'}) {
	&use('utils');
	if (&ChAddrModeOK($Envelope{'mode:uip:chaddr'})) {
	    $Envelope{'mode:uip'} = $member_p = 1;
	}
    }

    # fml 0.x - fml 2.1gamma compat
    $compat_hml = &CompatFMLv1P;

    # default
    $REJECT_POST_HANDLER    = $REJECT_POST_HANDLER    || 'Reject';
    $REJECT_COMMAND_HANDLER = $REJECT_COMMAND_HANDLER || 'Reject';

    %RejectHandler = ("reject",      "RejectHandler",
		      "auto_regist", "AutoRegistHandler",
		      "autoregist",  "AutoRegistHandler",
		      "ignore",      "IgnoreHandler",

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
		require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
		&Command() if $ForceKickOffCommand;
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
	    &ModeratedDelivery(*Envelope); # Moderated: check Approval;
	}
	else {
	    &Log("Error: \$PERMIT_COMMAND_FROM is unknown type.");
	}
    }
    # distribute
    else {
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
	    &Log("Error: \$PERMIT_POST_FROM is unknown type.");
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

    # site_init
    if ($SiteInitPath = &SearchFileInLIBDIR("site_init.ph")) {
	if (-r $SiteInitPath) { 
	    &Log("require $SiteInitPath") if $debug;
	    require($SiteInitPath);
	}
    }

    # include fundamental configurations and library
    if (-r "$DIR/config.ph")  { 
	require("$DIR/config.ph");
    }
    else {
	print STDERR "I cannot read $DIR/config.ph\n" if !-r "$DIR/config.ph";
	print STDERR "no $DIR/config.ph exist?\n" if !-f "$DIR/config.ph";
	print STDERR "FYI: FML Release 2 Release requires \$DIR/config.ph\n";
	exit 1;
    }

    if ($SitedefPath = &SearchFileInLIBDIR("sitedef.ph")) {
	if (-r $SitedefPath) { 
	    &Log("require $SitedefPath") if $debug;
	    require($SitedefPath);
	}
    }

    require 'libsmtp.pl';		# a library using smtp

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
	 'X-Mailer',
	 'Mail-Followup-To',	# I-D now?
	 ':body:', ':any:', 
	 'X-Authentication-Warning',
	 'Mime-Version', 'Content-Type', 'Content-Transfer-Encoding',
	 'Content-ID', 'Content-Description', # RFC2045
	 'Precedence', 'Lines');
}

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);

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

    # $FML for process table readability
    if ($0 =~ m%^(.*)/(.*)%) { $FML = $2;}

    # a little configuration before the action
    if ($FML_UMASK || $UMASK) {
	$FML_UMASK ? umask($FML_UMASK) : umask($UMASK);
    }
    elsif ($USE_FML_WITH_FMLSERV) {
	umask(007); # rw-rw----
    }
    else {
	umask(077); # rw-------
    }

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
    if ($_cf{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

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

    for ($LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    ### CFVersion 3
    ### DEFINE INTERNAL FLAG FOR THE USE $DIR/members or $DIR/actives ?
    ### $ML_MEMBER_CHECK is internal variable to indicate file relation
    if (&AutoRegistrableP) {
	$ML_MEMBER_CHECK = 0;	# backward
	$touch = "${ACTIVE_LIST}_is_dummy_when_auto_regist";
	&Touch($touch) if ! -f $touch;
    }
    else {
	-f $ACTIVE_LIST || &Touch($ACTIVE_LIST);	
    }

    if ($SUBJECT_TAG_TYPE) { 
	&use("tagdef");
	&SubjectTagDef($SUBJECT_TAG_TYPE);
    }
    ### END CFVersion 3

    ### misc 
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$VARRUN_DIR/msgidcache";#important;
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
}

# one pass to cut out the header and the body
sub Parsing { &Parse;}
sub Parse
{
    $0 = "$FML: Parsing header and body <$LOCKFILE>";
    local($bufsiz, $buf, $p, $maxbufsiz);

    $maxbufsiz = &ATOI($INCOMING_MAIL_SIZE_LIMIT) if $INCOMING_MAIL_SIZE_LIMIT;

    undef $Envelope{'Body'};
    while ($p = sysread(STDIN, $_, 1024)) {
	$bufsiz += $p; 

	if ($INCOMING_MAIL_SIZE_LIMIT && ($bufsiz > $maxbufsiz)) {
	    $Envelope{'trap:mail_size_overflow'} = 1;
	    last;
	}

	$Envelope{'Body'} .= $_;
    }

    # Split buffer to Header and Body
    $p = index($Envelope{'Body'}, "\n\n");
    $Envelope{'Header'} = substr($Envelope{'Body'}, 0, $p + 1);
    $Envelope{'Body'}   = substr($Envelope{'Body'}, $p + 2);

    # Really? but check "what happen if no input is given?".
    if ($bufsiz == 0) {
	&Log("no input, stop");
	exit(0);
    }
}

# Phase 2 extract several fields 
sub GetFieldsFromHeader
{
    local($field, $value, @hdr, %hf);
    local($s);

    $0 = "$FML: GetFieldsFromHeader <$LOCKFILE>";

    # To ensure non exsistence
    for (split(/\|/, $SKIP_FIELDS)) { &DELETE_FIELD($_);}

    # pass all fields through
    if ($SUPERFLUOUS_HEADERS || $PASS_ALL_FIELDS_IN_HEADER) { 
	$hdr_entry = join("|", @HdrFieldsOrder);
    }

    ### Header Fields Extraction
    $s = "$Envelope{'Header'}\n";
    $* = 0;			# match one line
    if ($s =~ /^From\s+(\S+)/i) {
	$Envelope{'UnixFrom'} = $UnixFrom = $1;
	$s =~ s/^From\s+.*//i;
    }

    $s = "\n$s";		# tricky
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
    $e{'Addr2Reply:'}    = &Conv2mailbox($e{'h:reply-to:'},*e)||$From_address;

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
	$e{'h:To:'} = "$MAIL_LIST $ML_FN"; # force the original To: to pass
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

    # BBS style? CUT OFF 
    s/^\s*Re\[\d+\]:\s+/Re: /gi;
    s/^\s*Re\^\d+:\s+/Re: /gi;

    while (s/^\s*Re:\s*Re:\s*/Re: /gi) { ;} #'/gi' for RE: Re: re: ;
    s/^\s*Re:\s+/Re: /; # canonicalize it to "Re: ";

    $_;
}

sub CheckCurrentProc
{
    local(*e) = @_;

    # connection info
    &eval('&GetPeerInfo;') if $LOG_CONNECTION;

    ##### SubSection: Check Body Contents (For Command Mode)
    local($limit, $p, $buf, $boundary, $nclines, $cc);

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
    
    # Check the range to scan
    $limit =  $GUIDE_CHECK_LIMIT > $COMMAND_CHECK_LIMIT ? 
	$GUIDE_CHECK_LIMIT  : $COMMAND_CHECK_LIMIT;

    # dot-qmail(5) ~alias/.uja-default emulates uja-help@domain ("-> #help")
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
	if (index($e{'Body'}."\n", "\n", $p + 1) > 0) {
	    $p = index($e{'Body'}."\n", "\n", $p + 1);
	}
	else {
	    last;
	}
    }
    $buf = substr($e{'Body'}, 0, $p + 1); # +1 for the last "\n";

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
	# confirm trap (may be with citatin e.g. ">")
	if (/$CONFIRMATION_KEYWORD\s+\S+/i) {
	    $e{'mode:req:confirm'} = 1;
	    $e{'buf:req:confirm'} .= $_."\n";
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
	    $e{'mode:uip'} = 'on'    if /^\#\s*\w+\s|^\#\s*\w+$/;
	    $e{'mode:uip:chaddr'} = $_ 
		if /^\#\s*($CHADDR_KEYWORD)\s+/i;
	}

	$nclines++ if /^\#/o;    # the number of command lines
    }

    ### close(STDIN); # close(STDIN) prevents open2, really?

    $e{'nlines'}  = ($e{'Body'} =~ tr/\n/\n/);
    $e{'nclines'} = $nclines;
    $e{'size'}    = $bufsiz;
    $e{'h:Lines:'} = $e{'nlines'};

    ##### SubSection: special trap
    return 0 if $CheckCurrentProcUpperPartOnly;

    ##### SubSection: misc

    ### MailBody Size
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
		&NotifyMailSizeOver;
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


    ### WE SHOULD REJCECT "CANNOT IDENTIFIED AS PERSONAL" ADDRESSES;
    ###   In addition, we check another atack possibility;
    ###      e.g. majorodmo,listproc,list-subscribe <-> fml-ctl 
    if ($REJECT_ADDR && $From_address =~ /^($REJECT_ADDR)\@/i) {
	&Log("Mail From Addr to Reject [$&], FORW to Maintainer");
	&Warn("Mail From Addr to Reject [$&]", &WholeMail);
	$DO_NOTHING = 1;
	return 0;
    }

    ### security level
    while (($k, $v) = each %SEVERE_ADDR_CHECK_DOMAINS) {
	print STDERR "/$k/ && ADDR_CHECK_MAX += $v\n" if $debug; 
	($From_address =~ /$k/) && ($ADDR_CHECK_MAX += $v);
    }

    # AGAINST SPAM MAILS
    if (-f $REJECT_ADDR_LIST) {
	if (&RejectAddrP($From_address) ||
	    &RejectAddrP($UnixFrom)) {
	    $s="Reject spammers: UnixFrom=[$UnixFrom], From=[$From_address]";
	    &Warn("Spam mail from a spammer is rejected $ML_FN",
		  "Reject Spammers:\n".
		  "   UnixFrom\t$UnixFrom\n   From\t\t$From_address\n".
		  &WholeMail);
	    &Log($s);
	    $DO_NOTHING = 1;
	    return 0;
	}
    }

    ### For CommandMode Check(see the main routine in this flie)
    $e{'trap:rcpt_fields'}  = $e{'h:to:'} || $e{'h:apparently-to:'};
    $e{'trap:rcpt_fields'} .= ", $e{'h:Cc:'}, ";
    $e{'trap:rcpt_fields'}  =~ s/\n(\s+)/$1/g;

    ### SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS && $e{'h:Subject:'}) {
	local($_) = $e{'h:Subject:'};
	s/^\s*//;

	$e{'mode:req:guide'}++ if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	$e{'mode:uip'} = 'on'  if /^\#\s*\w+\s|^\#\s*\w+$/;
	$e{'mode:req:guide'}++          
	    if $COMMAND_ONLY_SERVER && /^\s*$GUIDE_KEYWORD\s*$/i;
	$e{'mode:uip'} = 'on' 
	    if $COMMAND_ONLY_SERVER && /^\s*\w+\s|^\s*\w+$/;
    }    

    # ? for --distribute, here and again in &MLMemberCheck; 
    &AdjustActiveAndMemberLists;

    ### DEBUG 
    if ($debug) { &eval(&FieldsDebug, 'FieldsDebug');}

    ###### LOOP CHECK PHASE 1: Message-Id
    if ($CHECK_MESSAGE_ID && &DupMessageIdP) { exit 0;}

    ###### LOOP CHECK PHASE 2
    # now before flock();
    if ((! $NOT_USE_UNIX_FROM_LOOP_CHECK) && 
	&AddressMatch($UnixFrom, $MAINTAINER)) {
	&Log("WARNING: UNIX FROM Loop[$UnixFrom == $MAINTAINER]");
	&Warn("WARNING: UNIX FROM Loop",
	      "UNIX FROM[$UnixFrom] == MAINTAINER[$MAINTAINER]\n\n".
	      &WholeMail);
	exit 0;
    }

    ### Address Test Mode; (Become Test Mode)
    if ($_cf{"opt:b"} eq 't') { 
	$DO_NOTHING = 1; &Log("Address Test Mode:Do nothing");
    } 

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

sub RuleSetTo
{
    local(*e) = @_;
    local($ok, $addr, $ml);
    local(@ml) = ($MAIL_LIST, @MAIL_LIST_ALIASES); # PLAY_TO Trick;

    for $addr (split(/[\s,]+/, $e{'h:to:'})) {
	$addr = &Conv2mailbox($addr, *e);
	for $ml (@ml) { &AddressMatch($addr, $ml) && $ok++;}
    }
    if (!$ok) { $e{'h:To:'} .= $e{'h:To:'} ? "\n\t,".$e{'h:to:'}: $e{'h:to:'};}
}

# Expand mailbox in RFC822
# From_address is user@domain syntax for e.g. member check, logging, commands
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
#
# macro:x is moved to FixHeaderFields (97/05/07 fukui@sonic.nm.fujitsu.co.jp)
#
sub Conv2mailbox
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

    # Filtering a mail body from members but not check other cases
    # e.g. null body subscribe request in "no-keyword" case
    if ($USE_DISTRIBUTE_FILTER) {
	&EnvelopeFilter(*e, 'distribute');
	return 0 if $DO_NOTHING;
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

    require 'libdist.pl';
    &DoDistribute(*e);	
}

sub RunStartHooks
{
    # additional before action
    $START_HOOK && &eval($START_HOOK, 'Start hook');

    for (keys %FmlStartHook) {
	print STDERR "Run StartHook $_ -> $FmlStartHook{$_}\n" if $debug;
	next unless $FmlStartHook{$_};
	$0 = "$FML: Run FmlStartHook [$_] <$LOCKFILE>";
	&eval($FmlStartHook{$_}, "Run FmlStartHook [$_]");
    }
}

# Lastly exec to be exceptional process
sub ExExec { &RunHooks(@_);}
sub RunHooks
{
    local($s);
    $0 = "$FML: Run Hooks <$LOCKFILE>";

    # FIX COMPATIBILITY
    $FML_EXIT_HOOK .= $_cf{'hook', 'str'};

    if ($s = $FML_EXIT_HOOK) {
	print STDERR "\nmain::eval >$s<\n\n" if $debug;
	$0 = "$FML: Run Hooks(eval) <$LOCKFILE>";
	&eval($s, 'Run Hooks:');
    }
    
    for (keys %FmlExitHook) {
	print STDERR "Run hooks $_ -> $FmlExitHook{$_}\n" if $debug;
	next unless $FmlExitHook{$_};
	$0 = "$FML: Run FmlExitHook [$_] <$LOCKFILE>";
	&eval($FmlExitHook{$_}, "Run FmlExitHook [$_]");
    }
}

sub ExecNewProcess
{
    local($s);
    $0 = "$FML: Run New Process <$LOCKFILE>";

    $FML_EXIT_PROG .= $_cf{'hook', 'prog'};

    if ($s = $FML_EXIT_PROG) {
	print STDERR "\nmain::exec $s\n\n" if $debug;
	$0 = "$FML: Run Hooks(prog) <$LOCKFILE>";
	exec $s || do { &Log("cannot exec $s");}
    }
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
	if ($status eq "auto_asymmetric_regist") {
	    $FILE_TO_REGIST = $FILE_TO_REGIST || $ACTIVE_LIST;
	    &Touch($FILE_TO_REGIST) unless -f $FILE_TO_REGIST;
	}

	$ACTIVE_LIST = $MEMBER_LIST;
	for (@MEMBER_LIST) {
	    grep(/$_/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $_);
	}
    }

    grep(/$MEMBER_LIST/, @MEMBER_LIST) || push(@MEMBER_LIST, $MEMBER_LIST);
    grep(/$ACTIVE_LIST/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $ACTIVE_LIST);

    if (($f = $FILE_TO_REGIST) && -f $FILE_TO_REGIST) {
	grep(/$f/, @MEMBER_LIST) || push(@MEMBER_LIST, $f);
	grep(/$f/, @ACTIVE_LIST) || push(@ACTIVE_LIST, $f);
    }
    elsif (-f $FILE_TO_REGIST) {
	&Log("Error: \$FILE_TO_REGIST NOT EXIST");
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

sub MailListAdminMemberP { &Lookup($_[0], $ADMIN_MEMBER_LIST);}

sub NonAutoRegistrableP { ! &AutoRegistrableP;}
sub AutoRegistrableP
{
    if ($Envelope{'mode:ctladdr'} && 
	($REJECT_POST_HANDLER    eq 'auto_asymmetric_regist' ||
	 $REJECT_COMMAND_HANDLER eq 'auto_asymmetric_regist')) {
	"auto_asymmetric_regist";
    }
    elsif ($REJECT_POST_HANDLER =~ /auto_regist/i ||
	   $REJECT_POST_HANDLER =~ /autoregist/i ||
	   $REJECT_COMMAND_HANDLER =~ /auto_regist/i ||
	   $REJECT_COMMAND_HANDLER =~ /autoregist/i) {
	1;
    }
    else {
	0;
    }
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
    &Warn("NOT MEMBER article from $From_address $ML_FN", &WholeMail);
    &SendFile($From_address, 
	      "You $From_address are not member $ML_FN", $DENY_FILE);
}

sub IgnoreHandler
{
    &Log("Ignored: \"From:\" field is not member");
    &Warn("Ignored NOT MEMBER article from $From_address $ML_FN", &WholeMail);
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
    ($addr) = split(/\@/, $address);
    
    # MUST BE ONLY * ? () [] but we enhance the category -> shell sc
    # add + (+ed user) 1998/11/08
    if ($addr =~ /[\+\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	$has_special_char = 1; 
    }

    &Open(FILE, $file) || return 0;
  getline: while (<FILE>) {
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
      if (/^\+/o) { 
	  &Debug("encounter + [$_]") if $debug;
	  $Envelope{'trap:+'} = 1;
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

####### Section: Info
# Recreation of the whole mail for error infomation
sub WholeMail   
{ 
    $_ = "\n";

    if ($MIME_CONVERT_WHOLEMAIL) { 
	&use('MIME'); 
	$_ .= &DecodeMimeStrings($Envelope{'Header'});
    }

    $_ .= "\n".$Envelope{'Header'}."\n".$Envelope{'Body'};
    s/\n/\n   /g; # against ">From ";
    
    $title = $Envelope{"tmp:ws"} || "Original Mail as follows";
    "\n$title:\n$_\n";
}

sub ForwMail
{
    local($s) = $Envelope{'Header'};
    $s =~ s/^From\s+.*\n//;

    $_  = "\n------- Forwarded Message\n\n";
    $_ .= $s."\n".$Envelope{'Body'};
    $_ .= "\n\n------- End of Forwarded Message\n";

    $_;
}

# &Mesg(*e, );
sub Mesg 
{ 
    local(*e, $s) = @_; 
    $e{'message'} .= "$s\n";
    $MesgBuf .= "$s\n";

    # dup to admins
    $e{'message:to:admin'} .= "$s\n" if $e{'mode:notify_to_admin_also'};
}

sub MesgSetBreakPoint { undef $MesgBuf;} 
sub MesgGetABP { $MesgBuf;}	# After Break Point

# Forwarded and Warned to Maintainer;
sub Warn { &Forw(@_);}
sub Forw { &Sendmail($MAINTAINER, $_[0], $_[1]);}

# Notification of the mail on warnigs, errors ... 
sub Notify
{
    local($buf) = @_;
    local($not_send, $addr);
    local($to, @to, $s, $proc, $m);

    # special flag
    return $NULL if $Envelope{'mode:disablenotify'};

    # refer to the original(NOT h:Reply-To:);
    $to   = $Envelope{'message:h:to'} || $Envelope{'Addr2Reply:'};

    # once only (e.g. used in chaddr)
    @to   = split(/\s+/, $Envelope{'message:h:@to'}); 
    undef $Envelope{'message:h:@to'};

    $s    = $Envelope{'message:h:subject'} || "Fml status report $ML_FN";
    $proc = $PROC_GEN_INFO || 'GenInfo';
    $GOOD_BYE_PHRASE = $GOOD_BYE_PHRASE || "--${MAIL_LIST}, Be Seeing You!   ";

    # send the return mail to the address (From: or Reply-To:)
    # (before it, checks whether the return address is not ML nor ML-Ctl)
    # Error Message is set to $Envelope{'error'} if loop is detected;
    if (($buf || $Envelope{'message'}) && 
	&CheckAddr2Reply(*Envelope, $to, @to)) {
	$REPORT_HEADER_CONFIG_HOOK .= 
	    q# $le{'Body:append:files'} = $Envelope{'message:append:files'}; #;
	
	$Envelope{'trailer'} = &$proc;

	&Sendmail($to, 
		  $s, 
		  ($buf || $Envelope{'message'}) .
		  "\n$GOOD_BYE_PHRASE $FACE_MARK\n", 
		  @to);
    }

    # if $buf is given, ignore after here.
    # admin error report is done in the last of fml.pl, &Notify(); 
    return if $buf;

    # send the report mail ot the maintainer;
    $Envelope{'error'} .= $m;
    if ($Envelope{'error'}) {
	&Warn("Fml System Error Message $ML_FN",$Envelope{'error'}.&WholeMail);
    }

    if ($Envelope{'message:to:admin'}) {
	&Warn("Fml System Message $ML_FN", $Envelope{'message:to:admin'});
    }
}

sub EnableReportForw2Admin
{ 
    local(*e) = @_; $e{'mode:notify_to_admin_also'} = 1;
}

sub DisableReportForw2Admin
{ 
    local(*e) = @_; $e{'mode:notify_to_admin_also'} = 0;
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
    if ($USE_RFC2369) {
	if ($Envelope{'mode:stranger'}) {
	    &DefineDefaultField("List-Subscribe", 
				"<mailto:$addr?body=${trap}subscribe>");
	}
	else {
	    &DefineDefaultField("List-Help", 
				"<mailto:$addr?body=${trap}help>");
	    &DefineDefaultField("List-Unsubscribe", 
				"<mailto:$addr?body=${trap}unsubscribe>");
	}
    }

    $s .= "If you have any questions or problems,\n";
    $s .= "   please make a contact with $MAINTAINER\n";

    if (! $Envelope{'mode:stranger'} && $has_ctladdr_p) { # a member
	$s .= "       or \n";
	$s .= "   send a mail with the body \"$message\"(without quotes) to\n";
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
	"If you have a question,\n\tplease make a contact with $MAINTAINER".
	    ";\n\t<mailto:$MAINTAINER>";
    }
    else {
	"If you have a question, send a mail with the body\n".
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
	$error .= "Sendmail Error:\n";
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

# append $s >> $file
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2 
{ 
    &Write2(@_, 1) || do {
	local(@caller) = caller;
	print STDERR "Append2(@_)::Error caller=<@caller>\n";
    };
}

sub Write2
{
    local($s, $f, $o_append) = @_;

    if ($o_append && $s && open(APP, ">> $f")) { 
	select(APP); $| = 1; select(STDOUT);
	print APP "$s\n";
	close(APP);
    }
    elsif ($s && open(APP, "> $f")) { 
	select(APP); $| = 1; select(STDOUT);
	print APP "$s\n";
	close(APP);
    }
    else {
	local(@caller) = caller;
	print STDERR "Write2(@_)::Error caller=<@caller>\n";
	return 0;
    }

    1;
}

sub Touch  { open(APP, ">>$_[0]"); close(APP); chown $<, $GID, $_[0] if $GID;}

sub Write3			# call by reference for effeciency
{ 
    local(*e, $f) = @_; 

    open(APP, "> $f") || (&Log("cannot open $f"), return '');
    select(APP); $| = 1; select(STDOUT);

    if ($MIME_DECODED_ARTICLE) { 
	&use('MIME');
	local(%me) = %e;
	&EnvelopeMimeDecode(*me);
	print APP "$me{'Hdr'}\n$me{'Body'}";
    }
    else {
	print APP "$e{'Hdr'}\n$e{'Body'}";
    }

    close(APP);
}

sub GetFirstLineFromFile 
{ 
    &Open(GFLFF, $_[0]) || return $NULL; 
    chop($_ = <GFLFF>);
    $_;
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
    open(COPYIN,  $_[0])     || (&Log("Error: Copy::In [$!]"), return 0);
    open(COPYOUT, "> $_[1]") || (&Log("Error: Copy::Out [$!]"), return 0);
    select(COPYOUT); $| = 1; select(STDOUT); 
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

sub GetFirstMultipartBlock
{
    local(*e, $_) = @_;
    if ($e{'MIME:boundary'}) {
	$pb = index($_, $e{'MIME:boundary'});
	$pb = index($_, "\n\n", $pb);
	$pe = index($_, $e{'MIME:boundary'}, $pb);
	if ($pb > 0 && $pe > 0) { 
	    $_ = substr($_, $pb, $pe - $pb);
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

sub MkDir { &Mkdir(@_);}
sub Mkdir
{
    if ($_[1] ne '') { return &MkDirHier($_[0], $_[1]);}
    &MkDirHier($_[0], $USE_FML_WITH_FMLSERV ? 0770 : 0700);
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
    if ($] !~ /^5\./) { &Log("Error: using $pm requires perl 5"); return 0;}
    eval("use $pm");
    if ($@) { &Log("${pm}5.pm NOT FOUND; Please install ${pm}.pm"); return 0;}
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

	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

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

####### Section: Security 
# anyway alias now (1998/05/03)
# If sent back directly, X-ML-Info: exists and must contains e.g. $MAIL_LIST .
sub MailLoopP
{
    if ($Envelope{'h:x-ml-info:'}) {
	if ($Envelope{'h:x-ml-info:'} =~ /$MAINTAINER/i ||
	    $Envelope{'h:x-ml-info:'} =~ /$MAIL_LIST/i ||
	    $Envelope{'h:x-ml-info:'} =~ /$CONTROL_ADDRESS/i) {
	    &Log("Loop Alert: dup X-ML-Info:");
	    &Warn("Loop Alert: dup X-ML-Info: $ML_FN", 
		  "fml <$MAIL_LIST> has detected a loop condition so that\n"
		  ."input mail has already our ML X-ML-Info: field.\n\n"
		  .&WholeMail);
	    return 1;
	}
    }
    
    &DupMessageIdP;
}

# If O.K., record the Message-Id to the file $LOG_MESSAGE_ID);
# message-id cache should be done for mails in action
sub CacheMessageId
{
    local(*e, $msgid) = @_;
    local($id);

    # checks
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
    $MESSAGE_ID_CACHE_BUFSIZE = $MESSAGE_ID_CACHE_BUFSIZE || 60*100;
    if ((stat($LOG_MESSAGE_ID))[7] > $MESSAGE_ID_CACHE_BUFSIZE) {
	&use('newsyslog');
	&NewSyslog'TurnOverW0($LOG_MESSAGE_ID);#';
	&Touch($LOG_MESSAGE_ID);
    }

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

    # 1. scan current and 
    if (-f $LOG_MESSAGE_ID) {
	$status = &Lookup($mid, $LOG_MESSAGE_ID);
    }

    # 2. scan all available caches
    for $i (0 .. $NEWSYSLOG_MAX) {
	if ($status) {
	    last; # end if non null $status is returned.
	}
	elsif (-f "$LOG_MESSAGE_ID.$i") {
	    $status = &Lookup($mid, "$LOG_MESSAGE_ID.$i");
	}
    }

    if ($status) {
	&Debug("\tDupMessageIdP::(DUPLICATED == LOOPED)") if $debug;
	local($s) = "Duplicated Message-ID is detected";
	&Log("Loop Alert: $s");
	&Warn("Loop Alert: $s $ML_FN", 
	      "$s in <$MAIL_LIST>.\n\n".&WholeMail);
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

    ### 01: check recipients == myself?
    for $addr (@addr_list) {
	if (&LoopBackWarn($addr)) {
	    &Log("Notify: Error: the mail is not sent to $addr",
		 "since the addr to reply == ML or ML-Ctl-Addr");
	    $m .= "\nNotify: Error: the mail is not sent to [$addr]\n";
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
	    $m .= "\nNotify: Error: the mail should not be sent to [$addr]\n";
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

    $m ? 0: 1;	# if O.K., return 1;
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

sub SecureP 
{ 
    local($s, $command_mode) = @_;

    $s =~ s#(\w)/(\w)#$1$2#g; # permit "a/b" form

    # permit m=12u; e.g. admin subscribe addr m=1;
    # permit m=12 for digest format(subscribe)
    $s =~ s/\s+m=\d+/ /g; $s =~ s/\s+[rs]=\w+/ /g;
    $s =~ s/\s+[rms]=\d+\w+/ /g;

    # ignore <addr+ext@domain>; but this is ugly hack ;-)
    if ($command_mode eq 'admin') { 
	$s =~ s/\+[-\w\.]+\@[-\w\.]+//g;
    }

    # special hooks (for your own risk extension)
    if (%SecureRegExp || %SECURE_REGEXP) { 
	for (values %SecureRegExp, values %SECURE_REGEXP) {
	    next if !$_;
	    return 1 if $s =~ /^($_)$/;
	}
    }

    # special hooks to reject some patterns
    if (%INSECURE_REGEXP) {
	for (values %INSECURE_REGEXP) {
	    next if !$_; 
	    return 0 if $s =~ /^($_)$/;
	}
    }

    # XXX: "# command" is internal represention
    # XXX: and for permitting a special backward compatibility.
    # permit Email Address, 100.tar.gz, # command, # mget 100,last:10 mp ...
    # if ($s =~ /^[\#\s\w\-\[\]\?\*\.\,\@\:]+$/) {
    if ($s =~ /^[\#\s\w\-\.\,\@\:]+$/) {
	1;
    }
    # since, this ; | is not checked when interact with shell in command.
    elsif ($command_mode && $s =~ /[\;\|]/) {
	&Log("SecureP: [$s] includes ; or |"); 
	$s = "Security alert:\n\n\t$s\n\t[$'$`] HAS AN INSECURE CHAR\n";
	&Warn("Security Alert $ML_FN", "$s\n".('-' x 30)."\n". &WholeMail);
	0;
    }
    else {
	&Log("SecureP: Security Alert for [$s]", "[$s] ->[($`)<$&>($')]");
	$s = "Security alert:\n\n\t$s\n\t[$'$`] HAS AN INSECURE CHAR\n";
	&Warn("Security Alert $ML_FN", "$s\n".('-' x 30)."\n". &WholeMail);
	0;
    }
}

sub ValidAddrSpecP
{
    ($_[0] !~ /\s|\033\$[\@B]|\033\([BJ]/ && 
     $_[0] =~ /^[\0-\177]+\@[\0-\177]+$/) ? 1 : 0;
}

sub GetPeerInfo
{
    local($family, $port, $addr);
    local($clientaddr);

    $addr = getpeername(STDIN);

    if (! $addr) {
	&Log("cannot getpeername()");
	return;
    }

    ($family, $port, $addr) = unpack($STRUCT_SOCKADDR, $addr);
    ($clientaddr) = gethostbyaddr($addr, 2);

    if (! defined($clientaddr)) {
	$clientaddr = sprintf("%d.%d.%d.%d", unpack('C4', $addr));
    }
    $PeerAddr = $clientaddr;
}

# Check Looping 
# return 1 if loopback
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;

    for ($MAIL_LIST, $CONTROL_ADDRESS, @MAIL_LIST_ALIASES, 
	 "fmlserv\@$DOMAINNAME", "majordomo\@$DOMAINNAME", 
	 "listserv\@$DOMAINNAME") {

	next if /^\s*$/oi;	# for null control addresses
	if (&AddressMatch($to, $_)) {
	    &Debug("AddressMatch($to, $_)") if $debug;
	    &Log("Loop Back Warning: ", "$to eq $_");
	    &Warn("Loop Back Warning: [$to eq $_] $ML_FN", &WholeMail);
	    return 1;
	}
    }

    0;
}

sub RejectAddrP
{
    local($from) = @_;
    local($pat);

    if (! -f $REJECT_ADDR_LIST) {
	&Log("RejectAddrP: \$REJECT_ADDR_LIST NOT EXISTS");
	return $NULL;
    }

    &Open(RAL, $REJECT_ADDR_LIST) || return $NULL;
    while (<RAL>) {
	chop;
	next if /^\s*$/;

	# adjust syntax
	s#\@#\\\@#g;
	s#\\\\#\\#g;

	if ($from =~ /^($_)$/i) { 
	    &Log("RejectAddrP: we reject [$from] which matches [$_]");
	    close(RAL);
	    return 1;
	}
    }
    close(RAL);

    0;
}

# Called under $USE_DISTRIBUTE_FILTER is not null.
# IF *HOOK is not defined, we apply default checkes.
# The function name looks strange but this is derived from
# that "filtering for %Envelope hash, not only mail message/body".
sub EnvelopeFilter
{
    local(*e, $mode) = @_;
    local($p, $r, $org_mlp);

    # force plural line match
    $org_mlp = $*;
    $* = 0;

    # compatible 
    # appending twice must be no problem since statments is "return".
    $DISTRIBUTE_FILTER_HOOK .= $REJECT_DISTRIBUTE_FILTER_HOOK;
    $COMMAND_FILTER_HOOK    .= $REJECT_COMMAND_FILTER_HOOK;

    if ($mode eq 'distribute' && $DISTRIBUTE_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *DISTRIBUTE_FILTER_HOOK);
    }
    elsif ($mode eq 'command' && $COMMAND_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *COMMAND_FILTER_HOOK);
    }

    if ($r) {
	; # O.K.
    }
    # reject for some header field patterns.
    elsif (%REJECT_HDR_FIELD_REGEXP) {
	local($hf, $pat, $match);

	for $hf (keys %REJECT_HDR_FIELD_REGEXP) {
	    next unless ($hf && $REJECT_HDR_FIELD_REGEXP{$hf});

	    $pat = $REJECT_HDR_FIELD_REGEXP{$hf};

	    if ($pat =~ m@/i$@) { # case insensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		$e{"h:$hf:"} =~ /$pat/i && $match++;
	    }
	    else {		# case sensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		$e{"h:$hf:"} =~ /$pat/ && $match++;
	    }

	    if ($match) {
		&Log("EnvelopeFilter: \$REJECT_HDR_FIELD_REGEXP{\"$hf\"} HIT");
		$r = "reject for invalid $hf field.";
		last;
	    }
	}
    }

    # If Multipart, evaluate the first block only.
    # skip the first multipart separator block
    # evalute the first multipart block
    if ($e{'MIME:boundary'}) {
	$_ = &GetFirstMultipartBlock(*e, $e{'Body'}) || $e{'Body'};
    }
    else {
	$_ = $e{'Body'};
    }

    # remove the last block which must be a signature.
    $_ =~ s/^[\n\s]*//;		# remove the first spaces
    $_ =~ s/[\n\s]*$//;		# remove the last spaces

    # ensure "block1 null-line block2 ..."
    $p = index($_, "\n\n");
    if ($p > 0) { 
	$p = rindex($_, "\n\n");
	$_ = substr($_, 0, $p) if $p > 0;
    }

    # count up "\n\n" lines;
    # If one paraghaph (+ signature), must be $c == 0. 
    local($c); $c = $p = 0;
    $_ =~ s/[\n\s]*$//;		# remove the last spaces
    while (($p = index($_, "\n\n", $p + 1)) > 0) { $c++;}

    # cut off Email addresses (exceptional).
    s/\S+@[-\.0-9A-Za-z]+/account\@domain/g;

    &Debug("--EnvelopeFilter::Buffer($_\n);\ncount=$c\n") if $debug;

    if ($r) { # must be matched in a hook.
	;
    }
    elsif (/^[\s\n]*$/) {
	$r = "null body";
    }
    # e.g. "unsubscribe", "help", ("subscribe" in some case)
    # DO NOT INCLUDE ".", "?" (I think so ...)! 
    # If we include them, we cannot identify a command or an English phrase ;D
    # If $c == 0, the mail must be one paragraph (+ signature).
    elsif (!$c && /^[\s\n]*[\s\w\d:,\@\-]+[\n\s]*$/) {
	$r = "one line body";
    }
    # elsif (/^[\s\n]*\%\s*echo.*[\n\s]*$/i) {
    elsif (/^[\s\n]*\%\s*echo.*/i) {
	$r = "invalid command line body";
    }
    
    # JIS: 2 byte A-Z => \043[\101-\132]
    # EUC 2-bytes "A-Z" (243[301-332])+
    # e.g. reject "SUBSCRIBE" : octal code follows:
    # 243 323 243 325 243 302 243 323 243 303 243 322 243 311 243 302
    # 243 305
    if (/\033\044\102(\043[\101-\132])+/) { # JIS "2 byte"[A-Z]+
	$s = &STR2EUC($_);

	local($n_pat, $sp_pat);
	$n_pat  = '\243[\301-\332]';
	$sp_pat = '\241\241'; # 2-byte space

	$s = (split(/\n/, $s))[0]; # check the first line only
	if ($s =~ /^\s*(($n_pat){1,})[\s$sp_pat]+.*$|^\s*(($n_pat){1,})$/) {
	    &Log("2 byte <". &STR2JIS($s) . ">");
	    $r = '2 byte command';
	}
    }

    # some attributes
    # XXX: "# command" is internal represention
    # XXX: but to reject the old compatible syntaxes.
    if ($mode eq 'distribute' && $FILTER_ATTR_REJECT_COMMAND &&
	/^[\s\n]*(\#\s*[\w\d\:\-\s]+)[\n\s]*$/) {
	$r = $1; $r =~ s/\n//g;
	$r = "avoid to distribute commands [$r]";
    }

    # Spammer?  Message-Id should be <addr-spec>
    if ($e{'h:message-id:'} !~ /\@/) { $r = "invalid Message-Id";}

    if ($r) { 
	$DO_NOTHING = 1;

	&Log("EnvelopeFilter::reject for '$r'");
	&Warn("Rejected mail by FML EnvelopeFilter $ML_FN", 
	      "A mail from $From_address\nis rejected for '$r'.\n".&WholeMail);

	if ($FILTER_NOTIFY_REJECTION) {
	    &Mesg(*e, "Your mail is rejected for '$r'.\n". &WholeMail);
	}
    }

    $* = $org_mlp;
}

# return 0 if reject;
sub EvalRejectFilterHook
{
    local(*e, *filter) = @_;
    local($r) = sprintf("sub DoEvalRejectFilterHook { %s;}", $filter);
    eval($r); &Log($@) if $@;
    $r = &DoEvalRejectFilterHook;
    $r || $NULL;
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

sub STR2JIS { &JSTR(@_);}
sub JSTR
{
    local($s) = @_;
    require 'jcode.pl';
    &jcode'convert(*s, 'jis'); #';
    $s;
} 

sub STR2EUC
{
    local($s) = @_;
    require 'jcode.pl';
    &jcode'convert(*s, 'euc'); #';
    $s;
} 

sub DEFINE_SUBJECT_TAG { &use('tagdef'); &SubjectTagDef($_[0]);}

sub DEFINE_MODE 
{ 
    local($m) = @_;
    print STDERR "--DEFINE_MODE($m)\n" if $debug;

    $m =~ tr/A-Z/a-z/;
    $Envelope{"mode:$m"} = 1;

    # config.ph CFVersion == 3
    if ($CFVersion < 3) {
	&use("compat_cf2");
	&ConvertMode2CFVersion3($m);
    }

    if ($m =~ 
	/^(post=|command=|artype=confirm|ctladdr|disablenotify|makefml)/) {
	&Log("ignore $m call ModeDef") if $debug;
    }
    else {
	&Log("call ModeDef($m)") if $debug;
	&use("modedef"); 
	&ModeDef($m);
    }
}

sub DefineDefaultField
{
    local($f) = $_[0];
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

sub DEFINE_FIELD_FORCED 
{ 
    local($_) = $_[0]; tr/A-Z/a-z/; $Envelope{"fh:$_:"} = $_[1];
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_ORIGINAL
{ 
    local($_) = $_[0]; tr/A-Z/a-z/; $Envelope{"oh:$_:"} = 1;
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_OF_REPORT_MAIL 
{ 
    local($_) = $_[0]; $Envelope{"GH:$_:"} = $_[1];
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_PAT_TO_REJECT
{ 
    $REJECT_HDR_FIELD_REGEXP{$_[0]} = $_[1];
    $REJECT_HDR_FIELD_REGEXP_REASON{$_[0]} = $_[2] if $_[2];
}

sub ADD_FIELD
{ 
    grep(/$_[0]/, @HdrFieldsOrder) || push(@HdrFieldsOrder, $_[0]);
    &Debug("ADD_FIELD $_[0]") if $debug;
}

sub DELETE_FIELD 
{
    local(@h); 

    # If $SKIP_FIELDS has no this entry.
    # print STDERR "    if ($SKIP_FIELDS !~ /\"\\|$_[0]\\|\"/) { \n";
    if ($SKIP_FIELDS !~ /\|$_[0]$|\|$_[0]\|/) {
	$SKIP_FIELDS .= $SKIP_FIELDS ? "|$_[0]" : $_[0];
    }

    for (@HdrFieldsOrder) { push(@h, $_) if $_ ne $_[0];}
    @HdrFieldsOrder = @h;
}

# the value is not inserted now.
sub COPY_FIELD 
{ 
    $HdrFieldCopy{ $_[0] } = $_[1];
    &ADD_FIELD(&FieldCapitalize($_[1]));
}

# the value is not inserted now.
sub MOVE_FIELD 
{ 
    &COPY_FIELD(@_);
    &DELETE_FIELD($_[0]);
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

    $0 = "$FML: Locked(flock) until $ut <$LOCKFILE>";

    # spool is also a file!
    if (! open(LOCK, $FlockFile)) {
	&Log("Flock:Cannot open FlockFile[$FlockFile]"); 
	die("Flock:Cannot open FlockFile[$FlockFile]"); 
    }
    flock(LOCK, $LOCK_EX);
}

sub Funlock 
{
    $0 = "$FML: Unlock <$LOCKFILE>";

    flock(LOCK, $LOCK_UN);
    close(LOCK); # unlock,close <kizu@ics.es.osaka-u.ac.jp>
}

# do not anything except for logging since now the fatal error case.
sub TimeOut
{
    &GetTime;
    $0 = "$FML: TimeOut $Now <$LOCKFILE>";

    # Now we may be not able to connect socket, isn't it?
    # &Warn("TimeOut: $MailDate ($From_address) $ML_FN", &WholeMail);
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

    &GetTime; $0 = "$FML: Tick $Now <$LOCKFILE>";

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
