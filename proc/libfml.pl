# Copyright (C) 1993-2002 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2002 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

&Command() if $LOAD_LIBRARY eq 'libfml.pl';


# VARIABLE SCOPE is limited in this file.
local($Addr, %mget_list);


# Backward Compat for &Command($command) Syntax;
sub Command 
{ 
    local($cmd) = @_; 
    local($status);

    &Debug("DoProcedure($cmd, *Envelope);") if $debug;

    $status = &DoProcedure($cmd, *Envelope);

    $status;
}


# fml command routine
# return NONE but ,if exist, mail back $e{'message'} to the user
sub DoProcedure
{
    $0 = "${FML}: Command Mode in <$LOCKFILE>";

    # Rcsid offers usefu Information for you;
    # !~ fix (pointed out by ando@iij-mc.co.jp (by irc :))
    if ($Envelope{'mode:commandonly'} || $Envelope{'mode:ctladdr'} ||
	$COMMAND_ONLY_SERVER) {

	if ($Rcsid !~ /fml commands only mode/) {
	    $Rcsid .= "(fml commands only mode)";
	}
    }
    else {
	if ($Rcsid !~ /fml commands mode/) { $Rcsid .= "(fml commands mode)";}
    }

    ##### Initialize local variables #####
    local($mb, *e) = @_;
    local(@Fld, $misc, @misc, %misc, $to, $mailbody, $org_str);
    local($trap_counter);
    $to       = $e{'Addr2Reply:'}; # backward compatible (for COMMAND_HOOK);
    $mailbody = $mb || $e{'Body'}; # XXX malloc() too much?

    # Security: Mail Traffic Information
    if ($USE_MTI) { 
	&use('mti'); 
	&MTICache(*e, 'command');
	return $NULL if &MTIError(*e);
    }

    # special traps
    local($subscribe_key, $confirm_key);
    $subscribe_key = $REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE || 'subscribe';
    $confirm_key   = $CONFIRMATION_KEYWORD || 'confirm';

    # Use Subject as a command input;
    # PATCHED 95/12/29 kise@ocean.ie.u-ryukyu.ac.jp
    if ($USE_SUBJECT_AS_COMMANDS) { 
	$mailbody = $e{'h:subject:'}."\n".$mailbody;
	$mailbody =~ s/^\s*//;
    }

    # reset for reply
    # $FORCE_COMMAND_REPLY_TO is a backwad compat key;
    $e{'GH:Reply-To:'} = $e{'GH:Reply-To:'} || 
	$FORCE_COMMAND_REPLY_TO || $e{'CtlAddr:'};	
	
    # Loop Back Check
    return if 1 == &LoopBackWarn($e{'Addr2Reply:'});

    # HERE WE GO!
    &InitProcedure;
    &ReConfigProcedure;

    # WE SHOULD NOT CHANGE THE KEYWORD "GivenCommands" for "backward compat";
    local($status, $proc, $fp, $input_command_count, $linenum);
    local($limit, $history);
    $linenum = 0;

    # each line <= 128 bytes 
    my ($max_len) = &ATOI($MAXLEN_COMMAND_INPUT) || 128;

    # ATTENTION!
    # if $USE_SUBJECT_AS_COMMANDS != NULL,
    # $mailbody != $Envelope{'Body'};
  GivenCommands: for $xbuf (split(/\n/, $mailbody)) {
      $linenum++; # line number (!= %Envelope under subject: command)
      $_PCB{'proc'}{'buf_linep'} = $e{'tmp:line_number'} = $linenum;

      &Log("proc debug: input [$xbuf]") if $debug;

      # check each line length
      if (length($xbuf) > $max_len) {
	  &Mesg(*e, "> ". $xbuf);
	  &Mesg(*e, "   ERROR: ignore too long command ( >= $max_len bytes)");
	  my ($xxbuf) = substr($xbuf, 0, $max_len);
	  &Log("ignore too long command: ". $xxbuf . " ...");
	  next;
      }

      # skip null line
      next GivenCommands if $xbuf =~ /^\s*$/o;

      # counter
      $trap_counter++ if $xbuf =~ /^\#/;

      # reset variables
      # dup the current mesg to report to admin
      undef $e{'mode:message:to:admin'};

      # history buffer
      $history .= "\t". $xbuf. "\n"; 

      # XXX: CTK
      # e.g. *-ctl server, not require '# command' syntax
      # bug default has been false(not rewrite), true 198/01/19	
      if ($COMMAND_ONLY_SERVER && ($xbuf !~ /^\#/o)) {
	  &Log("Procedure: command only server") if $debug;
	  $xbuf = "\# $xbuf";
      }
      elsif (($e{'mode:ctladdr'} || $e{'mode:uip'}) && ($xbuf !~ /^\#/o)) {
	  &Log("Procedure: mode:ctladdr") if $debug;
	  for $p (keys %Procedure) {
	      if ($p && $xbuf =~ /^$p/i) {
		  # &Log("recognize $p => '# $p'"); # XXX: not log
		  $xbuf = "\# $xbuf"; # XXX: internal representation
	      }
	  }
      }
      else {
	  &Log("Procecure: neither command only nor mode:ctladdr") if $debug;	  
      }
      
      if ($debug) {
	  $xbuf =~ /^\#\s*(\w+)/ && &Log("proc debug: trap $`<$&>$'") || 
	      &Log("proc debug: invalid input? [$xbuf]");
      }

      # special traps when auto_regist mode;
      # e.g. even when permit from "anyone" mode, auto_regist works
      if ($REJECT_COMMAND_HANDLER eq "auto_regist" && 
	  $xbuf =~ /^($subscribe_key|$confirm_key)/i)  {
	  $xbuf = "\# $xbuf"; # XXX: CTK interal representation

	  # fml-support: 03100 <kishiba@ipc.hiroshima-u.ac.jp>
	  # we should consider this special case without "^#"
	  $trap_counter++; 
      }

      # check '# in-secre-matching-pattern ...'
      # XXX: CTK internal representation
      # against the signature (NOT COMMAND_ONLY)
      # \w == [0-9A-Za-z_]
      if ($xbuf =~ /^\#\s*(\w+)/) {
	  $try = $1;
	  $try =~ tr/A-Z/a-z/;
	  if (! ($Procedure{$try} || $Procedure{"#$try"})) {
	      &Log("warn: command [$try] not found in \%Procedure");
	  }
      }
      else { # if ($xbuf !~ /^\#\s*\w+/) 
	  # USE_WARNING = 0 (default), so go to the next line in usual.
	  next GivenCommands unless $USE_INVALID_COMMAND_WARNING; 
	  next GivenCommands unless $USE_WARNING; # backward

	  # XXX: (internally converted, so) already "# command" in usual
	  &Log("Command: SYNTAX ERROR /\# \\w+/ !~ [$xbuf]");
	  &Mesg(*e, "Command SYNTAX ERROR: without ^#") if $xbuf !~ /^\#/;
	  &Mesg(*e, "Command SYNTAX ERROR: expect \"# English-word\"") 
	      if $xbuf !~ /^\#\s*\w+/;

	  next GivenCommands;	# 'last' in old days 
      }


      ### THIS STAGE; string is a candidate of command sets;
      print STDERR "SECURE CHECK IN>$xbuf\n" if $debug;
      &SecureP($xbuf, $xbuf =~ /admin|approve/i ? "admin" : "command") ||
	  last GivenCommands;
      print STDERR "SECURE CHECK OK>$xbuf\n" if $debug;

      ### syntax check, and set the array of cmd..
      # XXX: (internally converted, so) already "# command" in usual
      $xbuf =~ s/^#(\S+)(.*)/# $1 $2/ if $COMMAND_SYNTAX_EXTENSION;
      $Fld = $xbuf;		# preserve the original string;
      @Fld = split(/\s+/, $xbuf);

      # XXX: internal representation; "# command" => "command" for convenience
      $xbuf =~ s/^#\s*//;
      $org_str = $xbuf;
      $xbuf = $Fld[1];

      # counter
      if ($MAXNUM_COMMAND_INPUT = &ATOI($MAXNUM_COMMAND_INPUT)) {
	  &Log("$input_command_count++ >= $MAXNUM_COMMAND_INPUT");
	  if ($input_command_count++ >= $MAXNUM_COMMAND_INPUT) {
	      &Log("input commans >= $MAXNUM_COMMAND_INPUT, force to a stop");
	      &Mesg(*e, 'too many ocmmands in one mail', 
		    'resource.exceed_max_command_input');
	      &Mesg(*e, "FYI: The following requests are processed.");
	      &Mesg(*e, $history);
	      last GivenCommands;
	  }
      }

      ### info
      $0 = "${FML}: Command Mode processing $xbuf: $LOCKFILE>";
      &Log("proc debug: eval [$xbuf]") if $debug;
      &Debug("Present command    $xbuf") if $debug;

      ### Special Syntax Modulation
      # enable us to use "mget 200.tar.gz" = "get 200.tar.gz"
      # EXCEPT FOR 'get \d+', get -> mget.
      if ($xbuf =~ /^(get|send)$/io && ($Fld[2] !~ /^\d+$/o)) { 
	  $xbuf = 'mget';
	  $MGET_MODE_DEFAULT = 'mp';
      }

      ### Procedures
      undef $status; undef $proc; undef $fp;
      $xbuf =~ tr/A-Z/a-z/;

      # extract each proc local message buffer (e.g. for plural "chaddr")
      &MesgSetBreakPoint;

      if ($proc = $Procedure{$xbuf}) {
	  $trap_counter++; # found in %Procedure;

	  # REPORT TO ADMINS ALSO 
	  if ($Procedure{"r2a#$xbuf"}) { &EnableReportForw2Admin(*e);}

	  if ($Procedure{"confirm#$xbuf"} &&
	      (! $Procedure{"confirm_r2a#$xbuf"})) { 
	      &DisableReportForw2Admin(*e);
	  }

	  # REPORT
	  if ($Procedure{"r#$xbuf"}) {
	      # hide the password;
	      if ($org_str =~ /^(admin|approve)/i) {
		  $org_str =~ s/(approve\s+)\S+/$1********/i;
		  $org_str =~ s/(\s+pass.*\s+)\S+/$1********/g;
	      };

	      &Mesg(*e, "\n>>> $org_str");
	      $o = $xbuf;
	      $xbuf = $o;
	  }

	  # LIMIT
	  if ($limit = $Procedure{"l#$xbuf"}) {
	      $ProcedureLimitCount{$xbuf}++;
	      if ($ProcedureLimitCount{$xbuf} > $limit) {
		  &Log("$xbuf command exceeds the limit $limit, STOP");
		  local($s);
		  $s .= "*** ";
		  $s .= "Sorry, we suppress the maximum number of requests\n";
		  $s .= "*** for $xbuf command in one mail up to $limit.\n";
		  $s .= "*** STOP PROCESSING IMMEDIATELY.\n";
		  &Mesg(*e, $s, 'resource.exceed_max_proc_req',$xbuf,$limit);
		  &Mesg(*e, "FYI: The following requests are processed.");
		  &Mesg(*e, $history);
		  last GivenCommands;
	      }
	  }

	  # INFO
	  &Debug("Call               &$Procedure{$xbuf}") if $debug;
	  $0 = "${FML}: Command calling $proc: $LOCKFILE>";

	  # PROCEDURE
	  $status = &$proc($xbuf, *Fld, *e, *misc);

	  &Debug("Addr=$Addr") if $Addr;
	  
	  # NEXT
	  &Log("status=[$status]") if $debug_proc;
	  last GivenCommands if $status eq 'LAST';
	  next GivenCommands;
      }

      # Special hook e.g. "# list",should be used as a ML's specific hooks
      eval $COMMAND_HOOK; 
      &Log("COMMAND_HOOK ERROR", $@) if $@;

      # if undefined commands, notify the user about it and abort.
      &Log("unknown command [$xbuf]");
      &Mesg(*e, ">>> $xbuf\n\tUnknown Command: $xbuf");
      &Mesg(*e, $NULL, 'no_such_command', $xbuf);

      # stops.
      &Mesg(*e, "\tStop.");
      last GivenCommands;

  } # the end of while loop;

    # process for mget submissions.
    if (%mget_list) {
	&use('sendfile');
	&MgetCompileEntry(*e);
	if ($FmlExitHook{'mget3'} !~ /mget3_SendingEntry/) {
	    $FmlExitHook{'mget3'} .= '&mget3_SendingEntry;';
	}
	undef %mget_list;#role ends & should expire for multiple'ML handling
    }

    # return "ERROR LIST"
    if ($e{'message'}) {
	$e{'message:h:to'}      = $e{'Addr2Reply:'};
	$e{'message:h:subject'} = "fml Command Status report $ML_FN";
    }

    # help
    if ($Envelope{'mode:ctladdr'} && 
	(!$trap_counter) && (!$COMMAND_ONLY_SERVER)) {
	local($s);

	$s .= "*" x 60;
	$s .= "\nFor Your Information:\n";
	if ($CONTROL_ADDRESS) {
	    $s .= "Address \"$CONTROL_ADDRESS\" is for fml commands.\n";
	    $s .= "Your mail DOES NOT include any effective command.\n";
	    $s .= "Please read the following HELP for FML usage.\n";
	    $s .= "*" x 60;
	    &Mesg(*e, $s, 'info.procfail.ctladdr', $CONTROL_ADDRESS);
	}
	else {
	    $s .= "If you have a problem, ";
	    $s .= "please contact ML maintainer.\n";
	    $s .= "Address for a ML maintainer is <$MAINTAINER>.\n";
	    $s .= "*" x 60;
	    &Mesg(*e, $s, 'info.procfail.noctladdr', $MAINTAINER);
	}

	if (-r $HELP_FILE) {
	    $e{'message:append:files'} = $HELP_FILE;
	}
	else {
	    ; # XXX we should emulate help file ???
	}
    }
}


############################################################
### PROCEDURE SETTINGS 
############################################################

sub InitProcedure
{
    # Backward compatibility
    $COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;

    # Command Line Options
    $COMMAND_ONLY_SERVER = 1 if $Opt{'opt:c'};

    # Initialize for libmember_name.pl
    &use('member_name') if $USE_MEMBER_NAME;

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
		    # Database Access
		    'dbd#members',  'dump_member_list',
		    'dbd#member',   'dump_member_list',

		    # return a active file of Mailing List
		    'actives',  'ProcFileSendBack',
		    '#actives',    $ACTIVE_LIST,
		    'active',  'ProcFileSendBack',
		    '#active',    $ACTIVE_LIST,
		    # Database Access
		    'dbd#actives',  'dump_active_list',
		    'dbd#active',   'dump_active_list',


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
		    # get limit
		    'l#get',      10,
		    'l#getfile',  10,
		    'l#sendfile', 10,
		    'l#sendfile', 10,

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
		    # codes only for notifying the alert to the user
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
		    'digest', 'ProcSetDeliveryMode',
		    'r#digest', 1,
		    'unmatome', 'ProcSetDeliveryMode2',
		    'r#unmatome', 1,
		    'undigest', 'ProcSetDeliveryMode2',
		    'r#undigest', 1,

		    'skip',   'ProcSetDeliveryMode',
		    'r#skip', 1,
		    'noskip', 'ProcSetDeliveryMode',
		    'r#noskip', 1,

		    # Bye - Good Bye Eternally
		    'chaddr',         'ProcSetMemberList',
		    'r#chaddr', 1,
		    'r2a#chaddr', 1,
		    'change-address', 'ProcSetMemberList',
		    'r#change-address', 1,
		    'r2a#change-address', 1,
		    'change',         'ProcSetMemberList',
		    'r#change', 1,
		    'r2a#change', 1,

		    # if under confirmation, do not report
		    'confirm#chaddr',         $CHADDR_AUTH_TYPE,
		    'confirm#change-address', $CHADDR_AUTH_TYPE,
		    'confirm#change',         $CHADDR_AUTH_TYPE,
		    'confirm_r2a#chaddr',         ($CHADDR_AUTH_TYPE ? 0 : 1),
		    'confirm_r2a#change-address', ($CHADDR_AUTH_TYPE ? 0 : 1),
		    'confirm_r2a#change',         ($CHADDR_AUTH_TYPE ? 0 : 1),

		    # confirmation mode chaddr
		    'chaddr-confirm',  'ProcSetMemberList',
		    'r#chaddr-confirm', 1,
		    'r2a#chaddr-confirm', 1,


		    'bye',            'ProcSetMemberList',
		    'r#bye',         1,
		    'r2a#bye',         1,
		    'unsubscribe',    'ProcSetMemberList',
		    'r#unsubscribe', 1,
		    'r2a#unsubscribe', 1,

		    # if under confirmation, do not report
		    'confirm_r2a#bye', ($UNSUBSCRIBE_AUTH_TYPE ? 0 : 1),
		    'confirm_r2a#unsubscribe', ($UNSUBSCRIBE_AUTH_TYPE? 0 : 1),
		    'confirm#bye',         $UNSUBSCRIBE_AUTH_TYPE,
		    'confirm#unsubscribe', $UNSUBSCRIBE_AUTH_TYPE,

		    # confirmation mode unsubscribe
		    'unsubscribe-confirm',  'ProcSetMemberList',
		    'r#unsubscribe-confirm', 1,
		    'r2a#unsubscribe-confirm', 1,

		    # Subscribe
		    ($REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE || 'subscribe'), 'ProcSubscribe',
		    'r#subscribe', 1,

		    # confirmation (for when form anyone)
		    ($CONFIRMATION_KEYWORD || 'confirm'), 'ProcSubscribe',
		    'r#subscribe', 1,

		    # confirmd
		    'ack', 'ProcConfirmdAckReply',

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

		    # moderated mode
		    'moderator', 'ProcModerator',
		    );


    ### Local
    local($k, $v);

    ### OVERWRITE by system for the extension
    while (($k, $v) = each %ExtProcedure) { $proc{$k} = $v;}

    ### OVERWRITE by user-defined-set-up-data (%LocalProcedure)
    ### REDEFINE  by @PermitProcedure and @DenyProcedure
    ### but --makefml mode permits all + local functions on shell

    # IF @PermitProcedure, PERMIT ONLY DEFINED FUNCTIONS;
    if (@PermitProcedure && (! $e{'mode:makefml'}))  { 
	for $k (@PermitProcedure) { 
	    $Procedure{$k}     = $proc{$k};
	    $Procedure{"#$k"}  = $proc{"#$k"}  if $proc{"#$k"};
	    $Procedure{"r#$k"} = $proc{"r#$k"} if $proc{"r#$k"};
	    $Procedure{"r2a#$k"} = $proc{"r2a#$k"} if $proc{"r2a#$k"};
	}
    }
    # PERMIT ALL FUNCTIONS
    else {
	%Procedure = %proc;
    }

    # OVERLOAD USER-DEFINED FUNCTIONS
    while (($k, $v) = each %LocalProcedure) { $Procedure{$k} = $v;}

    # IF @DenyProcedure, Delete DEFIEND FUNCTIONS
    if (@DenyProcedure && (! $e{'mode:makefml'})) {
	foreach $k (@DenyProcedure) { undef $Procedure{$k};}
    }

    if ($debug_procedure && 
	(@PermitProcedure || %LocalProcedure || @DenyProcedure)) {
	while (($key, $value) = each %Procedure) {
	    printf STDERR "\tProcedure %15s => %s\n", $key, $value;
	}
    }
    
    if ($PROCEDURE_CONFIG_HOOK) {
	&eval($PROCEDURE_CONFIG_HOOK, 'Procedure hook'); 
    }
}


# 1.6.1 whois becomes a standard.
sub ReConfigProcedure
{
    # IF USED AS ONLY COMMAND SERVER, 
    if ($COMMAND_ONLY_SERVER) {
	local($key) = $AUTO_REGISTRATION_KEYWORD || $DEFAULT_SUBSCRIBE;
	$Procedure{$key} = 'ProcSubscribe';
    }

    # permit arbitrary phrase when passwored related commands come in.
    %SecureRegExp = 
	('admin', 
	 '(#\s*|\s*)admin\s+(initpass|initpasswd|pass|password|passwd)\s+[\#\s\w\-\[\]\?\*\.\,\@\:]+',
	 'in_admin', 
	 '\s*(initpass|initpasswd|pass|password|passwd)\s+[\#\s\w\-\[\]\?\*\.\,\@\:]+',
	 );
}


sub ProcFileSendBack
{
    local($proc, *Fld, *e, *misc) = @_;
    local(@to, $subject, $f, @files, $draft, $draft_dir, @tmp);
    local($ignore_mode);

    # we use when dbdirective is defined, 
    # for example, in 'dump_*_list' cases.
    if ($USE_DATABASE && $Procedure{"dbd#$proc"}) {
	&use('databases');

	my ($dbdirective) = $Procedure{"dbd#$proc"};
	&Log("Directive => $dbdirective") if $dbdirective;

	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, $dbdirective);
	$f = $mib{'_cache_file'};

	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc);
	&Log("fail to do $dbdirective") if $mib{'error'};
	return $NULL if $mib{'error'};
    }
    # file to send back
    # ADMIN MODE
    elsif ( $e{'mode:admin'} ) {
	$f = $AdminProcedure{"#$proc"};
    }
    # USER MODE
    else {
	# IN actives, ignore all ^#
	# BUT IN members, ignore the first header and ^\#\# sequences
	# $e{'mode:doc:ignore#'} = 'a';
	$ignore_mode = 1;

	$f = $Procedure{"#$proc"};
    }

    # IF THE FILE TO SEND BACK DOES NOT EXIST, 
    # TRY TO AUTO CONVERT AND SEND BACK IT
    # e.g. s/_ML_/$ml/g; s/_DOMAIN_/$DOMAINNAME/g; s/_FQDN_/$FQDN/g;
    if (! -f $f) {
	$draft  = $f;
	$draft  =~ s#(.*)/([^/]*)#$2#;
	$f = &SearchFileInLIBDIR("drafts/$LANGUAGE/$draft") || $f;
	$Envelope{'mode:doc:repl'} = 1;
    }
    &Log("send $f");
    &Log($proc);

    # To:
    push(@to, $e{'Addr2Reply:'});

    # Subject:
    $subject = "$proc $ML_FN";

    # files to send
    if ($f eq $MEMBER_LIST) { 
	push(@files, $MEMBER_LIST); push(@files, @MEMBER_LIST);
    }
    elsif ($f eq $ACTIVE_LIST) { 
	push(@files, $ACTIVE_LIST); push(@files, @ACTIVE_LIST);
    }
    else {
	push(@files, $f);
    }

    &Uniq(*files);

    if ($proc =~ /member/i) { # $f eq $MEMBER_LIST) { 
	$e{'mode:doc:ignore#'} = 'm' if $ignore_mode;
    }
    elsif ($proc =~ /active/i) {  # $f eq $ACTIVE_LIST) { 
	$e{'mode:doc:ignore#'} = 'a' if $ignore_mode;
    }


    # ordinary people should not know $ADMIN_MEMBER_LIST content. 
    if (! $e{'mode:admin'}) {
	for (@files) {
	    next if $_ eq $ADMIN_MEMBER_LIST;
	    push(@tmp, $_);
	}

	@files = @tmp;
    }

    &SendPluralFiles(*to, *subject, *files);
    undef $Envelope{'mode:doc:repl'};	# off
    undef $e{'mode:doc:ignore#'};

    1;
}


