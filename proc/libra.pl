# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

# LOCAL SCOPE
local(%AdminProcedure, $UnderAuth, $AttachRRF);

####################################################
### Call &$proc Interfaces;

sub DoSetAdminMode
{
    local($proc, *Fld, *e, *misc) = @_;
    local($status);
    local($curaddr) = $misc || $Addr || $From_address;

    # Please customize below
    $ADMIN_MEMBER_LIST	= $ADMIN_MEMBER_LIST || "$DIR/members-admin";
    $ADMIN_HELP_FILE	= $ADMIN_HELP_FILE   || "$DIR/help-admin";
    $PASSWD_FILE        = $PASSWD_FILE       || "$DIR/etc/passwd";
    $REMOTE_AUTH        = $REMOTE_AUTH       || 0;
    $PGP_PATH           = $PGP_PATH          || "$DIR/etc/pgp";

    # PGP_PATH: PGP Directory
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp") {
	-d $PGP_PATH || &Mkdir($PGP_PATH);
	$ENV{'PGPPATH'} = $PGP_PATH;
    }

    # touch
    -f $PASSWD_FILE || &Touch($PASSWD_FILE);

    # pgp mode is not required of member check.
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp" ||
	&CheckMember($curaddr, $ADMIN_MEMBER_LIST)) {
	$e{'mode:admin'} = 1;	# AUTHENTICATED, SET MODE ADMIN

	$status = &AdminCommand(*Fld, *e);

	if ($status eq 'LAST') {
	    # not required since return value ends command
	    $e{'mode:admin'} = 0; 
	    return 'LAST';
	}
	elsif (! $status)  {
	    &Log("Error: admin command mode error, ends");
	    # not required since return value ends command
	    $e{'mode:admin'} = 0;
	    return 'LAST';
	};

	$e{'mode:admin'} = 0;	# UNSET for hereafter
	return $NULL;
    }
    else {
	&Mesg(*e, $NULL, 'auth.not_admin', $proc);
	&LogWEnv("$proc request from not administrator, ends", *e);
	$e{'mode:admin'} = 0;	# UNSET for hereafter
	return 'LAST';
    }

    $e{'mode:admin'} = 0;	# UNSET for hereafter

}


sub DoApprove
{
    local($proc, *Fld, *e, *misc) = @_;
    local($status);
    local($curaddr) = $misc || $Addr || $From_address;

    # get passwd
    local($p, @p) = @Fld[2..$#Fld];
    local(@Fld) = ('#', 'approve', @p);

    # Please customize below
    $ADMIN_MEMBER_LIST	= $ADMIN_MEMBER_LIST || "$DIR/members-admin";
    $ADMIN_HELP_FILE	= $ADMIN_HELP_FILE   || "$DIR/help-admin";
    $PASSWD_FILE        = $PASSWD_FILE       || "$DIR/etc/passwd";
    $REMOTE_AUTH        = 0;	# important
    $PGP_PATH           = $PGP_PATH          || "$DIR/etc/pgp";

    # touch
    (!-f $PASSWD_FILE) && open(TOUCH,">> $_") && close(TOUCH);
    
    &Log("&CmpPasswdInFile($PASSWD_FILE, $curaddr, $p)") if $debug;

    # member check
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp" ||
	&CheckMember($curaddr, $ADMIN_MEMBER_LIST)) {
	;
    }
    else {
	&Mesg(*e, $NULL, 'auth.not_admin', $proc);
	&LogWEnv("$proc request from not administrator, ends", *e);
	return 'LAST';
    }


    if (&CmpPasswdInFile($PASSWD_FILE, $curaddr, $p)) {
	&Log("$proc: Request[@p]") if $debug;

	$e{'mode:admin'} = 1;	# AUTHENTICATED, SET MODE ADMIN

	$status = &ApproveCommand(*Fld, *e);

	if ($status eq 'LAST') {
	    return 'LAST';
	}
	elsif (! $status)  {
	    &Log("Error: admin command mode error, ends");
	    return 'LAST';
	};

	$e{'mode:admin'} = 0;	# UNSET for hereafter
	return '';
    }
    else {
	&Mesg(*e, $NULL, 'auth.invalid_password', $proc);
	&Mesg(*e, "$proc: password unmatched.");
	&Log("Error: admin ${proc} password unmatches.");

	if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp") {
	    &Mesg(*e, $NULL, 'auth.please_use_pgp', $proc);
	    &Mesg(*e, " BTW why you use password authentication in pgp mode?");
	    &Mesg(*e, " which is of no use.");
	}
    }
}


####################################################
### Admin Libraries


