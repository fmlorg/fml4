# Front End for Voting System Library
# 0.x Project Code Osakana
# 1.0              Yumeko
# 1.2              Elena
$Elenaid = q$Id$;
($Elenaid) = ($Elenaid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid   .= "/$Elenaid";

require 'Elena.ph';

sub ElenaSummary
{
    local($summary) = '';
    open(ELENA, "$JCONVERTER ./spool/* | $MAKESUMMARY| $REVERSE_JCONVERTER|");
    while(<ELENA>) { $summary .= $_;}
    close(ELENA);
    &Sendmail($From_address, $SUMMARY_SUBJECT, $summary);
    &Logging(sprintf("Summary request from: (%s)", $From_address));
}

sub ElenaCancel {
    local($ID)      = @_;
    local($file)    = "$SPOOL_DIR/$ID";
    local($address) = '';

    if(!-f $file){
	&Sendmail($From_address, $CANCEL_NOFILE_SUBJECT . $ID, 
		  $CANCEL_NOFILE_BODY);
	&Logging("Cancel request, but cannot find $ID from: $From_address");
	return;
    }

    open(FD, "< $file") || (&Logging("cannot open $file: $!"), return);
    while(<FD>) {
	last if(/^$/o);		# check only the header
	if(/^From: *.* *<(\S+)> *.*$/io) { $address = $1; next;}
	if(/^From: *(\S+) *.*$/io)       { $address = $1; next;}
    }
    
    # if $address eq $From_address, the sender is authenticated.
    if($address eq $From_address) {
	if(unlink $file) {
	    &SendFile($From_address, $CANCEL_SUBJECT . $ID, $GUIDE_FILE);
	    &Logging("$ID is canceled from: $From_address");
	} else {
	    &SendFile($From_address, 
		      "Cannot unlink your vote " . $ID, $GUIDE_FILE);
	    &Logging("$ID is not unlinked? from: $From_address");
	}
    }else {
	&SendFile($From_address, 
		  $CANCEL_NO_AUTHENTICATED_SUBJECT . $ID, $GUIDE_FILE);
	&Logging("Cancel request,but not authenticated: $From_address");
    }
}

sub ElenaCommand {
    local($to) = $Reply_to ? $Reply_to : $From_address;
    local(@MAILBODY) = split(/\n/, $MailBody, 999) ;
    local($line, $cmd, $subcmd, $ok, $subject);
    $0 = "--Elena Command Mode in <$FML $LOCKFILE>";

  GivenCommands: foreach (@MAILBODY) {
      next GivenCommands if(/^$/o); # skip null line
      if(! /^#/o) {
	 &SendFile($to, "Illegal Command Syntax[$_] $ML_FN", $GUIDE_FILE);
	 &Logging("Guide sent to $From_address");
	 last GivenCommands;
     }
      @Fld = split(/[ \t\n]+/, $_, 999);
      $_ = $Fld[1];
      $0 = "--Elena Command Mode processing $_: $FML $LOCKFILE>";

      print STDERR "Now command is >$_<\n" if($debug);
      if(/summary/o){ &ElenaSummary;        next GivenCommands;}
      if(/cancel/o){ &ElenaCancel($Fld[2]); next GivenCommands;} 
      &SendFile($to, "Unknown Command [$_] $ML_FN", $GUIDE_FILE);
      &Logging("Unknown Command [$_]: $From_address");
  }# while loop ends;
}    

sub ElenaSpooling
{
    $0 = "--Spooling:Elena <$FML $$>";
    local($mail_file, $to);

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
    
# Distribution mode, but only spooling
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
}



# This is the main routine for Elena Library 
sub ElenaVoting{
    local($votelog)    = "$DIR/vote$$";
    local($returnbody) = '';

    # Spooling for vote
    &ElenaSpooling;
    $0 = "--Return process <$FML $$>";

    # Generate Return Mail, first vote result
    open(VOTELOG, "|$JCONVERTER | $VOTING |$REVERSE_JCONVERTER > $votelog") ||
	(&Logging("Cannot convert and do vote.pl"), return);
    print VOTELOG $MailBody;
    close(VOTELOG);

    # Added files
    open(GUIDE, "< $GUIDE_FILE") ||
	(&Logging("Cannot open $GUIDE_FILE:$!"), return);
    open(VOTELOG, "< $votelog") ||
	(&Logging("Cannot open $votelog:$!"), return);

    $returnbody .= $RETURN_MAIL_BODY_1;
    while(<VOTELOG>) { $returnbody .= $_;}
    $returnbody .= $RETURN_MAIL_BODY_2;
    $returnbody .= $MailBody;
    $returnbody .= $RETURN_MAIL_BODY_3;
    while(<GUIDE>) { $returnbody .= $_;}
    close VOTELOG, GUIDE;

    &Sendmail($From_address, $ELENA_SERVER_SUBJECT . $ID, $returnbody);
    &Sendmail($MAINTAINER, "Vote from $From_full_address", $returnbody);
    unlink $votelog;
}

1;