sub ProcModeSet
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s) = $Fld[2]; 
    local($p) = $Fld[3] ? $Fld[3] : 1; 
    $s =~ tr/A-Z/a-z/;

    &Mesg(*e, "\n>>> $proc $s $p");

    if ($s eq 'addr_check_max') {
	$ADDR_CHECK_MAX = $p;
    }
    elsif ($s eq 'exact') {
	$ADDR_CHECK_MAX = 9;	# return if 10;
    }
    elsif (! $e{'mode:admin'}) {
	$s = "$proc cannot be permitted without AUTHENTICATION";
	&Mesg(*e, $s);
	&Mesg(*e, $NULL, 'EACCES');
	&Log($s);
	return 'LAST';
    }

    ######### HEREAFTER ADMIN COMMANDS #########

    ### CASE
    if ($s eq 'debug') {
	$_PCB{'debug'} = $debug = $p;
    }

    ### LOG
    &Mesg(*e, "\t$s = $p;");
    &Log("$proc $s = $p");
}


sub ProcSummary
{
    local($proc, *Fld, *e, *misc) = @_;

    &use('lop');
    &DoSummary(@_);
}


sub ProcShowStatus
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("Status for $Fld[2]");
    &use('lop');
    &Mesg(*e, ">>> status $Fld[2]");
    &Mesg(*e, "    status check for [".($Fld[2] || $From_address)."]\n");
    &Mesg(*e, &MemberStatus($Fld[2] || $From_address));
}


