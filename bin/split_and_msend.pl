#!/usr/local/bin/perl
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");

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
require 'config.ph';		# configuration file for each ML
eval("require 'sitedef.ph';");  # common defs over ML's
&use('smtp');			# a library using smtp

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Init;

&Lock;				# Lock!

$START_HOOK && &eval($START_HOOK, 'Start hook'); # additional before action

&SplitAndMSend;			# Mail MatomeOkuri file

&Unlock;			# UnLock!

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'} || $Envelope{'error'};
				# some report or error message if needed.
				# should be here for e.g., mget, ...

exit 0;



sub Init
{
    $From_address = "split_and_msend";
    $MATOMEOKURI_SKIP_FIELDS .= 
	'Return-Path|Date|Reply-To|Errors-To|X-ML-Name|X-MLServer|X-ML-INFO|Precedence';
}


sub SplitAndMSend
{
    $0 = "--Matomete Sending <$FML $LOCKFILE>";

    local($to, $file, $Status, $lines, $mlist);
    local($i, $mode, $subject, $sleep, $tmpbase);
    local(@to, $mlist); 
    
    ### 
    $file = $_cf{"opt:f"} || $MATOMEOKURI_FILE;
    print STDERR "FILE: $file\n" if $debug;

    if (! -f $file) { &Log("Not exist such a file:$file"); return;}

    ### the numer of the lines of matome okuri file
    open(F, $file) || (&Log("MSend R1:$!"), return);
    while (<F>) { $lines++;} 
    close(F);

    # if no spooled, do nothing.
    if (0 == $lines) { &Log("No spooled mail to send"); return;}

    # the member list
    $mlist = $ML_MEMBER_CHECK ? ACTIVE_LIST : $MEMBER_LIST;
    &GetMember(*to, *mlist);
    if (! @to) { &Log("MSend R1: No member to send"); return;}

    &use('fop');

    ### Variables
    $mode    = $MATOMEOURI_MODE    || 'uf';
    $subject = $MATOMEOURI_SUBJECT || "Matome Okuri $ML_FN";
    $sleep   = $SLEEP_TIME || 30;
    $tmpbase = "$TMP_DIR/split_and_msend$$";

    $i = &SplitUnixFromFile($file, $tmpbase);
    &SendingBackInOrder($tmpbase, $i, $subject, $sleep, @to);

    ### reset
    truncate($file, 0);	# truncate is BSD only;
}


sub SplitUnixFromFile
{
    local($file, $tmpbase) = @_;
    local($i, $buflines, $buf);

    $i = 1;			# 1 not 0;

    open(F, $file) || (&Log("MSend R1:$!"), return);
    open(OUT, "> $tmpbase.$i") || (&Log("MSend R1:$!"), return);
    select(OUT); $| = 1; select(STDOUT);

    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 1000;

    while (<F>) { 
	next if $MATOMEOKURI_SKIP_FIELDS && /^($MATOMEOKURI_SKIP_FIELDS):/i;

	if ($buflines > $MAIL_LENGTH_LIMIT) {
	    close(OUT);
	    $i++;
	    open(OUT, "> $tmpbase.$i") || (&Log("MSend R1:$!"), return);
	    undef $buflines;
	}

	if (/^From\s+$MAINTAINER/i && $buf) {
	    print OUT $buf;
	    undef $buf;
	}

	$buf .= $_;
	$buflines++;
    }

    close(OUT);
    close(F);

    $i;
}

sub GetMember
{
    local(*to, *list) = @_;

    open(LIST, $list) || (&Log("MSend R1:$!"), return);

    # Get a member list to deliver
    # After 1.3.2, inline-code is modified for further extentions.
  line: while (<LIST>) {
      chop;

      # pre-processing
      /^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx
      next line if /^\#/o;	# skip comment and off member
      next line if /^\s*$/o;	# skip null line
      next line if /^$MAIL_LIST$/io; # no loop back
      next line if $CONTROL_ADDRESS && /^$CONTROL_ADDRESS$/io;

      # Backward Compatibility.	tricky "^\s".Code above need no /^\#/o;
      s/\smatome\s+(\S+)/ m=$1 /i;
      s/\sskip\s*/ s=skip /i;
      local($rcpt, $opt) = split(/\s+/, $_, 2);
      $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

      printf STDERR "%-30s %s\n", $rcpt, $opt if $debug;
      next line unless $opt =~ /\s[ms]=/i;	# tricky "^\s";

      print STDERR "push(\@to, $rcpt)\n\n" if $debug;
      push(@to, $rcpt);
      $num_rcpt++;
  }

    close(ACTIVE_LIST);
    $num_rcpt;
}



