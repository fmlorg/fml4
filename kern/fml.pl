#!/usr/local/bin/perl
#
# Copyright (C) 1993 fukachan@phys.titech.ac.jp
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# Directory of Mailing List Server Libraries
$DIR	      = $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/EXP';
while(@ARGV) { shift @ARGV;}

#################### MAIN ####################
# including libraries
push(@INC,"$DIR");		# add the path for include files
require 'config.ph';		# a config header file
require 'libsmtp.pl';		# a library using smtp
require 'liblock.pl' unless $USE_FLOCK;

# a little configuration before the action
umask (022);			# rw-r--r--
$CommandMode  = '';		# default CommandMode is nil.
$GUIDE_REQUEST_FROM_UNKNOWN = 0;# not member && guide request only

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Parsing;			# Phase 1(1st pass), pre-parsing here
				# e.g. MIME
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

$CommandMode = 1 if($CONTROL_ADDRESS &&
		    index($To_address, $CONTROL_ADDRESS) >= 0);
				# when the address is for command.

(!$USE_FLOCK) ? &Lock : &Flock;	# Locking 

if($ML_MEMBER_CHECK) { 
    if(! &MLMemberCheck) {	# if failed
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 0;
    }
} else { 
    if(! &MLMemberNoCheckAndAdd) { # if failed
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 0;
    }
}

if ($CommandMode) {		# If "# (.*)" form is given, Command mode
    require 'libfml.pl'; 
} else {			# distribution mode(Mailing List)
    &Distribute;
}

(!$USE_FLOCK) ? &Unlock : &Funlock;# UnLocking 
exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0755);}
    if(!-f $ACTIVE_LIST)   { open(TOUCH,"> $ACTIVE_LIST");   close(TOUCH);}
    if(!-f $MEMBER_LIST)   { open(TOUCH,"> $MEMBER_LIST");   close(TOUCH);}
    if(!-f $SUMMARY_FILE)  { open(TOUCH,"> $SUMMARY_FILE");  close(TOUCH);}
    if(!-f $LOGFILE)       { open(TOUCH,"> $LOGFILE");       close(TOUCH);}
    if(!-f $MGET_LOGFILE)  { open(TOUCH,"> $MGET_LOGFILE");  close(TOUCH);}
    if(!-f $SEQUENCE_FILE) { open(TOUCH,"> $SEQUENCE_FILE"); close(TOUCH);}

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

