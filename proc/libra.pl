# Admin Commands 
# Remote control library of fml

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# LOCAL SCOPE
local(*AdminProcedure);
local($UnderAuth) = 0;

sub AdminModeInit
{
    # Touch
    for ($ADMIN_MEMBER_LIST, $ADMIN_HELP_FILE, $PASSWD_FILE) {
	-f $_ || &Touch($_);
	-z $_ && &LogWEnv("ADMIN:Warning NO content in $_!");
    }

    %AdminProcedure = (
		       # ADMIN AUTH
		       'admin:pass',	    'ProcAdminDummy',
		       'admin:password',    'ProcAdminDummy',
		       'admin:passwd',	    'ProcAdminDummy',

		       # ADMIN send a guide back to the user
		       'admin:help',	    'ProcAdminFileSendBack',
		       '#admin:help',       $ADMIN_HELP_FILE,
		       'admin:log',	    'ProcAdminFileSendBack',
		       '#admin:log',        $LOGFILE,

		       # ADMIN Contoll users
		       'admin:on',          'ProcAdminSetDeliverMode',
		       'admin:off',         'ProcAdminSetDeliverMode',
		       'admin:skip',        'ProcAdminSetDeliverMode',
		       'admin:noskip',      'ProcAdminSetDeliverMode',
		       'admin:matome',      'ProcAdminSetDeliverMode',

		       'admin:add',         'ProcAdminSubscribe',
		       'admin:subscribe',   'ProcAdminSubscribe',

		       'admin:chaddr',      'ProcAdminSetDeliverMode',

		       'admin:bye',         'ProcAdminSetDeliverMode',
		       'admin:unsubscribe', 'ProcAdminSetDeliverMode',

		       # ADMIN SUBSCRITPIONS
		       'admin:addadmin',    'ProcAdminAddAdmin',
		       'admin:addpriv',     'ProcAdminAddAdmin',
		       'admin:byeadmin',    'ProcAdminByeAdmin',
		       'admin:byepriv',     'ProcAdminByeAdmin',

		       # ADMIN UTILS
		       'admin:dir',         'ProcAdminDir',
		       'admin:ls',          'ProcAdminDir',
		       'admin:remove',      'ProcAdminUnlink',
		       'admin:unlink',      'ProcAdminUnlink',
		       'admin:get',         'ProcAdminRetrieve',
		       'admin:send',        'ProcAdminRetrieve',
		       'admin:put',         'ProcAdminPutFile',
		       'admin:rename',      'ProcAdminRename',
		       
		       );
    
    # debug
    # while(($k, $v) = each %AdminProcedure) { print STDERR "$k => $v\n";}
}


sub ApproveCommand
{
    $UnderAuth = 1;
    &AdminCommand(@_);
}