sub ProcObsolete
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc[Not Implemented]");
    &Mesg(*e, "Command $proc is not implemented.");
    &Mesg(*e, $NULL, 'ENOSYS');
}


sub ProcRetrieveFileInSpool
{
    local($proc, *Fld, *e, *misc) = @_;
    local(*cat, $mail_file, $ar);
    local($ID) = $Fld[2]; 

    ($mail_file, $ar) = &ExistP($ID);# return "$SPOOL_DIR/ID" form;
    &Debug("ProcRetrieveFileInSpool:(file=$mail_file, ar=$ar)") if $debug;

    if ($mail_file) { 
	if ($COMPAT_FML20) {
	    require 'libcompat_fml20.pl';
	    &ProcRetrieveFileInSpool_FML_20($proc, *Fld, *e, *misc, *cat, 
					    $ar, $mail_file);
	}
	else {
	    &use('lop');
	    &ResentForwFileInSpool($proc, *Fld, *e, *misc, *cat, 
				   $ar, $mail_file);
	}
    } 
    else {				# or null $ID
	&Mesg(*e, "\n>>> $org_str\nArticle $ID is not found.");
	&Mesg(*e, $NULL, 'no_such_article', $ID);
	&Log("Get $ID, Fail");
    }
}


sub ProcForward
{
    local($proc, *Fld, *e, *misc) = @_;
    
    &Log('Msg');

    # XXX malloc() too much?
    &Warn("Msg ($From_address)", 
	  "*** Forwarded Message to the maintainer ***\n".
	  "From: $From_address\n".
	  "Subject: $e{'h:Subject:'}\n\n".$e{'Body'});

    'LAST';
}