# one pass to modify the mail header, ex. MIME...
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($WHOLE_MAIL) = '';
    # whether a command mode or not is checked within the first 3 lines.
    
    while(<>) { $WHOLE_MAIL .= $_;}
    local($MailBodyIndex) = index($WHOLE_MAIL, "\n\n");
    $MailHeaders = substr($WHOLE_MAIL, 0, $MailBodyIndex);
    $MailBody    = substr($WHOLE_MAIL, $MailBodyIndex + 2, 
			  length($WHOLE_MAIL));
    $MailHeaders =~ s/\s\n\s+//go; # not special, for e.g. MIME headers
    
    local(@body) = split(/\n/, $MailBody, 9999);
    local($i);
    for($i = 0; $i < $COMMAND_CHECK_LIMIT; $i++) {
	print STDERR $body[$i], "\n" if $debug;
	$CommandMode = 'on' if($body[$i] =~ /^\#/o);
    }
    $BodyLines = scalar(@body) - 1;
    $GUIDE_REQUEST_FROM_UNKNOWN = 1 if($MailBody =~ /\#\s*guide/io);
}

# Phase 2(2nd pass), extract several fields 
sub GetFieldsFromHeader
{
    # tuned below? 
    local(@MailHeaders) = split(/\n/, $MailHeaders, 999);
    
    # matching $MailHeaders =~ /\nDate: *(.*)\n/io is faster, is'nt it?
    while($_ = $MailHeaders[0], shift @MailHeaders) {
	/^Date: *(.*)$/io           && ($Date = $1, next);
	/^Reply-to: *(.*)$/io       && ($Reply_to = $1, next);
	/^Errors-to: *(.*)$/io      && ($Errors_to = $1, next);
	/^Sender: *(.*)$/io         && ($Sender = $1, next);
	/^X-Distribution: *(.*)$/io && ($Distribution = $1, next);
	/^From: *(.*)$/io           && ($From_full_address = $1);

	if(/^From: *.* *<(\S+)> *.*$/io) { $From_address = $1; next;}
	if(/^From: *(\S+) *.*$/io)       { $From_address = $1; next;}

	# To control each action corresponding to each address(1.1.2.15-)
	if(/^To: *.* *<(\S+)> *.*$/io) { $To_address = $1; next;}
	if(/^To: *(\S+) *.*$/io)       { $To_address = $1; next;}
	
	# get subject (strip [id:user], move multiple Re:)
	if(/^Subject: *(.*)$/io) { 
	    $_ = $1; print STDERR "subject: $_\n" if($debug);
	    if(/^Re: *\[.*\] *Re: *(.*)/o) { $Subject = "Re: " . $1; next;}
	    if(/^Re: *\[.*\] *(.*)/o)      { $Subject = "Re: " . $1; next;}
	    if(/^.*\[.*\] *(.*)/o)         { $Subject = $1; next;}
	    $Subject = $1;
	}
    }
    print STDERR  $From_address, "<---From_adress\n" if($debug);
    print STDERR  $Subject,      "<---Subject\n"     if($debug);
    print STDERR  $To_address,   "<---To_adress\n"   if($debug);
    $User = substr($From_address, 0, 15);
}

# check a mail from members or not? return 0 is end of whole fml process
sub MLMemberCheck
{
    $0 = "--Checking Members or not <$FML $LOCKFILE>";
    if(0 == &CheckMember($From_address, $MEMBER_LIST)) {
	# When just guide request from unknown person, return the guide only
	if($GUIDE_REQUEST_FROM_UNKNOWN) {
	    &Logging("Guide ($From_address) who is unknown");
	    &SendFile($From_address, "Guide $ML_FN", $GUIDE_FILE);
	}else{
	    # When not member, return the deny file.
	    &Logging("From not member: $From_address");
	    &Sendmail($MAINTAINER, "NOT MEMBER article from $From_address $ML_FN", $MailBody);
	    &SendFile($From_address, "You $From_address are not member $ML_FN",$DENY_FILE);
	}
	return 0;
    }
    return 1;
}    

# original designing is for luna ML 
# return 0 is end of whole fml process
# Member or not is checked, if failed, add the user as a new member of the ML
sub MLMemberNoCheckAndAdd
{
    $0 = "--Checking Members and add if new <$FML $LOCKFILE>";
    $ACTIVE_LIST 	= "$DIR/members"; # actives and members are the same 
    
    if (0 == &CheckMember($From_address, $MEMBER_LIST)) { # if not member
	# if not member but guide request, not add him and return the guide
	if($GUIDE_REQUEST_FROM_UNKNOWN) {
	    &Logging("Guide ($From_address) who is unknown");
	    &SendFile($From_address, "Guide $ML_FN", $GUIDE_FILE);
	    return 0;# fml ends if guide. if not, &Command also send the guide.
	}

	# if not guide, add him to the member list and do the next step.
	open(TMP, ">> $MEMBER_LIST")  || (&Logging("$!"), return 0);
	print TMP $From_address, "\n";
	close(TMP);
	&Logging(sprintf("Added: %s", $From_address));
	&Sendmail($MAINTAINER, sprintf("New added member: %s $ML_FN", 
				       $From_address), $MailBody);
	return 1;
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
    # require another file descripter for flock system call
    open(IDINC, "< $SEQUENCE_FILE") || (&Logging("$!"), return);
    $ID = <IDINC>; $ID++;
    close(IDINC);

    # for when not using flock system call, but no symmetry ;_;
    if(! $USE_FLOCK) { 
	open(LOCK, "> $SEQUENCE_FILE") || (&Logging("$!"), return);
    }

    # save the ID for the next process
    printf LOCK "%d\n", $ID; 
    close(LOCK);
    
    # save summary and put log
    open(SUMMARY, ">> $SUMMARY_FILE") || (&Logging("$!"), return);
    printf SUMMARY "%s [%d:%s] %s\n", $Now, $ID, $User, $Subject;
    close(SUMMARY);
    &Logging(sprintf("ARTICLE %d (%s)", $ID, $From_address));
    
    # Distribution mode
    @headers = ("HELO", "MAIL FROM: $MAINTAINER");
    open(ACTIVE_LIST) || 
	(&Logging("cannot open $ACTIVE_LIST when $ID:$!"), return);
    
    $rcsid  .= "/MX-0.0 "; $MX_PATCH_DATE = "";
  line: while (<ACTIVE_LIST>) {	# MX version(for 5.67+1.6w)
      chop;
      /^[ \t]*(.*)[ \t]*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx
      next line if(/^\#/o);	# skip comment and off member
      next line if(/^\s*$/o);	# skip null line
      local($rcpt, $mx) = split(/[ \t\n]+/, $_, 999);
      if($mx) {			# if MX is explicitly given,
	  print STDERR "MX = $mx, the given fields is $_\n" if($debug);
	  local($who, $mxhost) = split(/@/, $rcpt, 2);
	  $rcpt = "$who%$mxhost@$mx";
      }
      print STDERR "RCPT TO: $rcpt \n" if($debug);
      push(@headers, "RCPT TO: $rcpt");
  }
    close(ACTIVE_LIST);
    push(@headers, "DATA");
    
# This is the order recommended in RFC822, p.20. But not clear about X-*
    $body = 
	"Return-Path: <$MAINTAINER>\n" .
	"Date: $MailDate\n" .
	"From: $From_full_address\n";
    $body .= "Subject: $Subject\n" if $Subject; # When Subject is nil, no field
    $body .= "Sender: $Sender\n" if($Sender); # Sender is just additional. 
    $body .= "To: $MAIL_LIST $ML_FN\n";
    $body .= "Reply-To: ";
    $body .= $Reply_to ? "$Reply_to\n" : "$MAIL_LIST\n";
# Errors-to is not refered in RFC822. 
# Sendmail 8.x do not see this field in default. 
# However in error may be effective for e.g. Pasokon Tuusin, BITNET..
# I don't know details about them.
#      $body .= "Errors-To: ";
#      $body .= $Errors_to ? "$Errors_to\n" : "$MAINTAINER\n";
    $body .= 
	"Posted: $Date\n" .
	"$XMLNAME\n" .
	"$XMLCOUNT: " . sprintf("%05d", $ID) . "\n"; # 00010 
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "Precedence: list\n"; # for Sendmail 8.x, for delay mail
    $body .= "Lines: $BodyLines\n\n";
    $body .=  $MailBody;

    # spooling
    $mail_file = sprintf("%s/%d", $SPOOL_DIR, $ID);
    open(mail_file, "> $mail_file") || (&Logging("$!"), return);
    print mail_file "$body";
    close(mail_file);

    # IPC. when debug mode, no distributing 
    $Status = &Smtp($host, "$body.\n", @headers) if(! $debug);
    &Logging("Sendmail:$Status") if $Status;

    return ;
}

# CheckMember(address, file)
# return 1 if a given address is authentified as member's
sub CheckMember
{
    local($address, $file) = @_;
    
    open(FILE, $file) || return 0;
  getline: while (<FILE>) {
      chop; # strip comment and space below
      next getline if(/^\#/o);
      next getline if(/^\s*$/o); # skip null line
      /^[ \t]*(\S+)[ \t]*.*$/o && ($_ = $1); # including .*#.*

      # This searching algorithm must require about N/2, not tuned,
      # but for checking addresses registerd doubly
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
    local($message) = @_;
    open(LOGFILE, ">> $LOGFILE");
    printf LOGFILE "%s %s\n", $Now, $message;
    close(LOGFILE);
}

# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";
    open(LOCK, ">> $SEQUENCE_FILE"); # if using ">", remove the content
    flock(LOCK, $LOCK_EX);
    seek(LOCK, 0, 0);	# move to the top of file(above, open as append mode)
}

sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";
    flock(LOCK, $LOCK_UN);
}

1;
