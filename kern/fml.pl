#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

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
require 'config.ph';		# a config header file
require 'libsmtp.pl';		# a library using smtp
require 'liblock.pl' unless $USE_FLOCK;

# a little configuration before the action
umask (077);			# rw-------
$CommandMode  	= '';		# default CommandMode is nil.
$GUIDE_REQUEST 	= 0;		# not member && guide request only

&ChkREUid;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Parsing;			# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

#.forward
if($MULTIPLE_LOADING_SERVER || $_cf{'opt', 'F'}) {
    &MultipleMLForwarding && exit 0;
    exit 1;
}
#.endforward
(!$USE_FLOCK) ? &Lock : &Flock;	# Locking 

$START_HOOK && &eval($START_HOOK, 'Start hook'); # additional before action

if ($GUIDE_REQUEST) {
    &GuideRequest;		# Guide Request from everybady
} 
elsif(&MLMemberCheck) { 
    &AdditionalCommandModeCheck;# e.g. for ctl-only address;

    if ($LOAD_LIBRARY) {		# to be a special purpose server
	require $LOAD_LIBRARY;	# default is 'libfml.pl';
    } 
    else {			# distribution mode(Mailing List)
	&Distribute;
    }
}

(!$USE_FLOCK) ? &Unlock : &Funlock;# UnLocking;

&RunHooks;			# run hooks after unlocking, e.g. mget

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, 
		   $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if (! -d $SPOOL_DIR)     { mkdir($SPOOL_DIR, 0700);}
    $TMP_DIR = ( $TMP_DIR || "./tmp" ); # backward compatible
    if (! -d $TMP_DIR)       { mkdir($TMP_DIR, 0700);}
    for ($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE) {
	if (!-f $_) { 
	    open(TOUCH,">> $_"); close(TOUCH);
	}
    }

    &GetTime;

    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # Trick for tracing

    # since 1.3.1.23 define $_Ds in config.ph by Configure
    $_Ds || ($_Ds = "localhost");

    # for backward compatiblity
    push(@ARCHIVE_DIR, @StoredSpool_DIR);
    $SPOOL_DIR =~ s/$DIR\///;
    $SMTP_OPEN_HOOK .= $Playing_to;

    # Security level (default is 2 [1.4delta])
    $SECURITY_LEVEL = ($SECURITY_LEVEL || 2);

    # FIX INCLUDE PATH
    push(@INC, $LIBMIMEDIR) if $LIBMIMEDIR;
}

# one pass to cut out the header and the body
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";

    # Guide Request Check within in the first 3 lines
    $GUIDE_CHECK_LIMIT || ($GUIDE_CHECK_LIMIT = 3);
    
    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    if (/^$/o) { #required for split(tricky)
		$MailHeaders .= "\n";
		next;
	    } 

	    $MailHeaders .= $_;

	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$GUIDE_REQUEST = 1 if /\#\s*guide\s*$/io;
	    }

	    # Command or not is checked within the first 3 lines.
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$CommandMode = 'on' if /^\#/o;
	    }

	    $MailBody .= $_;
	    $BodyLines++;
	    $_cf{'cl'}++ if /^\#/o; # the number of command lines 
	}
    }# END OF WHILE LOOP;
}

