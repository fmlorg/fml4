# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;

##################################################################
##### Ftp for Local Directory #####
local($FtpEntry, %FtpEntry, %FtpEntrySubject);
local($CurrentDir, $TopDir, $LocalDir, $Mode);

sub Ftp
{
    local(*e, $body) = @_; # the second argv for the further extension
    local(@Fld);
    local(@FtpDirStack) = ('.');

    require 'libfop.pl';
    
    ### variables
    $ps        = "pseudo ftp (local)";# Process Table
    $sleeptime = $SLEEPTIME || 30;
    $body      = $body      || $e{'Body'};

    # Most Important Variable; 
    # We cannot permit the access upper this dir.
    if ($FTP_DIR) {
	$CurrentDir = $TopDir = $FTP_DIR;
    }
    else {
	&Mesg(*e, 'ERROR: $FTP_DIR is not defined', 'ftp.not_configure');
	&Log("ERROR: \$FTP_DIR not defined, STOP!");
	return;
    }    

    # Set Process Table
    $0 = "$FML: $ps <$LOCKFILE>";

    ### ATTACH TopDir 
    chdir $TopDir || do {
	&Log("Can't chdir to $TopDir");
	&Warn("Can't chdir to $TopDir");
	return;
    };

    ### GO! 
    foreach (split(/\n/, $body)) {
      next if (/^\s*$/o); # skip null line

      &Mesg(*e, "\n>>> $_");

      # XXX: "# command" is internal represention
      /^\#/o || ($_ = "# $_");
      s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      @Fld = split(/\s+/, $_, 999);
      $_   = $Fld[1];
      $0   = "$FML: $ps processing[$_] <$LOCKFILE>";

      print STDERR "Now local Ftp request >$_<\n" if $debug;

      # not implemented
      if (/^(ftp|connect)$/io) { 
	  &Mesg(*e, "$1 is not implemented", 'not_implemented', $1);
	  next;
      }

      # end of requests
      if (/^(quit|exit)$/io) { 
	  &Mesg(*e, "the current process ends", 'ftp.exit');
	  last;
      }

      # ls-lR
      if (/^(ls|ls-lR)$/io) { 
	  local($ok, $f);

	LS: for $f ("$TopDir/ls-lR.gz", "$TopDir/ls-lR.Z", "$TopDir/ls-lR") {
	    next LS unless -f $f;
	    $ok++;
	    &Log("ls-lR [$f]");
	}
	  
	  if (! $ok) {
	      &Mesg(*e, "ERROR: cannot find ls-lR(|.gz|.Z)", 
		    'no_such_file', "ls-lR(|.gz|.Z)");
	      &Log("ERROR: cannot find ls-lR(|.gz|.Z)");
	      &Log("Ftp(local): please create ls-lR.gz when use ls-lR");
	      next;
	  }

	  &FtpSetFtpEntry('.', $f, $Mode);
	  &Mesg(*e, "try send back ls-lR", 'ftp.sendback', 'ls-lR');
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
	      &Mesg(*e, "cd: Insecure directory changes", 'ftp.cd.insecure');
	      last;
	  }

	  chdir $CurrentDir || do { 
	      &Log("Can't chdir to $CurrentDir");
	      &Mesg(*e, "\tcannot chdir /$LocalDir", 'ftp.cannot_chdir');
	      last;
	  };

	  &Mesg(*e, "\tcurrent directory is /$LocalDir.");
	  &Log("chdir $LocalDir");
	  next;
      }

      # help for usage of commands
      if (/^help$/io) {		# help or HELP
	  &SendFile($Envelope{'Addr2Reply:'}, "Ftp(Local) help $ML_FN", 
		    $FTP_HELP_FILE || "$TopDir/help");
	  &Log("Ftp Help");
	  &Mesg(*e, "try sendback help file", 'ftp.sendback', 'help');
	  next;
      }
      
      # help for usage of commands
      if (/^(force|mode)$/io) {		# help or HELP
	  $Mode = $Fld[2];
	  &Log("Ftp Mode -> $Mode");
	  local($s) = &DocModeLookup("#3$Mode");
	  &Mesg(*e, "set mode to $Mode", 'ftp.set.mode', $Mode);
	  next;
      }
      
      # return address change
      if (/^(mail|reply\-to)$/) {	# help or HELP
	  local($to) = $Envelope{'Addr2Reply:'} = $Fld[2];
	  &Mesg(*e, "return address = $to", 
		'ftp.set.return_addr', $to);
	  &Log("ftp: recipient changed $From_address -> $to");
	  next;
      }
      
      # get one article from the spool, then return it
      if (/^(get|send|getfile)$/io) {
	  local($f) = $Fld[2];
	  local($mode); # the default is defined in &FtpSetFtpEntry;

	  foreach (@Fld) {
	      /^(\d+)$/o && ($SLEEPTIME = $1, next);
	      $mode = $Mode;
	  }

	  local($s)    = &DocModeLookup("#3$mode");
	  &Log("Get $f in $LocalDir");

	  if (! &SecureP($f)) {
	      &Log("Get: Insecure matching: $f");
	      &Mesg(*e, 
		"trap special charactors, so process stops for security reason",
		'filter.insecure_p.stop');
	      last;
	  }

	  &FtpSetFtpEntry($LocalDir, $f, $mode);
	  &Mesg(*e, "\ttry sednback $f in $LocalDir", 'ftp.sendback', $f);
	  # &Mesg(*e, "\tthe file is set-up with mode == [$mode]");
	  next;
      }

      # Unknown!
      &Log("ftp: no such command [$_]");
      &Mesg(*e, $NULL, 'no_such_command', $_);
  }# end of while loop;

    # Return Original $DIR
    chdir $DIR || &Log("Can't chdir to $DIR");

    &Mesg(*e, "pseudo ftp server mode ends", 'ftp.exit');

    if ($FML_EXIT_HOOK !~ /\&FtpSendingEntry/) {
	$FML_EXIT_HOOK .= ' &FtpSendingEntry;';
    }
}