sub ProcExit { &Log("exit[$proc]"); 'LAST';}


# ($ProcName, *FieldName, *Envelope, *misc)
# $misc      : E-Mail-Address to operate WHEN CHADDR (OBSOLETE 96/10/11)
# $misc      : Digest Parameter          WHEN MATOME or DIGEST
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
    local($status);

    &use('amctl');

    $e{'mode:in_amctl'} = 1;
    &SaveACL;
    $status = &DoSetDeliveryMode($proc, *Fld, *e, *misc);
    &RetACL;
    $e{'mode:in_amctl'} = 0;

    $status;
}


sub ProcSetDeliveryMode2
{
    local($proc, *Fld, *e, *misc) = @_;
    local($save_f, @save_f); 

    $save_f = $proc;
    @save_f = @Fld;

    if ($proc =~ /matome/i) {
	$proc = 'matome';
	@Fld = ('#', 'matome', 0); # XXX: "# command" is internal represention
    }
    elsif ($proc =~ /digest/i) {
	$proc = 'digest';
	@Fld = ('#', 'digest', 0);
    }
    else {
	&Log("ProcSetDeliveryMode2: unknown proc=$proc");
    }

    &ProcSetDeliveryMode($proc, *Fld, *e, *misc);

    $proc = $save_f;
    @Fld  = @save_f;
}


