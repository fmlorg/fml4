# Library of fml.pl 
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");


&Command if $LOAD_LIBRARY eq 'libfml.pl';


# VARIABLE SCOPE is limited in this file.
local($addr);
local(*mget_list);


# fml command routine
# return NONE but ,if exist, mail back $Envelope{'message'} to the user
sub Command
{
    $0 = "--Command Mode in <$FML $LOCKFILE>";

    ##### PERMIT TO PREAMBLE AND TRAILER to the reply-mail #####
    $_cf{'ADD2BODY'} = 1;
    ############################################################

    # set parameters 
    local(@Fld);
    local($mb) = @_;
    local($MailBody) = $mb || $Envelope{'Body'};

    # How severely check address
    # $_cf{'addr-check'} to save the value for the fugure
    # $ADDR_CHECK_MAX    global variable
    $_cf{'addr-check'} = $ADDR_CHECK_MAX  = ($ADDR_CHECK_MAX || 3);

    # From_address and Original_From_address are arbitrary.
    # set Reply-To:, use "original Reply-To:" if exists
    local($to) = $_cf{'reply-to'} = $Envelope{'h:reply-to:'} || $From_address;

    # reset for reply
    $Envelope{'h:Reply-To:'} = $CONTROL_ADDRESS ? 
	"$CONTROL_ADDRESS\@".(split(/\@/, $MAIL_LIST))[1] : $MAINTAINER;

    return if 1 == &LoopBackWarn($to);
    
    # HERE WE GO!
    &InitProcedure;
    &ReConfigProcedure;

  GivenCommands: foreach (split(/\n/, $MailBody, 999)) {
      # skip null line
      next GivenCommands if /^\s*$/o; 

      # e.g. *-ctl server, not require '# command' syntax
      $_ = "# $_" if $COMMAND_ONLY_SERVER && (!/^\#/o); 

      # Illegal syntax
      if (! /^#/o) {
	  next GivenCommands unless $USE_WARNING;

	  &Log("ERROR:Command Syntax without ^#");
	  $Envelope{'message'} .= "Command Syntax Error not with ^#\n";

	  next GivenCommands;	# 'last' in old days 
      }

      # syntax check, and set the array of cmd..
      s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      @Fld = split(/\s+/, $_, 999);
      s/^#\s*//, $org_str = $_;
      $_ = $Fld[1];

      # info
      $0 = "--Command Mode processing $_: $FML $LOCKFILE>";
      &Debug("Present command    $_") if $debug;

      ########## SWITCH ##########
      # enable us to use "mget 200.tar.gz" = "get 200.tar.gz"
      (/^get$/io) && ($Fld[2] =~ /^\d+.*z$/o) && ($_ = 'mget');

      ### Procedures
      local($status, $proc);
      tr/A-Z/a-z/;

      if ($proc = $Procedure{$_}) {
	  # REPORT
	  if ($Procedure{"r#$_"}) {
	      $Envelope{'message'} .= "\n>>> $org_str\n";
	  }

	  # INFO
	  &Debug("Call               &$Procedure{$_}") if $debug;
	  $0 = "--Command calling $proc: $FML $LOCKFILE>";

	  # PROCEDURE
	  $status = &$proc($_, *Fld);

	  # NEXT
	  last GivenCommands if $status eq 'LAST';
	  next GivenCommands;
      }

      # Special hook e.g. "# list",should be used as a ML's specific hooks
      if ($COMMAND_HOOK) {
	  &CheckCommandHook($_, @Fld) || last GivenCommands;
	  &eval($COMMAND_HOOK, 'Command hook');
      }

      # if undefined commands, notify the user about it and abort.
      &Log("Unknown Cmd $_");
      $Envelope{'message'} .= ">>> $_\n\tUnknown Command: $_\n\tStop.\n";

      # stops.
      last GivenCommands;

  } # the end of while loop;

    # process for mget submissions.
    if (%mget_list) {
	&MgetCompileEntry;
	$FML_EXIT_HOOK .= '&mget3_SendingEntry;';
    }

    # return "ERROR LIST"
    if ($Envelope{'message'}) {
	$Envelope{'message:h:to'}      = $to; 
	$Envelope{'message:h:subject'} = "fml Command Status report $ML_FN";
    }
}


################## PROCEDURE SETTINGS ##################
sub InitProcedure
{
    # Backward compatibility
    $COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;

    # Command Line Options
    $COMMAND_ONLY_SERVER = 1 if $_cf{'opt', 'c'};

    # BACKUP for user-defined-set-up-data 
    local(%bak) = %Procedure;

    # SYNTAX
    # $s = $_;(present line of the given mail body)
    # $ProcFileSendBack($proc, *s);
    %Procedure = (
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
		  'mget', 'ProcMgetMakeList',
		  'mget2', 'ProcMgetMakeList',
		  'msend', 'ProcMgetMakeList',

		  # these below are not implemented, 
		  # but implemented in hml 1.6
		  # codes only for notifying the alart to the user
		  'iam',    'ProcObsolete',
		  'r#iam', 1,
		  'whois',  'ProcObsolete',
		  'r#whois', 1,
		  'who',    'ProcObsolete',
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
		  'chaddr', 'ProcSetDeliveryMode',
		  'r#chaddr', 1,
		  'change-address', 'ProcSetDeliveryMode',
		  'r#change-address', 1,
		  'change', 'ProcSetDeliveryMode',
		  'r#change', 1,

		  # Bye - Good Bye Eternally
		  'bye',         'ProcUnSubscribe',
		  'r#bye',         1,
		  'unsubscribe', 'ProcUnSubscribe',
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
		  '#dummy', '#dummy'
		  );

    # SET UP! user-defined-set-up-data 
    if (%bak) {
	%Procedure = (%Procedure, %bak);
    }
}


sub ReConfigProcedure
{
    # these below are not implemented, but implemented in hml 1.6
    # codes only for notifying the alart to the user
    if ($USE_WHOIS) {
	$Procedure{'whois'} =  'ProcWhois';
    }

    # IF USED AS ONLY COMMAND SERVER, 
    if ($COMMAND_ONLY_SERVER) {
	local($key) = $REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE;
	$Procedure{$key} = 'ProcSubscribe';
    }

    # Use Subject as a command input
    if ($USE_SUBJECT_AS_COMMANDS) {
	$Envelope{'Body'} = $Envelope{'h:Subject:'}."\n".$Envelope{'Body'};
    }
}


sub ProcFileSendBack
{
    local($proc, *Fld) = @_;

    &Log($proc);
    &SendFile($_cf{'reply-to'}, "$proc $ML_FN", $Procedure{"#$proc"});
}


sub ProcModeSet
{
    local($proc, *Fld) = @_;
    local($s) = $Fld[2]; 
    local($p) = $Fld[3] ? $Fld[3] : 1; 
    $s =~ tr/A-Z/a-z/;

    $Envelope{'message'} .= "\n>>> $proc $s $p\n";

    if ($s eq 'addr_check_max') {
	$ADDR_CHECK_MAX = $p;
    }
    elsif ($s eq 'exact') {
	$ADDR_CHECK_MAX = 9;	# return if 10;
    }
    elsif (! $_cf{'mode:admin'}) {
	$s = "$proc cannot be permitted without AUTHENTIFICATION";
	$Envelope{'message'} .= "$s\n";
	&Log($s);
	return 'LAST';
    }

    ######### HEREAFTER ADMIN COMMANDS #########

    ### CASE
    if ($s eq 'debug') {
	$_cf{'debug'}= $debug = $p;
    }

    ### LOG
    $Envelope{'message'} .= "\t$s = $p;\n";
    &Log("$proc $s = $p");
}


sub ProcSummary
{
    local($proc, *Fld) = @_;

    if ($Fld[2] && ($proc eq 'search')) {
	$Envelope{'message'} .= "\n>>> Search Key=$Fld[2] in Summary file\n\n";
	&SearchKeyInSummary($Fld[2], 's');
	&Log("Search [$Fld[2]]");
    }
    elsif ($Fld[2] && ($proc eq 'summary')) {
	$Envelope{'message'} .= "\n>>> Summary: Search KEY=$Fld[2]\n\n";
	&SearchKeyInSummary($Fld[2], 'rs');
	&Log("Restricted Summary [$Fld[2]]");
    }
    else {
	&Log("Summary");
	&SendFile($_cf{'reply-to'}, "Summary $ML_FN", $SUMMARY_FILE);
    }
}


sub ProcShowStatus
{
    local($proc, *Fld) = @_;

    &Log("Status for $Fld[2]");
    &use('utils');
    $Envelope{'message'} .= "\n>>> status for $Fld[2].\n";
    $Envelope{'message'} .= &MemberStatus($Fld[2] ? $Fld[2] : $_cf{'reply-to'})."\n";
}


sub ProcObsolete
{
    local($proc, *Fld) = @_;

    &Log("$proc[Not Implemented]");
    $Envelope{'message'} .= "Command $proc is not implemented.\n";
}


sub ProcRetrieveFileInSpool
{
    local($proc, *Fld) = @_;
    local(*cat);
    local($ID) = $Fld[2]; 

    if (&InSecureP($ID)){ 
	$Envelope{'message'} .= "\n>>> $org_str\nget $Fld[2] failed.\n";
	return 'LAST';
    }

    local($mail_file, $ar) = &ExistP($ID);# return "$SPOOL_DIR/ID" form;
    &Debug("GET: local($mail_file, $ar)") if $debug;

    if ($mail_file) { 
	$cat{"$SPOOL_DIR/$ID"} = 1;
	if ($ar eq 'TarZXF') {  
	    &use('utils');
	    &Sendmail($_cf{'reply-to'}, "Get $ID $ML_FN", 
		      &TarZXF("$DIR/$mail_file", 1, *cat));
	}
	else {
	    &SendFile($_cf{'reply-to'}, "Get $ID $ML_FN", 
		      "$DIR/$mail_file", 
		      $_cf{'libfml', 'binary'});
	    undef $_cf{'libfml', 'binary'}; # destructor
	}

	&Log("Get $ID, Success");
    } 
    else {				# or null $ID
	$Envelope{'message'} .= "\n>>> $org_str\nArticle $ID is not found.\n";
	&Log("Get $ID, Fail");
    }
}


sub ProcForward
{
    local($proc, *Fld) = @_;
    
    &Log('Msg');
    &Warn("Msg ($From_address)", 
	  $Envelope{'h:Subject:'}."\n\n".$Envelope{'Body'});

    'LAST';
}


sub ProcExit
{
    local($proc, *Fld) = @_;

    &Log("exit[$proc]");
    'LAST';
}


# Off: temporarily.
# On : Return to Mailng List
# Matome : Matome Okuri ver.2 Control Interface
# Skip : can post but not be delivered
# NOSkip : inverse above
sub ProcSetDeliveryMode
{
    local($proc, *Fld) = @_;
    local($addr) = $addr ? $addr : $From_address;
    local($c, $_, $cmd, $opt, *misc);
    local($cmd, $opt, $misc) = ($proc, $Fld[2], $Fld[3]);
    $cmd =~ tr/a-z/A-Z/;
    $_   = $cmd;

    # KEYWORDO for 'chaddr'
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

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
		$Envelope{'message'} .= "$cmd: $opt parameter not match.\n";
		$Envelope{'message'} .= "\tDO NOTHING!\n";
		return $NULL;
	    }			
	}# $c == non-nil;
	
	&Log("O.K. Try matome $c");
    }
    ###### [case 2 "matome" call the default slot value]
    elsif (/^MATOME$/i) {
	&Log("$cmd: $opt inappropriate, do nothing");
	$Envelope{'message'} .= "$cmd: $opt parameter inappropriate.\n";
	$Envelope{'message'} .= "\tDO NOTHING!\n";
	return $NULL;
    }
    ###### change address [chaddr old-addr new-addr]
    # Default: $CHADDR_KEYWORD = 'CHADDR|CHANGE\-ADDRESS|CHANGE';
    elsif (/^($CHADDR_KEYWORD)$/i) {
	$addr = $opt;
	
	# LOOP CHECK
	&LoopBackWarn($misc) && &Log("$cmd: LOOPBACk ERROR, exit") && 
	    (return $NULL);

	#ATTENTION! $addr or $misc should be a member.
	if (&CheckMember($addr, $MEMBER_LIST) || 
	    &CheckMember($misc, $MEMBER_LIST)) {
	    &Log("$cmd: OK! Either $addr and $misc is a member.");
	    $Envelope{'message'} .= "\tTry change $addr to $misc\n";
	}
	else {
	    &Log("$cmd: NEITHER $addr and $misc is a member. STOP");
	    $Envelope{'message'} .= "$cmd:\n\tNEITHER\n\t$addr nor $misc\n\t";
	    $Envelope{'message'} .= "is a member.\n\tDO NOTHING!\n";
	    return 'LAST';
	}
    }


    if (&ChangeMemberList($cmd, $addr, $ACTIVE_LIST, *misc)) {
	&Log("$cmd [$addr] $c");
	$Envelope{'message'} .= "$cmd [$addr] $c accepted.\n";
    }
    else {
	&Log("$cmd [$addr] $c failed");
	$Envelope{'message'} .= "$cmd [$addr] $c failed.\n";
    }
}


