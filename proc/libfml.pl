# Library of fml.pl 
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


&Command if $LOAD_LIBRARY eq 'libfml.pl';


# VARIABLE SCOPE is limited in this file.
local($addr);
local(%mget_list, $misc, @misc, %misc);

# fml command routine
# return NONE but ,if exist, mail back $e{'message'} to the user
sub Command
{
    $0 = "--Command Mode in <$FML $LOCKFILE>";

    ### against loop 
    if (-f "$FP_VARRUN_DIR/emerg.stop") { 
	$e{'message'} .= "*** Server is now UNDER EMERGENCY STOP ***\n";
	$e{'message'} .= 
	    "Distribute function of ML Server is unavailable.\n";
    }

    # set parameters 
    local(*e) = *Envelope;# envelope
    local(@Fld);
    local($to) = $e{'Addr2Reply:'}; # compatible (for COMMAND_HOOK);
    local($mb) = @_;
    local($MailBody) = $mb || $e{'Body'};

    # Use Subject as a command input: (FIX:95/12/29 kise@ocean.ie.u-ryukyu.ac.jp)
    if ($USE_SUBJECT_AS_COMMANDS) { $MailBody = $e{'h:Subject:'}.$MailBody;}

    # reset for reply
    $e{'h:Reply-To:'} = $e{'h:reply-to:'} || $e{'Reply2:'};

    return if 1 == &LoopBackWarn($e{'Addr2Reply:'});
    
    # HERE WE GO!
    &InitProcedure;
    &ReConfigProcedure;

  GivenCommands: foreach (split(/\n/, $MailBody, 999)) {
      # skip null line
      next GivenCommands if /^\s*$/o; 

      # e.g. *-ctl server, not require '# command' syntax
      if ($COMMAND_ONLY_SERVER && (!/^\#/o)) { $_ = "# $_";}

      # check '# in-secre-matching-pattern ...' 
      next GivenCommands unless /^\#\s*\w+/o;	# against the signature(NOT COMMAND_ONLY)

      print STDERR "SECURE CHECK IN>$_\n" if $debug;
      &SecureP($_) || last GivenCommands;
      print STDERR "SECURE CHECK OK>$_\n" if $debug;

      ### Illegal syntax
      if (! /^\#/o) {
	  next GivenCommands unless $USE_WARNING;

	  &Log("ERROR:Command Syntax without ^#");
	  $e{'message'} .= "Command Syntax Error not with ^#\n";

	  next GivenCommands;	# 'last' in old days 
      }
      # since, this ; | is not checked when interact with shell.
      if (/[\;\|]/) {
	  $e{'message'} .= "[$_] have illegal characters, EXIT\n";
	  &Log("Insecure [$_] =~ [$`($&)$']"); 
	  &Warn("Insecure [$_] =~ [$`($&)$']", &WholeMail);
	  return;
      }

      ### syntax check, and set the array of cmd..
      s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      @Fld = split(/\s+/, $_, 999);
      s/^#\s*//, $org_str = $_;
      $_ = $Fld[1];

      ### info
      $0 = "--Command Mode processing $_: $FML $LOCKFILE>";
      &Debug("Present command    $_") if $debug;

      ### Special Syntax Modulation
      # enable us to use "mget 200.tar.gz" = "get 200.tar.gz"
      # EXCEPT FOR 'get \d+', get -> mget.
      /^get$/io && ($Fld[2] !~ /^\d+$/o) && ($_ = 'mget');

      ### Procedures
      local($status, $proc);
      tr/A-Z/a-z/;

      if ($proc = $Procedure{$_}) {
	  # REPORT
	  if ($Procedure{"r#$_"}) {
	      $e{'message'} .= "\n>>> $org_str\n";
	  }

	  # INFO
	  &Debug("Call               &$Procedure{$_}") if $debug;
	  $0 = "--Command calling $proc: $FML $LOCKFILE>";

	  # PROCEDURE
	  $status = &$proc($_, *Fld, *e, *misc);

	  # NEXT
	  last GivenCommands if $status eq 'LAST';
	  next GivenCommands;
      }

      # Special hook e.g. "# list",should be used as a ML's specific hooks
      eval $COMMAND_HOOK; 
      &Log("COMMAND_HOOK ERROR", $@) if $@;

      # if undefined commands, notify the user about it and abort.
      &Log("Unknown Cmd $_");
      $e{'message'} .= ">>> $_\n\tUnknown Command: $_\n\tStop.\n";

      # stops.
      last GivenCommands;

  } # the end of while loop;

    # process for mget submissions.
    if (%mget_list) {
	&MgetCompileEntry(*e);
	if ($FML_EXIT_HOOK !~ /mget3_SendingEntry/) {
	    $FML_EXIT_HOOK .= '&mget3_SendingEntry;';
	}
    }

    # return "ERROR LIST"
    if ($e{'message'}) {
	$e{'message:h:to'}      = $e{'Addr2Reply:'};
	$e{'message:h:subject'} = "fml Command Status report $ML_FN";
    }
}


################## PROCEDURE SETTINGS ##################
sub InitProcedure
{
    # Backward compatibility
    $COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;

    # Command Line Options
    $COMMAND_ONLY_SERVER = 1 if $_cf{'opt:c'};

    # SYNTAX
    # $s = $_;(present line of the given mail body)
    # $ProcFileSendBack($proc, *s);
    local(%proc) = (
		    # send a guide back to the user
		    'guide',	'ProcFileSendBack',
		    '#guide',	$GUIDE_FILE,

		    # ALIAS of 'guide' above
		    # send a guide back to the user
		    'info',	'ProcFileSendBack',
		    '#info',	$GUIDE_FILE,

		    # help for usage of commands
		    'help',	'ProcFileSendBack',
		    '#help',	$HELP_FILE,

		    # return the objective of Mailing List
		    'objective','ProcFileSendBack',
		    '#objective',  $OBJECTIVE_FILE,

		    # return a  member file of Mailing List
		    'members', 'ProcFileSendBack',
		    '#members',     $MEMBER_LIST,
		    'member', 'ProcFileSendBack',
		    '#member',     $MEMBER_LIST,

		    # return a active file of Mailing List
		    'actives',  'ProcFileSendBack',
		    '#actives',    $ACTIVE_LIST,
		    'active',  'ProcFileSendBack',
		    '#active',    $ACTIVE_LIST,

		    # MODE switch(users not require to know this option.)
		    'mode',    'ProcModeSet',
		    'set',     'ProcModeSet',

		    # return a summary of Mailing List
		    'summary', 'ProcSummary',

		    # return a summary of Mailing List
		    'stat',   'ProcShowStatus',
		    'status', 'ProcShowStatus',

		    # return a file list to enable to get
		    'index',   'ProcIndex',
		    'r#index',  1,

		    # get file in spool 
		    'get', 'ProcRetrieveFileInSpool',
		    'getfile', 'ProcRetrieveFileInSpool',
		    'send', 'ProcRetrieveFileInSpool',
		    'sendfile', 'ProcRetrieveFileInSpool',

		    # mget is a special case
		    'mget',  'ProcMgetMakeList',
		    'mget2', 'ProcMgetMakeList',
		    'mget3', 'ProcMgetMakeList',
		    'msend', 'ProcMgetMakeList',

		    # library access: another way to access archives
		    'library',	'ProcLibrary',
		    'r#library',	1, 

		    # these below are not implemented, 
		    # but implemented in hml 1.6
		    # codes only for notifying the alart to the user
		    'iam',    'ProcWhoisWrite',
		    'r#iam', 1,
		    'whois',  'ProcWhoisSearch',
		    'r#whois', 1,
		    'who',    'ProcWhoisList',
		    'r#who', 1,

		    # send a message to $MAINTAINER
		    'msg',    'ProcForward',

		    # for Convenience
		    'end',    'ProcExit',
		    'quit',   'ProcExit',
		    'exit',   'ProcExit',

		    # Off: temporarily.
		    # On : Return to Mailng List
		    # Matome : Matome Okuri ver.2 Control Interface
		    # Skip : can post but not be delivered
		    # NOSkip : inverse above
		    'off',    'ProcSetDeliveryMode',
		    'r#off', 1,
		    'on',     'ProcSetDeliveryMode',
		    'r#on', 1,
		    'matome', 'ProcSetDeliveryMode',
		    'r#matome', 1,
		    'skip',   'ProcSetDeliveryMode',
		    'r#skip', 1,
		    'noskip', 'ProcSetDeliveryMode',
		    'r#noskip', 1,

		    # Bye - Good Bye Eternally
		    'chaddr',         'ProcSetMemberList',
		    'r#chaddr', 1,
		    'change-address', 'ProcSetMemberList',
		    'r#change-address', 1,
		    'change',         'ProcSetMemberList',
		    'r#change', 1,
		    'bye',            'ProcSetMemberList',
		    'r#bye',         1,
		    'unsubscribe',    'ProcSetMemberList',
		    'r#unsubscribe', 1,

		    # Subscribe
		    'subscribe', 'ProcSubscribe',
		    'r#subscribe', 1,

		    # Subscribe
		    'admin', 'ProcSetAdminMode',
		    'r#admin', 1,
		    'approve', 'ProcApprove',
		    'r#approve', 1,

		    # PASSWD
		    'passwd', 'ProcPasswd',
		    'r#passwd', 1,

		    # Set the address to operate e.g. for exact matching
		    'addr', 'ProcSetAddr', 
		    'r#addr', 1,

		    # DUMMY SETTING for the easy coding
		    '#dummy', '#dummy',

		    # CONTRIB
		    'traffic', 'ProcTraffic', 
		    'r#traffic', 1,
		    );



    ### OVERWRITE by user-defined-set-up-data (%LocalProcedure)
    ### REDEFINE  by @PermitProcedure and @DenyProcedure

    # IF @PermitProcedure, PERMIT ONLY DEFINED FUNCTIONS;
    if (@PermitProcedure) { 
	foreach $k (@PermitProcedure) { $Procedure{$k} = $proc{$v};}
    }
    # PERMIT ALL FUNCTIONS
    else {
	%Procedure = %proc;
    }

    # OVERLOAD USER-DEFINED FUNCTIONS
    local($k, $v);
    while (($k, $v) = each %LocalProcedure) { $Procedure{$k} = $v;}

    # IF @DenyProcedure, Delete DEFIEND FUNCTIONS
    if (@DenyProcedure) { 
	foreach $k (@DenyProcedure) { undef $Procedure{$k};}
    }
}


# 1.6.1 whois becomes a standard.
sub ReConfigProcedure
{
    # IF USED AS ONLY COMMAND SERVER, 
    if ($COMMAND_ONLY_SERVER) {
	local($key) = $REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE;
	$Procedure{$key} = 'ProcSubscribe';
    }
}


sub ProcFileSendBack
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log($proc);
    &SendFile($e{'Addr2Reply:'}, "$proc $ML_FN", $Procedure{"#$proc"});
}


sub ProcModeSet
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s) = $Fld[2]; 
    local($p) = $Fld[3] ? $Fld[3] : 1; 
    $s =~ tr/A-Z/a-z/;

    $e{'message'} .= "\n>>> $proc $s $p\n";

    if ($s eq 'addr_check_max') {
	$ADDR_CHECK_MAX = $p;
    }
    elsif ($s eq 'exact') {
	$ADDR_CHECK_MAX = 9;	# return if 10;
    }
    elsif (! $_cf{'mode:admin'}) {
	$s = "$proc cannot be permitted without AUTHENTIFICATION";
	$e{'message'} .= "$s\n";
	&Log($s);
	return 'LAST';
    }

    ######### HEREAFTER ADMIN COMMANDS #########

    ### CASE
    if ($s eq 'debug') {
	$_cf{'debug'} = $debug = $p;
    }

    ### LOG
    $e{'message'} .= "\t$s = $p;\n";
    &Log("$proc $s = $p");
}