# ($ProcName, *FieldName, *Envelope, *misc)
# $misc      : E-Mail-Address to operate WHEN CHADDR (OBSOLETE 96/10/11)
# $misc      : Digest Parameter          WHEN MATOME or DIGEST
# $FieldName : "# procname opt1 opt2" FORM
#
# Bye - Good Bye Eternally
sub ProcSetMemberList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($status, $s);

    &Log("ProcSetMemberList: $proc") if $debug_confirm || $debug;

    ### UNSUBSCRIBE CONFIRMATION (if not admin mode ;)
    if (($proc eq 'unsubscribe' || $proc eq 'bye') &&
	(! $e{'mode:admin'})) {
	if ($UNSUBSCRIBE_AUTH_TYPE eq 'confirmation') {
	    &use('confirm');
	    &ConfirmationModeInit(*e, 'unsubscribe');

	    local(@addr) = split(/\@/, $From_address);
	    $s = join(" ", "unsubscribe", @addr);

	    &Confirm(*e, $From_address, $s) || return $NULL;
	}
    }
    elsif ($proc eq 'unsubscribe-confirm') {
	&use('confirm');
	&ConfirmationModeInit(*e, 'unsubscribe');
	&Confirm(*e, $From_address, join(" ", @Fld)) || return $NULL;
    }

    ### CHADDR CONFIRMATION
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';    
    if ($CHADDR_AUTH_TYPE eq 'confirmation' && (! $e{'mode:admin'})) {
	if ($proc =~ /^($CHADDR_KEYWORD)$/i) {
	    &use('trap');
	    return &Trap__ChaddrRequest(*e);
	}
	elsif ($proc eq 'chaddr-confirm') {
	    &use('trap');
	    return &Trap__ChaddrConfirm(*e);
	}
    }

    # XXX disable default reply-to (sender) in handling chaddr command.
    # XXX tell special treatment to __Notify() via $DisableInformToSender.
    unless ($ChaddrReplyTo) {
	if ($proc =~ /$CHADDR_KEYWORD/) {
	    $DisableInformToSender = 1;
	    $ChaddrReplyTo = $CHADDR_REPLY_TO;
	}
    }

    &use('amctl');
    $e{'mode:in_amctl'} = 1;
    &SaveACL;
    $status = &DoSetMemberList($proc, *Fld, *e, *misc);
    &RetACL;
    $e{'mode:in_amctl'} = 0;

    $status;
}


