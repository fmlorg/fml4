# Remote control library of fml

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

# Admin Commands
#
sub AdminCommand
{
    local($sharp, $admin, $_, @parameter) = @_;
    local($to) = $Reply_to ? $Reply_to : $From_address;
    local($parameter) = $parameter[0];

    # DEFINE for libfml.pl
    # for multiple-matching
    $_cf{'mode', 'com-admin'} = 1;
    
    if(/^help$/io) {
	&Logging("ADMIN: HELP REQUEST from $to");
	&SendFile($to, "ADMIN: HELP", $ADMIN_HELP_FILE);
	$_cf{'return'} .= "ADMIN: send $ADMIN_HELP_FILE to $to\n";
	return 'ok';
    }
    
    if(/^log$/io) {
	&Logging("ADMIN: LOG REQUEST from $to");
	&SendFile($to, "ADMIN: LOG", $LOGFILE);
	$_cf{'return'} .= "ADMIN: send $LOGFILE to $to\n";
	return 'ok';
    }

    ### REQUIRE PASSWD to access the remote fml server. ###
    # SYNTAX:
    # PASS       password
    # PASSWORD   password
    # PASSWD     new-password(change the password)
    # 
    if($REMOTE_AUTH) {
	require 'libcrypt.pl';

	if((/^PASS$/oi || /^PASSWORD$/oi) && $parameter) {
	    # 95/09/07 libcrypt.pl
	    if(&CmpPasswdInFile($PASSWD_FILE, $to, $parameter)) {
		$_cf{'remote', 'auth'} = 1;
		$_cf{'return'} .= "250 PASSWD AUTHENTIFIED... O.K.\n";
		return 'ok';
	    }else {
		$_cf{'return'} .= "554 Illegal Passwd\n";
		return 0;
	    }
	}

	# PREDICATE AUTHENTIFIED!
	if(1 != $_cf{'remote', 'auth'}) {
	    $_cf{'return'} .= "Cannot AUTHENTIFY YOU\n";
	    return 0;
	}

	if(/^PASSWD$/oi && $parameter) {
	    if(&ChangePasswd($PASSWD_FILE, $to, $parameter)) {
		$_cf{'return'} .= "250 PASSWD CHANGED... O.K.\n";
		return 'ok';
	    }else {
		$_cf{'return'} .= "554 PASSWD UNCHANGED\n";
		return 0;
	    }
	}
    }
    ### REQUIRE PASSWD to access the remote fml server. ###


    # using all the rest parameters for relay settting    
    # e.g. 
    # # admin add fukachan@phys.titech.ac.jp axion.phys.titech.ac.jp
    if(/^add$/io) {
	local($ADDRESSS) = join("\t", @parameter);
	open(TMP, ">> $MEMBER_LIST")  || (&Logging("$!"), return 0);
	print TMP "$ADDRESSS\n";
	close(TMP);
	&Logging("ADMIN: ADDS ($ADDRESSS) to $MEMBER_LIST");
	
	if($ML_MEMBER_CHECK) {
	    open(TMP, ">> $ACTIVE_LIST")  || (&Logging("$!"), return 0);
	    print TMP "$ADDRESSS\n";
	    close(TMP);
	    &Logging("ADMIN: ADDS ($ADDRESSS) to $ACTIVE_LIST");
	}	
	$_cf{'return'} .= "ADMIN: ADDS ($ADDRESSS)\n\tto members and actives files\n";
	return 'ok';
    }
    
######### almost the same except for "return syntax" as libfml.pl ##########
# next , last -> return
# Fld[2] <-> $parameter
# require TRICK below
    $addr = $parameter[1] ? $parameter[1] : $parameter;

    # Off: temporarily.
    # On : Return to Mailng List
    # Matome Okuri ver.2 Control Interface
    if(/^off$/io || /^on$/io || /^matome$/io || /^skip$/io || /^noskip$/io) {
	y/a-z/A-Z/; 
	$cmd = $_;
	local($c);
	local($addr) = $addr ? $addr : $From_address;
	
	# Matome Okuri preroutine
	if(($parameter =~ /^(\d+)$/)||($parameter =~ /^(\d+u)$/oi)||
	   ($parameter =~ /^(\d+)h$/oi)) { 
	    $c = $MATOME = $1;
	    $c = " -> Synchronous Delivery" if(0 == $MATOME);
	    &Logging("Try matome $MATOME") if $MATOME;
	}elsif($c = $parameter) {
	    # Set or unset Address to SKIP, OFF, ON ...
	    $addr = $c;
	}
	
	# LOOP CHECK
	if(&LoopBackWarning($addr)) {
	    &Log("$cmd: LOOPBACk ERROR, exit");
	    return 0;
	}
	
	# Go!
	if(&ChangeMemberList($cmd, $addr, $ACTIVE_LIST)) {
	    &Logging("$cmd [$addr] $c");
	    $_cf{'return'} .= "$cmd [$addr] $c accepted.\n";
	}else {
	    &Logging("$cmd [$addr] $c failed");
	    $_cf{'return'} .= "$cmd [$addr] $c failed. check and try again!\n";
	}
	return 'ok';
    }

    # change old-addr new-addr
    if(/^change$/io) {
	y/a-z/A-Z/; 
	$cmd = $_;
	local($c, $err);
	local($old, $new) = ($parameter, $parameter[1]);
	
	# LOOP CHECK
	if(&LoopBackWarning($old)||&LoopBackWarning($new)) {
	    &Log("$cmd: LOOPBACk ERROR, exit");
	    return 0;
	}
	
	if(! &ChangeMemberList('BYE', $old, $ACTIVE_LIST)) {
	    &Logging("BYE [$old] failed[$ACTIVE_LIST]");
	    $_cf{'return'} .= "BYE [$old] failed. check and try again!\n";
	    $err           .= "BYE [$old] failed. check and try again!\n";
	}
	
	if($ML_MEMBER_CHECK && 
	   (! &ChangeMemberList('BYE', $old, $MEMBER_LIST))) {
	    &Logging("BYE [$old] failed[$MEMBER_LIST]");
	    $_cf{'return'} .= "BYE [$old] failed. check and try again!\n";
	    $err           .= "BYE [$old] failed. check and try again!\n";
	}

	# log
	$_cf{'return'} .= "ADMIN: Remove [$old]\n"
	    unless $err;
	
	# add
	if(open(TMP, ">> $MEMBER_LIST")) {
	    print TMP "$new\n";
	    close(TMP);
	    &Log("ADMIN: ADDS ($new) to $MEMBER_LIST");
	}else {
	    &Log("ADMIN:$!");
	    $err .= "ADMIN:$!";
	}

	if($ML_MEMBER_CHECK && open(TMP, ">> $ACTIVE_LIST")) {
	    print TMP "$new\n";
	    close(TMP);
	    &Logging("ADMIN: ADDS ($new) to $ACTIVE_LIST");
	}else {
	    &Log("ADMIN:$!");
	    $err .= "ADMIN:$!";
	}	

	if(! $err) {
	    &Log("CHANGE [$old -> $new]");
	    $_cf{'return'} .= "ADMIN: ADDS [$new]\n";
	    $_cf{'return'} .= "Change [$old -> $new] accepted\n";
	    return 'ok';
	}else {
	    return 0;
	}
    }
    
    # Bye - Good Bye Eternally
    if(/^bye$/io) {
	local($addr) = $addr ? $addr : $From_address;
	
	if($c = $parameter) {
	    # Set or unset Address to SKIP, OFF, ON ...
	    $addr = $c;
	}
	
	# LOOP CHECK
	if(&LoopBackWarning($addr)) {
	    &Log("$cmd: LOOPBACk ERROR, exit");
	    return 0;
	}
	
	if(! &ChangeMemberList('BYE', $addr, $ACTIVE_LIST)) {
	    &Logging("BYE [$addr] failed[$ACTIVE_LIST]");
	    $_cf{'return'} .= "BYE [$addr] failed. check and try again!\n";
	    return 'ok';
	}
	
	if($ML_MEMBER_CHECK && 
	   (! &ChangeMemberList('BYE', $addr, $MEMBER_LIST))) {
	    &Logging("BYE [$addr] failed[$MEMBER_LIST]");
	    $_cf{'return'} .= "BYE [$addr] failed. check and try again!\n";
	    return 'ok';
	}
	
	&Logging("BYE [$addr]");
	$_cf{'return'} .= "Bye [$addr] accepted. So Long!\n";
	return 'ok';
    }

######### END OF THE SAME PART AS libfml.pl #########
    
    if(/^addadmin$/io || /^addpriv$/io) {
	open(TMP, ">> $ADMIN_MEMBER_LIST")  || (&Logging("$!"), return 0);
	print TMP $parameter, "\n";
	close(TMP);
	&Logging("ADMIN: ADDS $parameter to $ADMIN_MEMBER_LIST");
	$_cf{'return'} .= "ADMIN: ADDS $parameter to Admins\n";
	return 'ok';
    }
    
    if(/^byeadmin$/io || /^byepriv$/io) {
	$MEMBER_LIST = $ADMIN_MEMBER_LIST; # special effects
	if(! &ChangeMemberList('BYE', $parameter, $ADMIN_MEMBER_LIST)) {
	    &Logging("ADMIN: BYE FAILED[$ADMIN_MEMBER_LIST] for $parameter");
	    $_cf{'return'} .= "ADMIN: BYE FAILED[$ADMIN_MEMBER_LIST] for $parameter\n";
	    return 0;
	}
	&Logging("ADMIN: BYE to Admins ($parameter)");
	$_cf{'return'} .= "ADMIN: BYE to Admins ($parameter)\n";
	return 'ok';
    }
    
    if(/^dir$/io) {
	local($@) = "";
	local($RESULT);
	$RESULT=`chdir $DIR; ls -lR`;
	if($@) {
	    &Logging("ERROR: when ls -lR: $@");
	}else {
	    &Logging("ADMIN: ls -lR $DIR");
	}
	$_cf{'return'} .= "ADMIN: ls -lR $DIR\n\n$RESULT\n";
	return 'ok';
    }
    
    if(/^ls$/io) {
	local($@) = "";
	local($RESULT);
	local($COM) = join("\t",@parameter);
	$RESULT=`chdir $DIR; ls $COM`;
	if($@) {
	    &Logging("ERROR: when ls $COM: $@");
	}else {
	    &Logging("ADMIN: ls $COM in $DIR");
	}
	$_cf{'return'} .= "ADMIN: ls $COM in $DIR\n\n$RESULT\n";
	return 'ok';
    }
    
    if(/^remove$/io) {
	local($targetfile) = "$DIR/$parameter";
	if(-r $targetfile) { 
	    unlink $targetfile;
	    &Logging("ADMIN: remove $targetfile");
	    $_cf{'return'} .= "ADMIN: remove $targetfile\n";
	    return 'ok';
	}else {
	    &Logging("ADMIN: remove: cannot find $targetfile");
	    $_cf{'return'} .= "ADMIN: remove: cannot find $targetfile\n";
	    return 0;
	}
    }
    
    if(/^get$/io) {
	local($targetfile) = "$DIR/$parameter";
	if(-r $targetfile) { 
	    &Logging("ADMIN: get $targetfile");
	    &SendFile($to, "ADMIN: get $targetfile", $targetfile);
	    $_cf{'return'} .= "ADMIN: send $targetfile to $to\n";
	    return 'ok';
	}else {
	    &Logging("ADMIN: get: cannot get $targetfile");
	    $_cf{'return'} .= "ADMIN: cannot find $targetfile\n";
	    return 0;
	}
    }
    
    # admin put command fixed (+94/12/30,95/01/09)
    # modified 95/01/09 u93b217@ed.teu.ac.jp
    #          95/01/18 fukachan@phys.titech.ac.jp
    # skip command sequence until "# admin put" lines.
    if(/^put$/io) {
	local($targetfile) = "$DIR/$parameter";
	local($t) = $parameter;
	local($s);
	local($r) = "ADMIN: put $targetfile";
	local($not_in) = 1;

	foreach(split(/\n/, $MailBody, 9999)) {
	    print STDERR "PUT>$_\n";

	    if($not_in && /^\#\s*admin\s*put/i) {
		undef $not_in;
	    }elsif(! $not_in) {
		$s .= "$_\n";
	    }
	}

	if(-r $targetfile) {	# if exist, -> .bak
	    unlink "$targetfile.bak" if(-r "$targetfile.bak");
	    if(rename($targetfile, "$targetfile.bak")) {
		$r = "ADMIN: put $t [old $t -> $t.bak] in $DIR";
	    }else {
		$r = "ADMIN: Cannot rename $t in $DIR";
	    }
	}

	if(open(TMP, "> $targetfile")) {
	    print TMP $s;
	    close(TMP);
	}else {
	    $r = "ADMIN: Cannot Create $t in $DIR";
	}

	&Logging($r);
	$_cf{'return'} .= "$r\n";
	return 0; # must be done as "last NextCommand";
    }
    
    if(/^rename$/io) {
	local($targetfile) = "$DIR/$parameter";
	local($newname)    = "$DIR/$Fld[4]";
	if(-r $targetfile) { 
	    if(rename($targetfile, $newname)) {
		&Logging("ADMIN: rename $targetfile to $newname");
		$_cf{'return'} .= "ADMIN: rename $targetfile to $newname\n";
		return 'ok';
	    }else {
		&Logging("ADMIN: cannot rename $targetfile to $newname");
		$_cf{'return'} .= "ADMIN: cannot find $targetfile\n";
		return 0;
	    }
	}else {
	    &Logging("ADMIN: cannot find $targetfile");
	    $_cf{'return'} .= "ADMIN: cannot find $targetfile\n";
	    return 0;
	}
    }

    # LOG
    local($s) = $_ . join(" ", @parameter);
    &Log("ADMIN: UNKNOWN COMMAND [$s]");
    $_cf{'return'} .= "ADMIN: UNKNOWN COMMAND [$s]\n";

    # End Hook
    undef $_cf{'mode', 'com-admin'}; # for later use of not admin commands

    # O.K. comes back to the main
    return 0;
}


sub RemoteComDebug
{
    local($sharp, $admin, $_, @parameter) = @_;
    local($parameter) = $parameter[0];

local($s) = q#"
Remote Control Library Infomation

Return      $to
Admin       $admin
who         $to
now         $_
parameter   $parameter
rest        @parameter
AUTH        $_cf{'remote', 'auth'}
PASSWD      $PASSWD_FILE
"#;

"print STDERR $s";
}

1;