sub ProcSummary
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s) = $e{'r:Subject'};

    if ($Fld[2] && ($proc eq 'search')) {
	$e{'message'} .= "\n>>> Search Key=$Fld[2] in Summary file\n\n";
	&SearchKeyInSummary($Fld[2], 's');
	&Log(($s && "$s ")."Search [$Fld[2]]");
    }
    elsif ($Fld[2] && ($proc eq 'summary')) {
	$e{'message'} .= "\n>>> Summary: Search KEY=$Fld[2]\n\n";
	&SearchKeyInSummary($Fld[2], 'rs');
	&Log(($s && "$s ")."Restricted Summary [$Fld[2]]");
    }
    else {
	$s = ($s || "Summary");
	&Log($s);
	&SendFile($e{'Addr2Reply:'}, "$s $ML_FN", $SUMMARY_FILE);
    }
}


sub ProcShowStatus
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("Status for $Fld[2]");
    &use('utils');
    $e{'message'} .= "\n>>> status for $Fld[2].\n";
    $e{'message'} .= 
	&MemberStatus($Fld[2] ? $Fld[2] : $From_address)."\n";
}


sub ProcObsolete
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc[Not Implemented]");
    $e{'message'} .= "Command $proc is not implemented.\n";
}


sub ProcRetrieveFileInSpool
{
    local($proc, *Fld, *e, *misc) = @_;
    local(*cat);
    local($ID) = $Fld[2]; 

    local($mail_file, $ar) = &ExistP($ID);# return "$SPOOL_DIR/ID" form;
    &Debug("GET: local($mail_file, $ar)") if $debug;

    &Log(" $mail_file >< $ar ");

    if ($mail_file) { 
	$cat{"$SPOOL_DIR/$ID"} = 1;
	if ($ar eq 'TarZXF') {  
	    &use('utils');
	    &Sendmail($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		      &TarZXF("$DIR/$mail_file", 1, *cat));
	}
	else {
	    &SendFile($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		      "$DIR/$mail_file", 
		      $_cf{'libfml', 'binary'});
	    undef $_cf{'libfml', 'binary'}; # destructor
	}

	&Log("Get $ID, Success");
    } 
    else {				# or null $ID
	$e{'message'} .= "\n>>> $org_str\nArticle $ID is not found.\n";
	&Log("Get $ID, Fail");
    }
}