sub FML_SYS_SetMemberList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($status);

    &use('amctl');
    $e{'mode:in_amctl'} = 1;
    &SaveACL;
    $status = &DoSetMemberList($proc, *Fld, *e, *misc);
    &RetACL;
    $e{'mode:in_amctl'} = 0;

    $status;
}


# Set the address to operate e.g. for exact matching
sub ProcSetAddr
{
    local($proc, *Fld, *e, *misc) = @_;

    $s = "$proc is removed in fml 2.2 Release.\n";
    &Mesg(*e, $s);
    &Log($s);
    &Mesg(*e, $NULL, 'obsolete_command', $proc, 'fml 2.2');
    return 'LAST';

    if (&AddressMatch($Fld[2], $From_address)) {
	$Addr = $Fld[2];
	$ADDR_CHECK_MAX = 10;	# exact match(trick)
	&Mesg(*e, "try exact matching for $Addr.");
	&Log("set exact-address $Addr");
    }
    else {
	local($addr) = $Fld[2];
	&Mesg(*e, "Forbidden to use $addr,");
	&Mesg(*e, "since $addr is too different from $From_address.");
	&Log("failed to set exact-address $Addr");
    }
}


sub ProcSubscribe
{
    local($proc, *Fld, *e, *misc) = @_;
    local($buf) = $Fld;

    # if member-check mode, forward the request to the maintainer
    if (&NonAutoRegistrableP) {
	&Log("$proc request is forwarded to Maintainer", *e);
	&Mesg(*e, 
	      "$proc request is forwarded to Maintainer".
	      "Please wait a little",
	      'req.subscribe.forwarded_to_admin', $proc);
	&WarnE("$proc request from $From_address", $NULL);
    }
    else {
	&use('amctl');

	# XXX: "# command" is internal represention
	# cut the mode switch keyword
	$buf =~ s/^\#\s*//;
	&AutoRegist(*e, $buf);
    }
}


