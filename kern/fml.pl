#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");
$rcsid  .= '(1.6alpha)';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# Directory of Mailing List Server Libraries
# format: fml.pl DIR(for config.ph) PERLLIB's -options
$DIR		= $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/EXP';
$LIBDIR		= $ARGV[1] ? $ARGV[1] : $DIR;	# LIBDIR is the second arg. 
foreach (@ARGV) { /^\-/ && &Opt($_) || push(@INC, $_);}# add to include path;

#################### MAIN ####################
# including libraries
require 'config.ph';		# a config header file for each ML
eval("require 'sitedef.ph';");  # common defs over ML's
&use(smtp);			# a library using smtp

&ChkREUid;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Parsing;			# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

&Lock;				# Lock!

$START_HOOK && &eval($START_HOOK, 'Start hook'); # additional before action

if ($DO_NOTHING) {		# Do nothing. Tricky. Please ignore 
    ;
}
elsif ($Envelope{'req:guide'}) {
    &GuideRequest;		# Guide Request from anyone
} 
elsif (&MLMemberCheck) { 
    &AdditionalCommandModeCheck;# e.g. for ctl-only address;

    if ($DO_NOTHING) {		# Do nothing. Tricky. Please ignore 
	;
    }
    elsif ($LOAD_LIBRARY) {	# to be a special purpose server
	require $LOAD_LIBRARY;	# default is 'libfml.pl';
    } 
    else {			# distribution mode(Mailing List)
	&Distribute;
    }
}

&Unlock;			# UnLock!

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'};# Reply some report if-needed.
				# should be here for e.g. mget..

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

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
    &GetTime;

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER!\$MAIL_LIST = \$MAINTAINER, STOP!");
	exit 0;
    }

    ### Set Defaults
    $_cf{'perlversion'} = 5 if ($] =~ /5\.\d\d\d/);
    $TMP_DIR = ( $TMP_DIR || "./tmp" ); # backward compatible
    $VAR_DIR    = $VAR_DIR    || "$DIR/var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR = $VARLOG_DIR || "$DIR/var/log"; # absolute for ftpmail
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$VARLOG_DIR/log.msgid";
    $SECURITY_LEVEL = ($SECURITY_LEVEL || 2); # Security (default=2 [1.4d])
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)

    # Exceptional procedure KEYWORD to detect before &CheckMember
    # CHECK KEYWORDS. Default is 'guide'
    $GUIDE_KEYWORD  = $GUIDE_KEYWORD  || 'guide'; 

    # CHECK CHADDR_KEYWORDS. Default ...
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    ### Backward Compatibility
    push(@ARCHIVE_DIR, @StoredSpool_DIR); # FIX INCLUDE PATH
    push(@INC, $LIBMIMEDIR) if $LIBMIMEDIR;
    $SPOOL_DIR =~ s/$DIR\///;
    ($REMORE_AUTH||$REMOTE_AUTH) && $REMOTE_ADMINISTRATION_REQUIRE_PASSWORD++;

    ### Initialize the ML server, spool and log files.  
    ### moved from Distribute and codes are added to check log files
    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE) {
	-f $_ || &Touch($_);	
    }

    for ($SPOOL_DIR, $TMP_DIR) { 
	-d $_ || mkdir($_, 0700);
    }

    ### HELO in SMTP ($s in /etc/sendmail.cf)
    # Define for $s in config.ph by Configure since 1.3.1.23 
    # 95/09/14, 95/10/1 fukachan@phys.titech.ac.jp
    if (! $Envelope{'macro:s'}) {
	&use(utils);
	&Append2("\$Envelope{'macro:s'}\t= '".&GetFQN."';\n1;\n", 
		 "$DIR/config.ph");
    }

    ### misc 
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # Trick for tracing
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
	    if (/^$/o) { #required for split(tricky)
		$Envelope{'Header'} .= "\n";
		next;
	    } 

	    $Envelope{'Header'} .= $_;
	    $Envelope{'MIME'}    = 1 if /ISO\-2022\-JP/o;

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