sub ProcForward
{
    local($proc, *Fld, *e, *misc) = @_;
    
    &Log('Msg');
    &Warn("Msg ($From_address)", 
	  $e{'h:Subject:'}."\n\n".$e{'Body'});

    'LAST';
}


sub ProcExit
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("exit[$proc]");
    'LAST';
}


# ($ProcName, *FieldName, *Envelope, *misc)
# $misc      : E-Mail-Address to operate
# $FieldName : "# procname opt1 opt2" FORM
#
# Off: temporarily.
# On : Return to Mailng List
# Matome : Matome Okuri ver.2 Control Interface
# Skip : can post but not be delivered
# NOSkip : inverse above
sub ProcSetDeliveryMode
{
    local($proc, *Fld, *e, *misc) = @_;
    local($addr) = $misc || $addr || $From_address;
    local($c, $_, $cmd, $opt, *misc); # order is important(e.g. $misc)
    local($cmd, $opt, $misc) = ($proc, $Fld[2], $Fld[3]);
    $cmd =~ tr/a-z/A-Z/;
    $_   = $cmd;

    ###### LOOP CHECK
    if (&LoopBackWarn($addr)) {
	&Log("$cmd: LOOPBACk ERROR, exit");
	return $NULL;
    }

    ###### Matome Okuri prescan
    # [case 1 "matome 3u"]
    if (/^MATOME$/ && ($opt =~ /^(\d+|\d+[A-Za-z]+)$/oi)) {
	# set matome-okuri-parameter. *misc -> &Change..( , , , *misc);
	$c = $misc = $1;

	# Exception is synchronous delivery
	if (0 == $c) {
	    $c = " -> Synchronous Delivery";
	}
	# e.g. 6 , 6u , ...
	else {
	    # search this mode exists?
	    &use('utils');
	    local($d, $mode) = &ModeLookup($c);

	    if ((!$d) && (!$mode)) { 
		&Log("$cmd $c fails, not match");
		$e{'message'} .= "$cmd: $opt parameter not match.\n";
		$e{'message'} .= "\tDO NOTHING!\n";
		return $NULL;
	    }			
	}# $c == non-nil;
	
	&Log("O.K. Try matome $c");
    }
    ###### [case 2 "matome" call the default slot value]
    elsif (/^MATOME$/i) {
	&Log("$cmd: $opt inappropriate, do nothing");
	$e{'message'} .= "$cmd: $opt parameter inappropriate.\n";
	$e{'message'} .= "\tDO NOTHING!\n";
	return $NULL;
    }

    if (&ChangeMemberList($cmd, $addr, $ACTIVE_LIST, *misc)) {
	&Log("$cmd [$addr] $c");
	$e{'message'} .= "$cmd [$addr] $c accepted.\n";
    }
    else {
	&Log("$cmd [$addr] $c failed");
	$e{'message'} .= "$cmd [$addr] $c failed.\n";
    }
}