sub FtpSetFtpEntry
{
    local($dir, $file, $mode) = @_;
    local($total, $target, $name);
    local($ftpdir) = $FTP_DIR;
    
    # relative for all modes availability
    local($tmpf)   = "$TMP_DIR/Ftp$$:$FtpEntry"; 
    
    printf STDERR "FtpEntry %-15s => %s\n", $dir, $file if $debug;

    # Global variables
    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 1000;
    $FtpEntry++; # for temporary file identification

    $mode || ($mode = -T "$dir/$file" ? 'mp' : 'uu');

    chdir $DIR || &Log("Can't chdir to $DIR");

    $ftpdir =~ s#$DIR/##g;
    $target = "$ftpdir/$dir/$file";
    $name   = "$dir/$file";
    $name   =~ s#^/##;
    $total  = &DraftGenerate($tmpf, $mode, $name, $target);

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
	&Log("ERROR: LocalDir $`($&)$'");
	return 0;
    }
    
    foreach(split(/\//, $LocalDir)) {
	if ($_ eq '..') {
	    pop @FtpDirStack;
	}
	elsif ($_ =~ /(\.\S)/) {	# paranoia?
	    &Log("ERROR: LocalDir $`($&)$'");
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
	$dir = $dir || '/';
	$body .= "\nreply-to $to\nopen $host\ncd $dir\nget $file\nquit\n";
	$d{'Body'} = $body;

	# SMTP since Ftpmail Server checks "-admion syntax".
	push(@to, $FTPMAIL_SERVER);

	# Mail to Ftpmail Server
	print STDERR $d{'Hdr'}, "\n", $d{'Body'}, "\n";
	&Smtp(*d, *to);

	# Log
	$body =~ s/\n/\n   /g;
	&Mesg(*e, $NULL, 'ftpmail.submitted', $FTPMAIL_SERVER);
	&Mesg(*e, "Your requqst [ftp://$host/$file] is ");
	&Mesg(*e, "Submitted to Ftpmail Server [$FTPMAIL_SERVER]");
	&Mesg(*e, "as\n\n$body\n");
	&Mesg(*e, "Please wait a little for the reply");
	&Mesg(*e, "*** ATTENTION! ***");
	&Mesg(*e, "If you cancel your request");
	&Mesg(*e, "send the email to $FTPMAIL_SERVER");
	&Mesg(*e, "              NOT $MAIL_LIST");
    }
    else {
	&Mesg(*Envelope, $NULL, 'ftpmail.not_supported');
	&Mesg(*Envelope, 
	      "*** Sorry, Relay to Ftpmail Server is NOT SUPPORTED ***");
	&Log("Please set \$FTPMAIL_SERVER to relay when using ftpmail");
    }
}


1;