sub AdminModeInit
{
    local(%adminproc);

    # Touch
    for ($ADMIN_MEMBER_LIST, $ADMIN_HELP_FILE, $PASSWD_FILE) {
	stat($_);
	-f _ || &Touch($_);

	if ($REMOTE_ADMINISTRATION_AUTH_TYPE ne "pgp" &&
	    $REMOTE_ADMINISTRATION_AUTH_TYPE ne "address") {
	    -z _ && &LogWEnv("AdminMode: WARNING $_ == filesize 0", *Envelope);
	}
    }

    %adminproc = (
		  # ADMIN AUTH
		  'admin:initpass',       'ProcAdminInitPasswd',
		  'admin:initpasswd',     'ProcAdminInitPasswd',
		  'admin:pass',	          'ProcAdminDummy',
		  'admin:password',       'ProcAdminDummy',
		  'admin:passwd',	  'ProcAdminAuthP',

		  # ADMIN send a guide back to the user
		  'admin:help',	       'ProcAdminFileSendBack',
		  '#admin:help',       $ADMIN_HELP_FILE,
		  'admin:log',	       'ProcAdminLog',
		  '#admin:log',        $LOGFILE,


		  # ADMIN Contoll users
		  'admin:on',             'ProcAdminSetDeliverMode',
		  'admin:off',            'ProcAdminSetDeliverMode',
		  'admin:skip',           'ProcAdminSetDeliverMode',
		  'admin:noskip',         'ProcAdminSetDeliverMode',
		  'admin:matome',         'ProcAdminSetDeliverMode',

		  'admin:add',            'ProcAdminSubscribe',
		  'admin:subscribe',      'ProcAdminSubscribe',

		  'admin:chaddr',         'ProcAdminSetDeliverMode',
		  'admin:change',         'ProcAdminSetDeliverMode',
		  'admin:change-address', 'ProcAdminSetDeliverMode',

		  'admin:bye',            'ProcAdminSetDeliverMode',
		  'admin:unsubscribe',    'ProcAdminSetDeliverMode',

		  # ADMIN SUBSCRITPIONS
		  'admin:addadmin',       'ProcAdminAddAdmin',
		  'admin:addpriv',        'ProcAdminAddAdmin',
		  'admin:byeadmin',       'ProcAdminByeAdmin',
		  'admin:byepriv',        'ProcAdminByeAdmin',

		  # ADMIN UTILS
		  'admin:resend',         'ProcAdminReSend',
		  'admin:forward',        'ProcAdminForward',

		  'admin:get',            'ProcAdminRetrieve',
		  'admin:send',           'ProcAdminRetrieve',

		  'admin:dir',            'ProcAdminDir',
		  'admin:ls',             'ProcAdminDir',

		  'admin:remove',         'ProcAdminUnlink',
		  'admin:unlink',         'ProcAdminUnlink',
		  'admin:put',            'ProcAdminPutFile',
		  'admin:rename',         'ProcAdminRename',
		  'admin:newinfo',        'ProcAdminPutFile',
		  'admin:newguide',       'ProcAdminPutFile',

		  # special
		  'admin:unlink-article', 'ProcAdminUnlinkArticle',
		  'admin:remove-article', 'ProcAdminUnlinkArticle',

		  # PGP
		  'admin:pgp',            'ProcPGP',

		  # user commands
		  'admin:members', 'ProcFileSendBack',
		  '#members',     $MEMBER_LIST,
		  'admin:actives',  'ProcFileSendBack',
		  '#actives',    $ACTIVE_LIST,
		  );
    

    ### Local
    local($k, $v);

    ### OVERWRITE by system for the extension
    while (($k, $v) = each %ExtAdminProcedure) { $adminproc{$k} = $v;}

    ### IMPORTED FROM libfml.pl
    if (@PermitAdminProcedure) { 
	foreach $k (@PermitAdminProcedure) { 
	    $AdminProcedure{$k}     = $adminproc{$k};
	    $AdminProcedure{"#$k"}  = $adminproc{"#$k"}  if $adminproc{"#$k"};
	    $AdminProcedure{"r#$k"} = $adminproc{"r#$k"} if $adminproc{"r#$k"};
	}
    }
    # PERMIT ALL FUNCTIONS
    else {
	%AdminProcedure = %adminproc;
    }

    # OVERLOAD USER-DEFINED FUNCTIONS
    local($k, $v);
    while (($k, $v) = each %LocalAdminProcedure) { $AdminProcedure{$k} = $v;}

    # IF @DenyAdminProcedure, Delete DEFIEND FUNCTIONS
    if (@DenyAdminProcedure) { 
	foreach $k (@DenyAdminProcedure) { undef $AdminProcedure{$k};}
    }

    if ($debug && 
	(@PermitAdminProcedure||%LocalAdminProcedure||@DenyAdminProcedure)) {
	while (($key, $value) = each %AdminProcedure) {
	    printf STDERR "\tAdminProcedure %15s => %s\n", $key, $value;
	}
    }

    # EVAL HOOK
    if ($ADMIN_COMMAND_HOOK) {
	eval($ADMIN_COMMAND_HOOK);
	&Log("ADMIN_COMMAND_HOOK ERROR", $@) if $@;
    }

    if (! $AttachRRF) {
	local(@rrf);
	@rrf = ($INDEX_FILE,
		$WHOIS_DB,
		$ADMIN_MEMBER_LIST,
		$ADMIN_HELP_FILE,
		$PASSWD_FILE,
		$LOG_MESSAGE_ID,
		$MEMBER_LIST,
		$ACTIVE_LIST,
		$OBJECTIVE_FILE,
		$GUIDE_FILE,
		$HELP_FILE,
		$DENY_FILE,
		$WELCOME_FILE,
		$CONFIRMATION_FILE,
		$LOGFILE,
		$MGET_LOGFILE,
		$SMTPLOG,
		$SUMMARY_FILE,
		$SEQUENCE_FILE,
		$MSEND_RC,
		$LOCK_FILE,

		$FILE_TO_REGIST,

		$FTP_HELP_FILE,
		$WHOIS_HELP_FILE,

		);

	push(@rrf, @ACTIVE_LIST);
	push(@rrf, @MEMBER_LIST);
	push(@REMOTE_RECONFIGURABLE_FILES, @rrf);

	$AttachRRF = 1;	# ifndef ...:-)
    }
}