# ($ProcName, *FieldName, *Envelope, *misc)
# $misc      : E-Mail-Address to operate
# $FieldName : "# procname opt1 opt2" FORM
#
# Bye - Good Bye Eternally
sub ProcSetMemberList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($addr)             = $misc || $addr || $From_address;
    local($cmd, $opt, $misc) = ($proc, $Fld[2], $Fld[3]); # order (e.g. $misc)
    $cmd =~ tr/a-z/A-Z/;
    $_   = $cmd;

    # KEYWORD for 'chaddr'
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    # LOOP CHECK
    if (&LoopBackWarn($addr)) {
	&Log("$cmd: LOOPBACk ERROR, exit");
	return '';
    }
    
    ###### change address [chaddr old-addr new-addr]
    # Default: $CHADDR_KEYWORD = 'CHADDR|CHANGE\-ADDRESS|CHANGE';
    if (/^($CHADDR_KEYWORD)$/i) {
	$addr = $opt;
	$e{'message'} .= "\t set $cmd => CHADDR\n";
	$cmd = 'CHADDR';
	
	# LOOP CHECK
	&LoopBackWarn($misc) && &Log("$cmd: LOOPBACk ERROR, exit") && 
	    (return $NULL);

	#ATTENTION! $addr or $misc should be a member.
	if (&CheckMember($addr, $MEMBER_LIST) || 
	    &CheckMember($misc, $MEMBER_LIST)) {
	    &Log("$cmd: OK! Either $addr and $misc is a member.");
	    $e{'message'} .= 
		"\tTry change\n\n\t$addr\n\t=>\n\t$misc\n\n";
	}
	else {
	    &Log("$cmd: NEITHER $addr and $misc is a member. STOP");
	    $e{'message'} .= "$cmd:\n\tNEITHER\n\t$addr nor $misc\n\t";
	    $e{'message'} .= "is a member.\n\tDO NOTHING!\n";
	    return 'LAST';
	}
    }
    # NOT CHADDR;
    else {
	$e{'message'} .= "\t set $cmd => BYE\n";
	$cmd = 'BYE';
    }

    ##### Call recursively
    local($r) = 0;
    if ($ML_MEMBER_CHECK) {
	&ChangeMemberList($cmd, $addr, $MEMBER_LIST, *misc) && $r++;
	&Log("$cmd MEMBER [$addr] $c O.K.")   if $r == 1 && $debug2;
	&Log("$cmd MEMBER [$addr] $c failed") if $r != 1;
    }
    else {
	$r++;
    }

    &ChangeMemberList($cmd, $addr, $ACTIVE_LIST, *misc) && $r++;
    &Log("$cmd ACTIVE [$addr] $c O.K.")   if $r == 2  && $debug2;
    &Log("$cmd ACTIVE [$addr] $c failed") if $r != 2;

    # Status
    if ($r == 2) {
	&Log("$cmd [$addr] $c accepted");
	$e{'message'} .= "$cmd [$addr] $c accepted.\n";
    }
    else {
	&Log("$cmd [$addr] $c failed");
	$e{'message'} .= "$cmd [$addr] $c failed.\n";
    }

    return 'LAST';
}


# Set the address to operate e.g. for exact matching
sub ProcSetAddr
{
    local($proc, *Fld, *e, *misc) = @_;

    if (! $_cf{'mode:admin'}) {
	$s = "$proc cannot be permitted without AUTHENTIFICATION";
	$e{'message'} .= "$s\n";
	&Log($s);
	return 'LAST';
    }

    if (&AddressMatch($Fld[2], $From_address)) {
	$addr = $Fld[2];
	$ADDR_CHECK_MAX = 10;	# exact match(trick)
	$e{'message'} .= "Try exact-match for $addr.\n";
	&Log("Exact addr=$addr");
    }
    else {
	$e{'message'} .= "Forbidden to use $addr,\n";
	$e{'message'} .= "since $addr is too different from $From_address.\n";
	&Log("Exact addr=$addr fail");
    }
}


