# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

&FTPMAIL if ($LOAD_LIBRARY eq 'libftpmail.pl') || (!$MASTER_FML);

sub FTPMAIL
{
    require 'libutils.pl';

    ##### Preliminary settings #####
    # Subject preformat
    $FTPMAIL_SUBJECT = "Ftpmail";
    
    # the length of one mail < 3000 lines.
    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 1000;
    
    # default sleeping time between mails to send
    $SLEEPTIME 	= $SLEEPTIME || 30;
    
    # Most Important Variable; We cannot permit the access upper this dir.
    $CURRENT_DIR = $TOPDIR = $TOPDIR ? $TOPDIR : $DIR;
    chdir $TOPDIR || do {
	&Log("Can't chdir to $TOPDIR");
	&Warn("Can't chdir to $TOPDIR");
    };

    # Help file for ftpmail
    $FTPMAIL_HELP = "$TOPDIR/help";

    # From_address and Original_From_address are arbitrary.
    local($to) = $Reply_to ? $Reply_to : $From_address;

    # Process Table
    $0 = "--PSEUDO FTPMAIL COMPATIBLE Mode in <$FML $LOCKFILE>";

    # Local variables
    local(@dir_stack) = ('.');

  GivenCommands: foreach (split(/\n/, $MailBody, 999)) {
      next GivenCommands if (/^$/o); # skip null line

      if (! /^#/o) {
	 $_cf{'return'} .= "\n>>> $_\nCommand Syntax Error\n";
	 $_cf{'return', 'withhelp'} = 1;
	 &Logging("Command Syntax Error");
	 next GivenCommands;
     }

      s/^#(\S+)(.*)/# $1 $2/ if $RPG_ML_FORM_FLAG;
      @Fld = split(/[ \t\n]+/, $_, 999);
      $_cf{'return'} .= "\n>>> $_\n";
      $_ = $Fld[1];
      $0 = "--PSEUDO FTPMAIL COMAPTIBLE Mode processing $_: $FML $LOCKFILE>";
      print STDERR "Now command is >$_<\n" if ($debug);

      # not implemented
      if (/^ftp$/io || /^connect$/io) { 
	  $_cf{'return'} .= "Sorry. ftp or connect is not implemented\n";	  
	  next GivenCommands;
      }

      # end of requests
      if (/^quit$/io || /^exit$/io) { 
	  $_cf{'return'} .= "exit of current process\n";
	  last GivenCommands;
      }

      if (/^ls$/io || /^ls-lR$/io) { 
	  local($s) = "$FTPMAIL_SUBJECT ";
	  if (-f "$TOPDIR/ls-lR.gz") {
	      &Log("ls-lR.gz");
	      $f = "ls-lR.gz";
	      $s .= "[ls-lR.gz]";
	  }
	  elsif (-f "$TOPDIR/ls-lR.Z") {
	      &Log("ls-lR.Z");
	      $f = "ls-lR.Z";
	      $s .= "[ls-lR.Z]";
	  }
	  else {
	      &Log("FAIL $TOPDIR/ls-lR.gz or .Z");
	      $_cf{'return'} .= "Fail to Send Back ls-lR.gz or .Z\n";
	      next GivenCommands;
	  }

	  &SendBack($TOPDIR, $f, $s, $SLEEPTIME, $to);
	  $_cf{'return'} .= "Send Back ls-lR\n";
	  next GivenCommands;
      }

      # change the current directory
      if (/^cd$/io || /^chdir$/io) { 
	  $LOCAL_DIR = $Fld[2];
	  &Log("Try chdir $LOCAL_DIR in ".join("/", @dir_stack));

	  if (&dir_stack(*dir_stack, $LOCAL_DIR)) {
	      $LOCAL_DIR = join("/", @dir_stack);
	      $CURRENT_DIR = $TOPDIR . "/". $LOCAL_DIR;
	      print STDERR "CURRENT DIR = $CURRENT_DIR\n";
	  }
	  else {
	      &Logging("Cd: Insecure matching: $CURRENT_DIR");
	      $_cf{'return'} .= "Cd: Insecure directory changes\n";
	      last GivenCommands;
	  }

	  chdir $CURRENT_DIR || do { 
	      &Log("Can't chdir to $CURRENT_DIR");
	      $_cf{'return'} .= "cannot chdir /". $LOCAL_DIR. "\n";
	      last GivenCommands;
	  };

	  $_cf{'return'} .= "current directory is /". $LOCAL_DIR. "\n";
	  &Logging("chdir ". $LOCAL_DIR);
	  next GivenCommands;
      }

      # help for usage of commands
      if (/^help$/io) {		# help or HELP
	  &SendFile($to, "Help $ML_FN", "$TOPDIR/help");
	  &Logging("FTPMAIL Help");
	  $_cf{'return'} .= "Sent back [help] file to ". $to ."\n";
	  next GivenCommands;
      }
      
      # return address change
      if (/^mail$/io || /^reply\-to$/) {		# help or HELP
	  $to = $Fld[2];
	  $_cf{'return'} .= "Return address change to ". $to ."\n";
	  &Logging("RECIPIENT CHANGE: ". $From_address ."-> ". $to);
	  next GivenCommands;
      }
      
      # get one article from the spool, then return it
      if (/^get$/io || /^send$/io || /^getfile$/io) {
	  local($f) = local($file) = $Fld[2];
	  local($s) = "$FTPMAIL_SUBJECT ";
	  &Log("Get $f in $LOCAL_DIR");

	  if (&InSecureP($f)) {
	      &Logging("Get: Insecure matching: $file");
	      $_cf{'return'} .= "Get: Insecure Variable, exit\n";
	      last GivenCommands;
	  }

	  -T "$CURRENT_DIR/$file" && ($_cf{'SendBack', 'plaintext'} = 1);

	  &SendBack($CURRENT_DIR, $f, "$s[$f]", $SLEEPTIME, $to);
	  &Log("Send back $LOCAL_DIR/$f");
	  $_cf{'return'} .= "Try Send back [$f] in $LOCAL_DIR to $to\n";

	  next GivenCommands;
      }

      # Unknown!
      &Log("Unknown Commands $_");
      $_cf{'return'} .= "Unknown Commands $_\n";
  }# end of while loop;

    $_cf{'return'} .= "\nPseudo Ftpmail Mode Ends.\n";

    # return "ERROR LIST"
    if ($_cf{'return'}) {
	if ($_cf{'return', 'withhelp'}) {
	    $_cf{'return'} .= "\n\n\tHELP FILE\n\n".&ReadFile($FTPMAIL_HELP);
	}

	&Sendmail($to, "fml FTPMAIL Status report $ML_FN", $_cf{'return'});
    }

    undef $_cf{'return'};
    chdir $DIR || &Log("Can't chdir to $DIR");
}