sub ApproveCommand
{
    local(*Fld, *e) = @_;

    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp") {
	&use('pgp');
	$UnderAuth = &PGPGoodSignatureP(*e);
	&Mesg(*e, "554 YOU CANNOT BE AUTHENTICATED\n\tSTOP!");
	&Mesg(*e, $NULL, 'auth.fail');
    }
    else {
	$UnderAuth = 1;
    }

    $UnderAuth || return 0;

    &AdminCommand(*Fld, *e);
}


# proc   options;
# matome (address 3u) = @opt;
# chaddr (old-address new-address) = @opt;
#   ($_, @opt) = @Fld[2 .. $#Fld];
#
sub AdminCommand
{
    local(*Fld, *e) = @_;
    local($status, @opt, $opt, $cmd, $to, $_);

    ### ReDefine variables
    ($_, @opt) = @Fld[2 .. $#Fld];
    $to        = $e{'Addr2Reply:'};

    ### For convenience
    tr/A-Z/a-z/;		# lower
    $cmd = $_;			# cmd
    $opt = $opt[0];		# $cmd $opt @opt[ 1..$[ ]

    ### FIRSTLY AUTHENTICATION 
    # here call AdminAuthP, so admin:pass admin:password become a dummy();
    # since the authentication must be the first entry;
    # ALREADY whether member (in member-admin) or not is checked.
    # 
    $UnderAuth || &AdminAuthP($cmd, *Fld, *e, *opt) || do {
	&Log("Error: admin mode authentication fails");
	return $NULL;
    };

    ### initialize
    &AdminModeInit;		

    # Security Check Exception
    local($buf) = join(" ", $cmd, @opt);
    if (! &SecureP($buf, 'admin')) {
	  $_cf{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  &Mesg(*e, $NULL, 'filter.insecure_p.stop');
	  &Mesg(*e, "Execuse me. Please check your request.");
	  &Mesg(*e, "  PROCESS STOPS FOR SECURITY REASON\n");
	  &Log("stop for insecure syntax [ $cmd @opt ]");
	  return 0; # 0 == LAST(libfml.pl);
    }

    # DEFINE for libfml.pl for multiple-matching
    $_cf{'mode:addr:multiple'} = 1;

    ### Calling admin:command
    if ($proc = $AdminProcedure{"admin:$cmd"}) {
	# REPORT(DEFAULT, APPEND ANYTHING)
	$s = "$cmd @opt";
	$s =~ s/(pass.*\s+)\S+/$1********/g;
	&Debug(">>> admin:$s &$proc\n") if $debug;
	&Mesg(*e, "\n>>> admin:$s") if $debug;

	# INFO
	&Debug("Call ". $AdminProcedure{"admin:$cmd"}) if $debug;
	$0 = "$FML: Command calling $proc: $LOCKFILE>";

	# PROCEDURE
	# RETURN is 0 == LAST(libfml.pl);
	$status = &$proc($cmd, *Fld, *e, *opt);
	&Log("admin status=$status") if $debug_proc;

	# chaddr and bye
	if ($cmd =~ /^($CHADDR_KEYWORD)$/i ||
	    $cmd =~ /^(bye|unsubscribe)$/i) {

	    # if recipients exist,
	    if ($e{'message:h:@to'}) {
		&Log("flush message") if $debug;
		&Log("rcpts: $e{'message:h:@to'}") if $debug;
		&Notify(&MesgGetABP);
	    }
	    else {
		&Log("not flush message for no recipients") if $debug;
	    }
	}

	return $status;
    }
    else {
	# if undefined commands, notify the user about it and abort.
	&Mesg(*e, $NULL, 'no_such_admin_command', $cmd);
	&LogWEnv("*** unknown admin command $cmd ***", *e);
	&Mesg(*e, $NULL, 'info.ra', $CONTROL_ADDRESS);
	&Mesg(*e, "   FYI: To get help for administrators,");
	&Mesg(*e, "   send 'admin help' or 'approve PASSWORD help' to $CONTROL_ADDRESS.");
	return 0; # 0 == LAST(libfml.pl);
    }
} # admin mode ends;


sub ProcAdminAuthP { &AdminAuthP(@_);}


### REQUIRE PASSWD to access the remote fml server. ###
# SYNTAX:
# PASS       password
# PASSWORD   password
# PASSWD     new-password(change the password)
# 
sub AdminAuthP
{
    local($proc, *Fld, *e, *opt) = @_;
    local($to) = $From_address;

    &Log("AdminAuthP type=$REMOTE_ADMINISTRATION_AUTH_TYPE") if $debug;

    ### IF NOT SET, ANYTIME O.K.!
    # already member or not is checked here.
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp") {
	&use('pgp');
	$UnderAuth = &PGPGoodSignatureP(*e);
    }
    elsif ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "crypt" ||
	   $REMOTE_ADMINISTRATION_AUTH_TYPE eq "md5" ) {
	&use('crypt');

	### TRY AUTH
	if ($proc =~ /^(PASS|PASSWORD)$/i) {
	    if (! $opt) {
		&Log("AdminAuthP: no \$opt");
		&Mesg(*e, "554 PASS NEEDS PASSWORD parameter\n\tSTOP!");
		&Mesg(*e, $NULL, 'no_args');
		return $NULL;
	    }

	    # 95/09/07 libcrypt.pl
	    if (&CmpPasswdInFile($PASSWD_FILE, $to, $opt)) {
		$UnderAuth = 1;
		&Mesg(*e, "250 PASSWD AUTHENTICATED... O.K.");
		&Mesg(*e, $NULL, 'auth.ok');
		return 1;
	    }
	    else {
		&Mesg(*e, "554 Illegal Passwd\n\tSTOP!");
		&Mesg(*e, $NULL, 'auth.invalid_password');
		return $NULL;
	    }
	}
    }
    elsif ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "address") {
	return 1;
    }
    else {
	&Log("\$REMOTE_ADMINISTRATION_AUTH_TYPE is unknown");
	return $NULL;
    }

    ###################################################################

    ### SHOULD BE AFTER AUTH. IF NOT, STOPS(FATAL ERROR)
    if (! $UnderAuth) {
	&Mesg(*e, "554 YOU CANNOT AUTHENTICATED\n\tSTOP!");
	&Mesg(*e, $NULL, 'auth.fail');
	return $NULL;
    }

    ### O.K. Already Authenticated
    if (($proc =~ /^PASSWD$/i) && $opt) {
	&Mesg(*e, "210 TRY CHANGING PASSWORD ...");

	if (&ChangePasswd($PASSWD_FILE, $to, $opt)) {
	    &Mesg(*e, "250 PASSWD CHANGED... O.K.");
	    &Mesg(*e, $NULL, 'auth.change_password.ok');
	    return 'ok';
	}
	else {
	    &Mesg(*e, "554 PASSWD UNCHANGED");
	    &Mesg(*e, $NULL, 'auth.password_unchanged');
	    return $NULL;
	}
    }

    ### RETURN VALUE: Already Authenticated, O.K.!;
    $UnderAuth ? 1 : 0;
}