##### SubRoutines #####
#:include: fml.pl
#:sub Notify ExExec RunHooks Conv2mailbox GetTime Parsing
#:sub WholeMail eval AddressMatch Log Logging 
#:sub Opt SetCommandLineOptions LoopBackWarn Lock Unlock Flock Funlock
#:sub Touch Write2 Append2 use Debug InitConfig Warn ChkREUid
#:replace
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
    # a little configuration before the action
    umask (077);			# rw-------
    $Envelope{'mode:uip'}  	= '';	# default UserInterfaceProgram is nil.
    $Envelope{'req:guide'} 	= 0;	# not member && guide request only

    &SetCommandLineOptions;
    if ($_cf{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

    &GetTime;

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER!\$MAIL_LIST = \$MAINTAINER, STOP!");
	exit 0;
    }

    ### Set Defaults
    $_cf{'perlversion'} = 5 if ($] =~ /5\.\d\d\d/);
    $TMP_DIR = ( $TMP_DIR || "./tmp" ); # backward compatible
    $VAR_DIR    = $VAR_DIR    || "./var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR = $VARLOG_DIR || "./var/log"; # absolute for ftpmail
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$VARLOG_DIR/log.msgid";
    $SECURITY_LEVEL = ($SECURITY_LEVEL || 2); # Security (default=2 [1.4d])
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)

    # Exceptional procedure KEYWORD to detect before &CheckMember
    # CHECK KEYWORDS. Default is 'guide'
    $GUIDE_KEYWORD  = $GUIDE_KEYWORD  || 'guide'; 

    # CHECK CHADDR_KEYWORDS. Default ...
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    # message-id: loop check
    $CHECK_MESSAGE_ID = 1;

    ### Backward Compatibility
    push(@ARCHIVE_DIR, @StoredSpool_DIR); # FIX INCLUDE PATH
    push(@INC, $LIBMIMEDIR) if $LIBMIMEDIR;
    $SPOOL_DIR =~ s/$DIR\///;
    ($REMORE_AUTH||$REMOTE_AUTH) && $REMOTE_ADMINISTRATION_REQUIRE_PASSWORD++;
    &use('compat') if $COMPAT_FML15;
    
    ### Initialize the ML server, spool and log files.  
    ### moved from Distribute and codes are added to check log files
    for ($SPOOL_DIR, $TMP_DIR, $VAR_DIR, $VARLOG_DIR) { 
	-d $_ || mkdir($_, 0700);
    }

    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    # Turn Over log file (against too big)
    if ((stat($LOG_MESSAGE_ID))[7] > 25*100) { # once about 100 mails.
	&use('newsyslog');
	&NewSyslog'TurnOver($LOG_MESSAGE_ID);#';
    }

    ### HELO in SMTP ($s in /etc/sendmail.cf)
    # Define for $s in config.ph by Configure since 1.3.1.23 
    # 95/09/14, 95/10/1 fukachan@phys.titech.ac.jp
    if (! $Envelope{'macro:s'}) {
	&use('utils');
	&Append2("\$Envelope{'macro:s'}\t= '".&GetFQN."';\n1;\n", "config.ph");
    }

    ### misc 
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # For tracing Process Table
}


# one pass to cut out the header and the body
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($nlines, $nclines);

    # Guide Request Check within in the first 3 lines
    $GUIDE_CHECK_LIMIT || ($GUIDE_CHECK_LIMIT = 3);
    
    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    $Envelope{'Header'} .= $_ unless /^$/o;
	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$Envelope{'req:guide'} = 1      if /^\#\s*$GUIDE_KEYWORD\s*$/i;
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