# Phase 2(2nd pass), extract several fields 
# Here is in 1.2-current the local rule to define header fileds.
# Original form  -> $Subject                 -> distributed mails
#                -> $Original_From_address   -> distributed mails
# parsed headers -> $Summary_Subject(a line) -> summary file
sub GetFieldsFromHeader
{
    local($s) = $MailHeaders;
    local($field, $contents);

    #  These two lines are tricky for folding and unfolding.
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g;
    local(@MailHeaders) = split(/\n\n/, $s, 999);

    while (@MailHeaders) {
	$_ = $field = shift @MailHeaders;
	print STDERR "FIELD:          >$field<\n" if $debug;

        # UNIX FROM is a special case.
	# 1995/06/01 check UNIX FROM LoopBack
	if (/^from\s+(\S+)/io) {
	    $Unix_From = $1;
	    next;
	}

	$contents = shift @MailHeaders;
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^$/o;		# if null, skip. must be mistakes.

	# Fields to skip. Please custumize below.
	next if /^Received:/io;
	next if /^In-Reply-To:/io && (! $SUPERFLUOUS_HEADERS);
	next if /^Return-Path:/io;
	next if /^X-MLServer:/io;
	next if /^X-ML-Name:/io;
	next if /^X-Mail-Count:/io;
	next if /^Precedence:/io;
	next if /^Lines:/io;

	# filelds to use later.
	/^Date:$/io           && ($Date = $contents, next);
	/^Reply-to:$/io       && ($Reply_to = $contents, next);
	/^Errors-to:$/io      && ($Errors_to = $contents, next);
	/^Sender:$/io         && ($Sender = $contents, next);
	/^X-Distribution:$/io && ($Distribution = $contents, next);
	/^Apparently-To:$/io  && ($Original_To_address = $To_address = $contents, 
				  next);
	/^To:$/io             && ($Original_To_address = $To_address = $contents, 
				  next);
	/^Cc:$/io             && ($Cc = $contents, next);
	/^Message-Id:$/io     && ($Message_Id = $contents, next);

	# get subject (remove [Elena:id]
	# Now not remove multiple Re:'s),
	# which actions may be out of my business though...
	if (/^Subject:$/io && $STRIP_BRACKETS) {
	    # e.g. Subject: [Elena:001] Uso...
	    $contents =~ s/\[$BRACKET:\d+\]\s*//g;

	    local($r)  = 10;	# recursive limit against infinite loop
	    while (($contents =~ s/Re:\s*Re:\s*/Re: /g) && $r-- > 0) {;}

	    $Subject = $contents;
	    next;
	}
	/^Subject:$/io        && ($Subject = $contents, next); # default
	
	if (/^From:$/io) {
	    # From_address is modified for e.g. member check, logging, commands
	    # Original_From_address is preserved.
	    $_ = $Original_From_address = $contents;
	    s/\n(\s+)/$1/g;

	    # Hayakawa Aoi <Aoi@aoi.chan.panic>
	    if (/^\s*.*\s*<(\S+)>.*$/io) {
		$From_address = $1; 
		next;
	    }

	    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
	    if (/^\s*(\S+)\s*.*$/io) {
		$From_address = $1; 
		next;
	    }

	    # Aoi@aoi.chan.panic
	    $From_address = $_; next;
	}
	
	# Special effects for MIME, based upon rfc1521
	if (/^MIME-Version:$/io || 
	    /^Content-Type:$/io || 
	    /^Content-Transfer-Encoding:$/io) {
	    $_cf{'MIME', 'header'} .= "$field $contents\n";
	    next;
	}

	# when encounters unknown headers, hold if $SUPERFLUOUS_HEADERS is 1.
	$SuperfluousHeaders .= "$field $contents\n" if $SUPERFLUOUS_HEADERS;

    }# end of while loop;

    # for summary file
    $Summary_Subject = $Subject;
    $Summary_Subject =~ s/\n(\s+)/$1/g;
    $User = substr($From_address, 0, 15);

    # for CommanMode Check(see the main routine in this flie)
    $To_address =~ s/\n(\s+)/$1/g;
    $Cc         =~ s/\n(\s+)/$1/g;
    $To_address .= ", ". $Cc if $Cc;

    # MIME decoding. If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($USE_LIBMIME && ($MailHeaders =~ /ISO\-2022\-JP/o)) {
        require 'libMIME.pl';
	$Summary_Subject = &DecodeMimeStrings($Summary_Subject);
    }

    # Correction. $GUIDE_REQUEST is used only for unknown ones.
    if ($GUIDE_REQUEST && &CheckMember($From_address, $MEMBER_LIST)) {
	$GUIDE_REQUEST = 0, $CommandMode = 'on';
    }