sub ProcSubscribe
{
    local($proc, *Fld, *e, *misc) = @_;

    # if member-check mode, forward the request to the maintainer
    if ($ML_MEMBER_CHECK) {
	&LogWEnv("$proc request is forwarded to Maintainer", *e);
	$e{'message'} .= "Please wait a little\n";
	&Warn("$proc request from $From_address", &WholeMail);
    }
    else {
	&use('utils');
	&AutoRegist(*e);
    }
}


sub ProcSetAdminMode
{
    local($proc, *Fld, *e, *misc) = @_;
    local($addr) = $addr ? $addr : $From_address;

    # REMOTE PERMIT or NOT?
    if (! $REMOTE_ADMINISTRATION) {
	&Log("ILLEGAL REQUEST $proc mode, STOP!",
	     "Please \$REMOTE_ADMINISTRATION=1; for REMOTE-ADMINISTRATION");
	return 'LAST';
    }
    
    # Please customize below
    $ADMIN_MEMBER_LIST	= $ADMIN_MEMBER_LIST || "$DIR/members-admin";
    $ADMIN_HELP_FILE	= $ADMIN_HELP_FILE   || "$DIR/help-admin";
    $PASSWD_FILE        = $PASSWD_FILE       || "$DIR/etc/passwd";
    $REMOTE_AUTH        = $REMOTE_AUTH       || 0;

    # touch
    -f $PASSWD_FILE || &Touch($PASSWD_FILE);
    
    &use('ra');	# remote -> ra

    if (&CheckMember($addr, $ADMIN_MEMBER_LIST)) {
	&Log("$proc: Request[@Fld]") if $debug;

	$_cf{'mode:admin'} = 1;	# AUTHENTIFIED, SET MODE ADMIN

	&AdminCommand(*Fld, *e) || do {
	    &Log("AdminCommand return nil, STOP!");
	    return 'LAST';
	};

	$_cf{'mode:admin'} = 0;	# UNSET for hereafter
	return '';
    }
    else {
	&LogWEnv("$proc: Request From NOT ADMINISTRATORS, STOP!", *e);
	return 'LAST';
    }

    $_cf{'mode:admin'} = 0;	# UNSET for hereafter
}


sub ProcApprove
{
    local($proc, *Fld, *e, *misc) = @_;
    local($addr) = $addr ? $addr : $From_address;
    local($p);

    # REMOTE PERMIT or NOT?
    if (! $REMOTE_ADMINISTRATION) {
	&Log("ILLEGAL REQUEST $proc mode, STOP!",
	     "Please \$REMOTE_ADMINISTRATION=1; for REMOTE-ADMINISTRATION");
	return 'LAST';
    }
    
    # Please customize below
    $ADMIN_MEMBER_LIST	= $ADMIN_MEMBER_LIST || "$DIR/members-admin";
    $ADMIN_HELP_FILE	= $ADMIN_HELP_FILE   || "$DIR/help-admin";
    $PASSWD_FILE        = $PASSWD_FILE       || "$DIR/etc/passwd";
    $REMOTE_AUTH        = 0;	# important

    # touch
    (!-f $PASSWD_FILE) && open(TOUCH,">> $_") && close(TOUCH);
    
    # INCLUDE Libraries
    &use('crypt');
    &use('ra');	# remote -> ra

    # get passwd
    local($d0, $d1, $p, @p) = @Fld;
    local(@Fld) = ('#', 'approve', @p);

    &Log("&CmpPasswdInFile($PASSWD_FILE, $addr, $p)") if $debug;

    if (&CmpPasswdInFile($PASSWD_FILE, $addr, $p)) {
	&Log("$proc: Request[@p]") if $debug;

	$_cf{'mode:admin'} = 1;	# AUTHENTIFIED, SET MODE ADMIN

	&ApproveCommand(*Fld, *e) || do {
	    &Log("AdminCommand return nil, STOP!");
	    return 'LAST';
	};

	$_cf{'mode:admin'} = 0;	# UNSET for hereafter
	return '';
    }
    else {
	$e{'message'} .= "$proc: You are not an administrator\n";
	&Log("$proc: ILLEGAL ADMIN COMMANDS REQUEST");
    }
}


sub ProcPasswd
{
    local($proc, *Fld, *e, *misc) = @_;
    local($addr) = $addr ? $addr : $From_address;

    shift @Fld;
    shift @Fld;
    local($old) = shift @Fld;
    local($new) = shift @Fld;

    &Log("ProcPasswd: [$old] -> [$new]") if $debug;

    $PASSWD_FILE        = $PASSWD_FILE       || "$DIR/etc/passwd";
    (!-f $PASSWD_FILE) && open(TOUCH,">> $_") && close(TOUCH);

    &use('crypt');

    # if you know the old password, you are authentified.
    if (&CmpPasswdInFile($PASSWD_FILE, $addr, $old)) {
	$e{'message'} .= "$proc: Authentified\n";
	&Log("$proc; Authentified");
	if (&ChangePasswd($PASSWD_FILE, $addr, $new)) {
	    $e{'message'} .= "$proc; change passwd succeed";
	    &Log("$proc; change passwd succeed");
	}
	else {
	    $e{'message'} .= "$proc; change passwd fail";
	    &Log("$proc; change passwd fail");
	}
    }
    else {
	$e{'message'} .= "$proc: Illegal password\n";
	&Log("$proc: Illegal password");
    }
}


