# Library of fml.pl 
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$libid";

&FTPMAIL;

sub FTPMAIL
{
    # From_address and Original_From_address are arbitrary.
    local($to) = $Reply_to ? $Reply_to : $From_address;
    local(@MAILBODY) = split(/\n/, $MailBody, 999) ;
    local($REPLY_BODY) = "";
    $0 = "--FTPMAIL COMPATIBLE Mode in <$FML $LOCKFILE>";
    $CURRENT_DIR = ".";

  GivenCommands: foreach (@MAILBODY) {
      next GivenCommands if(/^$/o); # skip null line
      if(! /^#/o) {
	  &SendFile($to, "Command Syntax Error $ML_FN", $HELP_FILE);
	  &Logging("HELP sent to $From_address");
	  last GivenCommands;
      }

      s/^#(\S+)(.*)/# $1 $2/ if $RPG_ML_FORM_FLAG;
      @Fld = split(/[ \t\n]+/, $_, 999);
      $_ = $Fld[1];
      $0 = "--FTPMAIL COMAPTIBLE Mode processing $_: $FML $LOCKFILE>";
      print STDERR "Now command is >$_<\n" if($debug);

      # not implemented
      if(/^ftp$/io || /^connect$/io) { 
	  $REPLY_BODY .= "Sorry. not implemented\n";	  
      }

      # end of requests
      if(/^quit$/io || /^exit$/io) { 
	  $REPLY_BODY .= "exit of current process\n";
	  last GivenCommands;
      }

      # change the current directory
      if(/^cd$/io || /^chdir$/io) { 
	  if(! $Fld[2]) { $CURRENT_DIR = "."; next GivenCommands;}
	  $CURRENT_DIR = $Fld[2];
	  $REPLY_BODY .= "current directory changes to $CURRENT_DIR\n";
	  &Logging("chdir to $CURRENT_DIR ($From_address)");
	  next GivenCommands;
      }

      # help for usage of commands
      if(/^help$/io) {		# help or HELP
	  &SendFile($to, "Help $ML_FN", $HELP_FILE);
	  &Logging("Help ($From_address)");
	  $REPLY_BODY .= "Sent back [help] file to $to\n";
	  next GivenCommands;
      }
      
      # return address change
      if(/^mail$/io) {		# help or HELP
	  $to = $Fld[2];
	  $REPLY_BODY .= "Return address change to $to\n";
	  &Logging("RECIPIENT CHANGE: $From_address -> $to");
	  next GivenCommands;
      }
      
      # get one article from the spool, then return it
      if(/^get$/io || /^send$/io || /^getfile$/io) {
	  local($file) = $Fld[2];
	  if($file =~ /\\$CURRENT_DIR/) { $file =~ s/\\$CURRENT_DIR\///;}
	  if('ok' eq &mget($file)) {
	      &Logging("get $file ($From_address), success");
	      $REPLY_BODY .= "Sent back [$file] in $CURRENT_DIR to $to\n";
	  }else {
	      &Logging("get $file ($From_address), fail");
	      $REPLY_BODY .= "fails to sent back [$file] in $CURRENT_DIR to $to\n";
	  }
	  next GivenCommands;
      }

      $REPLY_BODY .= "Unknown Commands $_\n";
  }				# end of while loop

    &Sendmail($to, "FML FTPMAIL COMAPTIBLE SERVER", $REPLY_BODY) if $REPLY_BODY;
}


# "matomete" get :-), maybe insecure. require Bourne Shell REGEXP
sub mget {
    local($file) = @_;
    $SLEEPING = $Fld[3] ? $Fld[3] : 300;
    print STDERR "(cd $DIR/$CURRENT_DIR;$TAR $file)\n" if($debug);
    open(BUFFER, 
	 "(cd $DIR/$CURRENT_DIR;$TAR $file)|$COMPRESS|$UUENCODE spool.tar.Z|");

    return '' if(! -f "$CURRENT_DIR/$file");

    # make the return mail
    open(TMPFILE, "> $DIR/mget$$") || (&Logging("$!"), return);
    while(<BUFFER>) {
	print TMPFILE $_;
	$totallines++;		# counting the total lines of the uuencoded;
    }
    close TMPFILE, BUFFER;
    
    local($MGET_COMMAND) = "$LIBDIR/split_and_sendmail.pl";
    $MGET_COMMAND .= " -I " . join(":",@INC);
    $MGET_COMMAND .= " -f $DIR/mget$$ -s \'mget $ML_FN\'";
    $MGET_COMMAND .= " -d $DIR -l $MGET_LOGFILE -t $SLEEPING -m $MAINTAINER $to";

    # Pay attention! COMMAND uses Insecure mode
    system "/bin/sh", '-c', "$MGET_COMMAND &";

    return 'ok';
}

1;
