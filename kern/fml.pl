#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");
$rcsid  .= '(2.0alpha)';

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
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);

#################### MAIN ####################
# including libraries
require 'config.ph';		# configuration file for each ML
eval("require 'sitedef.ph';");  # common defs over ML's
&use('smtp');			# a library using smtp

&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Parse;				# Phase 1, pre-parsing here
&GetFieldsFromHeader;		# Phase 2, extract fields
&FixHeaders(*Envelope);		# Phase 3, fixing fields information
&CheckEnv(*Envelope);		# Phase 4, fixing environment and check loops
				# If an error is found, exit here.

#.IF CROSSPOST
&CrosspostCheck;		# Check crosspost in To: and Cc:
#.FI CROSSPOST
&Lock;				# Lock!

$START_HOOK && &eval($START_HOOK, 'Start hook'); # additional before action

if ($DO_NOTHING) {		# Do nothing. Tricky. Please ignore 
    ;
}
elsif ($Envelope{'req:guide'}) {
    &GuideRequest;		# Guide Request from anyone
} 
elsif (&MLMemberCheck) { 
    &FixMode;			# e.g. for ctl-only address;

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

&Notify if $Envelope{'message'} || $Envelope{'error'};
				# some report or error message if needed.
				# should be here for e.g., mget, ...

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

    ### Against the future loop possibility
    if (&AddressMatch($MAIL_LIST, $MAINTAINER)) {
	&Log("DANGER!\$MAIL_LIST = \$MAINTAINER, STOP!");
	exit 0;
    }

    &SetCommandLineOptions;	        # Options
    if ($_cf{"opt:b"} eq 'd') { &use('utils'); &daemon;} # become daemon;

    $_cf{'perlversion'} = 5 if ($] =~ /5\.\d\d\d/); # Set Defaults

    &GetTime;			        # Time

    # COMPATIBILITY
    if ($COMPAT_FML15) { &use('fixenv'); &use('compat');}
    
    ### Initialize DIR's and FILE's of the ML server
    for ($SPOOL_DIR, $TMP_DIR, $VAR_DIR, $VARLOG_DIR, $VARRUN_DIR) { 
	-d $_ || mkdir($_, 0700);
    }
    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    # Turn Over log file (against too big)
    if ((stat($LOG_MESSAGE_ID))[7] > 25*100) { # once per about 100 mails.
	&use('newsyslog');
	&NewSyslog'TurnOver($LOG_MESSAGE_ID);#';
    }

    ### misc 
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # For tracing Process Table
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
    $Envelope{'MIME'}= 1 if $Envelope{'Header'} =~ /ISO\-2022\-JP/o && $USE_LIBMIME;

    ### Get @Hdr;
    local($s) = $Envelope{'Header'}."\n";
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.

    # misc
    if ($SUPERFLUOUS_HEADERS) { $hdr_entry = join("|", @HdrOrder);}

    ### Parsing main routines
    for (@Hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {

	print STDERR "FIELD:          >$field<\n" if $debug;

        # UNIX FROM is special: 1995/06/01 check UNIX FROM against loop and bounce
	/^from\s+(\S+)/i && ($Envelope{'UnixFrom'} = $Unix_From = $1, next);
	
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
    $e{'h:Subject:'}     = $e{'h:subject:'};       # anyway save

    # Some Fields need to "Extract the user@domain part"
    # $e{'h:Reply-To:'} is "reply-to-user"@domain FORM
    $From_address        = &Conv2mailbox($e{'h:from:'});
    $e{'h:Reply-To:'}    = &Conv2mailbox($e{'h:reply-to:'});
    $e{'Addr2Reply:'}    = $e{'h:Reply-To:'} || $From_address;

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) 
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if (($_ = $e{'h:Subject:'}) && $STRIP_BRACKETS) {
	if ($e{'MIME'}) { # against cc:mail ;_;
	    &use('MIME'); 
	    &StripMIMESubject(*e);
	}
	else {
	    local($r)  = 10;	# recursive limit against infinite loop

	    # e.g. Subject: [Elena:003] E.. U so ...
	    s/\[$BRACKET:\d+\]\s*//g;

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
    $e{'Reply2:'} = &CtlAddr;
}

sub CheckEnv
{
    local(*e) = @_;

    ### For CommandMode Check(see the main routine in this flie)
    $e{'mode:chk'}  = $e{'h:to:'} || $e{'h:apparently-to:'};
    $e{'mode:chk'} .= ", $e{'h:Cc:'}, ";
    $e{'mode:chk'}  =~ s/\n(\s+)/$1/g;

    # Correction. $e{'req:guide'} is used only for unknown ones.
    if ($e{'req:guide'} && &CheckMember($From_address, $MEMBER_LIST)) {
	undef $e{'req:guide'}, $e{'mode:uip'} = 'on';
    }

    ### SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS) {
	($e{'h:Subject:'} =~ /^\#\s*$GUIDE_KEYWORD\s*$/i) && $e{'req:guide'}++;
	$COMMAND_ONLY_SERVER &&	
	    ($e{'h:Subject:'} =~ /^\s*$GUIDE_KEYWORD\s*$/i) && $e{'req:guide'}++;
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
# change reply-to: for convenience
sub GuideRequest
{
    &Log("Guide request from a stranger");
    $Envelope{'h:Reply-To:'} = $Envelope{'h:reply-to:'} || $Envelope{'Reply2:'}; 
    &SendFile($Envelope{'Addr2Reply:'}, "Guide $ML_FN", $GUIDE_FILE);
}

# the To_address is for command or not.
sub FixMode
{
    # Default LOAD_LIBRARY SHOULD NOT BE OVERWRITTEN!
    if ($Envelope{'mode:uip'} || 
       ($CONTROL_ADDRESS && ($Envelope{'mode:chk'} =~ /$CONTROL_ADDRESS/i))) {
	$LOAD_LIBRARY || ($LOAD_LIBRARY = 'libfml.pl'); 
    }

    # FOR "when + entry is matched" CASE:
    # prohibit an arbitrary user to use commands and to distribute in it
    if ($PROHIBIT_COMMAND_FOR_STRANGER &&
	$LOAD_LIBRARY &&
	$Envelope{'mode:anyone:ok'}) {
	&Warn("Permit nothing for a stranger", &WholeMail);
	&Log("Permit nothing for a stranger");
	$DO_NOTHING = 1;
    }

    ### Address Test Mode; (Become Test Mode)
    if ($_cf{"opt:b"} eq 't') { $DO_NOTHING = 1; &Log("Address Test Mode:Do nothing");} 
}

# Recreation of the whole mail for error infomation
sub WholeMail   
{ 
    $_ = ">".$Envelope{'Header'}."\n".$Envelope{'Body'};
    s/\n/\n\>/g; 
    "Original Mail:\n$_";
}

# check a mail from members or not? return 1 go on to Distribute or Command!
sub MLMemberNoCheckAndAdd { &MLMemberCheck;}; # backward compatibility
sub MLMemberCheck
{
    local($k, $v);

    $0 = "--Checking Members or not <$FML $LOCKFILE>";

    $ACTIVE_LIST = $MEMBER_LIST unless $ML_MEMBER_CHECK; # tricky

    ### EXTENSION FOR ADDR SEVERE CHECK
    if ($From_address =~ /^($REJECT_ADDR)/i) {
	&Log("Mail From Addr to Reject [$&], FORW to Maintainer");
	&Warn("Mail From Addr to Reject [$&]", &WholeMail);
	return 0;
    }

    while (($k, $v) = each %SEVERE_ADDR_CHECK_DOMAINS) {
	print STDERR "/$k/ && ADDR_CHECK_MAX += $v\n" if $debug; 
	($From_address =~ /$k/) && ($ADDR_CHECK_MAX += $v);
    }

    print STDERR "ChAddrModeOK $Envelope{'mode:uip:chaddr'} ? " if $debug;

    ### if "chaddr old-addr new-addr " is a special case of
    # $Envelope{'mode:uip:chaddr'} is the line "# chaddr old-addr new-addr"
    if ($Envelope{'mode:uip:chaddr'}) {
	&use('utils');
	&ChAddrModeOK($Envelope{'mode:uip:chaddr'}) && 
	    (return $Envelope{'mode:uip'} = 'on');
    }

    &Debug("NOT") if $debug;

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

	&use('utils');
	return &AutoRegist(*Envelope);
    }
}    


# Distribute mail to members
sub Distribute
{
    $0 = "--Distributing <$FML $LOCKFILE>";
    local($status, $num_rcpt, $s, @Rcpt);

    $DISTRIBUTE_START_HOOK && 
	&eval($DISTRIBUTE_START_HOOK, 'Distribute Start hook'); 

    ### declare distribution mode (see libsmtp.pl)
    $Envelope{'mode:dist'} = 1;

    ### EMERGENCY CODE against LOOP
    if (-f "$TMP_DIR/emerg.stop") { &use('utils'); &EmergencyNotify; return;}

    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    open(IDINC, $SEQUENCE_FILE) || (&Log($!), return);
    $ID = <IDINC>;		# get
    $ID++;			# increment, GLOBAL!
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    ##### ML Preliminary Session Phase 02: $DIR/summary
    # save summary and put log
    $s = $Envelope{'h:Subject:'};
    $s =~ s/\n(\s+)/$1/g;

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($Envelope{'MIME'}) { &use('MIME'); $s = &DecodeMimeStrings($s);}

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
      next line if /^$MAIL_LIST$/io; # no loop back
      next line if $CONTROL_ADDRESS && /^$CONTROL_ADDRESS$/io;

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
	  print STDERR "   ".($NoRcpt{$w} && "not ")."deliver\n" if $debug;
	  next line if $NoRcpt{$w}; # no add to @Rcpt
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

      print STDERR "RCPT:$rcpt\n\n" if $debug;
      push(@Rcpt, $rcpt);
      $num_rcpt++;
  }

    close(ACTIVE_LIST);


    ##### ML Distribute Phase 01: Fixing and Adjusting *Header
    # Run-Hooks. when you require to change header fields...
    $SMTP_OPEN_HOOK && &eval($SMTP_OPEN_HOOK, 'SMTP_OPEN_HOOK:');

    # set Reply-To:, use "original Reply-To:" if exists
    $Envelope{'h:Reply-To:'} = $Envelope{'h:reply-to:'} || $MAIL_LIST;
    
    if ($SUBJECT_HML_FORM) {# hml 1.6 form: (95/07/03) kise@ocean.ie.u-ryukyu.ac.jp
	local($ID) = sprintf("%05d", $ID) if $HML_FORM_LONG_ID;
	$Envelope{'h:Subject:'} = "[$BRACKET:$ID] ".($Envelope{'h:Subject:'} || $Subject); 
    }

    # Message ID: e.g. 199509131746.CAA14139@axion.phys.titech.ac.jp
    # 95/09/14 add the fml Message-ID for more powerful loop check
    # /etc/sendmail.cf H?M?Message-Id: <$t.$i@$j>
    # <>fix by hyano@cs.titech.ac.jp 95/9/29
    if (! $USE_ORIGINAL_MESSAGE_ID) { 
	$Envelope{'h:Message-Id:'}  = "<$CurrentTime.FML$$\@$FQDN>"; 
	&Append2("$CurrentTime.FML$$\@$s", $LOG_MESSAGE_ID);
    }

    # STAR TREK SUPPORT:-)
    if ($APPEND_STARDATE) { &use('stardate'); $Envelope{'h:X-Stardate:'} = &Stardate;}

#.IF CROSSPOST
    # Crosspost info
    {
	local($r) = &GetXRef;
	$body .= $r ? $r : '';
    }
#.FI CROSSPOST    

    # Run-Hooks
    $HEADER_ADD_HOOK && &eval($HEADER_ADD_HOOK, 'Header Add Hook');

    # Server info to add
    $Envelope{'h:X-MLServer'} = $rcsid if $rcsid;
    $Envelope{"h:$XMLCOUNT:"} = sprintf("%05d", $ID); # 00010 
    $Envelope{'h:X-Ml-Info:'} = "If you have a question, %echo \# help|Mail ".&CtlAddr;

    ##### ML Distribute Phase 02: Generating Hdr
    # This is the order recommended in RFC822, p.20. But not clear about X-*
    for (@HdrOrder) {
	if (/^:body:$/o && $body) {
	    $Envelope{'Hdr'} .= $body;
	}
	elsif (/^:any:$/ && $Envelope{'Hdr2add'}) {
	    $Envelope{'Hdr'} .= $Envelope{'Hdr2add'};
	}
	elsif (/^Message-Id$/ && ($Envelope{'Hdr'} !~ /Message-Id:/i)) { # UNIQUE!
	    $Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n";
	}
	elsif (/^:XMLNAME:$/o) {
	    $Envelope{'Hdr'} .= "$XMLNAME\n";
	}
	else {
	    $Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
	}
    }

    ##### ML Distribute Phase 03: Spooling
    # spooling, check dupulication of ID against e.g. file system full
    # not check the return value, ANYWAY DELIVER IT!
    # IF THE SPOOL IS MIME-DECODED, NOT REWRITE %e, so reset %me <- %e;
    if (! -f "$SPOOL_DIR/$ID") {	# not exist
	&Log("ARTICLE $ID");
	&Write3(*Envelope, "$SPOOL_DIR/$ID");
    } 
    else { # if exist, warning and forward againt DISK-FULL;
	&Log("ARTICLE $ID", "ID[$ID] dupulication");
	&Append2("$Envelope{'Hdr'}\n$Envelope{'Body'}", "$VARLOG_DIR/DUP$CurrentTime");
	&Warn("ERROR:ARTICLE ID dupulication $ML_FN", 
	      "Try save > $VARLOG_DIR/DUP$CurrentTime\n$Envelope{'Hdr'}\n$Envelope{'Body'}");
    }

    ##### ML Distribute Phase 04: SMTP
    # IPC. when debug mode or no recipient, no distributing 
    if ($num_rcpt && (! $debug)) {
	$status = &Smtp(*Envelope, *Rcpt);
	&Log("Smtp:$status") if $status;
    }

    ##### ML Distribute Phase 05: ends
    $DISTRIBUTE_CLOSE_HOOK .= $SMTP_CLOSE_HOOK;
    $DISTRIBUTE_CLOSE_HOOK && 
	&eval($DISTRIBUTE_CLOSE_HOOK, 'Distribute close Hook');
}

#.IF CROSSPOST
sub CrosspostCheck
{
    local($cps) = 'Crossed among:';
    local(%addr, $n_cr, *Crossed);

    &Debug("*** Crosspost Check Routine SETS IN ***") if $debug;
    
    # Crosspost extension
    # the tricky syntax ", " is required for the splitting(put above) 
    foreach (split(/\s*,\s*/, $Envelope{'mode:chk'})) {
	next if /^\s*$/o;

	# uniq emulation since ORDER is important, so "cannot sort" 
	next if $addr{$_};
	
	&Debug("   Candidate  :\t$_") if $debug;

	# lacking of this code leads to strange working...
	# e.g. when it has a name or ..
	# 95/08/07 fukachan@phys.titech.ac.jp
	# delete (..) e.g. Elen@fuwafuwa.or.jp (Fuwafuwa Elen)
	$_ = &Conv2mailbox($_);

	# EXCEPT FOR From_address
	if (! &AddressMatch($_, $From_address)) {
	    $cps .= " [$_]"; # LOG MATCHED ADDR
	    $n_cr++;
	    $Crossed .= $Crossed ? ",$_" : $_;
	    &Debug("   Crossposted:\t$_") if $debug;
	}
	else {
	    $cps .= " $_";	# LOG 'NOT MATCHED ONE'
	    &Debug("   HISOWN,SKIP:\t$_") if $debug;
	}

	$addr{$_} = 1;	# uniq emulation
    }

    # for libcrosspost.pl
    $Envelope{'mode:chk'} = $Crossed;

    # include $MAIL_LIST own, so (> 1)	
    # if plural addresses, call, COMMAND MODE->do nothing
    if ((!$Envelope{'mode:uip'}) && ($n_cr > 1)) {
	&Debug("\nCrosspost detected") if $debug;
	$Envelope{'crosspost'} = 1;
	&Log($cps);
	&use('crosspost');
	&Crosspost; 
    }
    else {
	&Debug("\nCrosspost NOT detected") if $debug;
    }

    &Debug("\n*** CROSSPOST ROUTINE ENDS ***\n") if $debug;
}

sub GetXRef
{
    local($body);
    local($XRef)   = $Envelope{'xref:'};
    local($touchf) = "$TMP_DIR/crosspost";
    local($contf)  = "$TMP_DIR/crosspost-c";
    local($fcount) = "$TMP_DIR/crosspost-first-count";
    local($lcount) = "$TMP_DIR/crosspost-last-count";

    &Debug("\$Envelope{'crosspost'}\t$Envelope{'crosspost'}");
    &Debug("-f $touchf") if -f $touchf;
    &Debug("-f $contf")  if -f $contf;
    &Debug("-f $fcount:".`cat $fcount`) if -f $fcount;
    &Debug("-f $lcount:".`cat $lcount`) if -f $lcount;

    # Crosspost ends
    if ((!$Envelope{'crosspost'}) && -f $touchf) { # when not crosspost
	$body .= "X-Crosspost-Warning:";

	if (-f $contf) {
	    chop($fid = `cat $fcount`);
	    chop($lid = `cat $lcount`);
	    $body .= "$fid-$lid SKIPPED for CROSSPOST\n";
	} 
	else {
	    $body .= "previous ".($ID - 1)." SKIPPED for CROSSPOST\n";
	}

	open(FILE, $touchf);
	$body .= "XRef: ". join("", <FILE>);# plural lines
	close(FILE);

	unlink $touchf, $contf;
    } 
    # Crosspost Continuing
    elsif ($Envelope{'crosspost'} && -f $touchf) { 
	local($a) = (split(/\@/, $MAIL_LIST))[0];
	$Envelope{'Crosspost:lists'} =~ s/$a/$a:$ID/i; 

	$body .= "X-Crosspost-Warning: CROSSPOST CONTINUING\n";	
	$body .= "XRef: $Envelope{'Crosspost:lists'}\n";

	&Append2("   $Envelope{'Crosspost:lists'}", $touchf);
	&Write2($ID, $lcount);
    } 
    # Crosspost (session begins)
    elsif ($Envelope{'crosspost'}) {
	local($a) = (split(/\@/, $MAIL_LIST))[0];
	$Envelope{'Crosspost:lists'} =~ s/$a/$a:$ID/i; 

	$body .= "X-Crosspost-Warning: ATTENTION! THIS IS A CROSSPOST\n";
	$body .= "XRef: $Envelope{'Crosspost:lists'}\n";

	&Write2($Envelope{'Crosspost:lists'}, $touchf);
	&Write2($ID, $fcount);
    }

    $body;
}
#.FI CROSSPOST

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

sub Touch  { &Append2("", $_[0]);}

sub Write2 { &Append2(@_, 1);}

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

# Notification of the mail on warnigs, errors ... 
sub Notify
{
    # refer to the original(NOT h:Reply-To:);
    local($to)   = $Envelope{'message:h:to'} || $Envelope{'Addr2Reply:'};
    local(@to)   = split(/\s+/, $Envelope{'message:h:@to'});
    local($s)    = $Envelope{'message:h:subject'} || "fml Status report $ML_FN";
    local($proc) = $PROC_GEN_INFO || 'GenInfo';

    if ($Envelope{'message'}) {
	$Envelope{'message'} .= "\n\tSee you!   $FACE_MARK\n";
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

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip:              $Envelope{'mode:uip'}

Another Header:     >$Envelope{'Hdr2add'}<
	
LOAD_LIBRARY:        $LOAD_LIBRARY

"#;

"print STDERR $s";
}

sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $debug_message;
}

# Check uid == euid && gid == egid
sub CheckUGID
{
    print STDERR "\nsetuid is not set $< != $>\n\n" if $< != $>;
    print STDERR "\nsetgid is not set $( != $)\n\n" if $( ne $);
}

# which address to use a COMMAND control.
sub CtlAddr { $CONTROL_ADDRESS =~ /\@/ ? $CONTROL_ADDRESS : "$CONTROL_ADDRESS\@$FQDN";}

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
