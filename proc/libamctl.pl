# List Modification functions
#
# Copyright (C) 1994-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


# $Id$;


# Auto registraion procedure
# Subject: subscribe
#        or 
# subscribe ... in Body.
# return 0 or 1 to use the return of &MLMemberCheck
sub AutoRegist
{
    local(*e, $set_addr) = @_;
    local($from, $s, $b, $r, @s);
    local($file_to_regist) = $FILE_TO_REGIST || $MEMBER_LIST;

    # &AutoRegist("address");
    if ($set_addr) { undef $REQUIRE_SUBSCRIBE; $from = $set_addr;}

    # for &Notify,  reply-to ? reply-to : control-address
    $e{'h:Reply-To:'} = $e{'h:reply-to:'} || $MAIL_LIST;#|| $e{'CtlAddr:'};

    # report mail such as WELCOME ..;
    $e{'GH:Reply-To:'} = $MAIL_LIST;
    
    # Special hook e.g. "# list",should be used as a ML's specific hooks
    &eval($AUTO_REGISTRATION_HOOK, "Auto Registration Hook:");

    ##### Confirm Mode: We request a confirm to $from before ADD.
    ##### listserv emulation code;
    # Confirmation Mode; 
    # check the MailBody to search $CONFIRMATION_KEYWORD
    if ($e{'mode:confirm'}) {
	&use('confirm');
	&ConfirmationModeInit;

	$s    = &GetSubscribeString($e{'Body'}); # the first line
	$from = $From_address;

	if (! &Confirm(*e, $from, $s)) {
	    $e{'mode:stranger'} = 1;
	    return 0;
	}
    }
    elsif ($REQUIRE_SUBSCRIBE && $REQUIRE_SUBSCRIBE_IN_BODY) {
	# Syntax e.g. "subscribe" in the body

	$s    = &GetSubscribeString($e{'Body'});
	$from = &GetAddr2Regist($REQUIRE_SUBSCRIBE, $s);

	if (! $from) {
	    &AutoRegistError(*e, 'Body', $s);
	    return 0;
	}
    }
    elsif ($REQUIRE_SUBSCRIBE) {
	# Syntax e.g. "Subject: subscribe"...

	$s    = &GetSubscribeString($e{'h:Subject:'});
	$from = &GetAddr2Regist($REQUIRE_SUBSCRIBE, $s);

	if (! $from) {
	    &AutoRegistError(*e, 'Subject', $s);
	    return 0;
	}
    }
    else {
	# In default, when changing your registered address
	# use "subscribe your-address" in body.
	# if not found, use $From-address;

	$s    = &GetSubscribeString($set_addr || $e{'Body'});
	$from = &GetAddr2Regist($DEFAULT_SUBSCRIBE || "subscribe", $s);
	$from = $from ? $from : $From_address;
    }

    # Check $from appliced already in regist_to_file (GetAddr2Regist())
    &Debug("AUTO REGIST FROM     >$from<") if $debug;

    return 0 if     &LoopBackWarn($from); 	# loop back check	
    return 0 unless &Chk822_addr_spec_P($from);	# permit only 822 addr-spec 

    ### duplicate check (patch by umura@nn.solan.chubu.ac.jp 95/06/08)
    if (&CheckMember($from, $file_to_regist)) {	
	&Log("AutoRegist: Dup $from");
	&Mesg(*e, "Address [$from] already subscribed.");
	&Mesg(*e, &WholeMail);
	return 0;
    }

    ##### ADD the newcomer to the member list
    local($ok, $er);		# ok and error-strings

    ### HERE WE GO REGISTRATION PROCESS;
    local($entry); # locally modified { addr -> addr mode syntax;}
    if ($AUTO_REGISTRATION_DEFAULT_MODE) {
	$entry = "$from $REGISTRATION_DEFAULT_MODE";
    }
    else {
	$entry = $from;
    }

    # WHEN CHECKING MEMBER MODE
    if ($ML_MEMBER_CHECK) {
	&Append2($entry, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	&Append2($entry, $ACTIVE_LIST)    ? $ok++ : ($er .= " $ACTIVE_LIST");
	($ok == 2) ? &Log("Added: $entry") : do {
	    &Warn("ERROR[sub AutoRegist]: cannot operate $er", &WholeMail);
	    return 0; 
	};
    }
    # AUTO REGISTRATION MODE
    else {
	&Append2($entry, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	$ok == 1 ? &Log("Added: $entry") : do {
	    &Warn("ERROR[sub AutoRegist]: cannot operate $er", &WholeMail);
	    return 0;
	};
    }

    ### WHETHER DELIVER OR NOT;
    # 7 is body 3 lines and signature 4 lines, appropriate?;
    # spelling miss fix;
    if (defined $AUTO_REGISTERD_UNDELIVER_P) {
        $AUTO_REGISTERED_UNDELIVER_P = $AUTO_REGISTERD_UNDELIVER_P;
    }

    local($limit) = $AUTO_REGISTRATION_LINES_LIMIT || 8;
    &Log("Deliver? $e{'nlines'} <=> $limit") if $debug;
    &Log("\$AUTO_REGISTERED_UNDELIVER_P is $AUTO_REGISTERED_UNDELIVER_P");

    if ($e{'nlines'} < $limit) { 
	&Log("Not deliver: lines:$e{'nlines'} < $limit");
	$r  = "The number of mail body-line is too short(< $limit),\n";
	$r .= "So NOT FORWARDED to ML($MAIL_LIST). O.K.?\n";
	$r .= "(FYI: \$AUTO_REGISTERED_UNDELIVER_P is set)\n" 
	    if $AUTO_REGISTERED_UNDELIVER_P;
	$r .= "\n".('-' x 30) . "\n\n";
	$AUTO_REGISTERED_UNDELIVER_P = 1;
    }
    elsif ($AUTO_REGISTERED_UNDELIVER_P) {
	$r  = "\$AUTO_REGISTERED_UNDELIVER_P is set, \n";
	$r .= "So NOT FORWARDED to ML($MAIL_LIST).\n\n";
	$r .= ('-' x 30) . "\n\n";
    }

    &Warn("New added member: $from $ML_FN", $r . &WholeMail);

    # HOOK's may modified this;
    local($cur_preamble) = $e{'preamble'};
    if ($e{'GH:Reply-To:'} eq $MAIL_LIST) {
	local($p);
	$p .= "ATTENTION!: IF YOU REPLY THIS MAIL SIMPLY\n";
	$p .= "YOUR REPLY IS DIRECTLY SENT TO THE MAILING LIST $MAIL_LIST\n";
	$p .= "-" x 60; $p .= "\n\n";
	$e{'preamble'} .= $p;
    }
    &SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);

    # reset preamble
    $e{'preamble'} =  $cur_preamble;

    ### Ends.
    ($AUTO_REGISTERED_UNDELIVER_P ? 0 : 1);
}

sub GetAddr2Regist
{
    local($key, $s) = @_;

    &Debug("--GetAddr2Regist(\n$key, $s\n)\n") if $debug;

    if ($s =~ /^$key\s+(\S+).*/i) { 
	return $1;
    }
    elsif ($s =~ /^$key\s*/i) { 
	return $From_address;
    }
    else {
	"";
    }
}

# [\033\050\112] is against a bug in cc:Mail (must be ATOK specification)
# patch by yasushi@pier.fuji-ric.co.jp
sub GetSubscribeString
{
    local($_) = @_;

    &Debug("--GetSubscribeString(\n$_\n);\n") if $debug;

    s/(^\#[\s\n]*|^[\s\n]*)//;
    s/^\033\050\112\s*//;
    (split(/\n/, $_))[0]; # GET THE FIRST LINE ONLY
}

# Here the addr is an unknown addr; 
# &AutoRegistError(*e, 'Subject', $s);
sub AutoRegistError
{
    local(*e, $key, $s) = @_;
    local($b, $sj);

    &Debug("AutoRegist()::($key, '$s') SYNTAX ERROR") if $debug;

    $sj = "Bad Syntax $key in AutoRegistration";
    $b  = "${key}: $REQUIRE_SUBSCRIBE [your-email-address]\n";
    $b .= "\t[] is optional\n";
    $b .= "\tfor changing your address to regist explicitly.\n";

    &Log($sj, "$key => [$s]");
    &Warn("$sj $ML_FN", &WholeMail);

    # for notify
    $e{'message:h:subject'} .= $sj;

    # here the addr is an unknown addr, so should not append "#help" info
    $e{'mode:stranger'} = 1;

    &Mesg(*e, $b.&WholeMail);
}


# check addr-spec in RFC822
# patched by umura@nn.solan.chubu.ac.jp 95/6/8
# return 1 if O.K. 
sub Chk822_addr_spec_P
{
    local($from) = @_;

    if ($from !~ /\@/) {
	&Log("NO \@ mark: $from");
        &Mesg(*Envelope, "WARNING ON AUTO-REGISTRATION::Chk822_addr_spec_P:");
        &Mesg(*Envelope, "Address [$from] contains NO '\@' STRING, SO EXIT!");
        &Mesg(*Envelope, "[$from\@$FQDN] FORM IS REQUIRED for uniqueness\n");
        &Mesg(*Envelope, "*** Please use e.g. [subscribe $from\@$FQDN] FORM");
        &Mesg(*Envelope, "***        OR                                ");
        &Mesg(*Envelope, "*** Manually Edit for $from on the localhost ");
	&Mesg(*Envelope, &WholeMail);
	return 0;
    }

    1;
}


########################################################################


sub DoSetDeliveryMode
{
    local($proc, *Fld, *e, *misc) = @_;
    local($c, $_, $cmd, $opt, $curaddr);

    &Debug("\$curaddr = $misc || $Addr || $From_address") if $debug;

    $curaddr = $misc || $Addr || $From_address; # address to operate;
    $cmd     = $proc; $cmd =~ tr/a-z/A-Z/; $_ = $cmd;
    $opt     = $Fld[2];

    ### LOOP CHECK ###
    if (&LoopBackWarn($curaddr)) {
	&Log("$cmd: LOOPBACK ERROR, exit");
	return $NULL;
    }

    ###### Matome Okuri prescan
    # [case 1 "matome 3u"]
    if (/^(MATOME|DIGEST)$/ && ($opt =~ /^(\d+|\d+[A-Za-z]+)$/)) {
	# set matome-okuri-parameter. *Fld -> &Change..( , , , *opt);
	$c = $opt;

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
		&Mesg(*e, "$cmd: $opt parameter not match.");
		&Mesg(*e, "\tDO NOTHING!");
		return $NULL;
	    }			
	}# $c == non-nil;

	$cmd = "MATOME";
	&Log("O.K. Try $cmd $c");
    }
    ###### [case 2 "matome" call the default slot value]
    elsif (/^(MATOME|DIGEST)$/i) {
	&Log("$cmd: $opt syntax is inappropriate, do nothing");
	&Mesg(*e, "$cmd: $opt syntax is inappropriate.");
	&Mesg(*e, "\t$cmd require someting as an option") if $opt eq "";
	&Mesg(*e, "\tDO NOTHING!");
	return $NULL;
    }

    local($list) = &MailListActiveP($curaddr);
    if (&ChangeMemberList($cmd, $curaddr, $list, *opt)) {
	&Log("$cmd [$curaddr] $c");
	&Mesg(*e, "$cmd [$curaddr] $c accepted.");
    }
    else {
	&Log("$cmd [$curaddr] $c failed");
	&Mesg(*e, "$cmd [$curaddr] $c failed.");
    }
}