#.if
    # Crosspost extension
    foreach (split(/\s*,\s*/, $To_address)) {
	next if /^\s*$/o;
	(! &AddressMatching($_, $From_address)) && $USE_CROSSPOST++;
    }
    ($USE_CROSSPOST > 0) && $USE_CROSSPOST-- || undef $USE_CROSSPOST; # syntax hosei..
    
    # if plural addresses, call, COMMAND MODE->do nothing
    if ( (!$CommandMode) && $USE_CROSSPOST) {
	require 'contrib/Crosspost/libcrosspost.pl';
    }
#.endif

    $debug && &eval(&FieldsDebug, 'FieldsDebug');

    # now before flock();
    if (&AddressMatch($Unix_From, $MAINTAINER)) {
	&Log("WARNING: UNIX FROM Loop");
	exit 0;
    }
}

# When just guide request from unknown person, return the guide only
sub GuideRequest
{
    &Logging("Guide from the unknown");
    &SendFile($From_address, "Guide $ML_FN", $GUIDE_FILE);
}

# the To_address is for command or not.
sub AdditionalCommandModeCheck
{
    # Default LOAD_LIBRARY SHOULD NOT BE OVERWRITTEN!
    if ($CommandMode || 
       ($CONTROL_ADDRESS && ($To_address =~ /$CONTROL_ADDRESS/i))) {
	$LOAD_LIBRARY || ($LOAD_LIBRARY = 'libfml.pl'); 
    }
}

# Recreation of the whole mail for error infomation
sub WholeMail
{
    "$MailHeaders\n$MailBody";
}

# check a mail from members or not? return 1 go on to Distribute or Command!
sub MLMemberNoCheckAndAdd { &MLMemberCheck;}; # backward compatibility
sub MLMemberCheck
{
    $0 = "--Checking Members or not <$FML $LOCKFILE>";

    $ACTIVE_LIST = $MEMBER_LIST unless $ML_MEMBER_CHECK; # tricky

    # if member, Go ahead!
    &CheckMember($From_address, $MEMBER_LIST) && (return 1);

    # Hereafter must be a mail from not member
#.if
    # Crosspost extension.
    if ($USE_CROSSPOST) {
	&Logging("Crosspost from not member");	    
	&Warn("Crosspost from not member: $From_address $ML_FN", &WholeMail);
	return 0;
    }

#.endif
    if ($ML_MEMBER_CHECK) {
	# When not member, return the deny file.
	&Logging("From not member");
	&Warn("NOT MEMBER article from $From_address $ML_FN", &WholeMail);
	&SendFile($From_address, 
		  "You $From_address are not member $ML_FN", $DENY_FILE);
	return 0;
    } else {
	# original designing is for luna ML (Manami ML)
	# If failed, add the user as a new member of the ML	
	$0 = "--Checking Members and add if new <$FML $LOCKFILE>";

	require 'libutils.pl';
	return &AutoRegist;
    }
}    

#.forward
sub MultipleMLForwarding
{
    local($to);
    local($host) = `hostname`;
    chop $host;	# cut '\n';

    # If not on $DOT_FORWARD_EXEC_HOST.
    if ($DOT_FORWARD_EXEC_HOST ne $host) { 
	print STDERR "($DOT_FORWARD_EXEC_HOST ne $host), exit\n";
	return 0;
	# exit ;
    }

    # Find X-ML: ML-NAME
    if ($MailHeaders =~ /\nX-ML:\s*(\S+)/i) {
	$KEY = $1;
    }
    # To: ...@... (ML-NAME) e.g. ML-NAME = 'uja' :-)
    else {
	to: foreach $to (split(/\s*,\s*/, $To_address, 999)) {
	    next to if $to =~ /^\s*$/;
	    $to  =~ y/A-Z/a-z/;
	    if ($to  =~ /\((\S+)\)/) {
		$KEY = $1;
	    }
	}
    }

    # lower
    $KEY =~ y/A-Z/a-z/;

    # O.K.! here we go!
    if ($KEY && $forward_key{$KEY}) {
	print STDERR "exec $forward_key{$KEY} $KEY\n" if $debug;

	if (open(F, "| $forward_key{$KEY}")) {
	    select(F); $| = 1;
	    print F &WholeMail;	    
	    close(F);
	}
	else {
	    &Log("Cannot fork");
	}
    }# .FORWARD;

    # HEADER 
    $Reply_to = "Reply-To: $MAIL_LIST ($KEY)\n";
    $HEADER_ADD_HOOK = q#
	$body .= "X-ML: $KEY";
    #;

    # against recursive
    undef $MULTIPLE_LOADING_SERVER;

    1;	# O.K.!;
}
#.endforward