##### PROC DEFINITIONS #####
sub ProcAdminDummy 
{ 
    local($proc, *Fld, *e, *opt) = @_; 
    &Mesg(*e, "O.K.!");
    return 1;
}


sub ProcPGP
{
    local($proc, *Fld, *e, *opt) = @_; 

    require 'libpgp.pl';
    &PGP($proc, *Fld, *e, *opt);
}


sub ProcAdminInitPasswd
{
    local($proc, *Fld, *e, *opt) = @_; 
    local($s) = " @Fld ";

    $s =~ s/$proc\s+(\S+)\s+(\S+).*/$who = $1, $pass = $2/e;

    &Log("admin $proc ${who}\'s password.");

    if (! &CheckMember($who, $ADMIN_MEMBER_LIST)) {
	&Mesg(*e, "  $who is not a member!!!");
	&Mesg(*e, "  Firstly 'admin addadmin $who'!!!");
	&Mesg(*e, $NULL, 'auth.admin_not_member');
	return 0;
    }

    &use('crypt');

    if (&ChangePasswd($PASSWD_FILE, $who, $pass, 1)) {
	$e{'message'} =~ s/($proc\s+\S+\s+)$pass/$1 ********/g;
	&Mesg(*e, "   O.K.");
    }

    return 1;
}