sub ProcSetAdminMode
{
    local($proc, *Fld, *e, *misc) = @_;

    # REMOTE PERMIT or NOT?
    if ($REMOTE_ADMINISTRATION) {
	;
    }
    else {
	&Log("ILLEGAL REQUEST $proc mode, STOP!",
	     "Please \$REMOTE_ADMINISTRATION=1; for REMOTE-ADMINISTRATION");
	&Mesg(*e, "   ERROR: remote maintenance service unavailable.");
	&Mesg(*e, $NULL, 'EACCES');
	return 'LAST';
    }
    
    &use('ra');	# remote -> ra
    &DoSetAdminMode(@_);
}


sub ProcApprove
{
    local($proc, *Fld, *e, *misc) = @_;

    # REMOTE PERMIT or NOT?
    if (! $REMOTE_ADMINISTRATION) {
	&Log("ILLEGAL REQUEST $proc mode, STOP!",
	     "Please \$REMOTE_ADMINISTRATION=1; for REMOTE ADMINISTRATION");
	&Mesg(*e, "   ERROR: remote maintenance service unavailable.");
	&Mesg(*e, $NULL, 'EACCES');
	return 'LAST';
    }
    
    # INCLUDE Libraries
    &use('crypt');
    &use('ra');	# remote -> ra
    &DoApprove(@_);
}


sub ProcPasswd
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("ProcPasswd: $Fld[2] -> $Fld[3]") if $debug;

    &use('crypt');
    &DoPasswd(@_);
}


sub ProcIndex
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s);

    &Log($proc);
    &DoIndex(@_);
}

sub DoIndex
{    
    local($proc, *Fld, *e, *misc) = @_;
    local($s, $lower, $upper);

    require 'ctime.pl';

    $lower = &DoIndexSearchMinCount();
    $upper = &GetID - 1; # seq is already +1;

    if (-f $INDEX_FILE && open(F, $INDEX_FILE)) {
	&Mesg(*e, <F>);
    }
    else {
	local($ok, $dir, $f);
	if ($lower < &GetID) {
	    $s .= "The spool of this ML have plain format articles\n";
	    $s .= "\tthe number(count) exists\n\t$lower <-> $upper";
	    &Mesg(*e, $s);
	}
	else {
	    &Mesg(*e, "NO plain format articles\n");
	}

	&Mesg(*e, "In 'ARCHIVE' the following files exist.");
	&Mesg(*e, "Please 'mget' command to get them\n");

	local($size, $mtime);
	$ok = 0;
      AR: for $dir (@ARCHIVE_DIR) {
	  next if /^\./o;

	  &Mesg(*e, "\n$dir:") if $INDEX_SHOW_DIRNAME;

	  if (-d $dir && opendir(DIRD, $dir) ) {
	    FILE: foreach $f (sort readdir(DIRD)) {
		next FILE if $f =~ /^\./;

		($size, $mtime) = (stat("$dir/$f"))[7,9];
		if (-f _) {
		    &Mesg(*e, sprintf("   %-20s  %10d bytes", $f, $size));
		    $ok++;
		}
	    }# FOREACH;

	      closedir DIRD;
	  }
	  else {
	      &Log("Index:cannot opendir $dir");
	  }
      }	# AR:;

	&Mesg(*e, "");
	&Mesg(*e, "\tNothing.") unless $ok;
    }# case of file no index exists.;
}


sub FindRange
{
    # $min == seconds.
    local($minimum, $max) = @_;

    print STDERR "$FindRangeLevel>FindRange($minimum, $max);\n" if $debug;

    # last: too short range or too recursive
    return ($minimum, $max) if ($max - $minimum) < 10;
    return ($minimum, $max) if $FindRangeLevel++ > 16; # 2^16

    # check the medium
    $x = int ($max - (($max - $minimum) / 2));

    if (-f "$FP_SPOOL_DIR/$x") {
	# status: <-- $x --->|(seq)
	print STDERR "<<< FindRange($minimum, $x)\n" if $debug_fr;
	&FindRange($minimum, $x);
    }
    else {
	# status: $x <----->|(seq)
	print STDERR ">>> FindRange($x, $max)\n" if $debug_fr;
	&FindRange($x, $max);
    }
}


sub DoIndexSearchMinCount
{
    local($try, $last);
    $try = $last = &GetID - 1; # seq is already +1;

    ($try, $last) = &FindRange(0, $last);

    print STDERR "FindRange=>($try, $last);\n" if $debug;

    for ($try = $try - 10; $try <= $last; $try++) {
	print STDERR "check: -f $FP_SPOOL_DIR/$try\n" if $debug;
	last if -f "$FP_SPOOL_DIR/$try";
    }

    print STDERR "MINIMUM ($try < 1) \? 1 \: $try\n" if $debug;
    ($try < 1) ? 1: $try;
}


