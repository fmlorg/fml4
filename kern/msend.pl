#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid  = '2.0 delta Internal';

# For the insecure command actions
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
$DIR    = $DIR    || '/home/axion/fukachan/work/spool/EXP';
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);

#################### MAIN ####################
# including libraries
require 'config.ph';		# a config header file
eval("require 'sitedef.ph';");  # common defs over ML's
require 'libsmtp.pl';		# a library using smtp
require 'libfop.pl';		# file operations

# a little configuration before the action
umask (077);			# rw-------

chdir $DIR || die "Can't chdir to $DIR\n";

&MSendInit;			# IF $MSEND_RC is NOT SET, exit

########## PROCESS GO! ##########
if ($0 eq __FILE__) {
    &InitConfig;			# initialize date etc..

    $Quiet      = 1 if $_cf{"opt:q"}; # quiet mode;
    $SLEEPTIME  = 5;

    print STDERR "MatomeOkuri Control Program Rel.4 for $ML_FN\n\n" unless $Quiet;

    if ($_cf{"opt:b"} eq 'd' || $_cf{"opt:b"} eq 'sr') {# Daemon or Self Running;
	local($t);
	while (1) {
	    $t = time;
	    &ExecMSend;
	    $t = time - $t; # used time 
	    &Log("MSend Daemon: sleep(3600 - $t)") if $debug;
	    $0 = "--MSend Daemon $ML_FN <$FML $LOCKFILE>";
	    sleep(3600 - $t); # adjust the sleeptime;
	}
    }
    else {
	&ExecMSend;
    }

    exit 0;				# the main ends.
}
else {
    print STDERR "Loading MSend.pl as a library\n" if $debug;
    for $proc (GetTime, InitConfig, GetID , Debug, MSending, 
	 MSendMasterControl, MSendRCConfig, Log, 
	 Logging, Warn, eval, Opt, Flock, Funlock) {
	undef &$proc;
    }
}

#################### MAIN ENDS ####################

##### SubRoutines #####
sub ExecMSend
{
    &GetTime;
    
    $Hour || die "Not Set \$Hour Variable\n";

    $MSEND_START_HOOK && &eval($MSEND_START_HOOK, 'Start hook'); # additional before action

    # NOTIFICATION of NO TRAFFIC
    $MSEND_NOTIFICATION && &MSendNotifyP && &MSendNotify;

    &MSend4You;			        # MAIN

    if ($_cf{"opt:n"}|| $debug && ($ID % 3 == 0)) {     # debug mode
	print STDERR "DEBUG MODE try turn over \@NEWSYSLOG_FILES \n";
	require 'libnewsyslog.pl'; 
	&NewSyslog(@NEWSYSLOG_FILES);
    }

    #&MSendRunHooks;			        # run hooks after unlocking

    &Notify if $Envelope{'message'};    # Reply some report if-needed.
	                                # should be here for e.g. mget..

}


sub MSend4You
{
    &Lock;

    &GetID;				# set $ID
    &GetDistributeList;

    &Unlock;			        # unlock against slow distributing

    &MSendMasterControl;

    &Lock;			        # lock to reconfig MSendRC

    &MSendRCConfig;			# When new comers exist. 

    &eval($_cf{'Destr'}, 'Destructer:');# Destructer;

    &Unlock;			        # Unlock and ENDS
}


# Check the Matome Okuri Kankaku
# if 2 hours, 0, 2, 4, 6, 8 ...(implies modulus is 2)
sub MSendP
{
    local($who, $str) = @_;

    if ((! $str) && (!$Quiet)) {
	printf STDERR 
	    "%-30s :(%-2d %% %-2d) && (%-5d - %-5d)>=0: %s\n",
	    $who, $Hour, $When{$who}, $ID, $Request{$who}, 
	    &DocModeLookup("#".$mode{$who});
    }

    return if (! defined($When{$who}));

    # CHECK: Modulus 
    if (($ID - $Request{$who}) >= 0) {
	return 1 if (0 == ($Hour % $When{$who}));
	return 1 if ($When{$who} > 12 && ($Hour + 24 == $When{$who}));
    }

    return 0;
}


# Get ID 
sub GetID
{
    open(IDINC, "< $SEQUENCE_FILE") || (&Log($!), return);
    $ID = <IDINC>; 
    chop $ID;
    close(IDINC);

    $ID;
}