sub ProcIndex
{
    local($proc, *Fld, *e, *misc) = @_;
    local(*e) = *Envelope;

    &Log($proc);
    
    if (-f $INDEX_FILE && open(F, $INDEX_FILE)) {
	$e{'message'} .= <F>;
	$e{'message'} .= "\n";
    }
    else {
	local($ok, $dir, $f);
	if (&ProcIndexSearchMinCount < &GetID) {
	    $e{'message'} .= 
		"The spool of this ML have plain format articles\n";
	    $e{'message'} .= "\tthe number(count) exists\n\t";
	    $e{'message'} .= &ProcIndexSearchMinCount;
	    $e{'message'} .= " <-> ";
	    $e{'message'} .= &GetID;
	    $e{'message'} .= "\n\n";
	}
	else {
	    $e{'message'} .= "NO plain format articles\n\n";
	}

	$e{'message'} .= "In 'ARCHIVE' the following files exist.\n";
	$e{'message'} .= "Please 'mget' command to get them\n\n";

	$ok = 0;
      AR: foreach $dir (@ARCHIVE_DIR) {
	  next if /^\./o;

	  $e{'message'} .= "\n$dir:\n" if $INDEX_SHOW_DIRNAME;

	  if ( -d $dir && opendir(DIRD, $dir) ) {
	    FILE: foreach $f (sort readdir(DIRD)) {
		next FILE if $f =~ /^\./;

		local($size) = (stat("$dir/$f"))[7];
		if (-f _) {
		    $e{'message'} .= 
			sprintf("\t%-20s\t%10d bytes\n", $f, $size);
		    $ok++;
		}
	    }# FOREACH;

	      closedir DIRD;
	  }
	  else {
	      &Log("Index:cannot opendir $dir");
	  }
      }	# AR:;

	$e{'message'} .= "\n";
	$e{'message'} .= "\tNothing.\n" unless $ok;
    }# case of file no index exists.;
}


sub ProcIndexSearchMinCount
{
    local($proc, *Fld, *e, *misc) = @_;
    local($try)  = &GetID - 1;# seq is already +1;
    local($last) = $try;

    while(-f "$FP_SPOOL_DIR/$try") {
	last if $try <= 1;	# ERROR
	$try  = int($try/2);
	print STDERR "ExistCheck: min /2 $try\n" if $debug;
    } 
    
    for ((!-f "$FP_SPOOL_DIR/$try"); (!-f "$FP_SPOOL_DIR/$try"); $try++) {
	last if $try > $last; # ERROR
	print STDERR "ExistCheck: min ++ $try\n" if $debug;
    }

    print STDERR "MINIMUM ($try < 1) \? 1 \: $try\n" if $debug;
    ($try < 1) ? 1: $try;
}


sub ProcMgetMakeList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($key);
    local(@fld) = @Fld;

    # cut the first three arrays.
    shift @fld;    shift @fld;    shift @fld;

    if (@fld) {
	$key = join(':', @fld);
    }
    else {
	$key = '';
    }

    if ($mget_list{$key}) {	        # '1 2 3' .. 
	$mget_list{$key} .= " $Fld[2]";	# must have NO SPACE
    }
    else {
	$mget_list{$key} = $Fld[2];
    }

    &Log("$proc submitted entry=[$Fld[2]:$key]");

    if ($debug) {
	local($key, $value);
	while (($key, $value) = each %mget_list) {
	    print STDERR "MGET ENTRY [$key]\t=>\t[$value]\n";
	}
    }

    1;
}


sub ProcLibrary
{
    local($proc, *Fld, *e, *misc) = @_;
    &use('library');
    &ProcLibrary4PlainArticle($proc, *Fld, *e, *misc);
}