sub ProcMgetMakeList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($key) = @Fld[3..$#Fld] ? join(':', @Fld[3..$#Fld]) : "";

    if ($mget_list{$key}) {	        # '1 2 3' .. 
	$mget_list{$key} .= " $Fld[2]";	# must have NO SPACE
    }
    else {
	$mget_list{$key} = $Fld[2];
    }

    &Log("$proc submitted entry=[$Fld[2]:$key]");

    if ($debug) {
	local($k, $v);
	while (($k, $v) = each %mget_list) {
	    &Debug("MGET ENTRY [$k]\t=>\t[$v]");
	}
    }

    1;
}


sub ProcLibrary
{
    local($proc, *Fld, *e, *misc) = @_;
    &use('library');
    &ProcLibrary4PlainArticle(@_);
}


# the left of e{'Body'} is whois-text
sub ProcWhoisWrite 
{ 
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc @Fld[2..$#Fld]");
    &use('whois');

    $e{'tmp:mailbody'} = $mailbody; # now under scope in &Procedure
    &WhoisWrite(*e);
    undef $e{'tmp:mailbody'};

    'LAST';
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

    &Log("$proc [@Fld[2..$#Fld]]");
    &use('traffic');
    &Traffic(*Fld, *e);
}


sub ProcModerator
{
    local($proc, *Fld, *e, *misc) = @_;

    &Log("$proc [@Fld[2..$#Fld]]");
    &use('moderated');
    &ModeratorProcedure(*Fld, *e, *misc);
}


sub ProcConfirmdAckReply
{
    local($proc, *Fld, *e, *misc) = @_;
    local($time) = time;

    &Log("$proc @Fld[2..$#Fld]");

    if ($CONFIRMD_ACK_LOGFILE) {
	&Touch($CONFIRMD_ACK_LOGFILE) if !-f $CONFIRMD_ACK_LOGFILE;
	&Append2("$From_address\t$time", $CONFIRMD_ACK_LOGFILE);
	1;
    }
    else {
	&Log("$proc: ack reply logfile is not defined");
	&Mesg(*e, "$proc: a configuration error");
	&Mesg(*e, $NULL, 'configuration_error');
	0;
    }
}


sub ProcDeny
{
    local($proc, *Fld, *e, *misc) = @_;

    &Mesg(*e, "Sorry, YOU CANNOT USE $proc command!");
    &Log("ProcDeny: $proc is disabled");
    &Mesg(*e, $NULL, 'EPERM');
}


##################################################################
### PROCEDURE SETTINGS ENDS 
##################################################################


### COMMON BETWEEN liblm and libsendfile
# 
# Exist a file or not, a binary or not, your file? read permitted?
# return full path filename or NULL
sub ExistP
{
    local($fp)      = @_;
    local($f)       = "$SPOOL_DIR/$fp";	# return "spool/100" form not fullpath
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;

    &Debug("ExistP($fp) called. search $f") if $debug;

    # global binary or not variable on (previous attached)
    $_PCB{'libfml', 'binary'} = 0; 

    # plain and 400 and your file. usually return here;
    stat($f);
    if (-T _ && -r _ && -o _) { 
	&Debug("ExistP: $f match -T && -r && -o") if $debug;
	return $f;
    }

    # NO!
    if ($fp < 1) { return $NULL;}

    # SEARCH
    if ($ARCHIVE_DIR || @ARCHIVE_DIR) {
	local($sp) = (int(($fp - 1)/$ar_unit) + 1) * $ar_unit;

	$_PCB{'libfml', 'binary'} = 2; # WHY HERE? 2 is uuencode operation

	for $dir ($SPOOL_DIR, @ARCHIVE_DIR) {
	    next unless $dir;

	    &Debug("ExistP: scan dir=$dir sp=$sp") if $debug;
	    $f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";

	    stat($f);
	    if (-B _ && -r _ && -o _ ) { 
		&Log("ExistP: return \"$f TarZXF\"") if $debug;
		return ($f, 'TarZXF');
	    }
	}# END FOREACH;

	&Log("ExistP: $f not match") if $debug;
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
	    &Mesg(*e, "Should NOT include META Char's.", 
		  'filter.has_meta_char');
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
    local($rcpt, $rc, $id);

    $MSEND_RC = $MSEND_RC || "$DIR/MSendrc";
    open(MSEND_RC, $MSEND_RC) || return &GetID;

    line: while (<MSEND_RC>) {
	next line if /^\#/o;	# skip comment and off member
	next line if /^\s*$/o;	# skip null line
	chop;

	tr/A-Z/a-z/;		# E-mail form(RFC822)
	($rcpt, $rc) = split(/\s+/, $_, 999);

	# overwritten;
	$id = $rc if &AddressMatch($adr, $rcpt);
    }

    close(MSEND_RC);

    $id ? $id : &GetID;
}


# LastID(last:\d+) 
# mh last:\d+ syntax;
#
# return $L, $R
sub GetLastID
{
    local($s) = @_;
    local($first, $last);

    # $ID from &GetID is ++ already;asymmetry is useful;
    if ($s =~ /^last:(\d+)$/) {
	$last = &GetID;
	$first = $last - $1;
    }

    ($first, $last);
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


1;
