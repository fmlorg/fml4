# Library of fml.pl 
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

&Command if $LOAD_LIBRARY eq 'libfml.pl';

# fml command routine
# return NONE but ,if exist, mail back $_cf{'return'} to the user
sub Command
{
    $0 = "--Command Mode in <$FML $LOCKFILE>";

    # How severely check address
    $_cf{'addr-check'} = $ADDR_CHECK_MAX  = ($ADDR_CHECK_MAX || 3);

    # From_address and Original_From_address are arbitrary.
    local($to) = $_cf{'reply-to'} = $Reply_to ? $Reply_to : $From_address;
    local($addr);
    return if 1 == &LoopBackWarn($to);

    # Set candidates
    local(@candidate) = split(/\n/, $MailBody, 999);
    $_cf{'mget', 'count'} = scalar(grep(/mget/i, @Fld));

    # Backward compatibility
    $COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;

  GivenCommands: foreach (@candidate) {
      next GivenCommands if /^$/o; # skip null line
      if (! /^#/o) {
	 next GivenCommands unless $USE_WARNING;
	 &Logging("HELP");
	 &SendFile($to, "Command Syntax Error $ML_FN", $HELP_FILE);
	 last GivenCommands;
     }

      # syntax check, and set the array of cmd..
      s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      @Fld = split(/\s+/, $_, 999);
      s/^#\s*//, $org_str = $_;
      $_ = $Fld[1];

      # info
      $0 = "--Command Mode processing $_: $FML $LOCKFILE>";
      &Debug("Now command is >$_<") if $debug;

      ########## SWITCH ##########
      if (/^end$/io || /^quit$/io || /^exit$/oi) { # for Convenience
	  last GivenCommands;	  
      }

      # MODE switch(users not require to know this option.)
      if (/^mode$/io) {
	  local($str) = $Fld[2];
	  $str =~ tr/A-Z/a-z/;

	  if ($str eq 'debug') {
	      $_cf{'debug'} = $debug = 1;
	  }

	  $_cf{'return'} .= "\n>>> $org_str\n";
	  $_cf{'return'} .= "set mode $str on.\n";

	  next GivenCommands;
      }

      # send a guide back to the user
      if (/guide/io) {
	  &Logging("Guide");
	  &SendFile($to, "Guide $ML_FN", $GUIDE_FILE);
	  next GivenCommands;
      }

      # help for usage of commands
      if (/help/io) {		# help or HELP
	  &Logging("Help");
	  &SendFile($to, "Help $ML_FN", $HELP_FILE);
	  next GivenCommands;
      }
      
      # return the objective of Mailing List
      if (/objective/io) {
	  &Logging("Objective");
	  &SendFile($to, "Objective $ML_FN", $OBJECTIVE_FILE);
	  next GivenCommands;
      }

      # return a  member file of Mailing List
      if (/member/io) {
	  &Logging("Members");
	  &SendFile($to, "Members $ML_FN", $MEMBER_LIST);
	  next GivenCommands;
      }
      
      # return a active file of Mailing List
      if (/active/io) {
	  &Logging("Actives");
	  &SendFile($to, "Actives $ML_FN", $ACTIVE_LIST);
	  next GivenCommands;
      }
      
      # return a summary of Mailing List
      if (/^summary$/io) {
	  &Logging("Summary");
	  &SendFile($to, "Summary $ML_FN", $SUMMARY_FILE);
	  next GivenCommands;
      }

      # return a summary of Mailing List
      if (/^stat$/io || /^status$/io) {
	  &Logging("Status for $Fld[2]");
	  require 'libutils.pl';
	  $_cf{'return'} .= "\n>>> status for $Fld[2].\n";
	  $_cf{'return'} .= &MemberStatus($Fld[2] ? $Fld[2] : $to)."\n";
	  next GivenCommands;
      }

      # Search KEYWORD in summary file
      if (/^search$/io) {
	  local($s);
	  open(F, $SUMMARY_FILE) || ($s = "Fail");
	  while (<F>) {
	      /$Fld[2]/ && ($s .= $_);
	  }
	  close(F);

	  &Logging("Search key=$Fld[2]");
	  $_cf{'return'} .= "\n>>> Search key=$Fld[2]\n$s\n";
	  next GivenCommands;
      }

      # send a message to $MAINTAINER
      if (/^msg$/io) {
	  &Logging("MSG");
	  &Sendmail($MAINTAINER, "Msg ($From_address), $Subject", $MailBody);
	  # MAIL_BODY has been closed in sendmail()
	  last GivenCommands;
      }

      # a little modulation for useful conversion between commands.
      s/getfile/get/io if $COMMAND_SYNTAX_EXTENSION; # "#getfile 1" is O.K.

      # enable us to use "mget 200.tar.gz" = "get 200.tar.gz"
      (/^get$/io) && ($Fld[2] =~ /^\d+.*z$/o) && ($_ = 'mget');

      # if illegal "get 1-10" is given, get -> mget? required or not?
      # if (/^get$/io) { if ($Fld[2] =~ /^[\d\-\,]+$/o){ $_ = 'mget';}}

      # get one article from the spool, then return it
      if (/^get$/io) {
	  local($ID) = $Fld[2]; 

	  if (&InSecureP($ID)){ 
	      $_cf{'return'} .= "\n>>> $org_str\nget $Fld[2] failed.\n";
	      last GivenCommands;
	  }

	  local($mail_file, $ar) = &ExistP($ID);# return is "spool/ID" form;
	  &Debug("GET: local($mail_file, $ar)") if $debug;

	  if ($mail_file) { 
	      $cat{"spool/$ID"} = 1;
	      if ($ar eq 'TarZXF') {  
		  require 'libutils.pl';
		  &Sendmail($to, "Get $ID $ML_FN", 
			    &TarZXF("$DIR/$mail_file", 1, *cat));
	      }
	      else {
		  &SendFile($to, "Get $ID $ML_FN", 
			    "$DIR/$mail_file", 
			    $_cf{'libfml', 'binary'});
	      }

	      &Logging("Get $ID, Success");
	  } 
	  else {				# or null $ID
	      $_cf{'return'} .= "\n>>> $org_str\nArticle $ID is not found.\n";
	      &Logging("Get $ID, Fail");
	  }

	  next GivenCommands;
      }

      # matomete get articles from the spool, then return them
      # mget is an old version. 
      # new version should be used as mget ver.2(mget[ver.2])
      # matomete get articles from the spool, then return them
      if (/^mget$/io || /^mget2$/io) {
	  $0 = "--Command Mode call mget[@Fld]: $FML $LOCKFILE>";

	  require 'SendFile.pl';
	  local($Status) = &mget2(@Fld);

	  $0 = "--Command Mode mget[@Fld] status=$Status: $FML $LOCKFILE>";

	  $Status || ($Status = "Fail");
	  &Logging("mget:[$$] $Fld[2] $Fld[3] : $Status");
	  $_cf{'return'} .= "\n>>> $org_str\nmget $Fld[2] $Fld[3] failed.\n"
	      if ($Status eq 'Fail');

	  next GivenCommands;
      }

      ### REPORT ###
      $_cf{'return'} .= "\n>>> $org_str\n";
      undef $_cf{'retry'};	# reset;

      # Set the address to operate e.g. for exact matching
      if (/^addr$/io) { 
	  $addr = $Fld[2];
	  if (&AddressMatching($addr, $From_address)) {
	      $ADDR_CHECK_MAX = 10;	# exact match(trick)
	      $_cf{'return'} .= "Try exact-match for $addr.\n";
	      &Logging("Exact addr=$addr");
	  }
	  else {
	      $_cf{'return'} .= "Forbidden to use $addr,\n";
	      $_cf{'return'} .= "since $addr is too different from $From_address.\n";
	      &Logging("Exact addr=$addr fail");
	  }
	  next GivenCommands;
      }

      # Off: temporarily.
      # On : Return to Mailng List
      # Matome : Matome Okuri ver.2 Control Interface
      # Skip : can post but not be delivered
      # NOSkip : inverse above
      if (/^off$/io || /^on$/io || /^matome$/io || /^skip$/io || /^noskip$/io) {
	  y/a-z/A-Z/; 
	  $cmd = $_;
	  local($c);
	  # $addr = $Fld[2] unless $addr;
	  local($addr) = $addr ? $addr : $From_address;

	  # Matome Okuri preroutine
	  if (($Fld[2] =~ /^(\d+)$/)||
	     ($Fld[2] =~ /^(\d+u)$/oi)||
	     ($Fld[2] =~ /^(\d+i)$/oi)||
	     ($Fld[2] =~ /^(\d+)h$/oi)) { 
	      $c = $MATOME = $1;
	      $c = " -> Synchronous Delivery" if 0 == $MATOME;
	      &Logging("Try matome $MATOME")  if $MATOME;
	  # }
	  # elsif ($c = $Fld[2]) {
	  #    # Set or unset Address to SKIP, OFF, ON ...
	  #    $addr = $c;
	  }
	  elsif (/^matome$/io) {
	      &Log("$cmd: $Fld[2] inappropriate, do nothing");
	      $_cf{'return'} .= "$cmd: $Fld[2] inappropriate.\nDO NOTHING!\n";
	      next GivenCommands;
	  }

	  # LOOP CHECK
	  if (&LoopBackWarning($addr)) {
	      &Log("$cmd: LOOPBACk ERROR, exit");
	      next GivenCommands;		  
	  }

	  # Retry when require more severe checking of address
	  do {
	      undef $_cf{'retry'};	# reset;
	      if (&ChangeMemberList($cmd, $addr, $ACTIVE_LIST)) {
		  &Logging("$cmd [$addr] $c");
		  $_cf{'return'} .= "$cmd [$addr] $c accepted.\n";
	      }
	      else {
		  if ($_cf{'retry'}) {
		      &Logging("$cmd [$addr] $c failed, try again");
		      $_cf{'return'} .= "\n";
		  }
		  else {
		      &Logging("$cmd [$addr] $c failed");
		      $_cf{'return'} .= "$cmd [$addr] $c failed. check and try again!\n";
		  }
	      }
	  }while ($_cf{'retry'});

	  next GivenCommands;
      }

      # Bye - Good Bye Eternally
      if (/^bye$/io) {
	  # $addr = $Fld[2] unless $addr;
	  local($addr) = $addr ? $addr : $From_address;

	  # if ($c = $Fld[2]) {
	  #    # Set or unset Address to SKIP, OFF, ON ...
	  #    $addr = $c;
	  # }

	  # LOOP CHECK
	  if (&LoopBackWarning($addr)) {
	      &Log("$cmd: LOOPBACk ERROR, exit");
	      next GivenCommands;		  
	  }

	  # Retry when require more severe checking of address
	  do {
	      undef $_cf{'retry'};	# reset;
	      if (! &ChangeMemberList('BYE', $addr, $ACTIVE_LIST)) {
		  if ($_cf{'retry'}) {
		      &Logging("BYE ACTIVE [$addr] $c failed, try again");
		      $_cf{'return'} .= "\n";
		  }
		  else {
		      &Logging("BYE ACTIVE [$addr] failed[$ACTIVE_LIST]");
		      $_cf{'return'} .= "BYE ACTIVE [$addr] failed.\ncheck and try again!\n";
		      last GivenCommands;
		  }
	      }
	  }while ($_cf{'retry'});

	  if ($ML_MEMBER_CHECK){
	      $ADDR_CHECK_MAX = $_cf{'addr-check'};
	      undef $_cf{'retry'};	# reset;
	      do {
		  if (! &ChangeMemberList('BYE', $addr, $MEMBER_LIST)) {
		      if ($_cf{'retry'}) {
			  &Logging("BYE MEMBER [$addr] $c failed, try again");
			  $_cf{'return'} .= "\n";
		      }
		      else {
			  &Logging("BYE MEMBER [$addr] failed[$MEMBER_LIST]");
			  $_cf{'return'} .= "BYE MEMBER [$addr] failed. check and try again!\n";
			  last GivenCommands;
		      }
		  }
	      }while ($_cf{'retry'});
	  }

	  &Logging("BYE [$addr]");
	  $_cf{'return'} .= "Bye [$addr] accepted. So Long!\n";
	  last GivenCommands;
      }

      # Special hook e.g. "# list",should be used as a ML's specific hooks
      defined($COMMAND_HOOK) && &eval($COMMAND_HOOK, 'Command hook');
      
      # these below are not implemented, but implemented in hml 1.6
      # codes only for notifying the alart to the user
      if (/^iam$/io || /^whois$/io || /^who$/io) {
	  &Log($_);
	  if ($USE_WHOIS) {
	      require 'libutils.pl';
	      $_cf{'return'} .= &Whois(@Fld)."\n";
	  } 
	  else {
	      $_cf{'return'} .= "Command $_ is not implemented.\n";
	  }
	  next GivenCommands;
      }

      # if undefined commands, notify the user about it and abort.
      &Logging("Unknown Cmd $_");
      $_cf{'return'} .= "Unknown Command: $_\n";

      last GivenCommands;

  } # the end of while loop

    # return "ERROR LIST"
    if ($_cf{'return'}) {
	&Sendmail($to, "fml Command Status report $ML_FN", $_cf{'return'});
    }
}