# VARIABLE LIST
# %Request	: send mails from $Request{$rcpt} to  $ID
# %When		: the time to send
# %mode		: mode of sending
# %RCPT		: recipient (if relay, aleady expanded relay-address)
#
# one pass to cut out the header and the body
sub GetDistributeList
{
    local($who) = @_;		# use when "# matome 0"
    local($rehash);

    # configuration of MSEND_RC
    if (-z $MSEND_RC) {		# if filesize is 0,
	print STDERR "WARNING: $MSEND_RC filesize=0 O.K.?\n" unless $Quiet;
    }

    if (! open(MSEND_RC, $MSEND_RC)) {
	print STDERR "not found $MSEND_RC\n" unless -f $MSEND_RC;
	print STDERR "cannot open $MSEND_RC:$!\n";
	&Log("cannot open $MSEND_RC:$!");
	return;
    };

    open(BACKUP, ">> $MSEND_RC.bak") || do {
	print STDERR "cannot open $MSEND_RC.bak:$!\n";
	&Log("cannot open $MSEND_RC.bak:$!");
	return;
    };
    print BACKUP "-----Backup on $Now-----\n";
    
    # make a table of "when" a matomeokuri is sent to "who".
    line: while(<MSEND_RC>) {
	print BACKUP $_;
	next line if (/^\#/o);	# skip comment and off member
	next line if (/^\s*$/o);	# skip null line
	chop;

	tr/A-Z/a-z/;		# E-mail form(RFC822)
	/^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment;
	local($rcpt, $rc) = split(/\s+/, $_, 999);
	$RCPT{$rcpt}    = $rcpt;
	$Request{$rcpt} = $rc;

	print STDERR "RC:\t$RCPT{$rcpt}\t$Request{$rcpt}\n" if $debug;

	$rehash = $rc if $who && &AddressMatch($who, $rcpt);
    }

    close MSEND_RC; 
    close BACKUP;

    # REHASH when "# matome 0"
    return $rehash if $who;

    ### O.K. open ACTIVE LIST and check matomeokuri or not 
    if (! $ML_MEMBER_CHECK) { $ACTIVE_LIST = $MEMBER_LIST;}

    open(ACTIVE_LIST) || do {
	print STDERR "cannot open $ACTIVE_LIST:$!\n";
	&Log("cannot open $ACTIVE_LIST:$!");
	return;
    };

  line: while (<ACTIVE_LIST>) {	# RMS <-> Relay, Matome, Skip
      chop;
      tr/A-Z/a-z/;		# E-mail form(RFC822)
      /^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx;
      next line if (/^\#/o);	# skip comment and off member
      next line if (/^\s*$/o);	# skip null line

      # Backward Compatibility.	tricky "^\s".Code above need no /^\#/o;
      s/\smatome\s+(\S+)/ m=$1 /i;
      s/\sskip\s*/ s=skip /i;
      local($rcpt, $opt) = split(/\s+/, $_, 2);
      $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

      next line if (/\ss=/io);
      next line unless(/\sm=/io); # for MatomeOkuri ver.2

      printf STDERR "AL:%-40s %-25s\n", $rcpt, $opt if $debug;

      # set candidates of delivery
      $RCPT{$rcpt} = $rcpt;

      # Matomeokuri Mode Settings
      if ($opt =~ /\sm=(\d+)\s/i) {
	  $When{$rcpt}  = $DefaultWhen || $1;
	  local($d, $m) = &ModeLookup($1.$2);
	  $mode{$rcpt}  = $m;
	  # $mode{$rcpt} = 'gz';
      }
      elsif ($opt =~ /\sm=(\d+)([A-Za-z]+)\s/i) {
	  $When{$rcpt}  = $DefaultWhen || $1;
	  local($d, $m) = &ModeLookup($1.$2);
	  $mode{$rcpt}  = $m;
      }
      else {
	  $mode{$rcpt} = $MSEND_MODE_DEFAULT || 'gz';
	  print STDERR "ERROR: NO MATCH OPTION[$opt], so => $mode{$rcpt} mode\n";
      }

      # Relay
      if ($opt =~ /\sr=(\S+)/i) {
	  local($relay) = $1;
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $RCPT{$rcpt} = "$who%$mxhost\@$relay";
      }	# % relay is not refered in RFC, but effective in Sendmail's.

      $When{$rcpt}   = 1 if $_cf{'opt:a'}; # opttion -a always(for Ver.5)

      if ($debug) {
	  printf STDERR 
	      "=> %-35s %-30s /%d [%s]\n", 
	      $rcpt, $RCPT{$rcpt}, $When{$rcpt}, &DocModeLookup("#".$mode{$rcpt});
      }
      
  }# end of while;

    close(ACTIVE_LIST);
}


sub Debug
{
local($s) = q#"
MEMBER_CHECKP $ML_MEMBER_CHECK
ACTIVE_LIST   $ACTIVE_LIST
"#;

"print STDERR $s";
}


sub MSending
{
    local($left, $right, $PACK_P, @to) = @_;
    local($to) = join(" ", @to);
    local(@filelist, $total);

    $0 = "--MSending to $to $ML_FN <$FML $LOCKFILE>";

    # check the given condistion is correct or not?
    print STDERR "TRY $left -> $right for $to \n" if $debug;
    if (!defined($left)) { 
	&Log("MSend: Cannot find left  for $to"); return;
    }
    if (!defined($right)) { 
	&Log("MSend: Cannot find right for $to"); return;
    }

    # get a file list to send
    for($left .. $right) { push(@filelist, "$SPOOL_DIR/$_");}

    # Sending
    &Log("MSend: $left -> $right ($to)");
    print STDERR "MSend: $left -> $right ($to)\n" unless $Quiet;
     
    $0 = "--MSending to $to $ML_FN ends <$FML $LOCKFILE>";

    # matome.gz -> matome.ish in LhaAndEncode2Ish().
    local($total, $tmp, $mode, $name, $s);
    $tmp   = "$FP_TMP_DIR/MSend$$"; # relative
    $mode = $mode{$to[0]};
    $total = &DraftGenerate($tmp, $mode, "matome.gz", @filelist);

    # Make a subject here since mode::constructor in DraftGenerate. 
    $s    = ($_cf{'subject', $mode} || "Matomete Send");
    $name = &DocModeLookup("#3$mode");
    $s   .= " [$name]";

    if ($total) {
print STDERR "
	&SendingBackInOrder($tmp, $total, $s, ($SLEEPTIME || 3), @to);
";

	&SendingBackInOrder($tmp, $total, $s, ($SLEEPTIME || 3), @to);
	$0 = "--MSending to $to $ML_FN ends <$FML $LOCKFILE>";
    }
}


sub MSendMasterControl
{
    local(%mconf);

    $0 = "--MSendMasterControl $ML_FN <$FML $LOCKFILE>";

    foreach (keys %RCPT) {
	if (! $When{$_}) {
	    print STDERR "Remove $RCPT{$_}\n" unless $Quiet;
	    delete $RCPT{$_};
	    next;
	}

	# patched by Shigeki Morimoto <mori@isc.mew.co.jp>
	# fml-support:00338 on Tue, 18 Apr 1995 10:52:24 +0900
        # if now the time to send
	if (1 == &MSendP($_)) {
	    # determine the first $ID
	    local($id)   = ($Request{$_} || $ID);
	    local($mode) = $mode{$_};

	    # Make a list ($id $mode)
	    # ($id $mode) is required for the last "change command"
	    # THIS LIST is required to lighten the sendmail work by 
	    # setting a list to deliver		
	    $mconf{"$id:$mode"} .= $RCPT{$_}." ";
	    print STDERR "\$mconf{\"$id:$mode\"} = $mconf{\"$id:$mode\"}\n" unless $Quiet;
	}
    }

    # O.K. sending
    foreach (keys %mconf) {
	local($id, $mode) = split(/:/, $_);
	local(@to) = split(/\s+/, $mconf{$_});
	
	# MSending($left, $right, $mode, @to);
	if (! $Quiet) {
	    print STDERR "\@to = ". join(":",@to) .";\n";
	    print STDERR "&MSending($id, $ID, $mode, ".join(" ", @to).");\n";
	}

	&MSending($id, $ID, $mode, @to);
    }
}


sub MSendRCConfig
{
    $0 = "--MSendRCConfig $ML_FN <$FML $LOCKFILE>";
    local($warn, $who);

    ### Update RC temporary file ###
    open(MSEND_RC, "> $MSEND_RC.new") || do {
	print STDERR "cannot open $MSEND_RC. Cannot reset:$!\n";
	&Log("cannot open $MSEND_RC. Cannot reset:$!");
	return;
    };
    select(MSEND_RC); $| = 1; select(STDOUT);

    foreach $who (keys %RCPT) { 
	print STDERR "Reconfigure MSendrc\t[$who]\n" if $debug;
	next unless $RCPT{$who}; # if matome 0, remove the member

	# if sent, reset the values
	if (1 == &MSendP($who, "NO_OUTPUT_HERE")) {
	    print MSEND_RC $who, "\t", $ID + 1, "\n";
	}
	else {			# not sent, old values
	    print MSEND_RC $who, "\t", 
	    $Request{$who} ? $Request{$who} : $ID, "\n"; 
	    # if no counter, add the present one
	}
    }

    close(MSEND_RC);

    ### Update RC file ###
    if ((! -z $MSEND_RC) && -z "$MSEND_RC.new") {
	print STDERR "WARNING:\n";
	print STDERR "\tReConfigured MSendrc must be filesize=0.\nO.K.?\n";
#	&Log("MSend R4: $MSEND_RC must be filesize=0");
#	&Warn("MSend R4 Inconsistency", 
#	      "$MSEND_RC must be filesize=0\nO.K.?\n");
	# return;# if only one matome -> synchronous delivery case?
    }

    if (0 == rename("$MSEND_RC.new", $MSEND_RC)) {
	print STDERR "ERROR:\n\tFILE UPDATE FAILS for $MSEND_RC.new\n";
	&Log("MSend R4: FILE UPDATE ERROR: $MSEND_RC.new");
	&Warn("MSend R4 Inconsistency", 
	      "MSend R4: FILE UPDATE ERROR: $MSEND_RC.new");
    }

    # remove the backup "MSendrc.bak" at moring 6 on Sunday
    if ((! $NOT_USE_NEWSYSLOG) && 
	('Sun' eq $WDay[$wday]) && (6 == $Hour)) {
	if (! $Quiet) {
	    print STDERR ('*' x 70)."\n\n";
	    print STDERR "Newsyslog at Sun 6 a.m\n\n";
	    print STDERR ('*' x 70)."\n\n"; 
	}

	require 'libnewsyslog.pl';
	&NewSyslog(@NEWSYSLOG_FILES);
    }

    &Warn("MSend R4 Inconsistency", $warn) if $warn;
}


# Distribute mail to members
sub MSendNotify
{
    $0 = "--Distributing <$FML $LOCKFILE>";
    local($mail_file, $status, $num_rcpt, $s, *Rcpt);

    ###### $Envelope{"h::"} #####
    $Envelope{"h:Return-Path:"}	= $MAINTAINER;
    $Envelope{"h:Date:"}	= $MailDate;
    $Envelope{"h:From:"}	= $MAINTAINER;
    $Envelope{"h:To:"}		= $MAIL_LIST;
    $Envelope{"h:Errors-To:"}	= $MAINTAINER if $AGAINST_NIFTY;
    $Envelope{"h:Precedence:"}	= 'list';

    # Please set $MSEND_NOTIFICATION_SUBJECT in config.ph
    $Envelope{"h:Subject:"}	= 
	$MSEND_NOTIFICATION_SUBJECT || "Notification $ML_FN";


    ##### ML Preliminary Session Phase 03: get @Rcpt
    open(ACTIVE_LIST) || (&Log("cannot open $ACTIVE_LIST ID=$ID:$!"), return);

  line: while (<ACTIVE_LIST>) {
      chop;

      # pre-processing
      /^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx
      next line if /^\#/o;	# skip comment and off member
      next line if /^\s*$/o;	# skip null line
      next line if /$MAIL_LIST/io; # no loop back
      next line if $CONTROL_ADDRESS && /$CONTROL_ADDRESS/io;

      # Backward Compatibility.	tricky "^\s".Code above need no /^\#/o;
      s/\smatome\s+(\S+)/ m=$1 /i;
      s/\sskip\s*/ s=skip /i;
      local($rcpt, $opt) = split(/\s+/, $_, 2);
      $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

      printf STDERR "%-30s %s\n", $rcpt, $opt if $debug;

      # Relay server
      if ($opt =~ /\sr=(\S+)/i) {
	  local($relay) = $1;
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $rcpt = "$who%$mxhost\@$relay";
      }	# % relay is not refered in RFC, but effective in Sendmail's.

      print STDERR "RCPT:$rcpt\n\n" if $debug;
      push(@Rcpt, $rcpt);
      $num_rcpt++;
  }

    close(ACTIVE_LIST);


    ##### ML Distribute Phase 01: Fixing and Adjusting *Header
    # Added INFOMATION
    if (! $NO_ML_INFO) {
	$Envelope{'h:X-ML-INFO:'} = 
	    "If you have a question, %echo \# help|Mail ".&CtlAddr;
    }

    ##### ML Distribute Phase 02: Generating Hdr
    # This is the order recommended in RFC822, p.20. But not clear about X-*
    for ('Return-Path', 'Date', 'From', 'Subject', 'Sender', 'To', 
	 'Reply-To', 'Errors-To', 'Cc', 'Posted') {
	$Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
    }

    # Server info to add
    $Envelope{'Hdr'} .= "$XMLNAME\n";
    $Envelope{'Hdr'} .= "X-Debug: $rcsid\n" if $debug && $rcsid;
    $Envelope{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
	
    # MIME (see RFC1521)
    if (! $PREVENT_MIME) {
	for ('mime-version', 'content-type', 'content-transfer-encoding') {
	    $Envelope{'Hdr'} .= 
		"$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
	}
    }

    # Precedence: Sendmail 8.x for delay mail
    for ('XRef', 'X-Stardate', 'X-ML-INFO', 'Precedence', 'Lines') {
	$Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
    }


    ##### ML Distribute Phase 03: SMTP
    # IPC. when debug mode or no recipient, no distributing 
    if ($num_rcpt && (!$debug)) {
	$status = &Smtp(*Envelope, *Rcpt);
	&Log("Sendmail:$status") if $status;
	&MSendNotifyTouch;
    }
}


sub MSendNotifyP { 
    ($Hour == 24 || $Hour == 1 || $Hour == 2 || $Hour == 3) &&
	(time - (stat($SEQUENCE_FILE))[9]) > (24 * 3600);
}


sub MSendInit
{
    $Envelope{'h:From:'}     = $From_address  = "MSend R4";
    $Envelope{'h:Reply-To:'} = $MAIL_LIST;	# for reply for matomeokuri

    $DefaultWhen   = 0;		# Default synchronous mode for 1153
    $Hour = (localtime(time))[2];	# Only this differ from &GetTime in fml.pl
    $Hour = (0 == $Hour) ? 24 : $Hour;

    $MSendTouchFile = "$TMP_DIR/msend_last_touch"; # what for ?

    ### SET DEFAULT MODE 
    # Default setting should be HERE 96/02/13 kishiba@ipc.hiroshima-u.ac.jp
    # DEFAULT ACTION is not 'mget'. 
    $MSEND_OPT_HOOK .= q%$MSendOpt{''} = 'gz';%;

    if ($USE_RFC1153_DIGEST || $USE_RFC1153) {# 1153 digest;
	# the standard for 1153-counter, but required?
	# anyway comment out below 95/6/27
	#    $DefaultWhen    = $DefaultWhen || 3;
	$MSEND_OPT_HOOK .= q%$MSendOpt{''} = 'rfc1153';%;
    }

    if ($USE_RFC934) {	# 934 
	$MSEND_OPT_HOOK .= q%$MSendOpt{''} = 'rfc934';%;
    }

    # CHECK MSEND_RC DEFINED OR NOT? for fml 1.x (96/02/13)
    # Using the default value is dangerous. This variable should be not automatic-fixed
    # for the continuous use of msend.pl even in 1.x -> 2.x installing process ...
    if (! $MSEND_RC) {
	&Log("\$MSEND_RC IS NOT DEFINED", "Please Define \$MSEND_RC in config.ph");
	die "\$MSEND_RC IS NOT DEFINED, SO EXIT!\nPlease define $MSEND_RC.\n";
    }

    print STDERR "\$MSEND_RC = $MSEND_RC\n";
}


##################################################################
#:include: fml.pl
#:sub LoadConfig SetDefaults BackwardCompat GetTime InitConfig 
#:sub Logging Log Append2 Warn eval Opt Flock Funlock
#:sub SetCommandLineOptions AddressMatch Lock Unlock use
#:sub Touch Write2 RunHooks Notify
#:~sub
##################################################################
#:replace
#:replace
# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    open(LOCK, $FP_SPOOL_DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}


sub SetDefaults
{
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)
    $Envelope{'mode:uip'}   = '';    # default UserInterfaceProgram is nil.;
    $Envelope{'req:guide'}  = 0;     # not member && guide request only

    %SEVERE_ADDR_CHECK_DOMAINS = ('or.jp', +1);
    $REJECT_ADDR = 'root|postmaster|MAILER-DAEMON|msgs|nobody';
    $SKIP_FIELDS = 'Received|Return-Receipt-To';

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
}


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
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP "$s\n" if $s;
    close(APP);

    1;
}


# Warning to Maintainer
sub Warn { &Sendmail($MAINTAINER, $_[0], $_[1]);}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}


# Getopt
sub Opt { push(@SetOpts, @_);}
    

sub LoadConfig
{
    # configuration file for each ML
    require 'config.ph' if -f "$DIR/config.ph" || -f "$LIBDIR/config.ph";

    eval("require 'sitedef.ph';");      # common defs over ML's
    require 'libsmtp.pl';		# a library using smtp
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


# Strange "Check flock() OK?" mechanism???
sub Lock { $USE_FLOCK ? &Flock : (&use('lock'), &V7Lock);}


sub Unlock { $USE_FLOCK ? &Funlock : &V7Unlock;}


# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}


sub Touch  { &Append2("", $_[0]);}


sub Write2 { &Append2(@_, 1);}


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


sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}



1;
