# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

##################################################################
##### Ftp for Local Directory #####

local(*FtpEntry, *FtpEntrySubject, *Ftp);
local($CurrentDir, $TopDir, $LocalDir, $Mode);

sub Ftp
{
    local(*e, $body) = @_;
    local(*Fld, $withhelp);
    local(@FtpDirStack) = ('.');

    require 'libutils.pl';
    
    ### variables
    $ps        = "--PSEUDO FML FTP FOR LOCALDIR";# Process Table
    $sleeptime = $SLEEPTIME || 30;
    $body      = $body      || $e{'Body'};

    # Most Important Variable; 
    # We cannot permit the access upper this dir.
    if ($FTP_DIR) {
	$CurrentDir = $TopDir = $FTP_DIR;
    }
    else {
	&LogWEnv("The spool of Ftp is NOT SET, STOP!", *e);
	&Log("If use ftp, please set \$FTP_DIR");
	return;
    }    

    # Set Process Table
    $0 = "$ps in <$FML $LOCKFILE>";

    ### ATTACH TopDir 
    chdir $TopDir || do {
	&Log("Can't chdir to $TopDir");
	&Warn("Can't chdir to $TopDir");
	return;
    };

    ### GO! 
    foreach (split(/\n/, $body)) {
      next if (/^\s*$/o); # skip null line

      $e{'message'} .= "\n>>> $_\n";

      if (! /^\#/o) {
	  &LogWEnv("Command Syntax Error [$_]", *e);
	  $withhelp = 1;
	  next;
      }

      s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      @Fld = split(/\s+/, $_, 999);
      $_ = $Fld[1];
      $0 = "$ps :processing[$_] $FML $LOCKFILE>";
      print STDERR "Now command is >$_<\n" if $debug;

      # not implemented
      if (/^(ftp|connect)$/io) { 
	  $e{'message'} .= "\tSorry. $1 is not implemented.\n";
	  next;
      }

      # end of requests
      if (/^(quit|exit)$/io) { 
	  $e{'message'} .= "\tExit of current process\n";
	  last;
      }

      # ls-lR
      if (/^(ls|ls-lR)$/io) { 
	  local($ok, $f);

	LS: for $f ("$TopDir/ls-lR.gz", "$TopDir/ls-lR.Z", "$TopDir/ls-lR") {
	    next LS unless -f $_;

	    $ok++;
	    &Log("ls-lR");
	    $f = $_;
	}
	  
	  if (! $ok) {
	      &LogWEnv("Cannot find ls-lR(|.gz|.Z)", *e);
	      next;
	  }

	  &FtpSetFtpEntry('.', $f, $Mode);
	  $e{'message'} .= "\tTry Send Back ls-lR\n";
	  next;
      }

      # change the current directory
      if (/^(cd|chdir)$/io) { 
	  $LocalDir = $Fld[2];
	  &Log("Try chdir $LocalDir in ".join("/", @FtpDirStack));

	  if (&FtpDirStack(*FtpDirStack, $LocalDir)) {
	      # reset $LocalDir;
	      $LocalDir   = join("/", @FtpDirStack); 
	      $CurrentDir = $TopDir ."/". $LocalDir;

	      &Debug("\$CurrentDir\t=> $CurrentDir") if $debug;
	  }
	  else {
	      &Log("Cd: Insecure matching: $CurrentDir");
	      $e{'message'} .= "\tCd: Insecure directory changes\n";
	      last;
	  }

	  chdir $CurrentDir || do { 
	      &Log("Can't chdir to $CurrentDir");
	      $e{'message'} .= "\tCannot chdir /$LocalDir\n";
	      last;
	  };

	  $e{'message'} .= "\tCurrent directory is /$LocalDir\n";
	  &Log("chdir $LocalDir");
	  next;
      }

      # help for usage of commands
      if (/^help$/io) {		# help or HELP
	  &FtpSetFtpEntry('.', $f, $Mode);
	  &Log("Ftp Help");
	  $e{'message'} .= "\tTry Sent back help file\n";
	  next;
      }
      
      # help for usage of commands
      if (/^(force|mode)$/io) {		# help or HELP
	  $Mode = $Fld[2];
	  &Log("Ftp Mode -> $Mode");
	  local($s) = &DocModeLookup("#3$Mode");
	  $e{'message'} .= "\tFile Encoding Mode set to $Mode[$s]\n";
	  $e{'message'} .= "\texcept for explicit command 'get file mode'\n";
	  next;
      }
      
      # return address change
      if (/^(mail|reply\-to)$/) {	# help or HELP
	  local($to) = $Envelope{'Addr2Reply:'} = $Fld[2];
	  $e{'message'} .= "\tReturn address change $From_address -> $to\n";
	  &Log("RECIPIENT CHANGE: $From_address -> $to");
	  next;
      }
      
      # get one article from the spool, then return it
      if (/^(get|send|getfile)$/io) {
	  local($f)    = $Fld[2];
	  local($mode) = $Fld[3] || $Mode;
	  local($s)    = &DocModeLookup("#3$mode");
	  &Log("Get $f in $LocalDir");

	  if (&InSecureP($f)) {
	      &Log("Get: Insecure matching: $file");
	      $e{'message'} .= "\tGet: Insecure Variable, STOP!\n";
	      last;
	  }

	  &FtpSetFtpEntry($LocalDir, $f, $mode);
	  $e{'message'} .= "\tTry Send back [$f] in [$LocalDir]\n";
	  $e{'message'} .= "\tthe file is set-up with mode == [$s]\n";
	  next;
      }

      # Unknown!
      &Log("Ftp: Unknown Commands [$_]");
      $e{'message'} .= "\tFtp: Unknown Commands [$_]\n";
  }# end of while loop;

    # Return Original $DIR
    chdir $DIR || &Log("Can't chdir to $DIR");

    $e{'message'} .= "\n\t*** Pseudo Ftpmail Mode Ends. ***\n";

    $FML_EXIT_HOOK .= ' &FtpSendingEntry;';
}