sub DoSetMemberList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($curaddr, $newaddr);

    $cmd = $proc; $cmd =~ tr/a-z/A-Z/; $_ = $cmd;

    # {3u,oldaddr} newaddr 
    $curaddr = $Fld[2] || $Addr || $From_address;#(From_address when bye)
    $newaddr = $Fld[3];

    &Debug("\n   SetMemberList::(\n\tcur  $curaddr\n\tnew  $newaddr\n\tmisc $misc\n") if $debug;

    # KEYWORD for 'chaddr'
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    # LOOP CHECK
    if (&LoopBackWarn($curaddr)) {
	&Log("$cmd: LOOPBACK ERROR, exit");
	return $NULL;
    }
    
    ###### change address [chaddr old-addr new-addr]
    # Default: $CHADDR_KEYWORD = 'CHADDR|CHANGE\-ADDRESS|CHANGE';
    if (/^($CHADDR_KEYWORD)$/i) {
	&Mesg(*e, "\t set $cmd => CHADDR") if $cmd ne "CHADDR";
	$cmd = 'CHADDR';
	
	if ($curaddr eq '' || $newaddr eq '') {
	    &Log("CHADDR Error: empty address is given");
	    &Mesg(*e, "Error: CHADDR requires two non-empty addresses.");
	    &Mesg(*e, "Please use the syntax \"CHADDR old-address new-address\"");
	    return $NULL;
	}

	# LOOP CHECK
	&LoopBackWarn($newaddr) && &Log("$cmd: LOOPBACK ERROR, exit") && 
	    (return $NULL);

	#ATTENTION! $curaddr or $newaddr should be a member.
	if (&MailListMemberP($curaddr) || &MailListMemberP($newaddr)) {
	    &Log("$cmd: OK! Either $curaddr and $newaddr is a member.");
	    &Mesg(*e, "\tTry change\n\n\t$curaddr\n\t=>\n\t$newaddr\n");
	}
	else {
	    &Log("$cmd: NEITHER $curaddr and $newaddr is a member. STOP");
	    &Mesg(*e, "$cmd:\n\tNEITHER\n\t$curaddr nor $newaddr");
	    &Mesg(*e, "\tis a member.\n\tDO NOTHING!");
	    return 'LAST';
	}
    }
    # NOT CHADDR;
    else {
	$newaddr = $curaddr; # tricky;
	&Mesg(*e, "\t set $cmd => BYE") if $cmd ne "BYE";
	$cmd = 'BYE';
    }

    ### Modification routine is called recursively in ChangeMemberList;
    local($r, $list);
    if ($ML_MEMBER_CHECK) {
	$list = &MailListMemberP($curaddr);
	&ChangeMemberList($cmd, $curaddr, $list, *newaddr) && $r++;
	&Log("$cmd MEMBER [$curaddr] $c O.K.")   if $r == 1 && $debug_amctl;
	&Log("$cmd MEMBER [$curaddr] $c failed") if $r != 1;
	&Mesg(*e, "Hmm,.., modifying member list fails.") if $r != 1;
    }
    else {
	$r++;
    }

    return $NULL if $Envelope{'mode:majordomo:chmemlist'};
    $list = &MailListActiveP($curaddr);
    &ChangeMemberList($cmd, $curaddr, $list, *newaddr) && $r++;
    &Log("$cmd ACTIVE [$curaddr] $c O.K.")   if $r == 2 && $debug_amctl;
    &Log("$cmd ACTIVE [$curaddr] $c failed") if $r != 2;
    &Mesg(*e, "Hmm,.., modifying delivery list fails.") if $r != 2;

    # Status
    if ($r == 2) {
	&Log("$cmd [$curaddr] $c accepted");
	&Mesg(*e, "$cmd [$curaddr] $c accepted.");
    }
    else {
	&Log("$cmd [$curaddr] $c failed");
	&Mesg(*e, "$cmd [$curaddr] $c failed.");
    }

    return 'LAST';
}