# Phase 2(2nd pass), extract several fields 
# Here is in 1.2-current the local rule to define header fileds.
# Original form  -> $Subject                 -> distributed mails
#                -> $Original_From_address   -> distributed mails(obsolete)
#                95/10/01 $Original_From_address == $Envelope{'h:from:'}
# parsed headers -> $Summary_Subject(a line) -> summary file
sub GetFieldsFromHeader
{
    $0 = "--GetFieldsFromHeader <$FML $LOCKFILE>";

    # Local Variables
    local($field, $contents, $skip_fields, $use_fields, *Hdr, $Message_Id, $u);

    ###### FORMER PART is just 'extraction'

    # IF WITHOUT UNIX FROM e.g. for slocal bug??? 
    if (! ($Envelope{'Header'} =~ /^From\s+\S+/i)) {
	$u = $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;
	$Envelope{'Header'} = "From $u $MailDate\n".$Envelope{'Header'};
    }

    local($s) = $Envelope{'Header'};
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.
    
    ### PLEASE CUSTOMIZE BELOW FOR 'FIELDS TO SKIP'
    $skip_fields  = 'Received|Return-Path|X-MLServer|X-ML-Name|';
    $skip_fields .= 'X-Mail-Count|Precedence|Lines';
    $skip_fields .= $SKIP_FIELDS if $SKIP_FIELDS;

    ### PLEASE CUSTOMIZE BELOW FOR 'FIELDS TO USE IN DISTRIBUTION'
    $use_fields   = 'Date|Errors-to|Sender|Reply-to|To|Apparently-To|Cc|';
    $use_fields  .= 'Message-Id|Subject|From|';
    $use_fields  .= 'MIME-Version|Content-Type|Content-Transfer-Encoding';
    $use_fields  .= $USE_FIELDS if $USE_FIELDS;

    ### Parsing main routines
    for (@Hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {

	print STDERR "FIELD:          >$field<\n" if $debug;

        # UNIX FROM is a special case.
	# 1995/06/01 check UNIX FROM against loop and bounce
	/^from\s+(\S+)/io && ($Envelope{'UnixFrom'} = $Unix_From = $1, next);
	
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^\s*$/o;		# if null, skip. must be mistakes.

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/;
	$Envelope{$field} .= $contents;

	# Fields to skip. Please custumize $skip_fields above
	next if /^($skip_fields):/io;

	# filelds for later use. Please custumize $use_fields above
	$Envelope{"h:$field"} = $contents;
	next if /^($use_fields):/io;

	# hold fields without in use_fields if $SUPERFLUOUS_HEADERS is 1.
	$Envelope{'Hdr2add'} .= "$_ $contents\n" if $SUPERFLUOUS_HEADERS;
    }# FOR;



    ###### LATTER PART is to fix extracts

    ### Set variables
    $Envelope{'h:Return-Path:'} = "<$MAINTAINER>";        # needed?
    $Envelope{'h:Date:'}        = $Envelope{'h:date:'} || $Date;
    $Envelope{'h:From:'}        = $Envelope{'h:from:'};	  # original from
    $Envelope{'h:Sender:'}      = $Envelope{'h:sender:'}; # orignal
    $Envelope{'h:To:'}          = "$MAIL_LIST $ML_FN";    # rewrite TO:
    $Envelope{'h:Cc:'}          = $Envelope{'h:cc:'};     
    $Envelope{'h:Message-Id:'}  = $Envelope{'h:message-id:'}; 
    $Envelope{'h:Posted:'}      = $MailDate;
    $Envelope{'h:Precedence:'}  = $PRECEDENCE || 'list';
    $Envelope{'h:Lines:'}       = $Envelope{'nlines'};
    $Envelope{'h:Subject:'}     = $Envelope{'h:subject:'}; # anyway save

    # Some Fields need to "Extract the user@domain part"
    # $Envelope{'h:Reply-To:'} is "reply-to-user"@domain FORM
    $From_address               = &Conv2mailbox($Envelope{'h:from:'});
    $Envelope{'h:Reply-To:'}    = &Conv2mailbox($Envelope{'h:reply-to:'});

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) 
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if (($_ = $Envelope{'h:Subject:'}) && $STRIP_BRACKETS) {
	local($r)  = 10;	# recursive limit against infinite loop

	# e.g. Subject: [Elena:003] E.. U so ...
	s/\[$BRACKET:\d+\]\s*//g;

	#'/gi' is required for RE: Re: re: format are available
	while (s/Re:\s*Re:\s*/Re: /gi && $r-- > 0) { ;}

	$Envelope{'h:Subject:'} = $_;
    } 

    # Obsolete Errors-to:, against e.g. BBS like a nifty
    if ($AGAINST_NIFTY) {
	$Envelope{'h:Errors-To:'} = $Envelope{'h:errors-to:'} || $MAINTAINER;
    }

    ### For CommandMode Check(see the main routine in this flie)
    $Envelope{'mode:chk'} = 
	$Envelope{'h:to:'} || $Envelope{'h:apparently-to:'};
    $Envelope{'mode:chk'} .= ", $Envelope{'h:cc:'}, $Envelope{'h:bcc:'},";
    $Envelope{'mode:chk'} =~ s/\n(\s+)/$1/g;

    # Correction. $Envelope{'req:guide'} is used only for unknown ones.
    if ($Envelope{'req:guide'} && &CheckMember($From_address, $MEMBER_LIST)) {
	undef $Envelope{'req:guide'}, $Envelope{'mode:uip'} = 'on';
    }
#.IF CROSSPOST

    {
	local($cps) = 'Crossed among:';
	local(%addr, $n_cr);
	&Debug("\n*** CROSSPOST? ***\n") if $debug;

	# Crosspost extension
	# the tricky syntax ", " is required for the splitting(put above) 
	foreach (split(/\s*,\s*/, $Envelope{'mode:chk'})) {
	    next if /^\s*$/o;

	    # uniq emulation since ORDER is important, so "cannot sort" 
	    next if $addr{$_};
	    
	    &Debug("Candidate:\t$_") if $debug;

	    # lacking of this code leads to strange working...
	    # e.g. when it has a name or ..
	    # 95/08/07 fukachan@phys.titech.ac.jp
	    # delete (..) e.g. Elen@fuwafuwa.or.jp (Fuwafuwa Elen)
	    $_ = &Conv2mailbox($_);

	    # EXCEPT FOR From_address
	    if (! &AddressMatch($_, $From_address)) {
		$cps .= " [$_]"; # LOG MATCHED ADDR
		$n_cr++;
		&Debug("Crossed:\t$_") if $debug;
	    }
	    else {
		$cps .= " $_";	# LOG 'NOT MATCHED ONE'
		&Debug("HIS OWN:\t$_") if $debug;
	    }

	    $addr{$_} = 1;	# uniq emulation
	}

	&Debug($n_cr > 1 ? "\nCROSSPOST" : "\nNot Crosspost") if $debug;

	# include $MAIL_LIST own, so (> 1)	
	# if plural addresses, call, COMMAND MODE->do nothing
	if ((!$Envelope{'mode:uip'}) && ($n_cr > 1)) {
	    $Envelope{'crosspost'} = 1;
	    &Log($cps);
	    &use(crosspost);
	    &Crosspost; 
	}

	&Debug("\n*** CROSSPOST ROUTINE ENDS ***\n") if $debug;
    }
#.FI CROSSPOST

    ### SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS) {
	($Envelope{'h:Subject'} =~ /^\#\s*$GUIDE_KEYWORD\s*$/i) && 
	    $Envelope{'req:guide'}++;
	$COMMAND_ONLY_SERVER &&	
	    ($Envelope{'h:Subject'} =~ /^\s*$GUIDE_KEYWORD\s*$/i) && 
		$Envelope{'req:guide'}++;
    }    
    

    ### DEBUG 
    $debug && &eval(&FieldsDebug, 'FieldsDebug');
    
    ###### LOOP CHECK PHASE 1
    ($Message_Id) = ($Envelope{'h:Message-Id:'} =~ /\s*\<(\S+)\>\s*/);

    if (&CheckMember($Message_Id, $LOG_MESSAGE_ID)) {
	&Log("WARNING: Message ID Loop");
	&Warn("WARNING: Message ID Loop", &WholeMail);
	exit 0;
    }

    # If O.K., record the Message-Id to the file $LOG_MESSAGE_ID);
    &Append2($Message_Id, $LOG_MESSAGE_ID);
    
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


# When just guide request from unknown person, return the guide only
sub GuideRequest
{
    &Log("Guide from the unknown");
    &SendFile($From_address, "Guide $ML_FN", $GUIDE_FILE);
}

# the To_address is for command or not.
sub AdditionalCommandModeCheck
{
    # Default LOAD_LIBRARY SHOULD NOT BE OVERWRITTEN!
    if ($Envelope{'mode:uip'} || 
       ($CONTROL_ADDRESS && ($Envelope{'mode:chk'} =~ /$CONTROL_ADDRESS/i))) {
	$LOAD_LIBRARY || ($LOAD_LIBRARY = 'libfml.pl'); 
    }

    # prohibit an arbitrary user to use commands
    # and do not distribute too 
    # when + entry is matched.
    if ($PROHIBIT_COMMAND_FOR_STRANGER &&
	$LOAD_LIBRARY &&
	$Envelope{'mode:anyone:ok'}) {
	&Warn("Permit nothing for a stranger", &WholeMail);
	&Log("Permit nothing for a stranger");
	$DO_NOTHING = 1;
    }
}

# Recreation of the whole mail for error infomation
sub WholeMail { $Envelope{'Header'}."\n".$Envelope{'Body'};}

# check a mail from members or not? return 1 go on to Distribute or Command!
sub MLMemberNoCheckAndAdd { &MLMemberCheck;}; # backward compatibility
sub MLMemberCheck
{
    local($k, $v, $ok);

    $0 = "--Checking Members or not <$FML $LOCKFILE>";

    $ACTIVE_LIST = $MEMBER_LIST unless $ML_MEMBER_CHECK; # tricky

    ### EXTENSION FOR ADDR SEVERE CHECK
    while(($k, $v) = each %SEVERE_ADDR_CHECK_DOMAINS) {
	print STDERR "/$k/ && ADDR_CHECK_MAX += $v\n" if $debug; 
	($From_address =~ /$k/) && ($ADDR_CHECK_MAX += $v);
    }

    print STDERR "ChAddrModeOK $Envelope{'mode:uip:chaddr'} ? " if $debug;

    ### if "chaddr old-addr new-addr " is a special case of
    # $Envelope{'mode:uip:chaddr'} is the line "# chaddr old-addr new-addr"
    if ($Envelope{'mode:uip:chaddr'}) {
	&use(utils);
	&ChAddrModeOK($Envelope{'mode:uip:chaddr'}) && 
	    (return $Envelope{'mode:uip'} = 'on');
    }

    &Debug("FAIL") if $debug;

    ### WHETHER a member or not?, Go ahead! if a member
    &CheckMember($From_address, $MEMBER_LIST) && (return 1);

    # Hereafter must be a mail from not member
#.IF CROSSPOST
    # Crosspost extension.
    if ($Envelope{'crosspost'}) {
	&Log("Crosspost from not member");	    
	&Warn("Crosspost from not member: $From_address $ML_FN", &WholeMail);
	return 0;
    }

#.FI CROSSPOST
    if ($ML_MEMBER_CHECK) {
	# When not member, return the deny file.
	&Log("From not member");
	&Warn("NOT MEMBER article from $From_address $ML_FN", &WholeMail);
	&SendFile($From_address, 
		  "You $From_address are not member $ML_FN", $DENY_FILE);
	return 0;
    } else {
	# original designing is for luna ML (Manami ML)
	# If failed, add the user as a new member of the ML	
	$0 = "--Checking Members and add if new <$FML $LOCKFILE>";

	&use(utils);
	return &AutoRegist;
    }
}    


# Distribute mail to members
sub Distribute
{
    $0 = "--Distributing <$FML $LOCKFILE>";
    local($mail_file, $status, $num_rcpt, $s, *Rcpt);

    ### declare distribution mode (see libsmtp.pl)
    $Envelope{'mode:dist'} = 1;

    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    open(IDINC, $SEQUENCE_FILE) || (&Log($!), return);
    $ID = <IDINC>;		# get
    $ID++;			# increment
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    ##### ML Preliminary Session Phase 021: $DIR/summary
    # save summary and put log
    $s = $Envelope{'h:Subject:'};
    $s =~ s/\n(\s+)/$1/g;

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($USE_LIBMIME && $Envelope{'MIME'}) {
        &use(MIME);
	$s = &DecodeMimeStrings($s);
    }

    &Append2(sprintf("%s [%d:%s] %s", 
		     $Now, $ID, substr($From_address, 0, 15), $s),
	     $SUMMARY_FILE) || return;

    ##### ML Preliminary Session Phase 03: get @Rcpt
    open(ACTIVE_LIST) || (&Log("cannot open $ACTIVE_LIST ID=$ID:$!"), return);

    # Original is for 5.67+1.6W, but R8 requires no MX tuning tricks.
    # So version 0 must be forever(maybe) :-)
    # RMS = Relay, Matome, Skip; C = Crosspost;
    $rcsid =~ s/:/#rmsc :/;

    # Get a member list to deliver
    # After 1.3.2, inline-code is modified for further extentions.
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
#.IF CROSSPOST
      # Crosspost Extension. if matched to other ML's, no deliber
      if ($Envelope{'crosspost'}) {
	  local($w) = $rcpt;
	  ($w) = ($w =~ /(\S+)@\S+\.(\S+\.\S+\.\S+\.\S+)/ && $1.'@'.$2 || $w);
	  print STDERR "   ".($NORCPT{$w} && "not ")."deliver\n" if $debug;
	  next line if $NORCPT{$w}; # no add to @Rcpt
      }
#.FI CROSSPOST
      next line if $opt =~ /\s[ms]=/i;	# tricky "^\s";
      next line if $skip{$rcpt};

      # Relay server
      if ($opt =~ /\sr=(\S+)/i) {
	  local($relay) = $1;
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $rcpt = "$who%$mxhost\@$relay";
      }	# % relay is not refered in RFC, but effective in Sendmail's.

      print STDERR "RCPT TO: $rcpt \n\n" if $debug;
      push(@Rcpt, "RCPT TO: $rcpt");
      $num_rcpt++;
  }

    close(ACTIVE_LIST);


    ##### ML Distribute Phase 01: Fixing and Adjusting *Header
    # Errors-to is not refered in RFC822. 
    # Sendmail 8.x do not see this field in default. 
    # However in error may be effective for e.g. Pasokon Tuusin, BITNET..
    # I don't know details about them.

    # Run-Hooks. when you require to change header fields...
    $SMTP_OPEN_HOOK && &eval($SMTP_OPEN_HOOK, 'SMTP_OPEN_HOOK:');

    # set Reply-To:, use "original Reply-To:" if exists
    $Envelope{'h:Reply-To:'} = $Envelope{'h:reply-to:'} || $MAIL_LIST;
    
    if ($SUBJECT_HML_FORM) {	# hml 1.6 form
	# fml-support:436 (95/7/3) kise@ocean.ie.u-ryukyu.ac.jp
	local($ID) = sprintf("%05d", $ID) if $HML_FORM_LONG_ID;

	$Envelope{'h:Subject:'} = "[$BRACKET:$ID] ";
	$Envelope{'h:Subject:'} = $Envelope{'h:Subject:'} || "None";
    }

    # Add Cc: (default)
    undef $Envelope{'h:Cc:'} if $NOT_USE_CC;

    # Message ID
    # 95/09/14 add the fml Message-ID for more powerful loop check
    # /etc/sendmail.cf H?M?Message-Id: <$t.$i@$j>
    # <>fix by hyano@cs.titech.ac.jp 95/9/29
    # e.g. 199509131746.CAA14139@axion.phys.titech.ac.jp
    if (! $USE_ORIGINAL_MESSAGE_ID) { 
	local($s) = $Envelope{'macro:s'};
	$Envelope{'h:Message-Id:'}  = "<$CurrentTime.FML$$\@$s>"; 
	&Append2("$CurrentTime.FML$$\@$s", $LOG_MESSAGE_ID);
    }

    # STAR TREK SUPPORT:-)
    if ($APPEND_STARDATE) {
	&use(Stardate);
	$Envelope{'h:X-Stardate:'} = &Stardate;
    } 

    # Added INFOMATION
    if (! $NO_ML_INFO) {
	$Envelope{'h:X-ML-INFO:'} = 
	    "If you have a question, %echo \# help|Mail ".&CtlAddr;
    }

#.IF CROSSPOST
    # Crosspost info
    if ($Envelope{'crosspost'}) {
	if ($Envelope{'bcc:'}) {
	    # set Reply-To:, use "original Reply-To:" if exists
	    $Envelope{'h:Reply-To:'} = $Envelope{'h:reply-to:'} || $MAIL_LIST;
	    $body .= "Xref: [BCC]\n";
	}
	else {
	    local($r) = &GetXRef;
	    $body .= $r ? $r : '';
	}
    }
#.FI CROSSPOST    

    ##### ML Distribute Phase 02: Generating Hdr
    # This is the order recommended in RFC822, p.20. But not clear about X-*
    for ('Return-Path', 'Date', 'From', 'Subject', 'Sender', 'To', 
	 'Reply-To', 'Errors-To', 'Cc', 'Posted') {
	$Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
    }

    # Run-Hooks
    $HEADER_ADD_HOOK && &eval($HEADER_ADD_HOOK, 'Header Add Hook');
    $Envelope{'Hdr'} .= $body if $body;

    # Message-ID is a special case to customize.
    if ($Envelope{'Hdr'} !~ /Message-Id:/i) { # when not fixed by user
	$Envelope{'Hdr'} .= "Message-Id: $Envelope{\"h:Message-Id:\"}\n";
    }

    # Superfluous
    if ($Envelope{'Hdr2add'} && $SUPERFLUOUS_HEADERS) {
	$Envelope{'Hdr'} .= $Envelope{'Hdr2add'};
    }

    # Server info to add
    $Envelope{'Hdr'} .= "$XMLNAME\n";
    $Envelope{'Hdr'} .= "$XMLCOUNT: ".sprintf("%05d", $ID)."\n"; # 00010 
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


    ##### ML Distribute Phase 03: Spooling
    # spooling, check dupulication of ID against e.g. file system full
    # not check the return value, ANYWAY DELIVER IT!
    if (! -f "$SPOOL_DIR/$ID") {	# not exist
	&Log("ARTICLE $ID");
	&Write3(*Envelope, "$SPOOL_DIR/$ID");
    } 
    else {			# if exist, warning and forward
	&Log("ARTICLE $ID", "ID[$ID] dupulication");
	&Warn("ERROR:ARTICLE ID dupulication $ML_FN", 
	      "$Envelope{'Hdr'}\n$Envelope{'Body'}");
    }

    ##### ML Distribute Phase 04: SMTP
    # IPC. when debug mode or no recipient, no distributing 
    if ($num_rcpt && (!$debug)) {
	$status = &Smtp(*Envelope, *Rcpt);
	&Log("Sendmail:$status") if $status;
    }

    ##### ML Distribute Phase 05: ends
    $DISTRIBUTE_CLOSE_HOOK && 
	&eval($DISTRIBUTE_CLOSE_HOOK, 'Distribute close Hook');
}