# Set the address to operate e.g. for exact matching
sub ProcSetAddr
{
    local($proc, *Fld) = @_;

    if (! $_cf{'mode:admin'}) {
	$s = "$proc cannot be permitted without AUTHENTIFICATION";
	$Envelope{'message'} .= "$s\n";
	&Log($s);
	return 'LAST';
    }

    if (&AddressMatch($Fld[2], $From_address)) {
	$addr = $Fld[2];
	$ADDR_CHECK_MAX = 10;	# exact match(trick)
	$Envelope{'message'} .= "Try exact-match for $addr.\n";
	&Log("Exact addr=$addr");
    }
    else {
	$Envelope{'message'} .= "Forbidden to use $addr,\n";
	$Envelope{'message'} .= "since $addr is too different from $From_address.\n";
	&Log("Exact addr=$addr fail");
    }
}


# Bye - Good Bye Eternally
sub ProcUnSubscribe
{
    local($proc, *Fld) = @_;

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
	return '';
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
	$Envelope{'message'} .= "$cmd [$addr] $c accepted.\n";
    }
    else {
	&Log("$cmd [$addr] $c failed");
	$Envelope{'message'} .= "$cmd [$addr] $c failed.\n";
    }

    return 'LAST';
}


sub ProcSubscribe
{
    local($proc, *Fld) = @_;

    # if member-check mode, forward the request to the maintainer
    if ($ML_MEMBER_CHECK) {
	&Log("$proc request is forwarded to Maintainer");
	&Warn("$proc request from $From_address", &WholeMail);
    }
    else {
	&use('utils');
	&AutoRegist;
    }
}


