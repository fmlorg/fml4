# Library of fml.pl 
# Copyright (C) 1993 fukachan@phys.titech.ac.jp
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$libid";

&Command;

sub Command
{
    # From_address and Original_From_address are arbitrary.
    local($to) = $Reply_to ? $Reply_to : $From_address;
    local(@MAILBODY) = split(/\n/, $MailBody, 999) ;
    $0 = "--Command Mode in <$FML $LOCKFILE>";

  GivenCommands: foreach (@MAILBODY) {
      next GivenCommands if(/^$/o); # skip null line
      if(! /^#/o) {
	  &Logging("HELP sent to $From_address");
	  &SendFile($to, "Command Syntax Error $ML_FN", $HELP_FILE);
	  last GivenCommands;
      }

      s/^#(\S+)(.*)/# $1 $2/ if $RPG_ML_FORM_FLAG;
      @Fld = split(/[ \t\n]+/, $_, 999);
      $_ = $Fld[1];
      $0 = "--Command Mode processing $_: $FML $LOCKFILE>";
      print STDERR "Now command is >$_<\n" if($debug);

      # send a guide back to the user
      if(/guide/io) {
	  &Logging("Guide ($From_address)");
	  &SendFile($to, "Guide $ML_FN", $GUIDE_FILE);
	  next GivenCommands;
      }

      # help for usage of commands
      if(/help/io) {		# help or HELP
	  &Logging("Help ($From_address)");
	  &SendFile($to, "Help $ML_FN", $HELP_FILE);
	  next GivenCommands;
      }
      
      # return the objective of Mailing List
      if(/objective/io) {
	  &Logging("Objective ($From_address)");
	  &SendFile($to, "Objective $ML_FN", $OBJECTIVE_FILE);
	  next GivenCommands;
      }

      # return a  member file of Mailing List
      if(/member/io) {
	  &Logging("Members ($From_address)");
	  &SendFile($to, "Members $ML_FN", $MEMBER_LIST);
	  next GivenCommands;
      }
      
      # return a active file of Mailing List
      if(/active/io) {
	  &Logging("Actives ($From_address)");
	  &SendFile($to, "Actives $ML_FN", $ACTIVE_LIST);
	  next GivenCommands;
      }
      
      # return a summary of Mailing List
      if(/summary/io) {
	  &Logging("Summary ($From_address)");
	  &SendFile($to, "Summary $ML_FN", $SUMMARY_FILE);
	  next GivenCommands;
      }
      
      # send a message to $MAINTAINER
      if(/^msg$/io) {
	  &Logging("MSG ($From_address)");
	  &Sendmail($MAINTAINER, "Msg ($From_address), $Subject", $MailBody);
	  # MAIL_BODY has been closed in sendmail()
	  last GivenCommands;
      }

      # a little modulation for useful conversion between commands.
      s/getfile/get/io if $RPG_ML_FORM_FLAG; # "#getfile 1" is O.K.
      # if illegal "get 1-10" is given, get -> mget? required or not?
      # if(/^get$/io) { if($Fld[2] =~ /^[\d\-\,]+$/o){ $_ = 'mget';}}

      # get one article from the spool, then return it
      if(/^get$/io) {
	  $ID = $Fld[2];
	  local($mail_file) = "$SPOOL_DIR/$ID";
	  if(-f $mail_file) {
	      &SendFile($to, "Get $ID $ML_FN", $mail_file);
	      $status = "Success";
	  } else {				# or null $ID
	      &Sendmail($to, "Article $ID is not found. $ML_FN");
	      $status = "Fail";
	  }
	  &Logging("Get $ID, ($From_address), status is $status");
	  next GivenCommands;
      }

      # matomete get articles from the spool, then return them
      # mget is an old version. 
      # new version should be used as mget ver.2(mget[ver.2])
      # matomete get articles from the spool, then return them
      if(/^mget$/io || /^mget2$/io) {
	  if(&mget2(@Fld)) {
	      &Logging("mget[ver.2] $Fld[2] $Fld[3] from <$to> request, called");
	      next GivenCommands;
	  }
	  &Logging("mget[ver.2] $Fld[2] $Fld[3] from <$to> request, failed");
	  &Sendmail($to, "mget request $Fld[2], $Fld[3] failed. $ML_FN");
	  next GivenCommands;
      }
      
      # Off temporarily.
      if(/^off$/io) {
	  if(&ChangeMemberList('off', $From_address, $ACTIVE_LIST)) {
	      &Logging("Off ($From_address)");
	      &Sendmail($to, "Off accepted. I'm waiting your On cmd. $ML_FN");
	      next GivenCommands;
	  }else {
	      &Logging("Off failed ($From_address)");
	      &Sendmail($to, "Off failed. check and try again! $ML_FN");
	      next GivenCommands;
	  }
      }

      # Return to Mailng List
      if(/^on$/io) {
	  if(&ChangeMemberList('on', $From_address, $ACTIVE_LIST)) {
	      &Logging("On ($From_address)");
	      &Sendmail($to, "On accepted $ML_FN");
	      next GivenCommands;
	  }else {
	      &Logging("On failed ($From_address)");
	      &Sendmail($to, "On failed. check and try again! $ML_FN");
	      next GivenCommands;
	  }
      }

      # Bye - off permanently 
      if(/^bye$/io) {
	  if(! &ChangeMemberList('bye', $From_address, $ACTIVE_LIST)) {
	      &Logging("bye failed[$ACTIVE_LIST] ($From_address)");
	      &Sendmail($to, "Bye failed. check and try again! $ML_FN");
	      last GivenCommands;
	  }
	  if($ML_MEMBER_CHECK && 
	     (! &ChangeMemberList('bye', $From_address, $MEMBER_LIST))) {
	      &Logging("bye failed[$MEMBER_LIST] ($From_address)");
	      &Sendmail($to, "Bye failed. check and try again! $ML_FN");
	      last GivenCommands;
	  }
	  &Logging("Bye ($From_address)");
	  &Sendmail($to, "Bye accepted. So Long! $ML_FN");
	  last GivenCommands;
      }

      # these below are not implemented, but implemented in hml 1.6
      # codes only for notifying the alart to the user
      local($implementedflag) = '';
      if(/^iam$/io)  { $implementedflag = 'off';}
      if(/^whois$/io){ $implementedflag = 'off';}
      if(/^who$/io)  { $implementedflag = 'off';}
      if($implementedflag) {
	  &Logging("$_, ($From_address)");
	  &SendFile($to, "Command $_ is not implemented $ML_FN", "$HELP_FILE");
	  next GivenCommands;
      }

      # if undefined commands, notify the user about it.
      &Logging("Unknown Cmd $_, ($From_address)");
      &Sendmail($to, "Unknown Command: $_ $ML_FN", $MailBody);
      last GivenCommands;
  } # the end of while loop
}