# For convenience
sub FML_HEADER 
{
$FML_HEADER = q$#.FML HEADER
# NEW FORMAT FOR FURTHER EXTENTION
# e.g. fukachan@phys r=relayserver m=3u s=skip 
# r= relayserver
# m= matomeokuri parameter is time and option
# s= skip. can post from this address but not delivered here.
#
# the same obsolete format is compatible with new format and as follows:
# e.g. fukachan@phys relayserver matome 3u
#.endFML HEADER
$;
}


# ChangeMemberList(cmd, address, file)
# Comment out or not of $file 
# Codes may be not insecure, I wonder.
# If multiply matched for the given address, do Log [$log = "$addr"; $log_c++;]
sub ChangeMemberList
{
    local($cmd, $Address, $file) = @_;
    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
	= localtime(time);
    local($Date) = sprintf("%02d%02d", ++$mon, $mday);
    local($Status, $log, $log_c);
    &Debug("&ChangeMemberList($cmd, $Address, $file)") if $debug;
    
    if ($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file) {
	open(BAK, ">> $file.bak") || (&Logging("$!"), return $NULL);
	select(BAK); $| = 1; select(stdout);
	print BAK "----- Backup on $Now -----\n";

	open(NEW, ">  $file.tmp") || (&Logging("$!"), return $NULL);
	select(NEW); $| = 1; select(stdout);

	open(FILE,"<  $file") || (&Logging("$!"), return $NULL);
    }
    else {
	&Logging("Cannot match $file in ChangeMemberList");
	return $NULL;
    }

    print NEW &FML_HEADER;

    in: while (<FILE>) {
	chop;

	# Backward Compatibility.	tricky "^\s".
	next in if /^#\.FML/o .. /^\#\.endFML/o;
	if (! /^\#/o) {
	    s/\smatome\s+(\S+)/ m=$1 /i;
	    s/\sskip\s*/ s=skip /i;
	    local($rcpt, $opt) = split(/\s+/, $_, 2);
	    $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";
	    $_ = "$rcpt $opt";
	    s/\s+$/ /g;
	}

	print BAK "$_\n";
	next in if /^$/o;
	next in if /^\s+$/o;

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	local($addr) = '';
	if (/^\s*(\S+)\s*.*/o)   { $addr = $1;}
	if (/^\#\s*(\S+)\s*.*/o) { $addr = $1;}

	if (! &AddressMatch($addr, $Address)) {
	    print NEW "$_\n"; 
	    next in;
	} 

	# if matched, get $addr including mx or comments
	if (/^\s*(.*)/o)   { $addr = $1;}
	if (/^\#\s*(.*)/o) { $addr = $1;}

	# not use "last" for the possibility the address is written double. 
	# may not be effecient.
	# Return to the ML
	if ($cmd eq 'ON')  { 
	    print NEW "$addr\n"; 
	    $log .= "ON $addr; "; $log_c++;
	    $Status = 'done'; 
	    next in;
	}

	# Good Bye to the ML eternally
	if ($cmd eq 'BYE') { 
	    print NEW "\#\#BYE $addr\n"; 
	    $Status = 'done'; 
	    $log .= "BYE $addr; "; $log_c++;
	    next in;
	}

	# Good Bye to the ML temporarily
	if ($cmd eq 'OFF') { 
	    print NEW "\#\t$addr\n"; 
	    $Status = 'done'; 
	    $log .= "OFF $addr; "; $log_c++;
	    next in;
	}

	# Address to SKIP
	if ($cmd eq 'SKIP') { 
	    print NEW "$addr\ts=skip\n"; 
	    $Status = 'done'; 
	    $log .= "SKIP $addr; "; $log_c++;
	    next in;
	}

	# Address to SKIP
	if ($cmd eq 'NOSKIP') { 
	    $addr =~ s/\ss=(\S+)//oig; # remover s= syntax
	    print NEW "$addr\n"; 
	    $Status = 'done'; 
	    $log .= "NOSKIP $addr; "; $log_c++;
	    next in;
	}

	# Matome Okuri Control
	if ($cmd eq 'MATOME') {
	    local($fl) = 1 if $addr =~ /\smatome/oi || $addr =~ /\sm=/;
	    $addr =~ s/^(.*)matome/$1/oig; # backward compatibility
	    $addr =~ s/\sm=(\S+)//oig; # remover m= syntax

	    if ($fl) {		# change status of matomeokuri
		print NEW "$addr\tm=$MATOME\n" if $MATOME;  
		print NEW "$addr\n"            if 0 == $MATOME;
		$addr =~ s/\s*//g;
		&Rehash($addr)                 if 0 == $MATOME;
	    } 
	    else {		# new comer
		print NEW "$addr\tm=".($MATOME ? $MATOME : 3)."\n";

		# Must be not 0 or non-zero-parameter
		if (! $MATOME) {
		    local($s) = "Hmm.. no given parameter. use default[m=3]";
		    &Log($s);
		    $_cf{'return'} .= "$s\n";
		    $_cf{'return'} .= 
			"So your request is accept but modified to m=3\n";
		}

		&Log("ReConfiguring $Address in MSendRC");
		&ConfigMSendRC($Address);
	    }
	    $Status = 'done';
	    $log .= "MATOME $addr; "; $log_c++;
	}
    } # end of while loop

    # CORRECTION; If not registerd, add the Address to SKIP
    if ($cmd eq 'SKIP' && $Status ne 'done') { 
	print NEW "$addr\ts=skip\n"; 
	$Status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close BAK; 
    close NEW; 
    close FILE;

    # ADMIN MODE permit multiplly matching
    $log_c = 1 if $_cf{'mode', 'com-admin'};

    # protection for multipy matching, logs if $log_c > 1(multiple match);
    if ($log_c > 1) {
	&Log("$cmd: Do nothing muliply matched..");
	$log =~ s/; /\n/g;
	$_cf{'return'} .= "Multiply Matched? So DO NOTHING!\n";
	$_cf{'return'} .= $log;

	if (! $_cf{'retry'}) {
	    $_cf{'return'} .= "Retry to check your adderss severely\n";
	    $_cf{'retry'} = 1 if $ADDR_CHECK_MAX < 10; # against infinite loop
	    $ADDR_CHECK_MAX++;
	}
	else {
	    $_cf{'return'} .= "Hmm... yet ambiguous..So please use \"# addr\" command\n";
	    $_cf{'return'} .= "\ne.g. use \"# addr ADDR\"\n";
	    $_cf{'return'} .= "\tto exact-match ADDR(= EXACT FULL ADDRESS here)\n";
	    undef $_cf{'retry'};
	}
	return "";
    }
    else {
	# MATCH ONLY ONCE OR NOT-MATCH
	if ($_cf{'retry'}) {	# must be a lot of a.b.c..? 
	    undef $_cf{'retry'};
	    return "";
	}

	# above code must be not used, so go here...
	if (($file eq $MEMBER_LIST) || ($file eq $ACTIVE_LIST)) {
	    if (&FileSizeCheck("$file.tmp", $file)) { 
		rename("$file.tmp", $file) || 
		    (&Log("fail to rename $file"), return "");
	    }
	    else {
		&Log("ChangeMemberList: ERROR of filesize"); 
		return "";
	    }
	}
	else {
	    &Log("ChangeMemberList:inappropriate to rename $file");
	    return "";
	}
    }# end of log_c;

    $Status;
}
    

# Send mails left in spool for "# matome 0".
sub Rehash
{
    local($adr) = @_;
    local($l, $r, $s);

    $r = &GetID;

    require 'SendFile.pl';
    require 'MSendv4.pl';
    $l = &GetDistributeList($adr);

    print STDERR "TRY $l $r\n";
    $s = "Rehash: Try send mails[$l - $r] left in spool";

    $_cf{'rehash'} = "$l-$r"; # for later use "# rehash" ???
    &Log($s);
    $_cf{'return'} .= "\n$s\n\n";

    if (&mget2('#', 'mget', "$l-$r", '10')) {
	&Log("Rehash: sending [$l-$r] configured");
    }
    else {
	&Log("Rehash: sending [$l-$r] Fail");
    }

    1;
}


# Exist a file or not, a binary or not, your file? read permitted?
# return filename or NULL
sub ExistP
{
    local($fp)      = @_;
    local($f)       = "spool/$fp";
    local($ar_unit) = $DEFAULT_ARCHIVE_UNIT ? $DEFAULT_ARCHIVE_UNIT : 100;

    $_cf{'libfml', 'binary'} = 0; # global binary or not variable on _(previous attached)

    # plain and 400 and your file. usually return here;
    stat($f);
    if (-T _ && -r _ && -o _ ) { return $f;}
    
    if (defined(@ARCHIVE_DIR)) {
	local($sp) = (int(($fp - 1)/$ar_unit) + 1) * $ar_unit;

	$_cf{'libfml', 'binary'} = 2;		# 2 is uuencode operation

	foreach $dir ("spool", @ARCHIVE_DIR) {
	    $f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";

	    stat($f);
	    if (-B _ && -r _ && -o _ ) { 
		return ($f, 'TarZXF');
	    }
	}# END FOREACH;
    }

    0;
}


# the syntax is insecure or not
# return 1 if insecure 
sub InSecureP
{
    local($ID) = @_;
    if ($ID =~ /..\//o || $ID =~ /\`/o){ 
	local($s)  = "INSECURE and ATTACKED WARNING";
	local($ss) = "Match: $ID  -> $`($&)$'";
	&Log($s, $ss);
	&Warn("Insecure $ID from $From_address. $ML_FN", "$s\n$ss");
	return 1;
    }

    0;
}


# Get ID from $SEQUENCE_FILE, and increment
# return ID(incremented already) or 0(if fail)
sub GetID
{
    local($ID);

    if (open(IDINC, $SEQUENCE_FILE)){
	$ID = <IDINC>; 
	chop $ID;
	$ID++; 
	close(IDINC);
    } 
    else { 
	&Logging("Cannot open $SEQUENCE_FILE");
	$ID = 0;
    }

    $ID;
}


# for matomeokuri control
# added the infomation to MSEND_RC
# return NONE
sub ConfigMSendRC
{
    local($Address) = @_;
    local($ID) = &GetID;

    if (open(TMP, ">> $MSEND_RC") ) {
	select(TMP); $| = 1; select(stdout);
	print TMP "$Address\t$ID\n";
	close TMP;
    } 
    else { 
	&Logging("Cannot open $MSEND_RC");
    }
}


# new, old ... must be (new >= old);
# but 'false is true ' is possible when a file changes..;-)
# 1; always (now)
sub FileSizeCheck
{    
    local($a, $b) = @_;

    $a = (stat($a))[7];
    $b = (stat($b))[7];

    &Debug("FILESIZE CHK: ($a >= $b) ? 1 : 0;") if $debug;
    ($a >= $b) ? 1 : 0;	# = is trick(meaningless commands)

    1;
}


# Status of actives(members) files
# return the string of the status
sub MemberStatus
{
    local($who) = @_;
    local($s);

    open(ACTIVE_LIST) || 
	(&Log("cannot open $ACTIVE_LIST when $ID:$!"), return "No Match");

    in: while (<ACTIVE_LIST>) {
	chop;

	$sharp = 0;
	/^\#\s*(.*)/ && do { $_ = $1; $sharp = 1;};

	# Backward Compatibility.	
	s/\smatome\s+(\S+)/ m=$1 /i;
	s/\sskip\s*/ s=skip /i;
	local($rcpt, $opt) = split(/\s+/, $_, 2);
	$opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

	if($rcpt =~ /$who/) {
	    $s .= "$rcpt:\n";
	    $s .= "\tpresent not participate in. (OFF)\n" if $sharp;

	    $_ = $opt;
	    /\sr=(\S+)/     && ($s .= "\tRelay server is $1\n"); 
	    /\ss=/          && ($s .= 
				"\tNOT delivered here, but can post to $ML_FN\n");
	    /\sm=/          && ($s .= "\tMatome Okuri, every other ");
	    /\sm=(\d+)\s/o  && ($s .= "$1 hour as GZIPed\n");
	    /\sm=(\d+)i\s/o && ($s .= "$1 hour as LHA+ISH\n");
	    /\sm=(\d+)u\s/o && ($s .= "$1 hour as PLAIN TEXT\n");
	    /\s*/           && ($s .= "\tdeliverd immediately\n");

	    $s .= "\n\n";
	}
    }

    close(ACTIVE_LIST);

    $s ? $s : "$who is NOT matched\n";
}


# Return 1 if Loopback is found in the given address
# return 1 if loopback, 0 if not
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;

    foreach ($MAIL_LIST, $CONTROL_ADDRESS, @Playing_to) {
	next if /^$/oi;		# for null control addresses
	if (&AddressMatching($to, $_)) {
	    &Log("LoopBack Warning: ", "[$From_address] or [$to]");
	    &Warn("Warning: $ML_FN", &WholeMail);
	    return 1;
	}
    }

    0;
}

1;
