# $Author$
# $State$
# $rcsid = q$Id$;

$libid = q$Id$;
($libid) = ($libid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$libid";

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/bin';    # or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

&Command;

sub Command
{
    local($to) = $Reply_to ? $Reply_to : $From_address;
    local($line, $cmd, $subcmd, $ok, $subject);
    local(@MAILBODY) = split("\n", $MailBody, 999) ;

  GivenCommands: while ($_ = $MAILBODY[0], shift @MAILBODY) {
      next GivenCommands if(/^$/o); # skip null line
      if(! /^#/o) {
	  &SendFile($to, "HELP ML Server <fml>", $HELP_FILE);
	  &Logging(sprintf("HELP sent to <%s>", $From_address));
	  last GivenCommands;
      }
      @Fld = split("[ \t]", $_, 999);
      $_ = $Fld[1];
      print STDERR "Now command is $_\n" if($debug);

      # notify the guide request from somebody to $MAINTAINER
      if(/guide/io) {
	  $msg = sprintf("Guide request: '%s' (%s)", $_, $From_address);
	  &Sendmail($MAINTAINER, $msg, $MailBody);
	  &Logging($msg);
	  next GivenCommands;
      }

      # help for usage of command
      if(/help/io) {		# help or HELP
	  &SendFile($to, "Help", $HELP_FILE);
	  &Logging(sprintf("Help (%s)", $From_address));
	  next GivenCommands;
      }
      
      # return mailing list objective
      if(/objective/io) {
	  &SendFile($to, "Objective", $OBJECTIVE_FILE);
	  &Logging(sprintf("Objective (%s)", $From_address));
	  next GivenCommands;
      }
      
      # return mailing list member list
      if(/member/io) {
	  &SendFile($to, "Members", $MEMBER_LIST);
	  &Logging(sprintf("Members (%s)", $From_address));
	  next GivenCommands;
      }
      
      # return active mailing list member list
      if(/active/io) {
	  &SendFile($to, "Actives", $ACTIVE_LIST);
	  &Logging(sprintf("Actives (%s)", $From_address));
	  next GivenCommands;
      }
      
      # return summary
      if(/summary/io) {
	  &SendFile($to, "Summary", $SUMMARY_FILE);
	  &Logging(sprintf("Summary (%s)", $From_address));
	  next GivenCommands;
      }
      
      # send msg to maintainer
      if(/^msg$/io) {
	  $subject = sprintf("Msg from %s - %s", $From_address, $Subject);
	  &Sendmail($MAINTAINER, $subject, $MailBody);
	  &Logging(sprintf("MSG (%s)", $From_address));
	  # MAIL_BODY has been closed in sendmail()
	  last GivenCommands;
	  next GivenCommands;
      }

      # get a msg from spool, then return it
      if(/^get$/io) {
	  $ID = $Fld[2];
	  local($mail_file) = "$SPOOL_DIR/$ID";
	  if(-f $mail_file) {
	      &SendFile($to, sprintf("Get %s", $ID), $mail_file);
	      $status = "Success";
	  } else {				# or null $ID
	      &SendFile($to, sprintf("Get %s failed. Msg not found.", $ID), "zonky");
	      $status = "Fail";
	  }
	  &Logging(sprintf("Get %s %s (%s)", $ID, $status, $From_address));
	  next GivenCommands;
      }
      # matomete get msgs from spool, then return them
      if(/^mget$/io) {
	  &mget($Fld[2]);
	  &Logging(sprintf("Mget %s from <%s> succeeded", $_, $From_address));
	  next GivenCommands;
      }
      
      # sign off
      if(/^off$/io) {
	  &ChangeMemberList('off', $From_address, $ACTIVE_LIST);
	  &Logging(sprintf("Off (%s)", $From_address));
	  &SendFile($to, "Off accepted. I'm waiting your On cmd.", "zonky");
	  next GivenCommands;
      }

      # sign on
      if(/^on$/io) {
	  &ChangeMemberList('on', $From_address, $ACTIVE_LIST);
	  &Logging(sprintf("On (%s)", $From_address));
	  &SendFile($to, "On accepted", "zonky");
	  next GivenCommands;
      }

      # bye   - permanently remove the user
      if(/^bye$/io) {
	  &ChangeMemberList('bye', $From_address, $ACTIVE_LIST);
	  &ChangeMemberList('bye', $From_address, $MEMBER_LIST);
	  &Logging(sprintf("Bye (%s)", $From_address));
	  &SendFile($to, "Bye accepted. So Long!", "zonky");
	  next GivenCommands;
      }

      # these below are not implemented, but implemented in hml 1.6
      # only for notifying the alart to the users
      local($implementedflag) = '';
      if(/^iam$/io)  { $implementedflag = 'off';}
      if(/^whois$/io){ $implementedflag = 'off';}
      if(/^who$/io)  { $implementedflag = 'off';}
      if($implementedflag) {
	  &Logging(sprintf("$_ (%s)", $From_address));
	  &SendFile($to, "Command $_ is not implemented", "$HELP_FILE");
	  next GivenCommands;
      }

      # undefined command
      &Sendmail($to, sprintf("Unknown Command: %s", $_),$MailBody);
      &Logging(sprintf("Unknown Cmd '%s'(%s)", $_, $From_address));
      last GivenCommands;
  } # the end of while loop
}

# "matomete" get :-)
sub mget {
    local($_);
    local($REGEXP) = @_;
    local($SPOOLEDFILE)  = "spool.tar.Z";
    local($TMPORARYFILE) = "$DIR/mget$$";	# the temporary file
    local($COMMAND); 
    $COMMAND = "(cd $DIR;$TAR ./spool/$REGEXP)|";
    $COMMAND .= "$COMPRESS|$UUENCODE $SPOOLEDFILE|";

    if(!-r "$SPOOL_DIR") { 
	local($errorlog) = "cannot find or read $SPOOL_DIR";
	&Sendmail($to, "mget: $errorlog", $MailBody);
	&Sendmail($MAINTAINER, "mget: $errorlog", $MailBody);
	return;
    }

    open(BUFFER, "$COMMAND");
    open(TMPFILE, "> $TMPORARYFILE"); # the temporary file
    while(<BUFFER>) {
	print TMPFILE $_;
	$totallines++;# counting the total lines of the uuencoded
    }
    close(TMPFILE);
    close(BUFFER);    
    system "$DIR/split_and_sendmail.pl $to -f $TMPORARYFILE -d $DIR &";
    unlink "$SPOOLEDFILE";
    return;
}

# ChangeMemberList(cmd, address, file)
# delete or add address from/to file
sub ChangeMemberList
{
    local($cmd, $Address, $file) = @_;
    local($executeflag) = '';
    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
	= localtime(time);
    local($Date) = sprintf("%02d%02d", ++$mon, $mday);

    open(BAK, ">> $file.bak$Date"); print BAK "-----Change on %Date-----\n";
    open(NEW, ">  $file.tmp");
    open(FILE,"<  $file");

    while(<FILE>) {
	print BAK $_;
	chop;
	next if (/^$/o);
	next if (/^[ \t]+$/o);

	# get $addr for ^#[ \t]+$addr$. if ^#, skip process except for 'off' 
	local($addr) = '';
	if(/^[ \t]*(.*)/o){ $addr = $1;}
	if(! $addr) { if(/^\#[ \t]*(.*)/o) {$addr = $1;}}
	if(! &StripFieldAndMatchCheck($addr, $Address)) {
	    print NEW "$_\n"; next;
	} 

	if($cmd eq 'on') { print NEW "$addr\n"; next;}
	if($cmd eq 'bye') { print NEW "##BYE $addr\n"; next;}
	if($cmd eq 'off') { print NEW "#\t$addr\n"; next;}
    } # end of while loop

    close BAK, NEW, FILE;
# rename("", "")    ;
    return ;
}
    
    
sub StripFieldAndMatchCheck
{
    local($_, $From_address) = @_;
    ($_) = /^[ \t]*(\S+)[ \t]*.*\#.*/ if(/\#/o);
    ($_) = /^[ \t]*(\S+)[ \t]*.*/;
    return $_ if("$_" eq "$From_address");
    return '';
}

1;
