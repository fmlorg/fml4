#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "beta";
# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# Directory of Mailing List Server Libraries
# format: fml.pl DIR(for config.ph) PERLLIB's
$DIR		= $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/EXP';
$LIBDIR		= $ARGV[1] ? $ARGV[1] :$DIR;	# LIBDIR is the second arg. 
foreach(@ARGV) { push(@INC, $_);} 		# adding to include path

#################### MAIN ####################
# including libraries
require 'config.ph';		# a config header file
require 'libsmtp.pl';		# a library using smtp
require 'liblock.pl' unless $USE_FLOCK;

# a little configuration before the action
umask (077);			# rw-------
$CommandMode  	= '';		# default CommandMode is nil.
$GUIDE_REQUEST 	= 0;		# not member && guide request only

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Parsing;			# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

$FILE      = "/home/axion/fukachan/work/spool/whois/whoisdb";
$JCONVERTER         = "/usr/sony/bin/jconv -e";
if(open(FILE, "|$JCONVERTER >> $FILE")) {
    print FILE "$From_address\n$MailBody.\n\n";
    close(FILE);
    &Logging("Submit from $From_address");
    &Sendmail($MAINTAINER, 
	      "Submit from $From_address $ML_FN", $MailBody);
} else {
    &Logging("Cannot open $FILE");
    &Sendmail($MAINTAINER, 
	      "Cannot open $FILE $ML_FN", $MailBody);
}

(!$USE_FLOCK) ? &Unlock : &Funlock;# UnLocking 
exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0700);}
    for($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	$SEQUENCE_FILE, $SUMMARY_FILE) {
	if(!-f $_) { open(TOUCH,"> $_"); close(TOUCH);}
    }

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