# using all the rest parameters for relay settting, so require @opt
# e.g. 
# # admin add fukachan@phys.titech.ac.jp axion.phys.titech.ac.jp
sub ProcAdminSubscribe
{
    local($proc, *Fld, *e, *opt) = @_;
    local($status, $swf, $addr);
    local($s) = join("\t", @opt);
    local($file_to_regist) = $FILE_TO_REGIST || $MEMBER_LIST;

    $addr = $opt;

    &Log("admin $proc $s");

    if ($REGISTRATION_ACCEPT_ADDR) {
	if ($addr !~ /$REGISTRATION_ACCEPT_ADDR/i) {
	    &Log("Error: AutoRegist: address [$addr] is not acceptable");
	    return 0;
	}
    }
    
    ## duplicate by umura@nn.solan.chubu.ac.jp  95/6/8
    if (&CheckMember($addr, $file_to_regist)) {	
	&LogWEnv("admin $proc [$addr] is duplicated in the file to regist", *e);
	&Mesg(*e, $NULL, 'already_subscribed');
	&Mesg(*e, "   different sub-domain address already exists?");
	&Mesg(*e, "   \"set exact\" command enforces exact address matching");
	&Mesg(*e, "   to ignore the difference of sub-domain parts.");
	return 1;# not fatal;
    }
    
    if (&UseSeparateListP && ($ACTIVE_LIST ne $file_to_regist)) {
	$status = &Append2($s, $ACTIVE_LIST);
	if ($status) {
	    &LogWEnv("admin $proc $s >> \$ACTIVE_LIST", *e);
	    $swf = 1;
	}
	else {
	    local($r) = $!;
	    &LogWEnv("ERROR: admin $proc [$r]",*e);
	    &Mesg(*e, $NULL, 'error_reason', "admin $proc", $r);
	    $swf = 0;
	}
    }

    $status = &Append2($s, $file_to_regist);

    if ($status) {
	&LogWEnv("admin $proc $s is added to the member list", *e);
	$swf += 1;
    }
    else {
	local($r) = $!;
	&LogWEnv("Error: admin $proc [$r]",*e);
	&Mesg(*e, $NULL, 'error_reason', "admin $proc", $r);
	$swf = 0;
    }

    if ($ADMIN_ADD_SEND_WELCOME_FILE) {
	if ($swf && $addr) {
	    &SendFile($addr, $WELCOME_STATEMENT, $WELCOME_FILE);
	}
	else {
	    &Log("ProcAdminSubscribe: fails to add") unless $swf;
	    &Log("ProcAdminSubscribe: no address to send") unless $addr;
	}
    }

    1;
}


# [NOTICE]
# sub ProcSetDeliveryMode
# sub ProcSetMemberList
# ($ProcName, *FieldName, *Envelope, *misc)
# $misc      : E-Mail-Address to operate
# $FieldName : "# procname opt1 opt2" FORM
#
sub ProcAdminSetDeliverMode
{
    local($proc, *Fld, *e, *opt) = @_;
    local($misc, @misc, %misc, $address);

    &Log("admin $proc ".join(" ", @opt));

    # $opt must be an address NOT OPTION;
    # Warn: the compat of a bug of help-admin
    if ($proc =~ /MATOME/i && $opt =~ /^(\d+|\d+[A-Za-z]+)$/) {
	&Mesg(*e, "   Sorry for a bug in help for admins.");
	&Mesg(*e, "   Please use 'admin command \"address\" options' SYNTAX.");
	@opt = reverse @opt;
	&Mesg(*e, "   Anyway try \"admin $proc @opt \" now!");
	&Mesg(*e, $NULL, 'admin.mandatry_addr_args');
    }

    # Variable Fixing...; @opt = (address, options(e.g."3u"), ...); 
    $address = $opt; # "address" to operate;
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    if ($proc =~ /^(ON|OFF|SKIP|NOSKIP|MATOME)$/i) {
	# @Fld = ('#', $proc, $opt[1]) if $proc =~ /MATOME/i;
	# FIX: (96/02/08) by kishiba@ipc.hiroshima-u.ac.jp

	shift @opt;
	@Fld = ('#', $proc, @opt);
	&Debug("A::SetDeliveryMode($proc, (@Fld), *e, $address);") if $debug;
	&ProcSetDeliveryMode($proc, *Fld, *e, *address);
    }
    elsif ($proc =~ /^(BYE|UNSUBSCRIBE|$CHADDR_KEYWORD)$/oi) {
	@Fld = ('#', $proc, @opt);
	&Debug("A::SetMemberList($proc, (@Fld), *e, $address);")   if $debug;
	&ProcSetMemberList($proc, *Fld, *e, *address);
    }

    1;
}