# Distribute mail to members
sub Distribute
{
    $0 = "--Distributing <$FML $LOCKFILE>";
    local($mail_file, $Status);

    # Get the present ID
    open(IDINC, $SEQUENCE_FILE) || (&Logging($!), return);
    $ID = <IDINC>;		# get
    $ID++;			# increment
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    open(IDINC, "> $SEQUENCE_FILE") || (&Logging($!), return);
    printf IDINC "%d\n", $ID; 
    close(IDINC);
    
    # save summary and put log
    open(SUMMARY, '>>'. $SUMMARY_FILE) || (&Logging($!), return);
    printf SUMMARY "%s [%d:%s] %s\n", $Now, $ID, $User, $Summary_Subject;
    close(SUMMARY);
    
    # Distribution mode
    @headers = ("HELO $_Ds", "MAIL FROM: $MAINTAINER");
    open(ACTIVE_LIST) || 
	(&Log("cannot open $ACTIVE_LIST when $ID:$!"), return);

    # Original is for 5.67+1.6W, but R8 requires no MX tuning tricks.
    # So version 0 must be forever(maybe) :-)
    # RMS = Relay, Matome, Skip; C = Crosspost;
    $rcsid =~ s/\// \#rsmc \//;

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
#.if
      # Crosspost Extension. if matched to other ML's, no deliber
      if ($USE_CROSSPOST) {
	  local($w) = $rcpt;
	  ($w) = ($w =~ /(\S+)@\S+\.(\S+\.\S+\.\S+\.\S+)/ && $1.'@'.$2 || $w);
	  print STDERR "RCPT $NORCPT{$w} for $w\n" if $debug;
	  next line if $NORCPT{$w}; # no add to @headers
      }
#.endif
      next line if $opt =~ /\s[ms]=/i;	# tricky "^\s";
      next line if $skip{$rcpt};

      # Relay server
      if ($opt =~ /\sr=(\S+)/i) {
	  local($relay) = $1;
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $rcpt = "$who%$mxhost\@$relay";
      }	# % relay is not refered in RFC, but effective in Sendmail's.

      print STDERR "RCPT TO: $rcpt \n\n" if $debug;
      push(@headers, "RCPT TO: $rcpt");
  }

    close(ACTIVE_LIST);

    ##### Hereafter the body of a mail #####
    push(@headers, "DATA");

    # If you require to change several header fields...
    $SMTP_OPEN_HOOK && &eval($SMTP_OPEN_HOOK, 'SMTP_OPEN_HOOK:');
    