# Expand mailbox in RFC822
# From_address is user@domain syntax for e.g. member check, logging, commands
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
sub Conv2mailbox
{
    local($mb) = @_;

    # NULL is given, return NULL
    ($mb =~ /^\s*$/) && (return $NULL);

    # RFC822 unfolding
    $mb =~ s/\n(\s+)/$1/g;

    # Hayakawa Aoi <Aoi@aoi.chan.panic>
    ($mb =~ /^\s*.*\s*<(\S+)>.*$/io) && (return $1);

    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
    ($mb =~ /^\s*(\S+)\s*.*$/io)     && (return $1);

    # Aoi@aoi.chan.panic
    return $mb;
}	



# Recreation of the whole mail for error infomation
sub WholeMail   
{ 
    $_ = ">".$Envelope{'Header'}."\n".$Envelope{'Body'};
    s/\n/\n\>/g; 
    "Original Mail:\n$_";
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



# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub LogWEnv { local($s, *e) = @_; &Log($s); $e{'message'} .= "$s\n";}
sub Log { 
    local($str, $s) = @_;
    local($package,$filename,$line) = caller; # called from where?
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

    if (! open(APP, $w ? "> $f": ">> $f")) {
	local($r) = -f $f ? "cannot open $f" : "$f not exists";
	$nor ? (print STDERR "$r\n") : &Log($r);
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP $s . ($nonl ? "" : "\n") if $s;
    close(APP);

    1;
}


sub Touch  { &Append2("", @_, 1);}


sub Write2 { &Append2(@_, 1);}


# Notification of the mail on warnigs, errors ... 
sub Notify
{
    # refer to the original(NOT h:Reply-To:);
    local($to) = $Envelope{'message:h:to'} || $Envelope{'Addr2Reply:'};
    local(@to) = split(/\s+/, $Envelope{'message:h:@to'});
    local($s)  = $Envelope{'message:h:subject'} || "fml Status report $ML_FN";

    if ($Envelope{'message'}) {
	$Envelope{'message'} .= "\n\tSee you!   $FACE_MARK\n";
	&use('utils');
	$Envelope{'trailer'}  = &GenInfo;
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


# Warning to Maintainer
sub Warn { &Sendmail($MAINTAINER, $_[0], $_[1]);}


# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    &CompatFML15_Post if $COMPAT_FML15;

    $@ ? (&Log("$_[1]:$@"), 0) : 1;
}


# Getopt
sub Opt { push(@CommandLineOptions, @_);}
    

# Setting CommandLineOptions after include config.ph
sub SetCommandLineOptions
{
    foreach (@CommandLineOptions) {
	/^\-(\S)/      && ($_cf{"opt:$1"} = 1);
	/^\-(\S)(\S+)/ && ($_cf{"opt:$1"} = $2);

	/^\-d|^\-bt/   && ($debug = 1)         && next;
	/^\-s(\S+)/    && &eval("\$$1 = 1;")   && next;
	/^\-u(\S+)/    && &eval("undef \$$1;") && next;
	/^\-l(\S+)/    && ($LOAD_LIBRARY = $1) && next;
    }

    if ($DUMPVAR) { require 'dumpvar.pl'; &dumpvar('main');}
}


sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $debug_message;
}


# Check uid == euid && gid == egid
sub ChkREUid
{
    print STDERR "\nsetuid is not set $< != $>\n\n" if $< != $>;
    print STDERR "\nsetgid is not set $( != $)\n\n" if $( ne $);
}


# Check Looping 
# return 1 if loopback
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;
    local($ml);

    foreach $ml ($MAIL_LIST, $CONTROL_ADDRESS, @PLAY_TO) {
	next if $ml =~ /^$/oi;	# for null control addresses
	if (&AddressMatch($to, $ml)) {
	    &Debug("&AddressMatch($to, $ml)") if $debug;
	    &Log("Loop Back Warning: ", "[$From_address] or [$to]");
	    &Warn("Loop Back Warning: $ML_FN", &WholeMail);
	    return 1;
	}
    }

    0;
}


sub Lock 
{ 
    # Check flock() OK?
    if ($USE_FLOCK) {
	eval "open(LOCK, $SPOOL_DIR) && flock(LOCK, $LOCK_SH);"; 
	$USE_FLOCK = ($@ eq "");
    }

    $USE_FLOCK ? &Flock : (&use('lock'), &V7Lock);
}


sub Unlock { $USE_FLOCK ? &Funlock : &V7Unlock;}


# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    open(LOCK, $SPOOL_DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}


sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}

1;





1;
