# Remote control library of fml

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

# Admin Commands
#
sub AdminCommand
{
    local($sharp, $admin, $_, @parameter) = @_;
    local($to) = $_cf{'reply-to'}; # reply-to is reset in libfml.pl
    local($parameter) = $parameter[0];

    &Log("ADMIN:($sharp, $admin, $_, \@parameter)") if $debug;

    &AdminModeInit;		# initialize

    # DEFINE for libfml.pl
    # for multiple-matching
    $_cf{'mode:addr:multiple'} = 1;
    
    if(/^help$/io) {
	&Log("ADMIN: HELP REQUEST from $to");
	&SendFile($to, "ADMIN: HELP", $ADMIN_HELP_FILE);
	$Envelope{'message'} .= "ADMIN: send $ADMIN_HELP_FILE\n\tto $to\n";
	return 'ok';
    }
    
    if(/^log$/io) {
	&Log("ADMIN: LOG REQUEST from $to");
	&SendFile($to, "ADMIN: LOG", $LOGFILE);
	$Envelope{'message'} .= "ADMIN: send $LOGFILE\n\tto $to\n";
	return 'ok';
    }

    ### REQUIRE PASSWD to access the remote fml server. ###
    # SYNTAX:
    # PASS       password
    # PASSWORD   password
    # PASSWD     new-password(change the password)
    # 
    if($REMOTE_AUTH) {
	&use('crypt');

	if((/^PASS$/oi || /^PASSWORD$/oi) && $parameter) {
	    # 95/09/07 libcrypt.pl
	    if(&CmpPasswdInFile($PASSWD_FILE, $to, $parameter)) {
		$_cf{'remote', 'auth'} = 1;
		$Envelope{'message'} .= "250 PASSWD AUTHENTIFIED... O.K.\n";
		return 'ok';
	    }else {
		$Envelope{'message'} .= "554 Illegal Passwd\n";
		return 0;
	    }
	}

	# PREDICATE AUTHENTIFIED!
	if(1 != $_cf{'remote', 'auth'}) {
	    $Envelope{'message'} .= "Cannot AUTHENTIFY YOU\n";
	    return 0;
	}

	if(/^PASSWD$/oi && $parameter) {
	    if(&ChangePasswd($PASSWD_FILE, $to, $parameter)) {
		$Envelope{'message'} .= "250 PASSWD CHANGED... O.K.\n";
		return 'ok';
	    }else {
		$Envelope{'message'} .= "554 PASSWD UNCHANGED\n";
		return 0;
	    }
	}
    }
    ### REQUIRE PASSWD to access the remote fml server. ###


    # using all the rest parameters for relay settting    
    # e.g. 
    # # admin add fukachan@phys.titech.ac.jp axion.phys.titech.ac.jp
    if(/^add$/io) {
	local($ADDRESS) = join("\t", @parameter);
	open(TMP, ">> $MEMBER_LIST")  || (&Log($!), return 0);
	print TMP "$ADDRESS\n";
	close(TMP);
	&Log("ADMIN: ADDS ($ADDRESS) to $MEMBER_LIST");
	
	if($ML_MEMBER_CHECK) {
	    open(TMP, ">> $ACTIVE_LIST")  || (&Log($!), return 0);
	    print TMP "$ADDRESS\n";
	    close(TMP);
	    &Log("ADMIN: ADDS ($ADDRESS) to $ACTIVE_LIST");
	}	
	$Envelope{'message'} .= "ADMIN: ADDS ($ADDRESS)\n\tto members and actives files\n";
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
	    &Log("Try matome $MATOME") if $MATOME;
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
	    &Log("$cmd [$addr] $c");
	    $Envelope{'message'} .= "$cmd [$addr] $c accepted.\n";
	}else {
	    &Log("$cmd [$addr] $c failed");
	    $Envelope{'message'} .= "$cmd [$addr] $c failed. check and try again!\n";
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
	    &Log("BYE [$old] failed[$ACTIVE_LIST]");
	    $Envelope{'message'} .= "BYE [$old] failed. check and try again!\n";
	    $err           .= "BYE [$old] failed. check and try again!\n";
	}
	
	if($ML_MEMBER_CHECK && 
	   (! &ChangeMemberList('BYE', $old, $MEMBER_LIST))) {
	    &Log("BYE [$old] failed[$MEMBER_LIST]");
	    $Envelope{'message'} .= "BYE [$old] failed. check and try again!\n";
	    $err           .= "BYE [$old] failed. check and try again!\n";
	}

	# log
	$Envelope{'message'} .= "ADMIN: Remove [$old]\n"
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
	    &Log("ADMIN: ADDS ($new) to $ACTIVE_LIST");
	}else {
	    &Log("ADMIN:$!");
	    $err .= "ADMIN:$!";
	}	

	if(! $err) {
	    &Log("CHANGE [$old -> $new]");
	    $Envelope{'message'} .= "ADMIN: ADDS [$new]\n";
	    $Envelope{'message'} .= "Change [$old -> $new] accepted\n";
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
	    &Log("BYE [$addr] failed[$ACTIVE_LIST]");
	    $Envelope{'message'} .= "BYE [$addr] failed. check and try again!\n";
	    return 'ok';
	}
	
	if($ML_MEMBER_CHECK && 
	   (! &ChangeMemberList('BYE', $addr, $MEMBER_LIST))) {
	    &Log("BYE [$addr] failed[$MEMBER_LIST]");
	    $Envelope{'message'} .= "BYE [$addr] failed. check and try again!\n";
	    return 'ok';
	}
	
	&Log("BYE [$addr]");
	$Envelope{'message'} .= "Bye [$addr] accepted. So Long!\n";
	return 'ok';
    }