# Subscrption of administrators
# for addadmin and addpriv
#
sub ProcAdminAddAdmin
{
    local($proc, *Fld, *e, *opt) = @_;
    local($s) = join("\t", @opt);

    &Log("admin $proc $s");
    
    if (&Append2($s, $ADMIN_MEMBER_LIST)) { 
	&Log("admin $proc $s >> \$ADMIN_MEMBER_LIST", *e);
	&Mesg(*e, "   O.K.");
    }
    else {
	local($r) = $!;
	&LogWEnv("Error: admin $proc [$r]", *e);
	&Mesg(*e, $NULL, 'error_reason', "admin $proc", $r);
	return $NULL;
    }

    1;
}


# UnSubscrption of administrators
# for addadmin and addpriv
# byeadmin and byepriv
# 
sub ProcAdminByeAdmin
{
    local($proc, *Fld, *e, *opt) = @_;
    local($ok);
    $proc = 'BYE';

    &Log("admin $proc $s");

    &use('amctl');
    &ChangeMemberList($proc, $opt, $ADMIN_MEMBER_LIST, *misc) && $ok++;
    &LogWEnv("admin $proc ".($ok || "Fails ")."[$opt]");
    &Mesg(*e, $NULL, 'error', "admin $proc") unless $ok;

    1;
}


# Send a file back
sub ProcAdminFileSendBack
{
    local($proc, *Fld, *e, *opt) = @_;
    local($to) = $e{'Addr2Reply:'};

    &LogWEnv("admin $proc send $proc to $to", *e);
    &SendFile($to, "admin $proc $ML_FN", $AdminProcedure{"#admin:$proc"});
    1;
}


# Send a file back
sub ProcAdminLog
{
    local($proc, *Fld, *e, *opt) = @_;
    local($lines, $flag, $all_p);
    local($to) = $e{'Addr2Reply:'};

    $lines = $ADMIN_LOG_DEFAULT_LINE_LIMIT || 100;

    # search lines
    for (@Fld) { 
	/^\-(\d+)$/ && ($lines = $1);
	/^all$/i    && ($all_p = 1)
    }

    &Mesg(*e, $NULL, 'admin.log', $proc);
    &Mesg(*e, "   \"$proc\" show the last $lines lines of log file.");
    &Mesg(*e, "     \"$proc all\" send back the whole log file.");
    &Mesg(*e, "     \"$proc -number\" show the last \"number\" lines.");
    &Mesg(*e, "     e.g. \"$proc -200\" show the last 200 lines.\n");

    if ($all_p) {
	&Log("admin $proc all");
	# send back the whole file;
	&ProcAdminFileSendBack($proc, *Fld, *e, *opt);
    }
    else {
	$prog = &SearchUsualPath('tail');
	$flag = "-$lines" if $lines;

	&Log("admin $proc $flag");

	&Mesg(*e, $_ = `$prog $flag $LOGFILE`);

	if ($@) {
	    &LogWEnv("Error: admin $proc $opt", *e);
	    &Mesg(*e, $NULL, 'error', "admin $proc");
	}
    }


    1;
}


# ReSend, a file forwarders
sub ProcAdminReSend
{
    local($proc, *Fld, *e, *opt) = @_;
    local($file) = $Fld[3];
    local($addr) = $Fld[4];

    &Log("admin $proc $file to $addr");

    if (! -f "$DIR/$file") {
	&Mesg(*e, $NULL, 'no_such_file', $file);
	&Mesg(*e, "file \"$file\" not exists");
	&Log("admin $proc \"$DIR/$file\" not exists");
	return;
    }

    &Mesg(*e, "admin $proc the file \"$file\" to $addr");

    &SendFile($addr, "$file $ML_FN", "$DIR/$file");

    1;
}


# e.g. when moderated mode;
#  After admin authed, forward ...
sub ProcAdminForward
{
    local($proc, *Fld, *e, *opt) = @_;
    local($s, $lines, $skip_p);

    &Log("admin $proc");

    $lines = 0;
    $skip_p = 1;

    for  (split(/\n/, $e{'Body'})) {
	# remove admin procedures until forw
	undef $skip_p if /admin\s+forward/i;
	next if $skip_p || /admin\s+forward/i;

	$s .= "$_\n";
	$lines++;
    }

    # not include command 
    $e{'Body'} = $s;

    # not require libmoderated;
    &Log("forward body $lines lines to ML");
    &Distribute(*e, 'permit from moderator');

    1;
}