# This is the order recommended in RFC822, p.20. But not clear about X-*
    $body = 
	"Return-Path: <$MAINTAINER>\n" .
	"Date: $MailDate\n" .
	"From: $Original_From_address\n";

    if (! $SUBJECT_HML_FORM && ! $STAR_TREK_FORM) {# the default is simple.
	# When Subject is nil, no field
	$body .= "Subject: $Subject\n" if $Subject;
    } 
    elsif ($STAR_TREK_FORM) {	# a play _o_(effective in 199?)
	local($ID) = sprintf("%02d%02d.%05d", $year - 90, $mon + 1, $ID);
	$body .= "Subject: [$ID] $Subject\n";
    } 
    elsif ($SUBJECT_HML_FORM) {	# hml 1.6 form
	$Subject = "None" unless $Subject;
	$body .= "Subject: [$BRACKET:$ID] $Subject\n";
    }

    $body .= "Sender: $Sender\n" if ($Sender); # Sender is just additional. 
    $body .= "To: ".($To || "$MAIL_LIST $ML_FN") ."\n";
    $body .= $Reply_to ? "Reply-To: $Reply_to\n" : "Reply-To: $MAIL_LIST\n";

    # Errors-to is not refered in RFC822. 
    # Sendmail 8.x do not see this field in default. 
    # However in error may be effective for e.g. Pasokon Tuusin, BITNET..
    # I don't know details about them.
    # $body .= "Errors-To: ", $Errors_to ? "$Errors_to\n" : "$MAINTAINER\n";
    # $body .= "Date: $Date\n"; # remove atove "Date: $MailDate" line.
    # $body .= "Message-Id: $Message_Id\n";

    $body .= "Errors-To: $MAINTAINER\n" if $AGAINST_NIFTY;
    
    # superfluous headers are added if $SUPERFLUOUS_HEADERS is non-nil.
    $body .= "Cc: $Cc\n" if ($_cf{'use', 'cc'} || $SUPERFLUOUS_HEADERS) && $Cc;
    $body .= $_cf{'MIME', 'header'} if (!$PREVENT_MIME) && $_cf{'MIME', 'header'};
    $body .= $SuperfluousHeaders    if $SUPERFLUOUS_HEADERS;

    # Additional hook;
    $body .= "Message-Id: $Message_Id\n" if $USE_ORIGINAL_MESSAGE_ID;
    $HEADER_ADD_HOOK && &eval($HEADER_ADD_HOOK, 'Header Add Hook');

    # Server Information is added.
    $body .= 
	"Posted: $Date\n" .
	"$XMLNAME\n" .
	"$XMLCOUNT: " . sprintf("%05d", $ID) . "\n"; # 00010 
#.if
    # Crosspost
    if ((!$USE_CROSSPOST) && -f "$DIR/$TMP_DIR/crosspost") { # when not crosspost
	$body .= "X-Crosspost-Warning:";

	if (-f "$DIR/$TMP_DIR/crosspost-c") {
	    $body .= "Successively SKIPPED for CROSSPOST\n";
	    open(FILE, "< $DIR/$TMP_DIR/crosspost-c"); 
	} 
	else {
	    $body .= "previous ". ($ID - 1) . " SKIPPED for CROSSPOST\n";
	    open(FILE, "< $DIR/$TMP_DIR/crosspost"); 
	}

	$XRef = join("", <FILE>);# plural lines
	close(FILE);
	$body .= "XRef: $XRef";

	unlink "$DIR/$TMP_DIR/crosspost", "$DIR/$TMP_DIR/crosspost-c";

    } 
    elsif ($USE_CROSSPOST && -f "$DIR/$TMP_DIR/crosspost") { # continueing
	$body .= "X-Crosspost-Warning: CROSSPOST CONTINUING\n";	
	$body .= "XRef: $XRef\n";

	open(FILE, ">> $DIR/$TMP_DIR/crosspost-c"); 
	print FILE "\t$XRef\n";
	close(FILE);

    } 
    elsif ($USE_CROSSPOST) {
	$body .= "X-Crosspost-Warning: ATTENTION! THIS IS A CROSSPOST\n";
	$body .= "XRef: $XRef\n";

	open(FILE, "> $DIR/$TMP_DIR/crosspost"); 
	print FILE "$XRef\n";
	close(FILE);
    }