######### END OF THE SAME PART AS libfml.pl #########
    
    if(/^addadmin$/io || /^addpriv$/io) {
	open(TMP, ">> $ADMIN_MEMBER_LIST")  || (&Log($!), return 0);
	print TMP $parameter, "\n";
	close(TMP);
	&Log("ADMIN: ADDS $parameter to $ADMIN_MEMBER_LIST");
	$Envelope{'message'} .= "ADMIN: ADDS $parameter to Admins\n";
	return 'ok';
    }
    
    if(/^byeadmin$/io || /^byepriv$/io) {
	$MEMBER_LIST = $ADMIN_MEMBER_LIST; # special effects
	if(! &ChangeMemberList('BYE', $parameter, $ADMIN_MEMBER_LIST)) {
	    &Log("ADMIN: BYE FAILED[$ADMIN_MEMBER_LIST] for $parameter");
	    $Envelope{'message'} .= "ADMIN: BYE FAILED[$ADMIN_MEMBER_LIST] for $parameter\n";
	    return 0;
	}
	&Log("ADMIN: BYE to Admins ($parameter)");
	$Envelope{'message'} .= "ADMIN: BYE to Admins ($parameter)\n";
	return 'ok';
    }
    
    if(/^dir$/io) {
	local($@) = "";
	local($RESULT);
	$RESULT=`chdir $DIR; ls -lR`;
	if($@) {
	    &Log("ERROR: when ls -lR: $@");
	}else {
	    &Log("ADMIN: ls -lR $DIR");
	}
	$Envelope{'message'} .= "ADMIN: ls -lR $DIR\n\n$RESULT\n";
	return 'ok';
    }
    
    if(/^ls$/io) {
	local($@) = "";
	local($RESULT);
	local($COM) = join("\t",@parameter);
	$RESULT=`chdir $DIR; ls $COM`;
	if($@) {
	    &Log("ERROR: ls $COM: $@");
	}else {
	    &Log("ADMIN: ls $COM $DIR");
	}
	$Envelope{'message'} .= "ADMIN: ls $COM $DIR\n\n$RESULT\n";
	return 'ok';
    }
    
    if(/^remove$/io) {
	local($targetfile) = "$DIR/$parameter";
	if(-r $targetfile) { 
	    unlink $targetfile;
	    &Log("ADMIN: remove $targetfile");
	    $Envelope{'message'} .= "ADMIN: remove $targetfile\n";
	    return 'ok';
	}else {
	    &Log("ADMIN: remove: cannot find $targetfile");
	    $Envelope{'message'} .= "ADMIN: remove: cannot find $targetfile\n";
	    return 0;
	}
    }
    
    if(/^get$/io) {
	local($targetfile) = "$DIR/$parameter";
	if(-r $targetfile) { 
	    &Log("ADMIN: get $targetfile");
	    &SendFile($to, "ADMIN: get $targetfile", $targetfile);
	    $Envelope{'message'} .= "ADMIN: send $targetfile\n\tto $to\n";
	    return 'ok';
	}else {
	    &Log("ADMIN: get: cannot get $targetfile");
	    $Envelope{'message'} .= "ADMIN: cannot find $targetfile\n";
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

	foreach(split(/\n/, $Envelope{'Body'}, 9999)) {
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

	&Log($r);
	$Envelope{'message'} .= "$r\n";
	return 0; # must be done as "last NextCommand";
    }
    
    if(/^rename$/io) {
	local($targetfile) = "$DIR/$parameter";
	local($newname)    = "$DIR/$Fld[4]";
	if(-r $targetfile) { 
	    if(rename($targetfile, $newname)) {
		&Log("ADMIN: rename $targetfile to $newname");
		$Envelope{'message'} .= "ADMIN: rename $targetfile to $newname\n";
		return 'ok';
	    }else {
		&Log("ADMIN: cannot rename $targetfile to $newname");
		$Envelope{'message'} .= "ADMIN: cannot find $targetfile\n";
		return 0;
	    }
	}else {
	    &Log("ADMIN: cannot find $targetfile");
	    $Envelope{'message'} .= "ADMIN: cannot find $targetfile\n";
	    return 0;
	}
    }

    # LOG
    local($s) = $_ . join(" ", @parameter);
    &Log("ADMIN: UNKNOWN COMMAND [$s]");
    $Envelope{'message'} .= "ADMIN: UNKNOWN COMMAND [$s]\n";

    # End Hook
    undef $_cf{'mode:addr:multiple'}; # for later use of not admin commands

    # O.K. comes back to the main
    return 0;
}


sub AdminModeInit
{
    # Touch
    for ($ADMIN_MEMBER_LIST, $ADMIN_HELP_FILE, $PASSWD_FILE) {
	if (!-f $_) { 
	    open(TOUCH,">> $_"); close(TOUCH);
	}
	else {
	    &Log("WARNING: no exist in $_!");
	}

	(-z $_) && &Log("WARNING: no content in $_!");
    }
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