sub ProcAdminDir
{    
    local($proc, *Fld, *e, *opt) = @_;
    local($flag, $prog);

    &Log("admin $proc $opt");

    $opt  = $opt || '.';
    $flag = "-lR" if /^dir$/oi || /^ls\-lR$/oi;

    $prog = &SearchUsualPath('ls');

    &Mesg(*e, $_ = `$prog $flag $opt`); # this cast (->scaler)is required;
    if ($@) {
	&LogWEnv("Error: admin $proc $opt", *e);
	&Mesg(*e, $NULL, 'error', "admin $proc");
    }

    1;
}
    

sub ProcAdminUnlink
{
    local($proc, *Fld, *e, *opt) = @_;
    local($file) = "$DIR/$opt";

    &Log("admin $proc $file");

    &ReconfigurableFileP(*e, $DIR, $file) || return 0;

    if (-f $file && unlink $file) { 
	&LogWEnv("admin remove \$DIR/$opt", *e);
    }
    else {
	&LogWEnv("admin remove cannot find \$DIR/$opt, STOP!", *e);
	&Mesg(*e, $NULL, 'no_such_file', "\$DIR/$opt");
	return $NULL;		# dangerous, should stop
    }

    1;
}


sub ProcAdminUnlinkArticle
{
    local($proc, *Fld, *e, *opt) = @_;
    local($f) = "$FP_SPOOL_DIR/$opt";

    &Log("admin $proc $opt");

    if ($opt =~ /^\d+$/) {
	local($atime, $mtime) = (stat($f))[8,9];
	if (open(OW, "> $FP_SPOOL_DIR/$opt")) {
	    select(OW); $| = 1; select(STDOUT);
	    print OW "This article $opt is removed by an administrator.\n\n";
	    print OW "-- $MAINTAINER\n";
	    close(OW);
	    utime($atime, $mtime, $f);

	    &LogWEnv("admin $proc $opt", *e);
	}
	else {
	    &LogWEnv("admin $proc: cannot find $opt, STOP!", *e);
	    &Mesg(*e, $NULL, 'no_such_file', $opt);
	    return $NULL;		# dangerous, should stop
	}
    }
    else {
	&LogWEnv("admin $proc $opt: invalid argument, STOP!", *e);
	&Mesg(*e, $NULL, 'invalid_args', "admin $proc $opt"); 
	return 0; 
    }

    ### 
    # O.K. here, searching plain article is done. 
    # Now search html article.
    $hook = qq#sub wanted { /^$opt\\.html\$/ && push(\@wanted,\$name);}#;
    eval($hook);
    &Log($@) if $@;

    require 'find.pl';
    &find($HTML_DIR);

    # o$pt
    if (@wanted) {
	&use('synchtml');
	for (@wanted) { &SyncHtmlUnlinkArticle(*e, $_);}
    }
    else {
	&Log("$opt.html to remove is not found");
    }

    1;
}




sub ProcAdminRetrieve
{    
    local($proc, *Fld, *e, *opt) = @_;
    local($file) = "$DIR/$opt";

    &Log("admin $proc $file");

    if (-f $file) { 
	&LogWEnv("admin $proc \$DIR/$opt", *e);
	&SendFile($to, "admin $proc \$DIR/$opt", $file);
    }
    else {
	&LogWEnv("admin $proc cannot find \$DIR/$opt");
	&Mesg(*e, $NULL, 'no_such_file', "\$DIR/$opt");
    }

    1;
}