sub ProcSetAdminMode
{
    local($proc, *Fld) = @_;
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
    (!-f $PASSWD_FILE) && open(TOUCH,">> $_") && close(TOUCH);
    
    &use('remote');

    if (&CheckMember($addr, $ADMIN_MEMBER_LIST)) {
	&Log("$proc: REQUEST: " . join(" ", @Fld)) if $debug;

	$_cf{'mode:admin'} = 1;	# AUTHENTIFIED, SET MODE ADMIN

	&AdminCommand(@Fld) || do {
	    &Log("&AdminCommand return nil, STOP!");
	    return 'LAST';
	};

	$_cf{'mode:admin'} = 0;	# UNSET for hereafter
	return '';
    }
    else {
	$Envelope{'message'} .= "$proc: You are not member\n";
	&Log("$proc: ILLEGAL ADMIN COMMANDS REQUEST");
    }

    $_cf{'mode:admin'} = 0;	# UNSET for hereafter
}


sub ProcApprove
{
    local($proc, *Fld) = @_;	# 
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
    &use('remote');

    # get passwd
    shift @Fld;    shift @Fld;
    $p = shift @Fld;

    &Log("&CmpPasswdInFile($PASSWD_FILE, $addr, $p)") if $debug;

    if (&CmpPasswdInFile($PASSWD_FILE, $addr, $p)) {
	&Log("$proc: REQUEST: " . join(" ", @Fld)) if $debug;

	$_cf{'mode:admin'} = 1;	# AUTHENTIFIED, SET MODE ADMIN

	@Fld = ('#', 'admin', @Fld);
	&AdminCommand(@Fld) || do {
	    &Log("&AdminCommand return nil, STOP!");
	    return 'LAST';
	};

	$_cf{'mode:admin'} = 0;	# UNSET for hereafter

	return '';
    }
    else {
	$Envelope{'message'} .= "$proc: You are not an administrator\n";
	&Log("$proc: ILLEGAL ADMIN COMMANDS REQUEST");
    }
}


