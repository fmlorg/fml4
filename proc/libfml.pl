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
    $_cf{'mget', 'count'} = scalar(grep(/mget/i, @candidate));

    # Backward compatibility
    $COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;

    # Command Line Options
    $COMMAND_ONLY_SERVER = 1 if $_cf{'opt', 'c'};

  GivenCommands: foreach (@candidate) {
      next GivenCommands if /^\s*$/o; # skip null line

      # e.g. *-ctl server, not require '# command' syntax
      $_ = "# $_" if $COMMAND_ONLY_SERVER && (!/^\#/o); 

      if (! /^#/o) {
	  next GivenCommands unless $USE_WARNING;

	  &Log("ERROR:Command Syntax without ^#");
	  $_cf{'return'} .= "Command Syntax Error not with ^#\n";

	  next GivenCommands;	# 'last' in old days 
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
      if (/^guide/io) {
	  &Logging("Guide");
	  &SendFile($to, "Guide $ML_FN", $GUIDE_FILE);
	  next GivenCommands;
      }

      # help for usage of commands
      if (/^help/io) {		# help or HELP
	  &Logging("Help");
	  &SendFile($to, "Help $ML_FN", $HELP_FILE);
	  next GivenCommands;
      }
      
      # return the objective of Mailing List
      if (/^objective/io) {
	  &Logging("Objective");
	  &SendFile($to, "Objective $ML_FN", $OBJECTIVE_FILE);
	  next GivenCommands;
      }

      # return a  member file of Mailing List
      if (/^member/io) {
	  &Logging("Members");
	  &SendFile($to, "Members $ML_FN", $MEMBER_LIST);
	  next GivenCommands;
      }
      
      # return a active file of Mailing List
      if (/^active/io) {
	  &Logging("Actives");
	  &SendFile($to, "Actives $ML_FN", $ACTIVE_LIST);
	  next GivenCommands;
      }
      
      # return a summary of Mailing List
      if (/^summary$/io) {
	  if ($Fld[2]) {
	      $_cf{'return'} .= "\n>>> Summary: Search KEY=$Fld[2]\n\n";
	      &SearchKeyInSummary($Fld[2], 'rs');
	      &Log("Restricted Summary [$Fld[2]]");
	  }
	  else {
	      &Log("Summary");
	      &SendFile($to, "Summary $ML_FN", $SUMMARY_FILE);
	  }
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
	  $_cf{'return'} .= "\n>>> Search Key=$Fld[2] in Summary file\n\n";
	  &SearchKeyInSummary($Fld[2], 's');
	  &Log("Search [$Fld[2]]");
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
      s/send/get/io;
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

	  local($mail_file, $ar) = &ExistP($ID);# return "$SPOOL_DIR/ID" form
	  &Debug("GET: local($mail_file, $ar)") if $debug;

	  if ($mail_file) { 
	      $cat{"$SPOOL_DIR/$ID"} = 1;
	      if ($ar eq 'TarZXF') {  
		  require 'libutils.pl';
		  &Sendmail($to, "Get $ID $ML_FN", 
			    &TarZXF("$DIR/$mail_file", 1, *cat));
	      }
	      else {
		  &SendFile($to, "Get $ID $ML_FN", 
			    "$DIR/$mail_file", 
			    $_cf{'libfml', 'binary'});
		  undef $_cf{'libfml', 'binary'}; # destructor
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
	  $0 = "--Command Mode call mget[\@Fld]: $FML $LOCKFILE>";

	  require 'SendFile.pl';
	  local($Status) = &mget2(@Fld);

	  $0 = "--Command Mode mget[\@Fld] status=$Status: $FML $LOCKFILE>";

	  $Status || do {
	      $Status = "Fail";
	      $_cf{'return'} .= "\n>>> $org_str\nmget $Fld[2] $Fld[3] failed.\n";
	  };

	  &Log("mget:[$$] $Fld[2] $Fld[3] : $Status");
	  next GivenCommands;
      }

      ### REPORT ###
      $_cf{'return'} .= "\n>>> $org_str\n";

      # Set the address to operate e.g. for exact matching
      if (/^addr$/io) { 
	  if (&AddressMatching($Fld[2], $From_address)) {
	      $addr = $Fld[2];
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
      if (/^off$/io    || 
	  /^on$/io     || 
	  /^matome$/io || 
	  /^skip$/io   || 
	  /^noskip$/io 
	  ) {
	  y/a-z/A-Z/; 
	  local($cmd) = $_;
	  local($c);
	  # $addr = $Fld[2] unless $addr;
	  local($addr) = $addr ? $addr : $From_address;

	  # Matome Okuri preroutine
	  print STDERR "WARN: $cmd $Fld[2]\n";
	  if ($cmd eq 'MATOME' && 
	      (($Fld[2] =~ /^(\d+)$/) || ($Fld[2] =~ /^(\d+[A-Za-z]+)$/oi))) {

	      # set key
	      $c = $MATOME = $1;

	      # Exception is synchronous delivery
	      if (0 == $MATOME) {
		  $c = " -> Synchronous Delivery";
	      }
	      # e.g. 6 , 6u , ...
	      else {
		  # KEY MARIEL;
		  # search this mode exists?
		  require 'libutils.pl';
		  local($d, $mode) = &ModeLookup($c);

		  if ((!$d) && (!$mode)) { 
		      &Logging("MATOME $c fails, not match");
		      $_cf{'return'} .= "$cmd: $Fld[2] parameter not match.\n";		  
		      $_cf{'return'} .= "DO NOTHING!\n";
		      next GivenCommands;
		  }
	      }
	      
	      &Log("O.K. Try matome $c");
	  # }# parameter=address
	  # elsif ($c = $Fld[2]) {
	  #    # Set or unset Address to SKIP, OFF, ON ...
	  #    $addr = $c;
	  }
	  elsif (/^matome$/io) {
	      &Log("$cmd: $Fld[2] inappropriate, do nothing");
	      $_cf{'return'} .= "$cmd: $Fld[2] parameter inappropriate.\n";
	      $_cf{'return'} .= "DO NOTHING!\n";
	      next GivenCommands;
	  }

	  # LOOP CHECK
	  if (&LoopBackWarn($addr)) {
	      &Log("$cmd: LOOPBACk ERROR, exit");
	      next GivenCommands;		  
	  }

	  if (&ChangeMemberList($cmd, $addr, $ACTIVE_LIST)) {
	      &Logging("$cmd [$addr] $c");
	      $_cf{'return'} .= "$cmd [$addr] $c accepted.\n";
	  }
	  else {
	      &Logging("$cmd [$addr] $c failed");
	      $_cf{'return'} .= "$cmd [$addr] $c failed.\n";
	  }

	  next GivenCommands;
      }

      # Bye - Good Bye Eternally
      if (/^bye$/io || /^unsubscribe$/io) {
	  local($cmd) = 'BYE';
	  # $addr = $Fld[2] unless $addr;
	  local($addr) = $addr ? $addr : $From_address;

	  # if ($c = $Fld[2]) {
	  #    # Set or unset Address to SKIP, OFF, ON ...
	  #    $addr = $c;
	  # }

	  # LOOP CHECK
	  if (&LoopBackWarn($addr)) {
	      &Log("$cmd: LOOPBACk ERROR, exit");
	      next GivenCommands;		  
	  }
	  
	  # Call recursively
	  local($r) = 0;
	  if ($ML_MEMBER_CHECK) {
	      $ADDR_CHECK_MAX = $_cf{'addr-check'};
	      &ChangeMemberList($cmd, $addr, $MEMBER_LIST) && $r++;
	      &Log("BYE MEMBER [$addr] $c O.K.")   if $r == 1 && $debug2;
	      &Log("BYE MEMBER [$addr] $c failed") if $r != 1;

	      $ADDR_CHECK_MAX = $_cf{'addr-check'};
	      &ChangeMemberList($cmd, $addr, $ACTIVE_LIST) && $r++;
	      &Log("BYE ACTIVE [$addr] $c O.K.")   if $r == 2 && $debug2;
	      &Log("BYE ACTIVE [$addr] $c failed") if $r != 2;
	  }
	  else {
	      $r++;
	      &ChangeMemberList($cmd, $addr, $ACTIVE_LIST) && $r++;
	      &Log("BYE ACTIVE [$addr] $c O.K.")   if $r == 2  && $debug2;
	      &Log("BYE ACTIVE [$addr] $c failed") if $r != 2;
	  }

	  # Status
	  if ($r == 2) {
	      &Log("$cmd [$addr] $c accepted");
	      $_cf{'return'} .= "$cmd [$addr] $c accepted.\n";
	  }
	  else {
	      &Log("$cmd [$addr] $c failed");
	      $_cf{'return'} .= "$cmd [$addr] $c failed.\n";
	  }

	  last GivenCommands;	# should be 'last' when BYE
      }

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

      # IF USED AS ONLY COMMAND SERVER, 
      if ($COMMAND_ONLY_SERVER) {
	  local($key) = $REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE;
	  if (/$key/) {
	      require 'libutils.pl';
	      &AutoRegist;
	      next GivenCommands;
	  }
      }

      # Special hook e.g. "# list",should be used as a ML's specific hooks
      if ($COMMAND_HOOK) {
	  &CheckCommandHook($_, @Fld) || last GivenCommands;
	  &eval($COMMAND_HOOK, 'Command hook');
      }

      # if undefined commands, notify the user about it and abort.
      &Logging("Unknown Cmd $_");
      $_cf{'return'} .= "Unknown Command: $_\n";
      $_cf{'return'} .= "Stop.\n";

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
# If multiply matched for the given address, do Log [$log = "$addr"; $log_c++;]
sub ChangeMemberList
{
    local($cmd, $Address, $file) = @_;
    &GetTime;
    local($Date) = sprintf("%02d%02d", ++$mon, $mday);
    local($Status, $log, $log_c, $r);
    &Debug("&ChangeMemberList($cmd, $Address, $file)") if $debug;
    
    if ($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file) {
	open(BAK, ">> $file.bak") || (&Logging($!), return $NULL);
	select(BAK); $| = 1; select(STDOUT);
	print BAK "----- Backup on $Now -----\n";

	open(NEW, ">  $file.tmp") || (&Logging($!), return $NULL);
	select(NEW); $| = 1; select(STDOUT);

	open(FILE,"<  $file") || (&Logging($!), return $NULL);
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
	next in if /^\s*$/o;

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	local($addr) = '';
	if (/^\s*(\S+)\s*.*/o)   { $addr = $1;}
	if (/^\#\s*(\S+)\s*.*/o) { $addr = $1;}

	if (! ($r = &AddressMatch($addr, $Address))) {
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
	    # Flag on for the next remover
	    local($org_addr) = $addr;
	    local($fl) = 1 if $addr =~ /\smatome/oi || $addr =~ /\sm=/;

	    # Remove the present configuration
	    $addr =~ s/^(.*)matome/$1/oig; # backward compatibility
	    $addr =~ s/\sm=(\S+)//oig; # remover m= syntax

	    if ($fl) {		# if modify
		# change status of matomeokuri
		if ($MATOME) {
		    print NEW "$addr\tm=$MATOME\n";
		}
		else {
		    print NEW "$addr\n";
		    $LOCAL_HACK_HOOK = "&Rehash(\"$org_addr\");";
		}
	    } 
	    else {		# new comer
		print NEW "$addr\tm=".($MATOME ? $MATOME : 3)."\n";

		# Must be not 0 or non-zero-parameter
		if (! $MATOME) {
		    local($s) = "Hmm.. no given parameter. use default[m=3]";
		    &Log($s);
		    $_cf{'return'} .= "$s\n";
		    $_cf{'return'} .= 
			"So your request is accepted but modified to m=3\n";
		}

		&Log("ReConfiguring $Address in MSendRC");
		&ConfigMSendRC($Address);
	    }
	    $Status = 'done';
	    $log .= "MATOME $addr; "; $log_c++;
	}
    } # end of while loop;

    # CORRECTION; If not registerd, add the Address to SKIP
    if ($cmd eq 'SKIP' && $Status ne 'done') { 
	print NEW "$addr\ts=skip\n"; 
	$Status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close BAK; 
    close NEW; 
    close FILE;

    # protection for multipy matching, logs if $log_c > 1(multiple match);
    # ADMIN MODE permit multiplly matching
    if ($log_c > 1 && $ADDR_CHECK_MAX < 10 && (!$_cf{'mode', 'com-admin'})) {
	&Log("$cmd: Do nothing muliply matched..");
	$log =~ s/; /\n/g;
	$_cf{'return'} .= "Multiply Matched?\n$log\n";
	$_cf{'return'} .= "Retry to check your adderss severely\n";
	$ADDR_CHECK_MAX++;

	# Recursive Call
	print STDERR "Call ChangeM...($cmd,..[$ADDR_CHECK_MAX]);\n" if $debug;
	return &ChangeMemberList($cmd, $Address, $file);
    }
    elsif ($ADDR_CHECK_MAX == 10) {
	&Log("MAXIMUM of ADDR_CHECK_MAX, stop");
    }
    else {
	if (($file eq $MEMBER_LIST) || ($file eq $ACTIVE_LIST)) {
	    if (rename("$file.tmp", $file)) {
		;
	    }
	    else {
		&Log("fail to rename $file");
		return $NULL;
	    }
	}
	else {	# FILE INAPPROPRIATE
	    &Log("ChangeMemberList:inappropriate to rename $file");
	    return $NULL;
	}
    }#;

    # Only once being called is "Required"
    $LOCAL_HACK_HOOK && &eval($LOCAL_HACK_HOOK, "ChangeMemberList localhack:");
    undef $LOCAL_HACK_HOOK;	# should be global for recursive calls.

    $_cf{'return'} .= "O.K.!\n" if $Status eq 'done';
    $Status;
}
    

# Send mails left in spool for "# matome 0".
sub Rehash
{
    local($adr) = @_;
    local($l, $r, $s, $d, $mode);
    ($adr, $mode) = split(/\s+/, $adr, 2);

    print STDERR "\n---Rehash local($adr, $mode)\n\n";

    require 'libutils.pl';
    require 'SendFile.pl';

    if ($mode =~ /m=(\S+)/) {
	($d, $mode) = &ModeLookup($1);
    }
    else {
	($d, $mode) = &ModeLookup('');
    }

    $r = &GetID;
    $l = &GetPrevID($adr);
    $s = "Rehash: Try send mails[$l - $r] left in spool";

    $_cf{'rehash'} = "$l-$r"; # for later use "# rehash" ???
    &Log($s);
    $_cf{'return'} .= "\n$s\n\n";

    if ($l <= $r && &mget2('#', 'mget', "$l-$r", '10', "$mode")) {
	&Log("Rehash: send [$l-$r] mode=$mode configured.");
    }
    else {
	&Log("Rehash: send [$l-$r] mode=$mode NOT done.");
    }
    
    1;
}


# Exist a file or not, a binary or not, your file? read permitted?
# return filename or NULL
sub ExistP
{
    local($fp)      = @_;
    local($f)       = "$SPOOL_DIR/$fp";
    local($ar_unit) = ($DEFAULT_ARCHIVE_UNIT || 100);

    $_cf{'libfml', 'binary'} = 0; # global binary or not variable on _(previous attached)

    # plain and 400 and your file. usually return here;
    stat($f);
    if (-T _ && -r _ && -o _ ) { return $f;}

    # NO!
    if ($fp < 1) { return $NULL;}

    # SEARCH
    if (defined(@ARCHIVE_DIR)) {
	local($sp) = (int(($fp - 1)/$ar_unit) + 1) * $ar_unit;

	$_cf{'libfml', 'binary'} = 2;		# WHY HERE? 2 is uuencode operation

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
	&Warn("Insecure $ID from $From_address. $ML_FN", 
	      "$s\n$ss\n".('-' x 30)."\n". &WholeMail);
	return 1;
    }

    0;
}


# Check the string contains Shell Meta Characters
# return 1 if match
sub MetaCharP
{
    local($r) = @_;

    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Log("Match: $r -> $`($&)$'");
	return 1;
    }

    0;
}


# Check arguments whether secure or not. 
# require META-CHAR check against e.g. unlink('log'), getpwuid()...
# return 1 if secure.
sub CheckCommandHook
{
    local($com, @s) = @_;
    local($s);

    foreach $s (@s) {
	if(&MetaCharP($s)) {
	    $_cf{'return'} .= "NOT permit META Char's in parameters.\n";
	    return 0;
	};
    }

    return 1;
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


# 
# return ID
sub GetPrevID
{
    local($adr) = @_;

    $MSEND_RC = $MSEND_RC || "$DIR/MSendrc";
    open(MSEND_RC) || return &GetID;

    line: while(<MSEND_RC>) {
	next line if /^\#/o;	# skip comment and off member
	next line if /^\s*$/o;	# skip null line
	chop;

	tr/A-Z/a-z/;		# E-mail form(RFC822)
	local($rcpt, $rc) = split(/\s+/, $_, 999);
	return $rc if &AddressMatch($adr, $rcpt);
    }

    close(MSEND_RC);

    &GetID;
}


# LastID(last:\d+) 
# mh last:\d+ syntax;
#
# return $L, $R
sub GetLastID
{
    local($s) = @_;

    if($s =~ /^last:(\d+)$/) {
	$R = &GetID;
	$L = $R - $1;# $ID from &GetID is ++ already;asymmetry is useful;
    }

    ($L, $R);
}


# for matomeokuri control
# added the infomation to MSEND_RC
# return NONE
sub ConfigMSendRC
{
    local($Address) = @_;
    local($ID) = &GetID;

    if (open(TMP, ">> $MSEND_RC") ) {
	select(TMP); $| = 1; select(STDOUT);
	print TMP "$Address\t$ID\n";
	close TMP;
    } 
    else { 
	&Logging("Cannot open $MSEND_RC");
    }
}


# "rsummary" command
# search keyword in summary 
# return NONE
sub SearchKeyInSummary
{
    local($s, $fl) = @_;
    local($a, $b);

    if($fl eq 's') {
	;
    }
    elsif($s =~ /^(\d+)\-(\d+)$/) {
	$a = $1; 
	$b = $2; 
    }
    elsif($s =~ /^last:\d+$/) {
	($a, $b) = &GetLastID($s);
    }
    else {
	$_cf{'return'} .= "Restricted Summary: the parameter not matched\n";
	return;
    }

    open(TMP, $SUMMARY_FILE) || do { &Log($!); return;};
    if($fl eq 'rs') {
	while(<TMP>) {
	    if(/\[$a:/ .. /\[$b:/) {
		$_cf{'return'} .= $_;
	    }
	}
    }
    elsif($fl eq 's') {
	while(<TMP>) {
	    if(/$s/) {
		$_cf{'return'} .= $_;
	    }
	}
    }
    close(TMP);
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
	    # KEY MARIEL;
	    if (/\sm=(\S+)\s/o) {
		local($d, $mode) = &ModeLookup($1);
		$s   .= "MATOME OKURI mode = ";

		if ($d) {
		    $s .= &DocModeLookup("\#$d$mode");
		}
		else {
		    $s .= "Realtime Delivery";
		}

		$s .= "\n";
	    }
	    else {
		$s .= "Realtime delivery\n";
	    }

	    $s .= "\n\n";
	}
    }

    close(ACTIVE_LIST);

    $s ? $s : "$who is NOT matched\n";
}

1;