# For convenience
sub GenFmlHeader
{
q$#.FML HEADER
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
    local($cmd, $curaddr, $file, *misc) = @_;
    local($status, $log, $log_c, $r, $addr, $org_addr, $addr_opt);
    local($acct) = split(/\@/, $curaddr);

    &Debug("DoChangeMemberList($cmd, $curaddr, $file, $misc)") if $debug;

    if (! $file) {
	&Log("DoChangeMemberList:: arg's file == null");
	return $NULL;
    }
    elsif (! -f $file) {
	&Log("DoChangeMemberList::Cannot open file[$file]");
	return $NULL;
    }
    
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
    print NEW &GenFmlHeader;

    # $c == conserve comment;
    local($c, $rcpt, $o);

    in: while (<FILE>) {
	chop;

	print STDERR "TRY       [$_]\n" if $debug;

	# If allow all people to post, OK ends here.
	if (/^\+/o) { 
	    &Log("NO CHANGE[$file] when no member check");
	    close(FILE); 
	    return ($status = 'done'); 
	}

	# Backward Compatibility.	tricky "^\s".
	next in if /^#\.FML/o .. /^\#\.endFML/o;
	if (! /^\#/o) {
	    undef $c;		# reset comment;

	    s/\s(\#.*)$/$c = $2/e; # comment extension 96/10/08,16;
	    s/\smatome\s+(\S+)/ m=$1 /i;
	    s/\sskip\s*/ s=skip /i;

	    ($rcpt, $o) = split(/\s+/, $_, 2);
	    $o = ($o && !($o =~ /^\S=/)) ? " r=$o " : " $o ";
	    $_ = "$rcpt $o $c";
	    s/\s+$/ /g;
	}

	print STDERR "TRY DChML:[$_]\n" if $debug;

	# Backup
	print BAK "$_\n";
	next in if /^\s*$/o;

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	$addr = '';
	if (/^\s*(\S+)\s*(.*)/o)   { $addr = $1;}
	if (/^\#\s*(\S+)\s*(.*)/o) { $addr = $1;}

	# for high performance
	if ($addr !~ /^$acct/i) {
	    print NEW "$_\n"; 
	    next in;
	} 
	elsif (! &AddressMatch($addr, $curaddr)) {
	    print NEW "$_\n"; 
	    next in;
	}

	# if matched, get "$addr including mx or comments"
	if (/^\s*(.*)/o)   { $addr = $1;}
	if (/^\#\s*(.*)/o) { $addr = $1;}

	# fixing multiple s=skip possiblities;
	if ($cmd =~ /^ON|SKIP|NOSKIP$/) { $addr =~ s/s=skip//g;}

	print STDERR "ChangeAMList::{ CMD=$cmd \$addr=[$addr]}\n" if $debug;

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
	    # $addr is reset each time, $org_addr is reused after if matome 0
	    if ($cmd eq 'MATOME') {
		($addr, $org_addr) = &CtlMatome($addr, *misc);
		print NEW "$addr\n"; 
	    }

	    # Matome Okuri Control
	    if ($cmd eq 'CHADDR') {
		&Log("ChangeMemberList:$addr -> $misc");
		if ($addr =~ /^(\S+)\s*(.*)/o) { $addr = $1; $addr_opt = $2;}
		print NEW "$misc $addr_opt\n"; 
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
	print NEW "$curaddr\ts=skip\n"; 
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
	&Mesg(*e, "Multiply Matched?\n$log");
	&Mesg(*e, "Retry to check your adderss severely");

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
	&Log("ReConfiguring $curaddr in \$MSendRC");
	&ConfigMSendRC($curaddr);
	&Rehash($org_addr) if $org_addr;# info of original mode is required
    }
    elsif ($cmd eq 'MATOME' && $status ne 'done') {
	&Log("Matome[Digest]: something Error");
    }

    if ($status eq 'done') {
	&Mesg(*e, "O.K.");
    }
    else {
	&Mesg(*e, "Hmm,.. something fails.");
    }

    $status;
}
    

sub CtlMatome
{
    local($a, *m)    = @_;
    local($matome)   = $m;	# set value(0 implies Realtime deliver)
    local($org_addr) = $a;	# save excursion
    local($s);

    &Debug("CtlMatome::{ \$addr[$addr] => [$matome];}") if $debug;

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
	    &Mesg(*e, "$s");
	    &Mesg(*e, "So your request is accepted but modified to m=3");
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

    print STDERR "\n---Rehash local($adr, $mode)\n\n" if $debug;

    &use('utils');

    if ($mode =~ /m=(\S+)/) {
	($d, $mode) = &ModeLookup($1);
    }
    else {
	($d, $mode) = &ModeLookup('');
    }

    $r = &GetID;		# next ID when delivery
    $l = &GetPrevID($adr);	# next ID when msend

    if ($l < $r) {
	$s = "Rehash: Try send mails[$l - $r] left in spool.";
	$_cf{'rehash'} = "$l-$r"; # for later use "# rehash" ???
	&Log($s);
	&Mesg(*e, "\n$s\n");
    }
    else { # if $l == $r, no article must be left
	$s = "Rehash: no article to send you is left in spool.";
	&Log($s);
	&Mesg(*e, "\n$s\n");
	return;
    }

    # make an entry 
    local(@fld) = ('#', 'mget', "$l-$r", 10, $mode);

    ($l <= $r) && &ProcMgetMakeList('Rehash:EntryIn', *fld);

    1;
}


# for matomeokuri control
# added the infomation to MSEND_RC
# return NONE
sub ConfigMSendRC
{
    local($curaddr) = @_;
    local($ID)      = &GetID;

    # may be duplicated 
    # but the latter config is overwritten when msend.pl works. 
    if (open(TMP, ">> $MSEND_RC") ) {
	select(TMP); $| = 1; select(STDOUT);
	print TMP "$curaddr\t$ID\n";
	close TMP;
    } 
    else { 
	&Log("ConfigMSendRC: Cannot open $MSEND_RC");
    }
}


1;