# one pass to cut out the header and the body
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($GUIDE_CHK) = 3; # Guide Request Check within in the first 3 lines

    while(<STDIN>) { 
	if(1 .. /^$/o) {
	    if(/^$/o) {$MailHeaders .= "\n"; next;} #required for split(tricky)
	    $MailHeaders .= $_;
	} else {
	    # Command or not is checked within the first 3 lines.
	    if($GUIDE_CHK-- > 0) { $GUIDE_REQUEST = 1 if(/\#\s*guide\s*$/io);}
	    if($COMMAND_CHECK_LIMIT-- > 0) { $CommandMode = 'on' if(/^\#/o);}

	    $MailBody    .= $_;
	    $BodyLines++;
	}
    }
}

# Phase 2(2nd pass), extract several fields 
# Here is in 1.2-current the local rule to define header fileds.
# Original form  -> $Subject                 -> distributed mails
#                -> $Original_From_address   -> distributed mails
# parsed headers -> $Summary_Subject(a line) -> summary file
sub GetFieldsFromHeader
{
    local($field, $contents);

    #  These two lines are tricky for folding and unfolding.
    $MailHeaders =~ s/\n(\S+):/\n\n$1:\n\n/g;
    local(@MailHeaders) = split(/\n\n/, $MailHeaders, 999);

    while(@MailHeaders) {
	$_ = $field = $MailHeaders[0], shift @MailHeaders;
	print STDERR "FIELD:          >$field<\n" if($debug);
	next if(/^from\s/io); # UNIX FROM is a special case.
	$contents = $MailHeaders[0];
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if($debug);
	shift @MailHeaders;
	next if(/^$/o);		# if null, skip. must be mistakes.

	# Fields to skip. Please custumize below.
	next if(/^Received:/io);
	next if(/^In-Reply-To:/io);
	next if(/^Return-Path:/io);
	next if(/^Cc:/io);
	next if(/^X-M\S+:/io);
	next if(/^Precedence:/io);
	next if(/^Lines:/io);

	# filelds to use later.
	/^Date:$/io           && ($Date = $contents, next);
	/^Reply-to:$/io       && ($Reply_to = $contents, next);
	/^Errors-to:$/io      && ($Errors_to = $contents, next);
	/^Sender:$/io         && ($Sender = $contents, next);
	/^X-Distribution:$/io && ($Distribution = $contents, next);
	/^To:$/io             && ($To_address = $contents, next);
	/^Message-Id:$/io     && ($Message_Id = $contents, next);

	# get subject (remove [id:user], remove multiple Re:'s),
	# which actions may be out of my business though...
	if(/^Subject:$/io && $STRIP_BRACKETS) {
	    $_ = $contents;
	    if(/^Re:[\s\n]*\[[\s\S\n]*\][\s\n]*Re:[\s\n]*([\s\S\n]*)/o) {
		$Subject = "Re: $1"; next;
	    }
	    if(/^Re:[\s\n]*\[[\s\S\n]*\][\s\n]*([\s\S\n]*)/o) {
		$Subject = "Re: $1"; next;
	    }
	    if(/^[\s\n]*\[[\s\S\n]*\][\s\n]*(.*)/o) {
		$Subject = $1; next;
	    }
	    $Subject = $contents; next;
	}
	/^Subject:$/io        && ($Subject = $contents, next); # default
	
	if(/^From:$/io) {
	    # From_address is modified for e.g. member check, logging, commands
	    # Original_From_address is preserved.
	    $_ = $Original_From_address = $contents;
	    s/\n(\s+)/$1/g;
	    if(/^\s*.*\s*<(\S+)>.*$/io) {$From_address = $1; next;}
	    if(/^\s*(\S+)\s*.*$/io)     {$From_address = $1; next;}
	    $From_address = $_; next;
	}
	
	# when encounters unknown headers, hold if $SUPERFLUOUS_HEADER is 1.
	$SuperfluousHeaders .= "$field $contents\n" if($SUPERFLUOUS_HEADERS);
    }	# end of while loop

    # for summary file
    $Summary_Subject = $Subject;
    $Summary_Subject =~ s/\n(\s+)/$1/g;
    $User = substr($From_address, 0, 15);

    # for CommanMode Check(see the main routine in this flie)
    $To_address =~ s/\n(\s+)/$1/g;

    # MIME decoding. If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if($USE_LIBMIME && ($MailHeaders =~ /ISO\-2022\-JP/o)) {
	push(@INC, $LIBMIMEDIR);
        require 'libMIME.pl';
	$Summary_Subject = &DecodeMimeStrings($Summary_Subject);
    }

    if($debug) { # debug
	print STDERR  
	    $Original_From_address, "<---From(Original)\n",
	    $From_address,          "<---From_address\n",
	    $Subject,               "<---Original Subject\n",
	    $Summary_Subject,       "<---Subject for Summary\n",
	    $To_address,            "<---To_address\n",
	    "SUPERFULOUS>$SuperfluousHeaders<\n";
    }
}

sub GuideRequest
{
    # When just guide request from unknown person, return the guide only
    &Logging("Guide ($From_address) who is unknown");
    &SendFile($From_address, "Guide $ML_FN", $GUIDE_FILE);
}

# the To_address is for command or not.
sub AdditionalCommandModeCheck
{
    $CommandMode = 1 if($CONTROL_ADDRESS &&
			index($To_address, $CONTROL_ADDRESS) >= 0);
    
}

# check a mail from members or not? return 1 go on to Distribute or Command!
sub MLMemberCheck
{
    $0 = "--Checking Members or not <$FML $LOCKFILE>";
    if(0 == &CheckMember($From_address, $MEMBER_LIST)) {
	# When not member, return the deny file.
	&Logging("From not member: $From_address");
	&Sendmail($MAINTAINER, 
		  "NOT MEMBER article from $From_address $ML_FN", $MailBody);
	&SendFile($From_address, 
		  "You $From_address are not member $ML_FN", $DENY_FILE);
	return 0;
    }
    return 1;
}    

# original designing is for luna ML (Manami ML)
# return 1 go on to Distribute or Command!
# Member or not is checked, if failed, add the user as a new member of the ML
sub MLMemberNoCheckAndAdd
{
    $0 = "--Checking Members and add if new <$FML $LOCKFILE>";
    $ACTIVE_LIST 	= "$DIR/members"; # actives and members are the same 
    local($from) = $Reply_to ? $Reply_to : $From_address, "\n";    

    if (0 == &CheckMember($from, $MEMBER_LIST)) { # if not member
	# add the unknown to the member list
	open(TMP, ">> $MEMBER_LIST")  || (&Logging("$!"), return 0);
	print TMP $from, "\n";
	close(TMP);
	&Logging("Added: ($from)");
	$MailHeaders =~ s/\n\n/\n/g; $MailHeaders =~ s/:\n/:/g;
	&Sendmail($MAINTAINER, "New added member: $from $ML_FN",
		  $MailHeaders."\n".$MailBody);
	&SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);

	# 7 is body 3 lines and signature 4 lines, appropriate?
	if($BodyLines < 8) { $AUTO_REGISTERD_UNDELIVER_P = 1;}
	return ($AUTO_REGISTERD_UNDELIVER_P ? 0 : 1);
    }
    return 1;
}

# Distribute mail to member
sub Distribute
{
    $0 = "--Distributing <$FML $LOCKFILE>";
    local($mail_file, $to);
    local($Status) = 0;

    # ID = ID + 1( ID is a Count of ML article)
    open(IDINC, "< $SEQUENCE_FILE") || (&Logging("$!"), return);
    $ID = <IDINC>; $ID++; close(IDINC);
    open(IDINC, "> $SEQUENCE_FILE") || (&Logging("$!"), return);
    printf IDINC "%d\n", $ID; 
    close(IDINC);
    
    # save summary and put log
    open(SUMMARY, ">> $SUMMARY_FILE") || (&Logging("$!"), return);
    printf SUMMARY "%s [%d:%s] %s\n", $Now, $ID, $User, $Summary_Subject;
    close(SUMMARY);
    &Logging("ARTICLE $ID ($From_address)");
    
    # Distribution mode
    @headers = ("HELO", "MAIL FROM: $MAINTAINER");
    open(ACTIVE_LIST) || 
	(&Logging("cannot open $ACTIVE_LIST when $ID:$!"), return);

    # Original is for 5.67+1.6W, but R8 requires no MX tuning tricks.
    $rcsid  .= "/MX v0+rms ";	# so version 0 forever(maybe) :-)
  line: while (<ACTIVE_LIST>) {	# RMS <-> Relay, Matome, Skip
      chop;
      /^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx
      next line if(/^\#/o);	# skip comment and off member
      next line if(/^\s*$/o);	# skip null line
      local($rcpt, $mx, $matome) = split(/\s+/, $_, 999);
      print STDERR "$rcpt, $mx, $matome\n" if $debug;
      if($mx) {			# if MX is explicitly given,
	  next line if($mx     =~ /^skip$/io);   # for member check mode 
	  next line if($mx     =~ /^matome$/io); # for MatomeOkuri ver.2
	  next line if($matome =~ /^matome$/io); # for MatomeOkuri ver.2
	  print STDERR "MX = $mx, the given fields is $_\n" if($debug);
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $rcpt = "$who%$mxhost@$mx";
      }	# % relay is not refered in RFC, but effective in sendmails.
      print STDERR "RCPT TO: $rcpt \n" if($debug);
      push(@headers, "RCPT TO: $rcpt");
  }
    close(ACTIVE_LIST);
    push(@headers, "DATA");
    
# This is the order recommended in RFC822, p.20. But not clear about X-*
    $body = 
	"Return-Path: <$MAINTAINER>\n" .
	"Date: $MailDate\n" .
	"From: $Original_From_address\n";
    if(! $SUBJECT_HML_FORM) {	# the default is simple.
	# When Subject is nil, no field
	$body .= "Subject: $Subject\n" if $Subject;
    } else {			# hml 1.6 form
	$Subject = "None" unless $Subject;
	$body .= "Subject: [$BRACKET:$ID] $Subject\n";
    }
    $body .= "Sender: $Sender\n" if($Sender); # Sender is just additional. 
    $body .= "To: $MAIL_LIST $ML_FN\n";
    $body .= $Reply_to ? "Reply-To: $Reply_to\n" : "Reply-To: $MAIL_LIST\n";

    # Errors-to is not refered in RFC822. 
    # Sendmail 8.x do not see this field in default. 
    # However in error may be effective for e.g. Pasokon Tuusin, BITNET..
    # I don't know details about them.
    # $body .= "Errors-To: ", $Errors_to ? "$Errors_to\n" : "$MAINTAINER\n";
    # $body .= "Message-Id: $Message_Id\n";

    $body .= "Errors-To: $MAINTAINER\n" if $AGAINST_NIFTY;
    
    # superfluous headers are added if $SUPERFLUOUS_HEADERS is non-nil.
    $body .= $SuperfluousHeaders if($SUPERFLUOUS_HEADERS);
    $body .= 
	"Posted: $Date\n" .
	"$XMLNAME\n" .
	"$XMLCOUNT: " . sprintf("%05d", $ID) . "\n"; # 00010 
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "Precedence: list\n"; # for Sendmail 8.x, for delay mail
    $body .= "Lines: $BodyLines\n\n";
    $body .=  $MailBody;

    # spooling
    open(mail_file, "> $SPOOL_DIR/$ID") || (&Logging("$!"), return);
    print mail_file "$body";
    close(mail_file);

    # IPC. when debug mode, no distributing 
    $Status = &Smtp($host, "$body.\n", @headers) if(! $debug);
    &Logging("Sendmail:$Status") if $Status;

    return ;
}

# CheckMember(address, file)
# return 1 if a given address is authenticated as member's
sub CheckMember
{
    local($address, $file) = @_;

    open(FILE, $file) || return 0;
  getline: while (<FILE>) {
      chop; # strip comment and space below
      $ML_MEMBER_CHECK || do { /^\#\s*(.*)/ &&( $_ = $1);};
      next getline if(/^\#/o);
      next getline if(/^\s*$/o); # skip null line
      /^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

      # member nocheck(for nocheck but not add mode)
      return 1 if(/^\+/o);

      # This searching algorithm must require about N/2, not tuned,
      if (1 == &AddressMatching($_, $address)) {
	  close(FILE);
	  return 1;
      }
  }# while loop;
    close(FILE);
    return 0;
}

# sub AddressMatching($addr1, $addr2)
# return 1 given addresses are matched at the accuracy of 4 fields
sub AddressMatching
{
    local($addr1, $addr2) = @_;
    $addr1 =~ y/A-Z/a-z/;	# canonicalize to lower case
    $addr2 =~ y/A-Z/a-z/;
    
    if ($addr1 eq $addr2) { return 1;} # try exact match
    
    local($acct1, $addr1) = split(/@/, $addr1); # parse account and host
    local($acct2, $addr2) = split(/@/, $addr2);
    
    if($acct1 ne $acct2) {return 0;}# account is the same or not?;
    
    # get an array "jp.ac.titech.phys" for "fukachan@phys.titech.ac.jp"
    local(@domain1) = reverse split(/\./, $addr1);
    local(@domain2) = reverse split(/\./, $addr2);
    
    # if you like to strict the address check, 
    # add fields like a ...$domain[3].$domain[4]...;
    if("$domain1[0].$domain1[1].$domain1[2].$domain1[3]" eq 
       "$domain2[0].$domain2[1].$domain2[2].$domain2[3]") { 
	return 1;
    }
    return 0;			# not matched
}

# Logging(String as message)
sub Logging
{
    open(LOGFILE, ">> $LOGFILE");
    printf LOGFILE "%s %s\n", $Now, @_;
    close(LOGFILE);
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