# ChangeMemberList(cmd, address, file)
# Comment out or not of $file 
# Codes may be not insecure, I wonder.
sub ChangeMemberList
{
    local($cmd, $Address, $file) = @_;
    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
	= localtime(time);
    local($Date) = sprintf("%02d%02d", ++$mon, $mday);
    local($Status) = '';
    print STDERR "Now is $file\n" if($debug);

    if($MEMBER_LIST eq $file) {
	open(BAK, ">> $MEMBER_LIST.bak") || (&Logging("$!"), return $NULL);
	print BAK "-----Backup on $Now-----\n";
	open(NEW, ">  $MEMBER_LIST.tmp") || (&Logging("$!"), return $NULL);
	open(FILE,"<  $MEMBER_LIST") || (&Logging("$!"), return $NULL);
    }elsif($ACTIVE_LIST eq $file) {
	open(BAK, ">> $ACTIVE_LIST.bak") || (&Logging("$!"), return $NULL);
	print BAK "-----Backup on $Now-----\n";
	open(NEW, ">  $ACTIVE_LIST.tmp") || (&Logging("$!"), return $NULL);
	open(FILE,"<  $ACTIVE_LIST") || (&Logging("$!"), return $NULL);
    }else {
	&Logging("Cannot match $file in ChangeMemberList");
	return $NULL;
    }

    while(<FILE>) {
	print BAK $_;
	chop;
	next if (/^$/o);
	next if (/^[ \t]+$/o);

	# get $addr for ^#[ \t]+$addr$. if ^#, skip process except for 'off' 
	local($addr) = '';
	if(/^\s*(\S+)\s*.*/o)   { $addr = $1;}
	print STDERR "address = $addr\n" if($debug);
	if(/^\#\s*(\S+)\s*.*/o) { $addr = $1;}
	print STDERR "address = $addr\n" if($debug);
	if(! &StripFieldAndMatchCheck($addr, $Address)) {
	    print NEW "$_\n"; next;
	} 

	# if matched, get $addr including mx or comments
	if(/^\s*(.*)/o)   { $addr = $1;}
	if(/^\#\s*(.*)/o) { $addr = $1;}

	# not use "last" for the possibility the address is written double. 
	# may not be effecient.
	if($cmd eq 'on')  { print NEW "$addr\n"; $Status = 'done'; next;}
	if($cmd eq 'bye') { print NEW "\#\#BYE $addr\n"; $Status = 'done'; next;}
	if($cmd eq 'off') { print NEW "\#\t$addr\n"; $Status = 'done'; next;}
    } # end of while loop

    close BAK, NEW, FILE;
    if($file eq $MEMBER_LIST) {
	rename("$MEMBER_LIST.tmp", "$MEMBER_LIST");
    }elsif($file eq $ACTIVE_LIST) {
	rename("$ACTIVE_LIST.tmp", "$ACTIVE_LIST");
    }else {
	&Logging("Cannot rename for $file in ChangeMemberList");
	return $NULL '';
    }
    return $Status;
}
    
# require the exact matching of given addresses
sub StripFieldAndMatchCheck
{
    local($_, $From_address) = @_;
    /^[ \t]*(\S+)[ \t]*.*/o && ($_ = $1);
    return 'ok' if("$_" eq "$From_address");
    return $NULL;
}

# New mget routine  e.g. 
# mget2 *, ? and 1?, in addition like a
# mget2 1-100,101,110-1000
sub mget2 
{
    local($sharp, $_, $which, $SLEEPING) = @_;
    $SLEEPING = 300 if(! $SLEEPING);
    local($matched)  = local($USE_MGET2) = 0;
    $filelist = "";
    @filelist = ();

    # global 
    $MAXFILE_ON_SHELL = 1000;

    # check of regular expressions type, where mget or mget2? 
    if($which =~ /\.\.\//o){ &Logging("Insecure matching:$which"); return 0;}
    if($which =~ /^[\d\-\,]+$/){ $USE_MGET2 = 1;}
    local(@which)    = split(/\,/, $which, 9999);

    if($USE_MGET2) {		# if type mget2
	foreach $which (@which) {
	    print STDERR  "MGET2 >$which\n" if($debug);
	    if($which =~ /(\d+)\-(\d+)/io) {
		print STDERR  "MGET2>>$which\n" if($debug);
		if(! &ExistCheck($1, $2, *filelist)) { 
		    &Logging("mget[ver.2] scan $1 ->$2 fails");
		}
	    }else {
		push(@filelist, $which);
	    }
	}
    }else {			# old type mget
	push(@filelist, <./spool/$which>);	
    }

    # if not matched, process stops.
    if(scalar(@filelist) > $MAXFILE_ON_SHELL) {
	&Logging("mget[ver.2]: Requested number of files are exceeded!");
	&Sendmail($to, "Sorry. the number of files given in your request\n\t\nexceed $MAXFILE_ON_SHELL\n");
	return 0;
    }

    # whether the requested files exist or not?
    # a filename "spool" is different in each case.
    if($USE_MGET2) {
	foreach $file (@filelist) {
	    if(-r "./spool/$file" && -w "./spool/$file")
	    { $filelist .= " ./spool/$file"; $matched++;}
	}# end of foreach loop
    } else {
	foreach $file (@filelist) {
	    if(-r "./spool/$file" && -w "./spool/$file")
		{ $filelist .= " $file"; $matched++;}
	}# end of foreach loop
    }

    # debug info
    print STDERR "MATCHED FILES>$filelist\n" if($debug);

    # not matched!
    if(0 == $matched) {	&Logging("mget[ver.2] no matched."); return 0;}

    # evaluation on the shell 
    open(BUFFER,"cd $DIR ;$TAR $filelist|$COMPRESS|$UUENCODE spool.tar.Z|");
    open(TMPFILE, "> $DIR/mget$$") || (&Logging("$!"), return);
    while(<BUFFER>) {
	print TMPFILE $_;
	$totallines++;# counting the total lines of the uuencoded;
    }
    close TMPFILE, BUFFER;

    local($MGET_COMMAND) = "$LIBDIR/split_and_sendmail.pl";
    $MGET_COMMAND .= " -I " . join(":",@INC);
    $MGET_COMMAND .= " -f $DIR/mget$$ -s \'mget[$which] $ML_FN\'";
    $MGET_COMMAND .= " -d $DIR -l $MGET_LOGFILE -t $SLEEPING -m $MAINTAINER $to";

    # Pay attention! COMMAND uses Insecure mode
    system "/bin/sh", '-c', "$MGET_COMMAND &";

    return 'ok';
}

#	&Logging($errorlog);
#	&Sendmail($to, "mget: $errorlog $ML_FN", $MailBody);


# if ok, return 1;
sub ExistCheck
{
    local($left, $right, *filelist) = @_;
    $CHECK_MAXFILE = 100;	# if requested files > 100, go!
    print STDERR "$left $right in ExistCheck\n" if($debug);

    # illegal
    if($left > $right) {
	$ERRLOG .= $errlog = "mget[ver.2]: illegal condition: $left > $right";
	&Logging($errlog);
	return 0;
    }

    # meaningless?
    if($left == $right) {
	push(@filelist, $left);
	return 1;
    }

    # O.K. Here we go!
    if($left < $right) {
	# for too large request e.g. 1-100000
	# This code may be not good but useful enough.
	if(($right - $left) > $CHECK_MAXFILE && 
	   (! -r "$SPOOL_DIR/$right")) {
	    do {
		$right  = int($right / 2);
		$med = int($right / 2);
		print STDERR "$left $right\n" if($debug);
	    }while(! -r "$SPOOL_DIR/$med");

	    if($left > $right) { return 0;}	# meaningless
	    $file = $right;

	    do { # for too large request e.g. 1-100000
		$right = $file;
		$file  = int(($right + $med) / 2);
		print STDERR "$left $right\n" if($debug);
	    }while(! -r "$SPOOL_DIR/$file");
	}

	if($left > $right) { return 0;}	# meaningless
	print STDERR  "scan: $left -> $right\n" if($debug);

	# store the existing files
	for($i = $left; $i < $right + 1; $i++) { push(@filelist, $i);}
	return 1;
    }

    return 0;
}

1;