# return 0 is danger.
sub  dir_stack 
{
    local(*dir_stack, $LOCAL_DIR) = @_;

    print STDERR "dir_stack $LOCAL_DIR\n" if $debug;    
    print STDERR "Stack: ".join("/",@dir_stack)."\n" if $debug;
    
    if ($LOCAL_DIR =~ /\.\w/o || $LOCAL_DIR =~ /\`/o){ 
	&Log("LOCAL_DIR $`($&)$'");
	return 0;
    }
    
    foreach(split(/\//, $LOCAL_DIR, 9999)) {
	if ($_ eq '..') {
	    pop @dir_stack;
	}
	elsif ($_ =~ /\.\S/) {	# paranoia?
	    &Log("Parts of LOCAL_DIR $`($&)$'");
	    return 0;
	}
	else {
	    push(@dir_stack, $_);
	}
	
	print STDERR "Stack: ".join("/",@dir_stack)."\n"  if $debug;
    }
    
    return 1 if length(@dir_stack) > 0;
}

sub SendBack
{
    local($dir, $f, $SUBJECT, $SLEEPTIME, $to) = @_;
    local($tmpf)    = "$TMP_DIR/ftpmail$$";
    local($tmpfile) = "$DIR/$TMP_DIR/ftpmail$$";

    if ($_cf{'SendBack', 'plaintext'}) {
	&system("cd $dir; $CP $f $tmpfile");
    }
    else {
	&system("cd $dir; $UUENCODE $f $f > $tmpfile");
    }

    local($lines)   = &WC($tmpfile);
    local($TOTAL)   = int($lines/$MAIL_LENGTH_LIMIT + 1);

    if (($TOTAL > 1) && 0 == &SplitFiles($tmpfile, $lines, $TOTAL)){
	&Log("Cannot split $returnfile");
	return 0;
    }
    elsif (1 == $TOTAL) {	# tricky
	rename($tmpfile, "$tmpfile.1"); 
    }

    &SendingBackOrderly($tmpf, $TOTAL, $SUBJECT, $SLEEPTIME, $to);
    unlink "$DIR/$TMP_DIR/ftpmail$$" unless $debug;
    undef $_cf{'SendBack', 'plaintext'};
}

# may be a DUPLICATED SUBROLUTINE
if (! defined(&InSecureP)) {
    sub InSecureP
    {
	local($ID) = @_;
	if ($ID =~ /..\//o || $ID =~ /\`/o){ 
	    &Logging("Insecure matching: $ID  -> $`($&)$'");
	    &Sendmail($MAINTAINER, "Insecure $ID from $From_address. $ML_FN");
	    return 1;
	}
    }
}

if (! defined(&ReadFile)) {
sub ReadFile
{
    local($f) = @_;
    local($s);

    open(f, $f) || do { 
	&Log("Cannot open $f"); 
	return "";
    };
    while(<f>) { $s .= $_;}
    close(f);

    $s;
}
}

1;
