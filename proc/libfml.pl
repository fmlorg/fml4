# Library of fml.pl 
# Copyright (C) 1993 fukachan@phys.titech.ac.jp
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

&Command;

sub Command
{
    $0 = "--Command Mode in <$FML $LOCKFILE>";

    # From_address and Original_From_address are arbitrary.
    local($to) = $Reply_to ? $Reply_to : $From_address;

  GivenCommands: foreach (split(/\n/, $MailBody, 999)) {
      next GivenCommands if(/^$/o); # skip null line
      if(! /^#/o) {
	  &Logging("HELP sent to $From_address");
	  &SendFile($to, "Command Syntax Error $ML_FN", $HELP_FILE);
	  last GivenCommands;
      }

      s/^#(\S+)(.*)/# $1 $2/ if $RPG_ML_FORM_FLAG;
      @Fld = split(/\s+/, $_, 999);
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
	  $ID = $Fld[2]; local($mail_file);
	  if(&InSecureP($ID)){ 
	      &Sendmail($to, "get $Fld[2] failed. $ML_FN");
	      last GivenCommands;
	  }

	  if($mail_file = &ExistP($ID)) { # return is "spool/ID" form.
	      &SendFile($to, "Get $ID $ML_FN", "$DIR/$mail_file", $BINARY_P);
	      &Logging("Get $ID, Success ($From_address)");
	  } else {				# or null $ID
	      &Sendmail($to, "Article $ID is not found. $ML_FN");
	      &Logging("Get $ID, Fail ($From_address)");
	  }
	  next GivenCommands;
      }

      # matomete get articles from the spool, then return them
      # mget is an old version. 
      # new version should be used as mget ver.2(mget[ver.2])
      # matomete get articles from the spool, then return them
      if(/^mget$/io || /^mget2$/io) {
	  $Status = ( &mget2(@Fld) ? "Success" : "Fail");
	  &Logging("mget[ver.2] $Fld[2] $Fld[3] from <$to>, $Status");
	  &Sendmail($to, "mget $Fld[2] $Fld[3] failed. $ML_FN")
	      if($Status eq 'Fail');
	  next GivenCommands;
      }

      # Off: temporarily.
      # On : Return to Mailng List
      # Matome Okuri ver.2 Control Interface
      if(/^off$/io || /^on$/io || /^matome$/io) {
	  y/a-z/A-Z/; 
	  $cmd = $_;

	  # Matome Okuri preroutine
	  if(($Fld[2] =~ /^(\d+)$/)||($Fld[2] =~ /^(\d+u)$/oi)||
	     ($Fld[2] =~ /^(\d+)h$/oi)) { 
	      $MATOME = $1;
	  }
	  &Logging("Try matome $MATOME") if $MATOME;

	  # Go!
	  if(&ChangeMemberList($cmd, $From_address, $ACTIVE_LIST)) {
	      &Logging("$cmd ($From_address)");
	      &Sendmail($to, "$cmd accepted. $ML_FN");
	  }else {
	      &Logging("$cmd failed ($From_address)");
	      &Sendmail($to, "$cmd failed. check and try again! $ML_FN");
	  }
	  next GivenCommands;
      }

      # Bye - Good Bye Eternally
      if(/^bye$/io) {
	  if(! &ChangeMemberList('BYE', $From_address, $ACTIVE_LIST)) {
	      &Logging("BYE failed[$ACTIVE_LIST] ($From_address)");
	      &Sendmail($to, "BYE failed. check and try again! $ML_FN");
	      last GivenCommands;
	  }

	  if($ML_MEMBER_CHECK && 
	     (! &ChangeMemberList('BYE', $From_address, $MEMBER_LIST))) {
	      &Logging("BYE failed[$MEMBER_LIST] ($From_address)");
	      &Sendmail($to, "BYE failed. check and try again! $ML_FN");
	      last GivenCommands;
	  }

	  &Logging("BYE ($From_address)");
	  &Sendmail($to, "Bye accepted. So Long! $ML_FN");
	  last GivenCommands;
      }

      # Special hook e.g. "# list"
      # should be used as a ML's specific hooks
      if(defined($COMMAND_HOOK)) {
	  eval $COMMAND_HOOK;
	  &Logging("COMMAND HOOK:$@") if $@;
      }
      
      # these below are not implemented, but implemented in hml 1.6
      # codes only for notifying the alart to the user
      if(/^iam$/io || /^whois$/io || /^who$/io) {
	  &Logging("$_, ($From_address)");
	  if(defined($USE_WHOIS)) {
	      require 'libutils.pl';
	      &Whois(@Fld);
	  } else {
	      &SendFile($to, "Command $_ is not implemented $ML_FN", "$HELP_FILE");
	  }
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

    if($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file) {
	open(BAK, ">> $file.bak") || (&Logging("$!"), return $NULL);
	print BAK "-----Backup on $Now-----\n";
	open(NEW, ">  $file.tmp") || (&Logging("$!"), return $NULL);
	open(FILE,"<  $file") || (&Logging("$!"), return $NULL);
    }else {
	&Logging("Cannot match $file in ChangeMemberList");
	return $NULL;
    }

    while(<FILE>) {
	print BAK $_;
	chop;
	next if (/^$/o);
	next if (/^\s+$/o);

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	local($addr) = '';
	if(/^\s*(\S+)\s*.*/o)   { $addr = $1;}
	if(/^\#\s*(\S+)\s*.*/o) { $addr = $1;}

	if(! &StripFieldAndMatchCheck($addr, $Address)) {
	    print NEW "$_\n"; 
	    next;
	} 

	# if matched, get $addr including mx or comments
	if(/^\s*(.*)/o)   { $addr = $1;}
	if(/^\#\s*(.*)/o) { $addr = $1;}

	# not use "last" for the possibility the address is written double. 
	# may not be effecient.
	# Return to the ML
	if($cmd eq 'ON')  { 
	    print NEW "$addr\n"; 
	    $Status = 'done'; 
	    next;
	}

	# Good Bye to the ML eternally
	if($cmd eq 'BYE') { 
	    print NEW "\#\#BYE $addr\n"; 
	    $Status = 'done'; 
	    next;
	}

	# Good Bye to the ML temporarily
	if($cmd eq 'OFF') { 
	    print NEW "\#\t$addr\n"; 
	    $Status = 'done'; 
	    next;
	}

	# Matome Okuri Control
	if($cmd eq 'MATOME') {
	    if($addr =~ /^(.*)matome/oi) {
		print STDERR "$1\tmatome\t$MATOME\n";
		print NEW "$1\tmatome\t$MATOME\n" if $MATOME;  
		print NEW "$1\n" if(0 == $MATOME);
	    } else {
		print NEW "$1\tmatome\t", $MATOME ? $MATOME : 3, "\n";
		&ConfigMSendRC($Address);
	    }
	    $Status = 'done';	next;	    
	}
    } # end of while loop
    
    close BAK, NEW, FILE;

    if(($file eq $MEMBER_LIST) || ($file eq $ACTIVE_LIST)) {
	rename("$file.tmp", $file);
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
    /^\s*(\S+)\s*.*/o && ($_ = $1);

    # at least to lower characters. 94/07/29
    tr/A-Z/a-z/;
    $From_address =~ tr/A-Z/a-z/;

    return 'ok' if("$_" eq "$From_address");
    return $NULL;
}

# New mget routine  e.g. 
# mget2 *, ? and 1?, in addition like a
# mget2 1-100,101,110-1000
sub mget2 
{
    local($matched, $PACK_P, $FileCandidate, @FileCandidate);
    local($sharp, $_, $which, $SLEEPING, $UNPACK) = @_;
    $PACK_P   = 1   unless($SLEEPING =~ /^unpack$/io);
    $PACK_P   = 0   if($UNPACK);
    $SLEEPING = 300 unless($SLEEPING =~ /^\d+$/o);
    $MAXFILE_ON_SHELL = 1000;      # global 

    # for security
    &InSecureP($which) && return 0;

    # check of regular expressions type, which of mget or mget2? 
    # USE_MGET2 is a global for convenience(1.2.1++)
    if($which =~ /^[\d\-\,]+$/){ $USE_MGET2 = 1;}

    if($USE_MGET2) {		# if type mget2
	foreach (split(/\,/, $which, 9999)) {
	    if(/(\d+)\-(\d+)/io) {
		&ExistCheck($1, $2, *FileCandidate) || 
		    &Logging("mget[ver.2] scan $1 ->$2 fails");
	    }else { push(@FileCandidate, 
			 ($_ > $STORED_BOUNDARY) ? "spool/$_" : &ExistP($_));
		}
	}# foreach ends;
    }else {			# old type mget. Not use StoredSpool
	push(@FileCandidate, <./spool/$which>);	
    }

    # if not matched, process stops.
    if(scalar(@FileCandidate) > $MAXFILE_ON_SHELL) {
	&Logging("mget[ver.2]: Requested number of files are exceeded!");
	&Sendmail($to, "Sorry. your request exceeds $MAXFILE_ON_SHELL\n");
	return 0;
    }

    return 'ok' if 
	&GenerateConfigAndExec($which, $SLEEPING, $PACK_P, @FileCandidate);
}

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
	push(@filelist, "spool/$left");
	return 1;
    }

    # O.K. Here we go!
    if($left < $right) {
	# for too large request e.g. 1-100000
	# This code may be not good but useful enough.
	if(($right - $left) > $CHECK_MAXFILE && (! &ExistP($right)) ) {
	    do {
		$right  = int($right / 2);
		$med = int($right / 2);
		print STDERR "$left $right\n" if($debug);
	    }while(! &ExistP($med));

	    if($left > $right) { return 0;}	# meaningless
	    $file = $right;

	    do { # for too large request e.g. 1-100000
		$right = $file;
		$file  = int(($right + $med) / 2);
		print STDERR "$left $right\n" if($debug);
	    }while(! &ExistP($file));
	}

	if($left > $right) { return 0;}	# meaningless
	print STDERR  "scan: $left -> $right\n" if($debug);

	# store the candidates
	for($i = $left; $i < $right + 1; $i++) { push(@filelist, "spool/$i");}
	if(defined(@StoredSpool_DIR) && $left < ($STORED_BOUNDARY + 1)) { 
	    push(@filelist, &Storedfilelist($left, $right));	    
	}
	return 1;
    }

    return 0;
}

sub Storedfilelist
{
    local($left, $right) = @_;
    local($i) = 0;
    local(@tmp);

    while($i < ($right + 1)) {
	local($space_op) = (int($i/100) + 1) * 100;
	foreach $dir ("spool", @StoredSpool_DIR) {
	    $filename = "$dir/$space_op.gz";
	    if(-B $filename && -r _ && -o _ ) { push(@tmp, $filename);}
	}
	$i += 100;
    }
    return @tmp;
}

# Exist a file or not, a binary or not, your file? read permitted?
sub ExistP
{
    local($file) = @_;		# must be a number
    local($filename) = "spool/$file";

    $BINARY_P = 0; # global binary or not variable on _(previous attached)

    # plain and 400 and your file;
    # usually return here
    if(-T $filename && -r _ && -o _ ) {	return $filename;}

    if(-B "$filename.gz" && -r _ && -o _ ) {# may be .gz?(binary);
	$BINARY_P = 1;		# 1 is gunziped and send back
	return "$filename.gz";
    } 

    if(defined(@StoredSpool_DIR)) {
	local($space_op) = (int($file/100) + 1) * 100;
	$BINARY_P = 2;		# 2 is uuencode operation
	foreach $dir ("spool", @StoredSpool_DIR) {
	    $filename = "$dir/$space_op.gz";
	    if(-B $filename && -r _ && -o _ ) { return $filename;}
	}
    }

    return 0;
}

sub InSecureP
{
    local($ID) = @_;
    if($ID =~ /..\//o || $ID =~ /\`/o){ 
	&Logging("Insecure matching: $ID  -> $`($&)$'");
	&Sendmail($MAINTAINER, "Insecure $ID from $From_address. $ML_FN");
	return 1;
    }
}

sub ConfigMSendRC
{
    local($Address) = @_;
    local($ID);

    if(open(IDINC, "< $SEQUENCE_FILE")){
	$ID = <IDINC>; $ID++; close(IDINC);
    } else { &Logging("Cannot open $SEQUENCE_FILE");}

    if(open(TMP, ">> $MSEND_RC") ) {
	print TMP "$Address\t$ID\n";
	close TMP;
    } else { &Logging("Cannot open $MSEND_RC");}
}

# Generate Msend controling file and exec the SendFile with the config file.
sub GenerateConfigAndExec
{
    local($which, $SLEEPING, $PACK_P, @FileCandidate) = @_;
    local(@filelist, $PREV);

    # whether the requested files exist or not?
    # if with unpack option, select only plain text files. 
    foreach (sort @FileCandidate) { # require 400, your own
	next if($PREV eq $_);	# uniq emulation
	($PACK_P && -r $_ && -o _ ) && push(@filelist, $_) && $matched++;
	((! $PACK_P) && -r $_ && -o _ && -T _) 
	    && push(@filelist, $_) && $matched++;
	((! $PACK_P) && -r $_ && -o _ && -B _) 
	    && push(@filelistB, $_) && $matched++;
	$PREV = $_;
    }
    
    # Check and Log: not matched!
    print STDERR "MATCHED FILES>",join(" ",@filelist),"\n" if($debug);
    if(0 == $matched) {	&Logging("mget[ver.2] no matched files."); return 0;}

    # The Called Command
    local($MGET_CONFIG)  = "$DIR/mget$$.config ";
    local($MGET_COMMAND) = "$LIBDIR/SendFile.pl $MGET_CONFIG $DIR/config.ph";

    # Make a Config file
    open(CONFIG, "> $MGET_CONFIG") || (&Logging("$!"), return 0);
    print CONFIG 
	"CONFIG:$MGET_CONFIG\n", 
	"PACK:$PACK_P\n",
	"INCLUDE:". join("\nINCLUDE:", @INC).   "\n",
	"FILE:".    join("\nFILE:", @filelist). "\n",
	"FILEB:".   join("\nFILEB:", @filelistB). "\n",
	"DIR:$DIR\n",  
	"PID:$$\n",  
	"SUBJECT:mget v2 [$which]\n",
	"LOGFILE:$MGET_LOGFILE\n",  
	"SLEEP:$SLEEPING\n",
	"MAINTAINER:$MAINTAINER\n", 
	"TO:$to\n";
    print CONFIG "DEBUG:\n" if $debug;
    close(CONFIG);

    # Pay attention! COMMAND uses Insecure mode
    system "sh", '-c', "$MGET_COMMAND &" || do {
	&Logging("System:$?:$!"); return 0;};

    return 'ok';
}

1;