#.endif
    if ($APPEND_STARDATE) {
	require 'libStardate.pl';
	$body .= "X-Stardate: ".&Stardate."\n";
    } 
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "Precedence: ".($PRECEDENCE || 'list')."\n"; #Sendmail 8.x for delay mail
    $body .= "Lines: $BodyLines\n\n";
    $body .= $MailBody;

    # spooling, check dupulication of ID against e.g. file system full
    if (! -f "$SPOOL_DIR/$ID") {	# not exist
	&Logging("ARTICLE $ID");
	open(mail_file, "> $SPOOL_DIR/$ID") || (&Logging($!), return);
	select(mail_file); $| = 1; select(STDOUT);

	if ($MIME_DECODED_ARTICLE) { 
	    require 'libMIME.pl';
	    print mail_file &DecodeMimeStrings($body);
	}
	else {
	    print mail_file $body;
	}

	close(mail_file);
    } 
    else {			# if exist, warning and forward
	&Log("ARTICLE $ID", "ID[$ID] dupulication");
	&Warn("ERROR:ID dupulication $ML_FN", $body);
    }

    # IPC. when debug mode, no distributing 
    $Status = &Smtp($host, "$body.\n", @headers) unless $debug;
    &Logging("Sendmail:$Status") if $Status;

    $DISTRIBUTE_CLOSE_HOOK && 
	&eval($DISTRIBUTE_CLOSE_HOOK, 'Distribute close Hook');
}

# CheckMember(address, file)
# return 1 if a given address is authentified as member's
sub CheckMember
{
    local($address, $file) = @_;

    open(FILE, $file) || return 0;

  getline: while (<FILE>) {
      chop; 

      $ML_MEMBER_CHECK || do { /^\#\s*(.*)/ && ($_ = $1);};

      next getline if /^\#/o;	# strip comments
      next getline if /^\s*$/o; # skip null line
      /^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

      # member nocheck(for nocheck but not add mode)
      # fixed by yasushi@pier.fuji-ric.co.jp 95/03/10
      if (/^\+/o) { 
	  close(FILE); 
	  return 1;
      }

      # This searching algorithm must require about N/2, not tuned,
      if (1 == &AddressMatching($_, $address)) {
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

# Alias but delete \015 and \012 for seedmail return values
sub Log { 
    local($str, $s) = @_;
    $str =~ s/\015\012$//;
    &Logging($str);
    &Logging("   ERROR: $s", 1) if $s;
}

# Logging(String as message)
# $errf(FLAG) for ERROR
sub Logging
{
    local($str, $e) = @_;

    &GetTime;

    open(LOGFILE, ">> $LOGFILE");
    select(LOGFILE); $| = 1; select(STDOUT);
    print LOGFILE "$Now $str ". ((!$e)? "($From_address)\n": "\n");
    close(LOGFILE);
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
    ($opt =~ /^\-(\S)/)      && ($_cf{'opt', $1} = 1);
    ($opt =~ /^\-(\S)(\S+)/) && ($_cf{'opt', $1} = $2);

    # Reassign options
    $debug = 1 if $_cf{'opt', 'd'};
    $LOAD_LIBRARY = $_cf{'opt', 'l'} if $_cf{'opt', 'l'};
}

# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
MailingList:         $MAIL_LIST
UNIX FROM:           $Unix_From
From(Original):      $Original_From_address
From_address:        $From_address
Original Subject:    $Subject
Subject for Summary: $Summary_Subject
To_address:          $To_address

CONTROL_ADDRESS:     $CONTROL_ADDRESS
CommandMode:         $CommandMode

SUPERFLUOUS:        >$SuperfluousHeaders<

LOAD_LIBRARY:        $LOAD_LIBRARY

"#;

"print STDERR $s";
}


sub Debug
{
    local($s) = @_;

    print STDERR "$s\n";
    $_cf{'return'} .= "\nDEBUG $s\n" if $_cf{'debug'};
}


# Check uid == euid && gid == egid
sub ChkREUid
{
    print STDERR "\n";
    print STDERR "setuid is not set $< != $>\n" if $< ne $>;
    print STDERR "setgid is not set $( != $)\n" if $( ne $);
    print STDERR "\n";
}


# Check Looping 
# return 1 if loopback
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;
    local($ml);

    foreach $ml ($MAIL_LIST, $CONTROL_ADDRESS, @Playing_to) {
	next if $ml =~ /^$/oi;	# for null control addresses
	if (&AddressMatch($to, $ml)) {
	    &Log("Loop Back Warning: ", "[$From_address] or [$to]");
	    &Warn("Loop Back Warning: $ML_FN", &WholeMail);
	    return 1;
	}
    }

    return 0;
}


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