sub ProcPasswd
{
    local($proc, *Fld) = @_;
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
	$Envelope{'message'} .= "$proc: Authentified\n";
	&Log("$proc; Authentified");
	if (&ChangePasswd($PASSWD_FILE, $addr, $new)) {
	    $Envelope{'message'} .= "$proc; change passwd succeed";
	    &Log("$proc; change passwd succeed");
	}
	else {
	    $Envelope{'message'} .= "$proc; change passwd fail";
	    &Log("$proc; change passwd fail");
	}
    }
    else {
	$Envelope{'message'} .= "$proc: Illegal password\n";
	&Log("$proc: Illegal password");
    }
}


sub ProcWhois
{
    local($proc, *Fld) = @_;

    &Log("whois $Fld[2]");

    &use('utlis');
    $Envelope{'message'} .= &Whois(@Fld)."\n";
}


sub ProcIndex
{
    local($proc, *Fld) = @_;

    &Log($proc);
    $INDEX_FILE = $INDEX_FILE || "$DIR/index";
    
    if (-f $INDEX_FILE && open(F, $INDEX_FILE)) {
	$Envelope{'message'} .= <F>;
	$Envelope{'message'} .= "\n";
    }
    else {
	local($ok, $dir, $f);

	$Envelope{'message'} .= "The spool of this ML have plain format articles\n";
	$Envelope{'message'} .= "\tthe number(count) exists\n\t";
	$Envelope{'message'} .= &ProcIndexSearchMinCount;
	$Envelope{'message'} .= " <-> ";
	$Envelope{'message'} .= &GetID;
	$Envelope{'message'} .= "\n\n";
	$Envelope{'message'} .= "In 'ARCHIVE' the following files exist.\n";
	$Envelope{'message'} .= "Please 'mget' command to get them\n\n";

	$ok = 0;

      AR: foreach $dir (@ARCHIVE_DIR) {
	  next if /^\./o;

	  if ( -d $dir && opendir(DIRD, $dir) ) {
	    FILE: foreach $f (readdir(DIRD)) {
		next FILE if $f =~ /^\./;

		stat("$dir/$f");
		if (-f _) {
		    $Envelope{'message'} .= "\t$f\n";
		    $ok++;
		}
	    }# FOREACH;

	      closedir DIRD;
	  }
	  else {
	      &Log("Index:cannot open $dir");
	  }
      }	# AR:;

	$Envelope{'message'} .= "\n";
	$Envelope{'message'} .= "\tNothing.\n" unless $ok;
    }# case of file no index exists.;
}