# the left of e{'Body'} is whois-text
sub ProcWhoisWrite 
{ 
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc @Fld[2..$#Fld]");
    &use('whois');
    &WhoisWrite(*e);
    return 'LAST';
}


sub ProcWhoisList
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc @Fld[2..$#Fld]");
    &use('whois');
    &WhoisList(*e);
}


sub ProcWhoisSearch 
{ 
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc @Fld[2..$#Fld]");
    &use('whois'); 
    &WhoisSearch(*e, *Fld);
}


sub ProcTraffic
{
    local($proc, *Fld, *e, *misc) = @_;

    &use('traffic');

    &Log("$proc [@Fld[2..$#Fld]]");
    &Traffic(*Fld, *e);
}


################## PROCEDURE SETTINGS ENDS ##################


# matomete get articles from the spool, then return them
# mget is an old version. 
# new version should be used as mget ver.2(mget[ver.2])
# matomete get articles from the spool, then return them
sub MgetCompileEntry
{
    local(*e) = @_;
    local($key, $value, $status, $fld, @fld, $value, @value);
    local($proc) = 'mget';

    # Do nothing if no entry.
    return unless %mget_list;

    $0 = "--Command Mode loading mget library: $FML $LOCKFILE>";

    &use('sendfile');

    while (($key, $value) = each %mget_list) {
	print STDERR "TRY MGET ENTRY [$key]\t=>\t[$value]\n" if $debug;

	# SPECIAL EFFECTS
	next if $key =~ /^\#/o;
	
	@fld = split(/:/, $fld = $key); 
	$fld =~ s/:/ /;		# for $0;

	# targets, may be multiple
	@value = split(/\s+/, $value); 

	# Process Table
	$0 = "--Command Mode mget[$key $fld]: $FML $LOCKFILE>";

	# mget3 is a new interface to generate requests of "mget"
	$fld = $key;		# to make each "sending entry"
	$status = &mget3(*value, *fld, *e);

	$0 = "--Command Mode mget[$key $fld] status=$status: $FML $LOCKFILE>";

	# regardless of RETURN VALUE;
	return if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

	if ($status) {
	    ;
	}
	else {
	    $status = "Fail";
	    $e{'message'} .= "\n>>>$proc $value $fld\n\tfailed.\n";
	};

	&Log("$proc:[$$] $key $fld: $status");
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


sub ChangeMemberList
{
    local($org_addr) = $ADDR_CHECK_MAX;	# save the present severity
    local($status);

    while ($ADDR_CHECK_MAX < 10) { # 10 is built-in;
	$status = &DoChangeMemberList(@_);
	last if $status ne 'RECURSIVE';
	$ADDR_CHECK_MAX++;
	&Debug("Call Again ChangeMemberList(...)[$ADDR_CHECK_MAX]") if $debug;
    } 

    $ADDR_CHECK_MAX = $org_addr; # reset;
    $status;
}


# MAIN Routine of ChangeMemberList(cmd, address, file) 
# If multiply matched for the given address, 
# do Log [$log = "$addr"; $log_c++;]
sub DoChangeMemberList
{
    local($cmd, $Address, $file, *misc) = @_;
    local($status, $log, $log_c, $r, $addr, $org_addr);
    local($acct) = split(/\@/, $Address);

    &Debug("ChangeMemberList ($cmd, $Address, $file, misc)") if $debug;
    
    ### File IO
    # NO CHECK 95/10/19 ($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file)
    # Backup
    open(BAK, ">> $file.bak") || (&Log($!), return $NULL);
    select(BAK); $| = 1; select(STDOUT);
    print BAK "----- Backup on $Now -----\n";

    # New
    open(NEW, ">  $file.tmp") || (&Log($!), return $NULL);
    select(NEW); $| = 1; select(STDOUT);

    # Input
    open(FILE,"<  $file") || (&Log($!), return $NULL);


    ### Process GO!
    print NEW &FML_HEADER;

    in: while (<FILE>) {
	chop;

	# If allow all people to post, OK ends here.
	if (/^\+/o) { 
	    &Log("NO CHANGE[$file] when no member check");
	    close(FILE); 
	    return ($status = 'done'); 
	}

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

	# Backup
	print BAK "$_\n";
	next in if /^\s*$/o;

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	$addr = '';
	if (/^\s*(\S+)\s*.*/o)   { $addr = $1;}
	if (/^\#\s*(\S+)\s*.*/o) { $addr = $1;}

	# for high performance
	if ($addr !~ /^$acct/i) {
	    print NEW "$_\n"; 
	    next in;
	} 
	elsif (! &AddressMatch($addr, $Address)) {
	    print NEW "$_\n"; 
	    next in;
	}

	# if matched, get $addr including mx or comments
	if (/^\s*(.*)/o)   { $addr = $1;}
	if (/^\#\s*(.*)/o) { $addr = $1;}

	# not use "last" for the possibility the address is written double. 
	# may not be effecient.
	if ($cmd =~ /^ON|OFF|BYE|SKIP|NOSKIP|MATOME|CHADDR$/) {
	    # Return to the ML
	    print NEW "$addr\n" 	if $cmd eq 'ON';

	    # Good Bye to the ML temporarily
	    print NEW "\#\t$addr\n"     if $cmd eq 'OFF';

	    # Good Bye to the ML eternally
	    print NEW "\#\#BYE $addr\n" if $cmd eq 'BYE';

	    # Address to SKIP
	    print NEW "$addr\ts=skip\n" if $cmd eq 'SKIP';

 	    # Delete SKIP
	    if ($cmd eq 'NOSKIP') {
		$addr =~ s/\ss=(\S+)//ig; # remover s= syntax
		print NEW "$addr\n"; 
	    }

	    # Matome Okuri Control
	    if ($cmd eq 'MATOME') {
		($addr, $org_addr) = &CtlMatome($addr, *misc);
		print NEW "$addr\n"; 
	    }

	    # Matome Okuri Control
	    if ($cmd eq 'CHADDR') {
		&Log("ChangeMemberList:$addr -> $misc");
		print NEW "$misc\n"; 
	    }

	    $status = 'done'; 
	    $log .= "$cmd $addr; "; $log_c++;
	}# CASE of COMMANDS;
	else {
	    print NEW "$_\n"; 
	    &Log("ChangeMemberList:Unknown cmd = $cmd");
	}
    } # end of while loop;

    # CORRECTION; If not registerd, add the Address to SKIP
    if ($cmd eq 'SKIP' && $status ne 'done') { 
	print NEW "$addr\ts=skip\n"; 
	$status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close(BAK); close(NEW); close(FILE);

    # protection for multiplly matching, 
    # $log_c > 1 implies multiple matching;
    # ADMIN MODE permit multiplly matching($_cf{'mode:addr:multiple'} = 1);
    ## IF MULTIPLY MATCHED
    if ($log_c > 1 && 
	($ADDR_CHECK_MAX < 10) && 
	(! $_cf{'mode:addr:multiple'})) {
	&Log("$cmd: Do NOTHING since Muliply MATCHed..");
	$log =~ s/; /\n/g;
	$e{'message'} .= "Multiply Matched?\n$log\n";
	$e{'message'} .= "Retry to check your adderss severely\n";

	# Recursive Call
	return 'RECURSIVE';
    }
    ## IF TOO RECURSIVE
    elsif ($ADDR_CHECK_MAX >= 10) {
	&Log("MAXIMUM of ADDR_CHECK_MAX, STOP");
    }
    ## DEFAULT 
    else {
	rename("$file.tmp", $file) || 
	    (&Log("fail to rename $file"), return $NULL);
    }

    # here should be "Only once called"
    if ($cmd eq 'MATOME' && $status eq 'done') {
	&Log("ReConfiguring $Address in \$MSendRC");
	&ConfigMSendRC($Address);
	&Rehash($org_addr) if $org_addr;# info of original mode is required
    }

    $e{'message'} .= "O.K.!\n" if $status eq 'done';

    $status;
}
    

sub CtlMatome
{
    local($addr, *misc) = @_;
    local($matome) = $misc;	# set value(0 implies Realtime deliver)
    local($org_addr) = $addr;	# save excursion
    local($s);

    &Log("matome => $matome") if $debug;

    # parameter is whether 0 or not-defiend
    if ($matome eq '') {
	# modification
	if ($addr =~ /\smatome/oi || $addr =~ /\sm=/) {
	    $matome = 'RealTime';
	}
	# new comer, set default
	else {
	    $matome = 3;
	    $s = "Hmm.. no given parameter. use default[m=3]";
	    &Log($s);
	    $e{'message'} .= "$s\n";
	    $e{'message'} .= 
		"So your request is accepted but modified to m=3\n";
	}
    }
    elsif ($matome == 0) {
	$matome = 'RealTime';
    }

    # Remove the present matomeokuri configuration
    $addr =~ s/^(.*)matome/$1/ig; # backward compatibility
    $addr =~ s/\sm=(\S+)//ig; # remover m= syntax

    # Set value
    if ($matome eq 'RealTime') {    # 'call &Rehash'
	;
    }
    else {
	$addr = "$addr\tm=$matome";
	undef $org_addr;	# 'NOT require call &Rehash'
    }

    # return value
    ($addr, $org_addr);
}


# Send mails left in spool for "# matome 0".
sub Rehash
{
    local($adr) = @_;
    local($l, $r, $s, $d, $mode);
    ($adr, $mode) = split(/\s+/, $adr, 2);

    print STDERR "\n---Rehash local($adr, $mode)\n\n";

    &use('utils');

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
    $e{'message'} .= "\n$s\n\n";

    # make an entry 
    local(@fld) = ('#', 'mget', "$l-$r", 10, $mode);

    ($l <= $r) && &ProcMgetMakeList('Rehash:EntryIn', *fld);

    1;
}


# Exist a file or not, a binary or not, your file? read permitted?
# return full path filename or NULL
sub ExistP
{
    local($fp)      = @_;
    local($f)       = "$SPOOL_DIR/$fp";	# return string is "spool/100" form not fullpath-ed
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


# Check arguments whether secure or not. 
# require META-CHAR check against e.g. unlink('log'), getpwuid()...
# return 1 if secure.
sub CheckCommandHook
{
    local($com, @s) = @_;
    local($s);

    foreach $s (@s) {
	if ($s =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	    $e{'message'} .= "Should NOT include META Char's.\n";
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
	&Log("Cannot open $SEQUENCE_FILE");
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
	&Log("Cannot open $MSEND_RC");
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
	$e{'message'} .= "Restricted Summary: the parameter not matched\n";
	return;
    }

    open(TMP, $SUMMARY_FILE) || do { &Log($!); return;};
    if($fl eq 'rs') {
	while(<TMP>) {
	    if(/\[$a:/ .. /\[$b:/) {
		$e{'message'} .= $_;
	    }
	}
    }
    elsif($fl eq 's') {
	while(<TMP>) {
	    if(/$s/) {
		$e{'message'} .= $_;
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

	if($rcpt =~ /$who/i) {	# koyama@kutsuda.kuis 96/01/30
	    $s .= "$rcpt:\n";
	    $s .= "\tpresent not participate in. (OFF)\n" if $sharp;

	    $_ = $opt;
	    /\sr=(\S+)/     && ($s .= "\tRelay server is $1\n"); 
	    /\ss=/          && ($s .= 
				"\tNOT delivered here, but can post to $ML_FN\n");
	    # KEY MARIEL;
	    if (/\sm=(\S+)\s/o) {
		local($d, $mode) = &ModeLookup($1);
		$s   .= "\tMATOME OKURI mode = ";

		if ($d) {
		    $s .= &DocModeLookup("\#$d$mode");
		}
		else {
		    $s .= "Realtime Delivery";
		}

		$s .= "\n";
	    }
	    # REALTIME
	    else {
		$s .= "\tRealtime delivery\n";
	    }

	    $s .= "\n\n";
	}
    }

    close(ACTIVE_LIST);

    $s ? $s : "$who is NOT matched\n";
}

1;