#.IF CROSSPOST
sub GetXRef
{
    local($body);
    local($XRef)   = $Envelope{'xref:'};
    local($touchf) = "$DIR/$TMP_DIR/crosspost";
    local($contf)  = "$DIR/$TMP_DIR/crosspost-c";

    # Crosspost
    if ((!$Envelope{'crosspost'}) && -f $touchf) { # when not crosspost
	$body .= "X-Crosspost-Warning:";

	if (-f $contf) {
	    $body .= "Successively SKIPPED for CROSSPOST\n";
	    open(FILE, $contf); 
	} 
	else {
	    $body .= "previous ". ($ID - 1) . " SKIPPED for CROSSPOST\n";
	    open(FILE, $touchf);
	}

	$XRef = join("", <FILE>);# plural lines
	close(FILE);
	$body .= "XRef: $XRef";

	unlink $touchf, $contf;
    } 
    # Continuing
    elsif ($Envelope{'crosspost'} && -f $touchf) { 
	$body .= "X-Crosspost-Warning: CROSSPOST CONTINUING\n";	
	$body .= "XRef: $XRef\n";
	&Append2("\t$XRef", $contf);
    } 
    elsif ($Envelope{'crosspost'}) {
	$body .= "X-Crosspost-Warning: ATTENTION! THIS IS A CROSSPOST\n";
	$body .= "XRef: $XRef\n";
	&Append2("\t$XRef", $touchf);
    }

    $body;
}
#.FI CROSSPOST