sub AdminCommand
{
    local(*Fld, *e) = @_;
    local($status, *opt, $cmd);
    local($to) = $e{'Addr2Reply:'};
    local($dummy, $dummy1, $_, @opt) = @Fld; # # admin com opt,..

    ### For convenience
    tr/A-Z/a-z/;		# lower
    $cmd = $_;			# cmd
    $opt = $opt[0];		# $cmd $opt @opt[ 1..$[ ]

    ### FIRSTLY AUTHENTIFICATION 
    $UnderAuth || &AdminAuthP($cmd, *Fld, *opt, *e) || return $NULL;

    ### initialize
    &AdminModeInit;		

    if (! &SecureP(" $cmd @opt ") ) {
	  $_cf{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  $e{'message'}   .= "Execuse me. Please check your request.\n";
	  $e{'message'}   .= "  PROCESS STOPS FOR SECURITY REASON\n\n";
	  &Log("STOP for insecure syntax");
	  return 0; # 0 == LAST(libfml.pl);
    }

    # DEFINE for libfml.pl
    # for multiple-matching
    $_cf{'mode:addr:multiple'} = 1;

    ### Calling admin:command
    if ($proc = $AdminProcedure{"admin:$cmd"}) {
	# REPORT(DEFAULT, APPEND ANYTHING)
	$e{'message'} .= "\n>>>ADMIN:$cmd $opt\n";

	# INFO
	&Debug("Call ". $AdminProcedure{"admin:$cmd"}) if $debug;
	$0 = "--Command calling $proc: $FML $LOCKFILE>";

	# PROCEDURE
	# RETURN is 0 == LAST(libfml.pl);
	return &$proc($cmd, *Fld, *opt, *e);
    }
    else {
	# if undefined commands, notify the user about it and abort.
	&LogWEnv("*** ADMIN: Unknown Cmd $cmd ***", *e);
	return 0; # 0 == LAST(libfml.pl);
    }
} # admin mode ends;



### REQUIRE PASSWD to access the remote fml server. ###
# SYNTAX:
# PASS       password
# PASSWORD   password
# PASSWD     new-password(change the password)
# 
sub AdminAuthP
{
    local($proc, *Fld, *opt, *e) = @_;
    local($s) = join("\t", @opt);
    local($to) = $From_address;
    local($ok);

    ### IF NOT SET, ANYTIME O.K.!

    $Permit{'ra:req:passwd'} || (return 1);

    &use('crypt');

    ### TRY AUTH
    if ($proc =~ /^(PASS|PASSWORD)$/oi) {
	if (! $opt) {
	    $e{'message'} .= 
		"554 PASS NEEDS \$PARAMETER AS PASSWORD\n\tSTOP!\n";
	    return $NULL;
	}

	# 95/09/07 libcrypt.pl
	if (&CmpPasswdInFile($PASSWD_FILE, $to, $opt)) {
	    $UnderAuth = 1;
	    $e{'message'} .= "250 PASSWD AUTHENTIFIED... O.K.\n";
	    return 1;
	}
	else {
	    $e{'message'} .= "554 Illegal Passwd\n\tSTOP!\n";
	    return $NULL;
	}
    }

    ### SHOULD BE AFTER AUTH. IF NOT, STOPS(FATAL ERROR)
    if (! $UnderAuth) {
	$e{'message'} .= "554 YOU CANNOT AUTHENTIFIED\n\tSTOP!\n";
	return $NULL;
    }

    ### O.K. Already Authentified
    if(($proc =~ /^PASSWD$/oi) && $opt) {
	if (&ChangePasswd($PASSWD_FILE, $to, $opt)) {
	    $e{'message'} .= "250 PASSWD CHANGED... O.K.\n";
	    return 'ok';
	}
	else {
	    $e{'message'} .= "554 PASSWD UNCHANGED\n";
	    return $NULL;
	}
    }

    ### RETURN VALUE: Already Authentified, O.K.!;
    $UnderAuth ? 1 : 0;
}



##### PROC DEFINITIONS #####
sub ProcAdminDummy { 
    local($proc, *Fld, *opt, *e) = @_; 
    $e{'message'} .= "O.K.!\n";
    return 1;
}

# using all the rest parameters for relay settting, so require @opt
# e.g. 
# # admin add fukachan@phys.titech.ac.jp axion.phys.titech.ac.jp
sub ProcAdminSubscribe
{
    local($proc, *Fld, *opt, *e) = @_;
    local($s) = join("\t", @opt);
    local($ok);
    
    ## duplicate by umura@nn.solan.chubu.ac.jp  95/6/8
    if (&CheckMember($opt, $MEMBER_LIST)) {	
	&LogWEnv("ADMIN:$proc [$opt] is duplicated in \$MEMBER_LIST", *e);
	return 1;# not fatal;
    }

    if ($ML_MEMBER_CHECK) {
	&Append2($s, $ACTIVE_LIST) ? 
	    &LogWEnv("ADMIN:$proc $s >> \$ACTIVE_LIST", *e) :
		&LogWEnv("ERROR: ADMIN:$proc [$!]",*e);
    }

    &Append2($s, $MEMBER_LIST) ? 
	&LogWEnv("ADMIN:$proc $s >> \$MEMBER_LIST", *e) :
	    &LogWEnv("ERROR: ADMIN:$proc [$!]",*e);

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
    local($proc, *Fld, *opt, *e) = @_;
    local(*misc);

    # Variable Fixing...
    $misc = $opt; 
    @Fld = ('#', $proc, @opt);
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    if ($proc =~ /^(ON|OFF|SKIP|NOSKIP|MATOME)$/oi) {
	@Fld = ('#', $proc, $opt[1]) if $proc =~ /MATOME/oi;
	&Debug("ProcSetDeliveryMode($proc, (@Fld), *e, $misc);") if $debug;
	&ProcSetDeliveryMode($proc, *Fld, *e, *misc);
    }
    elsif ($proc =~ /^(BYE|$CHADDR_KEYWORD)$/oi) {
	&Debug("ProcSetMemberList($proc, (@Fld), *e, $misc);")   if $debug;
	&ProcSetMemberList($proc, *Fld, *e, *misc);
    }

    1;
}


# Subscrption of administrators
# for addadmin and addpriv
#
sub ProcAdminAddAdmin
{
    local($proc, *Fld, *opt, *e) = @_;
    local($s) = join("\t", @opt);
    
    &Append2($s, $ADMIN_MEMBER_LIST) 
	? &Log("ADMIN:$proc $s >> \$ADMIN_MEMBER_LIST") 
	    : (&LogWEnv("ERROR: ADMIN:$proc [$!]", *e), return $NULL);
    1;
}


# UnSubscrption of administrators
# for addadmin and addpriv
# byeadmin and byepriv
# 
sub ProcAdminByeAdmin
{
    local($proc, *Fld, *opt, *e) = @_;
    local($ok);
    $proc = 'BYE';

    &ChangeMemberList($proc, $opt, $ADMIN_MEMBER_LIST, *misc) && $ok++;
    &LogWEnv("ADMIN:$proc ".($ok || "Fails ")."[$opt]");

    1;
}


# Send a file back
sub ProcAdminFileSendBack
{
    local($proc, *Fld, *opt, *e) = @_;
    local($to) = $e{'Addr2Reply:'};

    &LogWEnv("ADMIN:$proc send $proc to $to", *e);
    &SendFile($to, "ADMIN:$proc $ML_FN", $AdminProcedure{"#admin:$proc"});
    1;
}


sub ProcAdminDir
{    
    local($proc, *Fld, *opt, *e) = @_;
    local($flag);

    $opt  = $opt || '.';
    $flag = "-lR" if /^dir$/oi || /^ls\-lR$/oi;

    &LogWEnv("Error: ADMIN:$proc $opt", *e) if $@;
    $e{'message'} .= `ls $flag $opt`;
    1;
}
    

sub ProcAdminUnlink
{
    local($proc, *Fld, *opt, *e) = @_;
    local($file) = "$DIR/$opt";

    if (-f $file && unlink $file) { 
	&LogWEnv("ADMIN:remove \$DIR/$opt", *e);
    }
    else {
	&LogWEnv("ADMIN:remove cannot find \$DIR/$opt, STOP!", *e);
	return $NULL;		# dangerous, should stop
    }

    1;
}


sub ProcAdminRetrieve
{    
    local($proc, *Fld, *opt, *e) = @_;
    local($file) = "$DIR/$opt";

    if (-f $file) { 
	&LogWEnv("ADMIN:$proc \$DIR/$opt", *e);
	&SendFile($to, "ADMIN:$proc \$DIR/$opt", $file);
    }
    else {
	&LogWEnv("ADMIN:$proc cannot find \$DIR/$opt");
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
    local($proc, *Fld, *opt, *e) = @_;
    local($file) = "$DIR/$opt";
    local($s);

    ### skip until find "# admin put file" line.
    foreach (split(/\n/, $e{'Body'})) {
	next while /^\#\s*admin\s*put/i;
	$s .= $_."\n";
    }

    if (-f $file) {# if exist, -> .bak;
	unlink "$file.bak" if -f "$file.bak";

	if (rename($file, "$file.bak")) {
	    &LogWEnv("ADMIN:$proc $file -> $file.bakn", *e);
	}
	else {
	    &LogWEnv("ERROR: ADMIN:$proc cannot rename $file -> $file.bak",*e);
	}
    }

    &Append2($s, $file) ? &LogWEnv("ADMIN:$proc >> \$DIR/$opt") :
	&LogWEnv("ERROR: ADMIN:$proc >> \$DIR/$opt FAILS");

    return $NULL;# should stop Body is to put, not commands.
}


sub ProcAdminRename
{
    local($proc, *Fld, *opt, *e) = @_;
    local($file) = $opt;
    local($new)  = $opt[1];

    if (-f $file) { 
	# remove backup
	unlink "$new.bak" if -f "$new.bak";

	# backup
	if (-f $new) {
	    rename($new, "$new.bak") || 
		&LogWEnv("ERROR: ADMIN:$proc $new -> $new.bak Fails, stop",*e);
	}

	# rename
	rename($file, $new) ? &LogWEnv("ADMIN:$proc $opt to $new", *e) :
	    &LogWEnv("ERROR: ADMIN:$proc $opt to $new FAILS", *e);
    }
    else {
	&LogWEnv("ERROR: ADMIN:$proc cannot find \$DIR/$opt", *e);
    }

    1;
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