# admin put command fixed (+94/12/30,95/01/09)
# modified 95/01/09 u93b217@ed.teu.ac.jp
#          95/01/18 fukachan@phys.titech.ac.jp
#          95/10/19 fukachan@phys.titech.ac.jp -> 'sub Proc..'
# skip command sequence until "# admin put" lines.
sub ProcAdminPutFile
{
    local($proc, *Fld, *e, *opt) = @_;
    local($file) = "$DIR/$opt";
    local($s);

    &Log("admin $proc $file");

    # newinfo newguide mode:majordomo
    if ($proc =~ /(newinfo|newguide)/i) { 
	$opt = $file = $GUIDE_FILE;
	$opt =~ s#$DIR/##;
    }

    &ReconfigurableFileP(*e, $DIR, $file) || return 0;

    # buffer repalce
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "pgp") {
	&use('pgp');
	$e{'Body'} = &PGPDecode2($e{'Body'});	# decode only
    }

    ### skip until find "# admin put file" line.
    for (split(/\n/, $e{'Body'})) {
	next while /^(\#\s*|\s*)(admin|approve)\s*\S+/i; # skip all admin lines
	$s .= $_."\n";
    }

    if (-f $file) {# if exist, -> .bak;
	unlink "$file.bak" if -f "$file.bak";

	local($mode) = (stat($file))[2];

	if (rename($file, "$file.bak")) {
	    &LogWEnv("admin $proc $file -> $file.bak", *e);
	}
	else {
	    &LogWEnv("Error: admin $proc cannot rename $file -> $file.bak",*e);
	    &Mesg(*e, $NULL, 'fop.rename.fail', $file, $file.".bak");
	}

	&Touch($file);
	chmod $mode, $file;
    }

    if (&Append2($s, $file)) {
	&LogWEnv("admin $proc >> \$DIR/$opt", *e);
	1;
    }
    else {
	&LogWEnv("Error: admin $proc >> \$DIR/$opt FAILS", *e);
	&Mesg(*e, $NULL, 'fop.write.fail', "\$DIR/$opt");
	0; # should stop Body is to put, not commands.
    }

    return 'LAST';			# always "last";
}


sub ProcAdminRename
{
    local($proc, *Fld, *e, *opt) = @_;
    local($file) = $opt;
    local($new)  = $opt[1];

    &Log("ProcAdminRename: admin $proc $file $new");

    &ReconfigurableFileP(*e, $DIR, $file) || return 0;
    &ReconfigurableFileP(*e, $DIR, $new)  || return 0;

    if (-f $file) { 
	# remove backup
	unlink "$new.bak" if -f "$new.bak";

	# backup
	if (-f $new) {
	    local($mode) = (stat($new))[2];

	    rename($new, "$new.bak") || do {
		&LogWEnv("Error: admin $proc $new -> $new.bak Fails, stop",*e);
		&Mesg(*e, $NULL, 'fop.rename.fail', $new, $new.".bak");
	    };

	    chmod $mode, $new;
	}

	local($mode) = (stat($file))[2];

	# rename
	if (rename($file, $new)) {
	    &LogWEnv("admin $proc $opt to $new", *e);
	}
	else {
	    &LogWEnv("Error: admin $proc $opt to $new FAILS", *e);
	    &Mesg(*e, $NULL, 'fop.rename.fail', $file, $new);
	}

	chmod $mode, $file;
    }
    else {
	&LogWEnv("Error: admin $proc cannot find \$DIR/$opt", *e);
	&Mesg(*e, $NULL, 'no_such_file', "\$DIR/$opt");
    }

    1;
}


sub ReconfigurableFileP
{
    local(*e, $dir, $file) = @_;
    local($s);

    print STDERR "input $file == file\n" if $debug;

    $file =~ s/$dir//g;
    $file =~ s#^/##g; # superflous since s#//#/# below is done the same way.
    $file = "$dir/$file";
    $file =~ s#//#/#g;

    for (@REMOTE_RECONFIGURABLE_FILES) {
	print STDERR "match $file eq $_\n" if $debug;
	if ($file eq $_) {
	    return 1;
	}
    }

    &Log("admin: to reconfigure $file is forbidden.");
    &Log("FYI: reconfig only files in \@REMOTE_RECONFIGURABLE_FILES.");

    $s .= "Remote administraion mode error:\n";
    $s .= "File to remove is not listed in \@REMOTE_RECONFIGURABLE_FILES.\n";
    $s .= "You can substitute a file of \@REMOTE_RECONFIGURABLE_FILES.\n";
    $s .= "Please set \@REMOTE_RECONFIGURABLE_FILES to permit other files\n";
    $s .= "See doc/op for more details\n";

    &Mesg(*e, $NULL, 'admin.reconfigurable_error');
    &Mesg(*e ,$s);

    0;
}


sub SearchUsualPath
{
    local($f) = @_;
    local(@path) = split(/:/, $ENV{'PATH'});

    # too pesimistic?
    for $dir ("/usr/bin", "/bin", @path) {
	if (-x "$dir/$f") { 
	    &Log("SearchUsualPath: $dir/$f found") if $debug;
	    return "$dir/$f";
	}
    }
}


##### DEBUG #####
sub RemoteComDebug
{
    local($sharp, $admin, $_, @parameter) = @_;
    local($opt) = $opt[0];

local($s) = q#"
Remote Control Library Infomation

Return      $to
Admin       $admin
who         $to
now         $_
opt         $opt
rest        @parameter
AUTH        $_cf{'remote', 'auth'}
PASSWD      $PASSWD_FILE
"#;

"print STDERR $s";
}

1;