# CheckMember(address, file)
# return 1 if a given address is authentified as member's
#
# performance test example 1 (100 times for 158 entries)
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
	  $Envelope{'mode:anyone:ok'} = 1;
	  close(FILE); 
	  return 1;
      }

      # for high performance
      next getline unless /^$addr/i;

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
	&Debug("Exact Match") if $debug;
	return 1;
    }

    # for further investigation, parse account and host
    local($acct1, $addr1) = split(/@/, $addr1);
    local($acct2, $addr2) = split(/@/, $addr2);

    # At first, account is the same or not?;    
    if ($acct1 ne $acct2) {return 0;}

    # Get an array "jp.ac.titech.phys" for "fukachan@phys.titech.ac.jp"
    local(@domain1) = reverse split(/\./, $addr1);
    local(@domain2) = reverse split(/\./, $addr2);

    # Check only "jp.ac.titech" part( = 3)(default)
    # If you like to strict the address check, 
    # change $ADDR_CHECK_MAX = e.g. 4, 5 ...
    local($i);
    while ($domain1[$i] && $domain2[$i] && 
	  ($domain1[$i] eq $domain2[$i])) { $i++;}

    &Debug("$i >= ($ADDR_CHECK_MAX || 3)") if $debug;
    return ($i >= ($ADDR_CHECK_MAX || 3));
}

# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub Log { 
    local($str, $s) = @_;
    local($package,$filename,$line) = caller; # called from where?

    &GetTime;

    $str =~ s/\015\012$//;	# FIX for SMTP
    $str = "$filename:$line% $str" if $debug_log;

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

    if (! open(APP, $w ? ">$f": ">>$f")) {
	local($r) = -f $f ? "cannot open $f" : "$f not exists";
	$nor ? (print STDERR "$r\n") : &Log($r);
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP $s . ($nonl ? "" : "\n") if $s;
    close(APP);
}

# WRITE $s >> $file, so $file is rewritten overall(ATTENTION!).
# return NONE
sub Touch  { &Append2("", @_, 1);}
sub Write2 { &Append2(@_, 1);}
sub Write3			# call by reference for effeciency
{ 
    local(*e, $f) = @_; 

    if ($MIME_DECODED_ARTICLE) { 
	&use(MIME);
	&EnvelopeMimeDecode(*e);
    }

    open(APP, "> $f") || (&Log("cannot open $f"), return '');
    select(APP); $| = 1; select(STDOUT);
    print APP "$e{'Hdr'}\n$e{'Body'}";
    close(APP);
}

# Notification of the mail on warnigs, errors ... 
sub Notify
{
    # refer to the original(NOT h:Reply-To:);
    local($to) = $Envelope{'message:h:to'} || 
	$Envelope{'h:reply-to:'} || $From_address;
    local(@to) = split(/\s+/, $Envelope{'message:h:@to'});
    local($s)  = $Envelope{'message:h:subject'} || "fml Status report $ML_FN";

    $Envelope{'message'} .= "\n\tSee you!   $FACE_MARK\n";
    &use(utils);
    $Envelope{'trailer'}  = &GenInfo;

    &Sendmail($to, $s, $Envelope{'message'}, @to);
}