sub ProcIndexSearchMinCount
{
    local($try)  = &GetID - 1;# seq is already +1;
    local($last) = $try;

    while(-f "$SPOOL_DIR/$try") {
	last if $try <= 1;	# ERROR
	$try  = int($try/2);
	print STDERR "ExistCheck: min /2 $try\n" if $debug;
    } 
    
    for ((!-f "$SPOOL_DIR/$try"); (!-f "$SPOOL_DIR/$try"); $try++) {
	last MIN if $try > $last; # ERROR
	print STDERR "ExistCheck: min ++ $try\n" if $debug;
    }

    print STDERR "MINIMUM ($try < 1) \? 1 \: $try\n" if $debug;
    ($try < 1) ? 1: $try;
}

sub ProcMgetMakeList
{
    local($proc, *Fld) = @_;
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


################## PROCEDURE SETTINGS ENDS ##################


# matomete get articles from the spool, then return them
# mget is an old version. 
# new version should be used as mget ver.2(mget[ver.2])
# matomete get articles from the spool, then return them
sub MgetCompileEntry
{
    local($key, $value, $Status, *fld, *value);
    local($proc) = 'mget';

    # Do nothing if no entry.
    return unless %mget_list;

    $0 = "--Command Mode loading mget library: $FML $LOCKFILE>";

    require 'SendFile.pl';

    while (($key, $value) = each %mget_list) {
	print STDERR "TRY ENTRY [$key]\t=>\t[$value]\n" if $debug;

	# options
	@fld = split(/:/, $fld = $key); 
	$fld =~ s/:/ /;

	# targets, may be multiple
	@value = split(/\s+/, $value); 

	# Process Table
	$0 = "--Command Mode mget[$key $fld]: $FML $LOCKFILE>";

	# mget3 is a new interface to generate requests of "mget"
	$fld = $key;		# to make each "sending entry"
	$Status = &mget3(*value, *fld);

	$0 = "--Command Mode mget[$key $fld] status=$Status: $FML $LOCKFILE>";

	# regardless of RETURN VALUE;
	return if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

	if ($Status) {
	    ;
	}
	else {
	    $Status = "Fail";
	    $Envelope{'message'} .= "\n>>>$proc $value $fld\n\tfailed.\n";
	    $ERROR_FLAG++;	# global
	};

	&Log("$proc:[$$] $key $fld: $Status");
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
# If multiply matched for the given address, 
# do Log [$log = "$addr"; $log_c++;]
sub ChangeMemberList
{
    local($cmd, $Address, $file, *misc) = @_;
    &GetTime;
    local($Date) = sprintf("%02d%02d", ++$mon, $mday);
    local($Status, $log, $log_c, $r, $addr, $org_addr);
    local($acct) = split(/\@/, $Address);

    &Debug("&ChangeMemberList($cmd, $Address, $file)") if $debug;
    
    if ($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file) {
	open(BAK, ">> $file.bak") || (&Log($!), return $NULL);
	select(BAK); $| = 1; select(STDOUT);
	print BAK "----- Backup on $Now -----\n";

	open(NEW, ">  $file.tmp") || (&Log($!), return $NULL);
	select(NEW); $| = 1; select(STDOUT);

	open(FILE,"<  $file") || (&Log($!), return $NULL);
    }
    else {
	&Log("Cannot match $file in ChangeMemberList");
	return $NULL;
    }

    print NEW &FML_HEADER;

    in: while (<FILE>) {
	chop;

	# If allow all people to post, OK ends here.
	if (/^\+/o) { 
	    &Log("NO CHANGE[$file] when no member check");
	    close(FILE); 
	    return ($Status = 'done'); 
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

	    $Status = 'done'; 
	    $log .= "$cmd $addr; "; $log_c++;
	}# CASE of COMMANDS;
	else {
	    &Log("ChangeMemberList:Unknown cmd = $cmd");
	}
    } # end of while loop;

    # CORRECTION; If not registerd, add the Address to SKIP
    if ($cmd eq 'SKIP' && $Status ne 'done') { 
	print NEW "$addr\ts=skip\n"; 
	$Status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close BAK;     close NEW;     close FILE;

    # protection for multiplly matching, 
    # $log_c > 1 implies multiple matching;
    # ADMIN MODE permit multiplly matching($_cf{'mode:addr:multiple'} = 1);
    ## IF MULTIPLY MATCHED
    if ($log_c > 1 && $ADDR_CHECK_MAX < 10 && (!$_cf{'mode:addr:multiple'})) {
	&Log("$cmd: Do nothing muliply matched..");
	$log =~ s/; /\n/g;
	$Envelope{'message'} .= "Multiply Matched?\n$log\n";
	$Envelope{'message'} .= "Retry to check your adderss severely\n";
	$ADDR_CHECK_MAX++;

	# Recursive Call
	print STDERR "Call ChangeM...($cmd,..[$ADDR_CHECK_MAX]);\n" if $debug;
	return &ChangeMemberList($cmd, $Address, $file);
    }
    ## IF TOO RECURSIVE
    elsif ($ADDR_CHECK_MAX >= 10) {
	&Log("MAXIMUM of ADDR_CHECK_MAX, stop");
    }
    ## DEFAULT 
    else {
	rename("$file.tmp", $file) || 
	    (&Log("fail to rename $file"), return $NULL);
    }#;

    # here should be "Only once called"
    if ($cmd eq 'MATOME' && $Status eq 'done') {
	&Log("ReConfiguring $Address in \$MSendRC");
	&ConfigMSendRC($Address);
	&Rehash($org_addr) if $org_addr;# info of original mode is required
    }

    $Envelope{'message'} .= "O.K.!\n" if $Status eq 'done';
    $Status;
}
    

sub CtlMatome
{
    local($addr, *misc) = @_;
    local($MATOME) = $misc;	# set value(0 implies Realtime deliver)
    local($org_addr) = $addr;	# save excursion
    local($s);

    # parameter is whether 0 or not-defiend
    if (! $MATOME) {
	# modification
	if ($addr =~ /\smatome/oi || $addr =~ /\sm=/) {
	    $MATOME = 'RealTime';
	}
	# new comer, set default
	else {
	    $MATOME = 3;
	    $s = "Hmm.. no given parameter. use default[m=3]";
	    &Log($s);
	    $Envelope{'message'} .= "$s\n";
	    $Envelope{'message'} .= 
		"So your request is accepted but modified to m=3\n";
	}
    }

    # Remove the present matomeokuri configuration
    $addr =~ s/^(.*)matome/$1/ig; # backward compatibility
    $addr =~ s/\sm=(\S+)//ig; # remover m= syntax

    # Set value
    if ($MATOME eq 'RealTime') {    # 'call &Rehash'
	;
    }
    else {
	$addr = "$addr\tm=$MATOME";
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
    $Envelope{'message'} .= "\n$s\n\n";

    # make an entry 
    local(@fld) = ('#', 'mget', "$l-$r", 10, $mode);

    ($l <= $r) && &ProcMgetMakeList('Rehash:EntryIn', *fld);

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
	    $Envelope{'message'} .= "NOT permit META Char's in parameters.\n";
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
	$Envelope{'message'} .= "Restricted Summary: the parameter not matched\n";
	return;
    }

    open(TMP, $SUMMARY_FILE) || do { &Log($!); return;};
    if($fl eq 'rs') {
	while(<TMP>) {
	    if(/\[$a:/ .. /\[$b:/) {
		$Envelope{'message'} .= $_;
	    }
	}
    }
    elsif($fl eq 's') {
	while(<TMP>) {
	    if(/$s/) {
		$Envelope{'message'} .= $_;
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