sub FtpSetFtpEntry
{
    local($dir, $file, $mode) = @_;
    local($total);

    printf STDERR "FtpEntry %-15s => %s\n", $dir, $file if $debug;

    # Global variables
    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 1000;
    $FtpEntry++; # for temporary file identification

    local($tmpf) = "$TMP_DIR/Ftp$$:$FtpEntry";

    if ($mode) {
	;
    }
    else {
	$mode = -T "$dir/$file" ? 'uf' : 'uu';
    }

    chdir $DIR        || &Log("Can't chdir to $DIR");

    $total = &DraftGenerate($tmpf, $mode, "$dir/$file", "$dir/$file");
    $FtpEntrySubject{"$FtpEntry:$total"} = "Ftp(local) $dir/$file";
    $FtpEntry{"$FtpEntry:$total"}        = $tmpf; 

    chdir $CurrentDir || &Log("Can't chdir to $DIR");
}


# return 0 is danger.
sub FtpDirStack
{
    local(*FtpDirStack, $LocalDir) = @_;

    if ($debug) {
	print STDERR "FtpDirStack $LocalDir\n";
	print STDERR "Stack: ".join("/",@FtpDirStack)."\n";
    }
    
    if ($LocalDir =~ /\.\w/o || $LocalDir =~ /\`/o){ 
	&Log("LocalDir $`($&)$'");
	return 0;
    }
    
    foreach(split(/\//, $LocalDir)) {
	if ($_ eq '..') {
	    pop @FtpDirStack;
	}
	elsif ($_ =~ /\.\S/) {	# paranoia?
	    &Log("Parts of LocalDir $`($&)$'");
	    return 0;
	}
	else {
	    push(@FtpDirStack, $_);
	}
	
	print STDERR "Stack: ".join("/",@FtpDirStack)."\n"  if $debug;
    }
    
    return 1 if length(@FtpDirStack) > 0;
}


sub FtpSendingEntry
{
    local($entry, $tmpf, $t, $subject, $sleep, $to);

    # variables
    $to    = $Envelope{'Addr2Reply:'};
    $sleep = $SLEEPTIME;

    while (($entry, $tmpf) = each %FtpEntry) {
	$t       = (split(/:/, $entry))[1];
	$subject = $FtpEntrySubject{$entry};

	&SendingBackInOrder($tmpf, $t, $subject, $sleep, $to);
    }
}


##################################################################
##### Ftpmail #####
#
# Given PARAMETER($body):
# (*Envelope, ftp.phys.titech.ac.jp, pub/net/fml-current/fml-current.tar.gz)
sub Ftpmail
{
    local($body, $dir, $file, *to, *d);
    local(*e, $host, $file) = @_;

    $to   = $Envelope{'Addr2Reply:'};
    $file =~ s/(\S+)\/(\S+)/$dir = $1, $file = $2/e;
    $file =~ s#/##g;

    &Log("Ftpmail ftp://$host/$dir/$file");

    if ($FTPMAIL_SERVER) {
	# draft <- envelope
	%d = %e;

	# Header
	$d{'Hdr'}  = "From: $to\nSubject: Ftpmail Request\nReply-To: $to\n";

	# Body
	$body .= "\nreply-to $to\nopen $host\ncd $dir\nget $file\nquit\n";
	$d{'Body'} = $body;

	# SMTP since Ftpmail Server checks "-admion syntax".
	push(@to, "RCPT TO: $FTPMAIL_SERVER");

	# Mail to Ftpmail Server
	print STDERR "$d{'Hdr'}\n$d{'Body'}\n";
	&Smtp(*d, *to);

	# Log
	$body =~ s/\n/\n   /g;
	$e{'message'} .= "Your requqst [ftp://$host/$file] is \n";
	$e{'message'} .= "Submitted to Ftpmail Server [$FTPMAIL_SERVER]\n";
	$e{'message'} .= "as\n\n$body\n\n";
	$e{'message'} .= "Please wait a little for the reply\n";
	$e{'message'} .= "*** ATTENTION! ***\n";
	$e{'message'} .= "If you cancel your request\n";
	$e{'message'} .= "send the email to $FTPMAIL_SERVER\n";
	$e{'message'} .= "              NOT $MAIL_LIST\n";
    }
    else {
	$Envelope{'message'} .= 
	    "*** Sorry, Relay to Ftpmail Server is NOT SUPPORTED ***\n";
	&Log("Please set \$FTPMAIL_SERVER to relay when using ftpmail");
    }
}


1;