# Lastly exec to be exceptional process
sub ExExec { &RunHooks(@_);}
sub RunHooks
{
    local($s);
    $0 = "--Run Hooks ".$_cf{'hook', 'prog'}." $FML $LOCKFILE>";

    if ($s = ($_cf{'hook', 'str'} . $FML_EXIT_HOOK)) {
	print STDERR "\nmain::eval >$s<\n\n" if $debug;
	&eval($s, 'Run Hooks:');
    }

    if ($s = $_cf{'hook', 'prog'}) {
	print STDERR "\nmain::exec $s\n\n" if $debug;
	exec $s;
    }
}

# Warning to Maintainer
sub Warn
{
    local($s, $b) = @_;
    &Sendmail($MAINTAINER, $s, $b);
}

# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use
{
    local($s) = @_;
    require "lib$s.pl"; # &eval("require \"lib$s.pl\";"); 
}

# eval and print error if error occurs.
sub eval
{
    local($exp, $s) = @_;

    eval $exp; 
    &Log("$s:".$@) if $@;

    return 1 unless $@;
}

# Getopt
sub Opt
{
    local($opt) = @_;
    push(@CommandLineOptions, $opt);
}
    
# Setting CommandLineOptions after include config.ph
sub SetCommandLineOptions
{
    local($opt);

    foreach $opt (@CommandLineOptions) {
	($opt =~ /^\-(\S)/)      && ($_cf{'opt', $1} = 1);
	($opt =~ /^\-(\S)(\S+)/) && ($_cf{'opt', $1} = $2);
	
	# Reassign options
	$debug = 1                       if $_cf{'opt', 'd'};
	$LOAD_LIBRARY = $_cf{'opt', 'l'} if $_cf{'opt', 'l'};
	&eval($_cf{'opt', 'e'})          if $_cf{'opt', 'e'};
	&eval("\$$opt = 1;")             if $_cf{'opt', 's'};

	if ($_cf{'opt', 'K'}) {	# fix header 
	    $MAIL_LIST .= "($_cf{'opt', 'K'})";
	    $HEADER_ADD_HOOK = q#$body .= "X-ML-Key: $_cf{'opt', 'K'}\n";#;
	}
    }

    if ($DUMPVAR) { require 'dumpvar.pl'; &dumpvar('main');}
}

# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
Mailing List:        $MAIL_LIST
UNIX FROM:           $Envelope{'UnixFrom'}
From(Original):      $Envelope{'from:'}
From_address:        $Envelope{'h:From:'}
Original Subject:    $Envelope{'subject:'}
To:                  $Envelope{'mode:chk'}
Reply-To:            $Envelope{'h:Reply-To:'}

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip:              $Envelope{'mode:uip'}

Another Header:     >$Envelope{'Hdr2add'}<
	
LOAD_LIBRARY:        $LOAD_LIBRARY

"#;

"print STDERR $s";
}

sub Debug
{
    local($s) = @_;

    print STDERR "$s\n";
    $Envelope{'message'} .= "\nDEBUG $s\n" if $_cf{'debug'};
}

# Check uid == euid && gid == egid
sub ChkREUid
{
    print STDERR "\nsetuid is not set $< != $>\n\n" if $< != $>;
    print STDERR "\nsetgid is not set $( != $)\n\n" if $( ne $);
}

# which address to use a COMMAND control.
sub CtlAddr 
{
    $CONTROL_ADDRESS || return $MAIL_LIST;
    local($d) = (split(/\@/, $MAIL_LIST))[1];
    "$CONTROL_ADDRESS\@$d";
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

    return 0;
}

sub Lock 
{ 
    # Check flock() OK?
    if ($USE_FLOCK) {
	eval "open(LOCK, $SPOOL_DIR) && flock(LOCK, $LOCK_SH);"; 
	$USE_FLOCK = ($@ eq "");
    }

    &use(utils) unless $USE_FLOCK;

    $USE_FLOCK ? &Flock : &V7Lock;
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
