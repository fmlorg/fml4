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


# Auto registraion procedure
# Subject: subscribe
#        or 
# subscribe ... in Body.
# return 0 or 1 to use the return of &MLMemberCheck
sub AutoRegist
{
    local(*e, $set_buf) = @_;
    local($from, $s, $b, $r, @s);
    local($file_to_regist) = $FILE_TO_REGIST || $MEMBER_LIST;

    # ifdef fmlserv
    # &AutoRegist(*e, "subscribe address");
    # ignore $AUTO_REGISTRATION_KEYWORD. fmlserv uses hard-coded "subscribe"
    # In addtion, $set_buf overwrites buffer to ignore the artype
    # except for confirmation.
    if ($e{'mode:fmlserv'} && $set_buf) { 
	$AUTO_REGISTRATION_KEYWORD = "subscribe"; # fmlserv;
	&Log("set_buf[$set_buf]") if $debug;
    }
    # endif fmlserv

    # for &Notify,  reply-to ? reply-to : control-address
    $e{'h:Reply-To:'} = $e{'h:reply-to:'} || $MAIL_LIST;#|| $e{'CtlAddr:'};

    ##### Confirm Mode: We request a confirm to $from before ADD.
    ##### listserv emulation code;
    # Confirmation Mode; 
    # check the MailBody to search $CONFIRMATION_KEYWORD
    if ($AUTO_REGISTRATION_TYPE eq "confirmation") {
	local($key);

	&use('confirm');
	&ConfirmationModeInit(*e, 'subscribe');

	# the first line
	$key  = "^$CONFIRMATION_SUBSCRIBE|$CONFIRMATION_KEYWORD";
	$s    = &GetSubscribeString($set_buf || $e{'Body'}, $key);
	$from = $From_address;

	&Debug("confirm input: {\n$s\n}") if $debug;

	if (! &Confirm(*e, $from, $s)) {
	    $e{'mode:stranger'} = 1;
	    return 0;
	}
    }
    elsif ($AUTO_REGISTRATION_TYPE eq "body") {
	# Syntax e.g. "subscribe" in the body

	$s    = &GetSubscribeString($set_buf || $e{'Body'});
	$from = &GetAddr2Regist($AUTO_REGISTRATION_KEYWORD, $s);

	if (! $from) {
	    &AutoRegistError(*e, 'Body', $s);
	    return 0;
	}
    }
    elsif ($AUTO_REGISTRATION_TYPE eq "subject") {
	# Syntax e.g. "Subject: subscribe"...

	$s    = &GetSubscribeString($set_buf || $e{'h:Subject:'});
	$from = &GetAddr2Regist($AUTO_REGISTRATION_KEYWORD, $s);

	if (! $from) {
	    &AutoRegistError(*e, 'Subject', $s);
	    return 0;
	}
    }
    elsif ($AUTO_REGISTRATION_TYPE eq "no-keyword") {
	# In default, when changing your registered address
	# use "subscribe your-address" in body.
	# if not found, use $From-address;

	$s    = &GetSubscribeString($set_buf || $e{'Body'});
	$from = &GetAddr2Regist($DEFAULT_SUBSCRIBE || "subscribe", $s);
    }
    else {
	&Log("\$AUTO_REGISTRATION_TYPE is unknown type. stop.");
	return 0;
    }

    # default is From: field.
    $from = $from ? $from : $From_address;

    # Check $from appliced already in regist_to_file (GetAddr2Regist())
    &Debug("AUTO REGIST FROM     >$from<") if $debug;

    return 0 if     &LoopBackWarn($from); 	# loop back check	
    return 0 unless &Chk822_addr_spec_P(*e, $from);# permit only 822 addr-spec 

    # acceptable address patterns
    if ($AUTO_REGISTRATION_ACCEPT_ADDR) {
	if ($from !~ /$AUTO_REGISTRATION_ACCEPT_ADDR/i) {
	    &Log("ERROR: AutoRegist: address [$from] is not acceptable");
	    return 0;
	}
    }
    if ($REGISTRATION_ACCEPT_ADDR) {
	if ($from !~ /$REGISTRATION_ACCEPT_ADDR/i) {
	    &Log("ERROR: AutoRegist: address [$from] is not acceptable");
	    return 0;
	}
    }
	
    ### duplicate check (patch by umura@nn.solan.chubu.ac.jp 95/06/08)
    if (&CheckMember($from, $file_to_regist)) {	
	&Log("AutoRegist: Dup $from");
	&Mesg(*e, "Address [$from] already subscribed.");
	&Mesg(*e, $NULL, "already_subscribed", $from);
	&MesgMailBodyCopyOn;
	return 0;
    }

    ##### ADD the newcomer to the member list
    local($ok, $er);		# ok and error-strings

    ### check resource limit
    if ($MAX_MEMBER_LIMIT) {
	if (&CheckResourceLimit(*e, 'member') > $MAX_MEMBER_LIMIT) {
	    &Log("AutoRegist: reject subscribe request",
		 "number of ML members exceeds the limit $MAX_MEMBER_LIMIT");
	    &Mesg(*e, "Sorry, the number of this ML exceeds the limit.");
	    &Mesg(*e, "Hence we cannot accept your request.");
	    &Mesg(*e, $NULL, 'resource.exceed_max_member_limit');
	    return 0;
	}
    }

    ### RUN HOOKS
    # report mail such as WELCOME ..;
    $e{'GH:Reply-To:'} = $MAIL_LIST;
  
    &eval($AUTO_REGISTRATION_HOOK, "Auto Registration Hook:");

    ### HERE WE GO REGISTRATION PROCESS;
    local($entry); # locally modified { addr -> addr mode syntax;}
    if ($AUTO_REGISTRATION_DEFAULT_MODE) {
	$entry = "$from $AUTO_REGISTRATION_DEFAULT_MODE";
    }
    else {
	$entry = $from;
    }

    # WHEN CHECKING MEMBER MODE
    if (&UseSeparateListP) {
	&Append2($entry, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	&Append2($entry, $ACTIVE_LIST)    ? $ok++ : ($er .= " $ACTIVE_LIST");
	($ok == 2) ? &Log("Added: $entry") : do {
	    &WarnE("ERROR[sub AutoRegist]: cannot operate $er", $NULL);
	    return 0; 
	};
    }
    # AUTO REGISTRATION MODE
    else {
	&Append2($entry, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	$ok == 1 ? &Log("Added: $entry") : do {
	    &WarnE("ERROR[sub AutoRegist]: cannot operate $er");
	    return 0;
	};
    }

    # Member Name Registration
    if ($USE_MEMBER_NAME) {
	&use('member_name');
	return 0 unless &AutoRegistMemberName(*e, $from);
    }

    ### WHETHER DELIVER OR NOT;
    # 7 is body 3 lines and signature 4 lines, appropriate?;
    # spelling miss fix;
    if (defined $AUTO_REGISTERD_UNDELIVER_P) {
        $AUTO_REGISTERED_UNDELIVER_P = $AUTO_REGISTERD_UNDELIVER_P;
    }

    local($limit) = $AUTO_REGISTRATION_LINES_LIMIT || 8;
    &Log("AutoRegist: Deliver? $e{'nlines'} <=> $limit") if $debug;

    $r = "<$from> is added to <$MAIL_LIST>\n\n";
    $r = &Translate(*e, $r, 'amctl.added', $from, $MAIL_LIST);

    if ($AUTO_REGISTERED_UNDELIVER_P) {
	&Log("AutoRegist: not deliver since \$AUTO_REGISTERED_UNDELIVER_P is on");
	$r .= &Translate(*e, $NULL, 'amctl.mail.undelivered');
	$r .= "\$AUTO_REGISTERED_UNDELIVER_P is set, \n";
	$r .= "So NOT FORWARDED to ML($MAIL_LIST).\n\n";
	$r .= ('-' x 30) . "\n\n";
    }
    # IF $AUTO_REGISTERED_UNDELIVER_P NOT DEFINED, check Lines: 
    elsif ($e{'nlines'} < $limit) { 
	&Log("AutoRegist: not deliver since lines:$e{'nlines'} < $limit");
	$r .= &Translate(*e, $NULL, 'amctl.mail.undelivered');
	$r .= "The number of lines in the mailbody is too short(< $limit),\n";
	$r .= "So NOT FORWARDED to ML ($MAIL_LIST). O.K.?\n";

	if ($AUTO_REGISTRATION_LINES_LIMIT) {
	    $r .= "(FYI: limit \limit is \$AUTO_REGISTRATION_LINES_LIMIT)\n";
	}
	else {
	    $r .= "(FYI: limit $limit is default value, ";
	    $r .= "since \$AUTO_REGISTRATION_LINES_LIMIT is not defined)\n";
	}

	$r .= "\n".('-' x 30) . "\n\n";
	$AUTO_REGISTERED_UNDELIVER_P = 1;
    }

    # notified to $MAINTAINER
    {
	local($subject) = $e{"GH:Subject:"};
	$e{"GH:Subject:"} = "New added member: $from $ML_FN";
	&WarnE("New added member: $from $ML_FN", $r);
	$e{"GH:Subject:"} = $subject;
    }

    # HOOK's may modified this;
    local($cur_preamble) = $e{'preamble'};
    if ($e{'GH:Reply-To:'} eq $MAIL_LIST) {
	local($p);
	$p = "<$from> is added to <$MAIL_LIST>.\n\n";
	$p .= "ATTENTION!: IF YOU REPLY THIS MAIL SIMPLY\n";
	$p .= "YOUR REPLY IS DIRECTLY SENT TO THE MAILING LIST $MAIL_LIST\n";
	$p .= "-" x 60; $p .= "\n\n";
	$p = &Translate(*e, $p, 'amctl.added', $from, $MAIL_LIST);
	$p = &Translate(*e, $p, 'amctl.added.caution', 
			$MAINTAINER, $MAIL_LIST, $CONTROL_ADDRESS);
	$e{'preamble'} .= $p if $p;
    }
    &SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);

    # reset preamble
    $e{'preamble'} =  $cur_preamble;

    ### Ends.

    ### distribute when auto_regist?
    if ($AUTO_REGISTERED_UNDELIVER_P) {
	; # not delivery
    }
    else {
	local($p);

	# save-excursion
	%OriginalEnvelope = %Envelope;

	# rewrite Body
	$p = &Translate(*Envelope, 
			"$from is newly added to $MAIL_LIST",
			'amctl.added.notify2ml', 
			$from, 
			$MAIL_LIST) || $Envelope{'Body'};

	$Envelope{'Body'} = $p || $Envelope{'Body'};

	# rewrite subject
	$p = &Translate(*Envelope,
			"$from is added",
			'amctl.added.notify2ml.subject',
			$from, 
			$MAIL_LIST);
	&DEFINE_FIELD_FORCED('subject', $p);

	# already member :-)
	&Distribute(*Envelope, 'permit from members_only');

	# reset %Envelope
	%Envelope = %OriginalEnvelope;
    }
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
    local($_, $key) = @_;
    local($buf);

    # evalute the first multipart block
    if ($e{'MIME:boundary'}) { $_ = &GetFirstMultipartBlock(*e);}

    if ($debug_confirm) {
	@c=caller; &Log("GetSubscribeString is called @c[1,2]");
    }
    &Debug("--GetSubscribeString(\n$_\n,\n$key\n);\n") if $debug;

    # XXX: "# command" is internal represention
    # XXX: remove the first '#\s+' and '\s+' part 
    if ($key) {	# return lines with $key
	s/(^\#[\s\n]*|^[\s\n]*)//;
	s/^\033\050\112\s*//; # against bugs of Japanese Softwares

	for (split(/\n/, $_)) {
	    $buf .= "$_\n" if /$key/;
	}
	$buf;
    }
    else {
	s/(^\#[\s\n]*|^[\s\n]*)//;
	s/^\033\050\112\s*//; # against bugs of Japanese Softwares
	(split(/\n/, $_))[0]; # GET THE FIRST LINE ONLY
    }
}

# Here the addr is an unknown addr; 
# &AutoRegistError(*e, 'Subject', $s);
sub AutoRegistError
{
    local(*e, $key, $s) = @_;
    local($b, $sj);

    &Debug("AutoRegist()::($key, '$s') SYNTAX ERROR") if $debug;

    $sj = "AutoRegist: NOT A ML MEMBER or bad subscribe syntax";
    $b  = "Hi, I am fml ML manager for the ML <$MAIL_LIST>.\n";
    $b .= "I find some errors. Please check your mail!\nFor example,\n\n";
    $b .= "   - The address you used IS NOT A ML MEMBER?\n";
    $b .= "     (TRUE if you try to subscribe)\n";
    $b .= "   - You sent a bad subscribe syntax $key?\n";
    $b .= "\nFYI: subscribe syntax\n";
    $b .= "${key}: $AUTO_REGISTRATION_KEYWORD [your-email-address]\n";
    $b .= "\t[] is optional\n";
    $b .= "\tfor changing your address to regist explicitly.\n";

    &Log($sj, "$key => [$s]");
    &WarnE("$sj $ML_FN", $NULL);

    # for notify
    $e{'message:h:subject'} .= $sj;

    # here the addr is an unknown addr, so should not append "#help" info
    $e{'mode:stranger'} = 1;

    &Mesg(*e, $NULL, 'auto_regist_not_member', 
	  $MAIL_LIST, 
	  $AUTO_REGISTRATION_KEYWORD,
	  $MAINTAINER,
	  $key);
    &Mesg(*e, $b);
    &MesgMailBodyCopyOn;
}


# check addr-spec in RFC822
# patched by umura@nn.solan.chubu.ac.jp 95/6/8
# return 1 if O.K. 
sub Chk822_addr_spec_P
{
    local(*e, $from) = @_;

    if (&ValidAddrSpecP($from)) {
	1;
    }
    else {
	&Mesg(*e, "AUTO REGISTRATION ERROR:");
	&Mesg(*e, $NULL, 'invalid_addr_syntax', $from);
	&Mesg(*e, "<$from> is invalid address form.");
	&Log("<$from> is invalid address form");

	if ($from !~ /\@/) {
	    &Mesg(*e, "address <$from> contains NO '\@' STRING.");
	    &Mesg(*e, "It should be <$from\@$FQDN> form.");
	}

	&MesgMailBodyCopyOn;

	0;
    }
}


########################################################################


sub AddrSimilarity
{
    local($a, $b) = @_;
    local(@a, @b, $i);

    $a = (split(/\@/, $a))[1];
    $b = (split(/\@/, $b))[1];
    @a = reverse split(/\./, $a);
    @b = reverse split(/\./, $b);

    for ($i = 0; $a[$i] && $b[$i]; $i++) {
	$a[$i] =~ s/A-Z/a-z/g;
	$b[$i] =~ s/A-Z/a-z/g;
	last if $a[$i] ne $b[$i];
    }

    $i;
}


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

	if ($NOT_USE_SPOOL) {
	    &Log("$proc is disabled when \$NOT_USE_SPOOL is set");
	    &Mesg(*e, "ERROR: $proc is disabled");
	    &Mesg(*e, "       since we have no spooled articles");
	    &Mesg(*e, $NULL, 'req.digest.no_spool', $proc);
	    return $NULL;
	}

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
		&Mesg(*e, $NULL, 'invalid_args', $proc);
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
	&Mesg(*e, $NULL, 'invalid_args', $proc);
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


# USAGE:
# &SaveACL; &DoSetMemberList; &RetACL;
sub DoSetMemberList
{
    local($proc, *Fld, *e, *misc) = @_;
    local($curaddr, $newaddr);

    ### Modification routine is called recursively in ChangeMemberList;
    local($list, $mcs);

    $cmd = $proc; $cmd =~ tr/a-z/A-Z/;

    # define current address (target address) & new address
    # In administrator mode, accecpt any address but
    # From: address only for an usual member. 
    $curaddr = $e{'mode:admin'} ? $Fld[2] : ($Addr || $From_address);
    $newaddr = $Fld[3];

    &Debug("\n   SetMemberList::(\n\tcur  $curaddr\n\tnew  $newaddr\n\tmisc $misc\n") if $debug;

    # KEYWORD for 'chaddr'
    # Default: $CHADDR_KEYWORD = 'CHADDR|CHANGE\-ADDRESS|CHANGE';
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    # LOOP CHECK
    if (&LoopBackWarn($curaddr)) {
	&Mesg(*e, "$cmd: $curaddr may case a mail loop. fml reject it.");
	&Mesg(*e, $NULL, 'mailloop', $curaddr);
	&Log("$cmd: $curaddr may case a mail loop. fml reject it.");
	return $NULL;
    }

    # NOT REQUIRED, since 'r2a' is defind in %Procedure.
    # $e{'message:h:@to'} = $MAINTAINER unless $e{'mode:admin'};

    # Under administration mode, ignore this check.
    # ATTENTION! $curaddr should be a member.
    if ((! $e{'mode:admin'}) &&
	(! ($list = &MailListMemberP($curaddr)))) {
	&Log("$cmd: ERROR: address '$curaddr' is not a member. STOP");
	&Mesg(*e, $NULL, 'auth.should_be_from_member', $curaddr);
	&Mesg(*e, "$cmd: ERROR: address '$curaddr' is not a member.");
	&Mesg(*e, "$cmd requires command from a member address.");
	&Mesg(*e, "please check your From: header field.");
	return $NULL;
    }

    # redefine
    $_ = $cmd;

    # switch: chaddr case
    if (/^($CHADDR_KEYWORD)$/i) {
	###### change address [chaddr old-addr new-addr]

	# addresses
	if ($curaddr eq '' || $newaddr eq '') {
	    &Log("$cmd: ERROR: empty address is given");
	    &Mesg(*e, "$cmd: ERROR: $cmd requires two non-empty addresses.");
	    &Mesg(*e, "Please use the syntax \"$cmd old-address new-address\"");

	    &Mesg(*e, $NULL, 'chaddr.no_args', $cmd);
	    return $NULL;
	}

	# loop check
	if (&LoopBackWarn($newaddr)) {
	    &Mesg(*e, "$cmd: $newaddr may cause a mail loop, reject");
	    &Mesg(*e, $NULL, 'mailloop');
	    &Log("$cmd: $newaddr may cause a mail loop, reject");
	    return $NULL;
	}

	# for usual user, From: == $curaddr is required
	# ATTENTION! $Fld[2] != $curaddr ($curaddr is forced to From:).
	# CHECK RAW CHECK TO COMPARE $Fld[2] (src argument) WITH From: address.
	if (! $e{'mode:admin'} && 
	    (! &AddressMatch($From_address, $Fld[2]))) {
	    &Log("$cmd: Security ERROR: requests to change another member's address '$Fld[2]'");
	    &Mesg(*e, "$cmd: Security Error:\n\tYou ($From_address) cannot change\n\tanother member's address '$Fld[2]'.");
	    &Mesg(*e, $NULL, 'chaddr.invalid_addr', $Fld[2]);
	    return $NULL;
	}

	#ATTENTION! $newaddr should not be a member.
	local($new_list, $asl);

	if (&ExactAddressMatch($curaddr, $newaddr)) {
	    &Log("$cmd: ERROR: $curaddr == $newaddr");
	    &Mesg(*e, $NULL, 'chaddr.same_args', $cmd);
	    &Mesg(*e, $NULL, 'chaddr.from.oldaddr');
	    &Mesg(*e, "$cmd: ERROR: $curaddr == $newaddr");
	    &Mesg(*e, "Please send command mail from old-address");
	    &Mesg(*e, "usage: $cmd old-address new-address");
	    return $NULL;
	}

	# check the similarity level; (e.g. sub-domain change)
	# possibility of "chaddr *@uja.x.y.z -> *@kitakitune.z.y.z"
	$asl = &AddrSimilarity($curaddr, $newaddr);
	if ($asl >= $ADDR_CHECK_MAX) { $ADDR_CHECK_MAX = $asl + 1;}

	if ($new_list = &MailListMemberP($newaddr)) {
	    &Log("$cmd: ERROR: newaddr '$newaddr' exist in '$new_list'");
	    &Mesg(*e, "$cmd: ERROR: New address '$newaddr' is already a member.");
	    &Mesg(*e, $NULL, 'already_subscribed', $newaddr);
	    return $NULL;
	}

	# return addrs 
	# valid for a general user but 
	# invalid for plural "chaddr" command in admin mode 
	# XXX: 2.2A#36 to become under $Procedure{"r2a#command"} control
	# $e{'message:h:@to'} = "$curaddr $newaddr $MAINTAINER";
	$e{'message:h:@to'} = "$curaddr $newaddr";

	&Log("$cmd: Try change address: $curaddr -> $newaddr");
	&Mesg(*e, "\t set $cmd => CHADDR") if $cmd ne "CHADDR";
	&Mesg(*e, "\tTry change\n\n\t$curaddr\n\t=>\n\t$newaddr\n");
	$cmd = 'CHADDR';
    } else {
	# NOT CHADDR -> BYE or UNSUBSCRIBE
	$newaddr = $curaddr; # tricky;

	# not required and wrong also.
	# $e{'message:h:@to'} = "$curaddr $MAINTAINER";

	&Mesg(*e, "set $cmd => BYE") if $cmd ne "BYE";
	$cmd = 'BYE';
    }

    # result check flag
    local($rm, $ra) = (0, 0);

    # obsolete code but left for compatibility.
    if (&UseSeparateListP) {
	$list = &MailListMemberP($curaddr);
	&ChangeMemberList($cmd, $curaddr, $list, *newaddr) && $rm++;
	if ($rm == 1) {
	    &Log($mcs = "$cmd MEMBER [$curaddr] $c O.K.") if $debug_amctl;
	    # XXX: no message if succeed
	    &Mesg(*e, "   changed a member list.") if $debug_amctl;
	}
	else {
	    &Log($mcs = "$cmd MEMBER [$curaddr] $c failed");
	    &Mesg(*e, "   Hmm,.., modifying member list fails.");
	    &Mesg(*e, "   since $curaddr is not found in member list.") unless $list;
	}
    }
    else {
	# ignore the result if manual registration case.
	$rm = 1;
    }

    # special flag
    return $NULL if $Envelope{'mode:majordomo:chmemlist'};

    $list = &MailListActiveP($curaddr);
    &ChangeMemberList($cmd, $curaddr, $list, *newaddr) && $ra++;
    &Log("$cmd ACTIVE [$curaddr] $c O.K.")   if $ra == 1 && $debug_amctl;

    if ($ra == 1) {
	# XXX: no message if succeed
	&Mesg(*e, "   changed a delivery list.") if $debug_amctl;
    }
    else {
	&Log("$cmd ACTIVE [$curaddr] $c failed");
	&Mesg(*e, "   Hmm,.., modifying delivery list fails.");
	&Mesg(*e, "   since $curaddr is not found in delivery list.") unless $list;    }

    if ($rm && $ra) {
	&Log("$cmd [$curaddr] $c accepted");
	&Mesg(*e, "$cmd [$curaddr] $c accepted.");
	&Mesg(*e, $NULL, 'amctl.change.ok');
    }
    elsif ($rm && (!$ra)) {
	&Log("$cmd [$curaddr] $c succeed for members not actives");
	&Mesg(*e, "$cmd [$curaddr] $c accepted".
	      " for member but not delivery list.");
	&Mesg(*e, $NULL, 'amctl.change.only_member_list');
    }
    elsif ($ra && (!$rm)) {
	&Log("$cmd [$curaddr] $c succeed for actives not members");
	&Mesg(*e, "$cmd [$curaddr] $c accepted".
	      " for delivery but not member list.");
	&Mesg(*e, $NULL, 'amctl.change.only_delivery_list');
    }
    else {
	&Log($mcs);
	&Log("$cmd [$curaddr] $c failed");
	&Mesg(*e, "$cmd [$curaddr] $c failed.");
	&Mesg(*e, $NULL, 'amctl.change.fail');
    }

    return 'LAST';
}


# For convenience
sub GenFmlHeader
{
q$#.FML HEADER
# NEW FORMAT FOR FURTHER EXTENSION
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
    local($status, $dup);

    # already back up file exists 
    $dup = 1 if -f "$file.bak";

    $ChMemCount = 0;
    while ($ChMemCount++ < 10) {
	$status = &DoChangeMemberList(@_);
	last if $status ne 'RECURSIVE';
	$ADDR_CHECK_MAX++;
	&Debug("Call Again ChangeMemberList(...)[$ADDR_CHECK_MAX + 1]") if $debug;
    }

    local($cmd, $curaddr, $file, *misc) = @_;
    if ($AMLIST_BACKUP_TYPE eq 'rcs') {
	&use('rcs');
	&RCSBackUp($file);
    }

    # Threshold is 3000 addresses ?
    $AMLIST_NEWSYSLOG_LIMIT = $AMLIST_NEWSYSLOG_LIMIT || 50*3000;
    $AMLIST_NEWSYSLOG_LIMIT = &ATOI($AMLIST_NEWSYSLOG_LIMIT);

    if ($dup && ((stat($file))[7] > $AMLIST_NEWSYSLOG_LIMIT)) {
	&Log("ChangeMemberList->NewSyslog($file.bak)") if $debug;
	require 'libnewsyslog.pl'; 
	&NewSyslog("$file.bak");
    }
    else {
	&Log("NO ChangeMemberList->NewSyslog($file.bak)") if $debug;
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
    if ($AMLIST_BACKUP_TYPE eq 'rcs') {
	open(BAK, "> $file.bak") || (&Log($!), return $NULL);
    }
    else {
	open(BAK, ">> $file.bak") || (&Log($!), return $NULL);
    }

    select(BAK); $| = 1; select(STDOUT);
    print BAK "----- Backup on $Now -----\n";

    # New
    open(NEW, ">  $file.tmp") || (&Log($!), return $NULL);
    select(NEW); $| = 1; select(STDOUT);

    # Input
    open(CHMEM_INPUT,"<  $file") || (&Log($!), return $NULL);


    ### Process GO!
    print NEW &GenFmlHeader;

    # $c == conserve comment;
    local($c, $rcpt, $o, $comment, $cbuf);

    in: while (<CHMEM_INPUT>) {
	chop;

	print STDERR "TRY       [$_]\n" if $debug;

	# If allow all people to post, OK ends here.
	if (/^\+/o) { 
	    &Log("NO CHANGE[$file] when no member check");
	    close(CHMEM_INPUT); 
	    return ($status = 'done'); 
	}

	# Backward Compatibility.	tricky "^\s".
	next in if /^#\.FML/o .. /^\#\.endFML/o;
	if (! /^\#/o) {
	    undef $c;		# reset comment (local);

	    # comment extension 96/10/08,16; fix 97/05/08
	    s/\s(\#.*)$/$c = $1, $NULL/e; 
	    s/\smatome\s+(\S+)/ m=$1 /i;
	    s/\sskip\s*/ s=skip /i;

	    ($rcpt, $o) = split(/\s+/, $_, 2);
	    $o = ($o && !($o =~ /^\S=/)) ? " r=$o " : " $o ";
	    $_ = "$rcpt $o $c";
	    s/\s+$/ /g;
	}

	&Debug("--change member list($_)") if $debug;

	# Backup
	print BAK $_, "\n";
	next in if /^\s*$/o;

	# get $addr for ^#\s+$addr$. if ^#, skip process except for 'off' 
	$cbuf = $comment = $addr = '';
	if (/^\s*(\S+)\s*(.*)/o)   { $addr = $1;}
	if (/^\#\s*(\S+)\s*(.*)/o) { $addr = $1;}

	# for high performance
	if ($addr !~ /^$acct/i) {
	    print NEW $_, "\n"; 
	    next in;
	} 
	elsif (! &AddressMatch($addr, $curaddr)) {
	    print NEW $_, "\n"; 
	    next in;
	}


	######################################################
	### HERE WE GO; $addr == $curaddr (target address)
	{
	    # $_ is splitted to "$addr(include options)" +  "$comment"

	    # phase 01: extract $comment;
	    s/\s(\#.*)$/$comment = $1, $NULL/e; 

	    # phase 02: if matched, get "$addr including mx or comments"
	    s/\s+/ /g; # "  " -> " ";
	    if (/^\s*(.*)/o)   { $addr = $1;}
	    if (/^(\#\s*)(.*)/o) { $addr = $2; $cbuf = $1;}
	}

	# fixing multiple s=skip possiblities;
	if ($cmd =~ /^(ON|SKIP|NOSKIP)$/) { $addr =~ s/s=skip//g;}

	print STDERR "ChangeAMList::{ CMD=$cmd \$addr=[$addr]}\n" if $debug;

	# not use "last" for the possibility the address is written double. 
	# may not be effecient.
	if ($cmd =~ /^(ON|OFF|BYE|SKIP|NOSKIP|MATOME|CHADDR)$/) {
	    # Return to the ML
	    print NEW "$addr $comment\n" 	 if $cmd eq 'ON';

	    # Good Bye to the ML temporarily
	    print NEW "\#\t$addr $comment\n"     if $cmd eq 'OFF';

	    # Good Bye to the ML eternally
	    print NEW "\#\#BYE $addr $comment\n" if $cmd eq 'BYE';

	    # Address to SKIP
	    print NEW "$addr\ts=skip $comment\n" if $cmd eq 'SKIP';

 	    # Delete SKIP
	    if ($cmd eq 'NOSKIP') {
		$addr =~ s/\ss=(\S+)//ig; # remover s= syntax
		print NEW "$addr $comment\n"; 
	    }

	    # Matome Okuri Control 
	    # $addr is reset each time, $org_addr is reused after if matome 0
	    if ($cmd eq 'MATOME') {
		($addr, $org_addr) = &CtlMatome($addr, $curaddr, *misc);
		print NEW "$cbuf$addr $comment\n";
	    }

	    # Matome Okuri Control
	    if ($cmd eq 'CHADDR') {
		&Log("ChangeMemberList:$addr -> $misc");
		if ($addr =~ /^(\S+)\s*(.*)/o) { $addr = $1; $addr_opt = $2;}
		print NEW "$cbuf$misc $addr_opt $comment\n"; 
	    }

	    $status = 'done'; 
	    $log .= "$cmd $addr; "; $log_c++;
	}# CASE of COMMANDS;
	else {
	    print NEW "$addr $comment\n"; 
	    &Log("ChangeMemberList:Unknown cmd = $cmd");
	}
    } # end of while loop;

    # CORRECTION; If not registerd, add the Address to SKIP
    if ($cmd eq 'SKIP' && $status ne 'done') { 
	print NEW "$curaddr\ts=skip\n"; 
	$status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close(BAK); close(NEW); close(CHMEM_INPUT);

    # protection for multiplly matching, 
    # $log_c > 1 implies multiple matching;
    # ADMIN MODE permit multiplly matching($_cf{'mode:addr:multiple'} = 1);
    ## IF MULTIPLY MATCHED
    if ($log_c > 1 && 
	($ChMemCount < 10) && # ($ADDR_CHECK_MAX < 10) && 
	(! $_cf{'mode:addr:multiple'})) {
	&Log("$cmd: Do NOTHING since Muliply MATCHed..");
	$log =~ s/; /\n/g;
	&Mesg(*e, "Multiply Matched?\n$log");
	&Mesg(*e, "Retry to check your adderss severely");
	&Mesg(*e, $NULL, 'amctl.multiply.match');

	# Recursive Call
	return 'RECURSIVE';
    }
    ## IF TOO RECURSIVE
    # elsif ($ADDR_CHECK_MAX >= 10) {
    elsif ($ChMemCount >= 10) {

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
	&Rehash($org_addr) if $org_addr;# info of original mode is required
	&ConfigMSendRC($curaddr); # not required in matome 0
    }
    elsif ($cmd eq 'MATOME' && $status ne 'done') {
	&Log("Matome[Digest]: something Error");
    }

    if ($status eq 'done') {
	;# &Mesg(*e, "O.K.");
    }
    else {
	&Mesg(*e, "Hmm,.. something fails.");
	&Mesg(*e, $NULL, 'command_something_error', $cmd);
    }

    $status;
}
    

sub CtlMatome
{
    local($a, $curaddr, *m)    = @_;
    local($matome)   = $m;	# set value(0 implies Realtime deliver)
    local($org_addr) = $a;	# save excursion
    local($s);

    &Debug("CtlMatome::{ \$addr[$addr] => [$matome];}") if $debug;

    # parameter is whether 0 or not-defiend
    if ($matome eq '') {
	# modification
	if ($addr =~ /\smatome/oi || $addr =~ /\sm=/) {
	    $matome = 'RealTime';
	    $NotAppendMsendRc = 1;
	}
	# new comer, set default
	else {
	    $matome = 3;
	    $s = "Hmm.. no given parameter. use default[m=3]";
	    &Log($s);
	    &Mesg(*e, $s);
	    &Mesg(*e, $NULL, 'amctl.no_args');
	}
    }
    elsif ($matome == 0) {
	$matome = 'RealTime';
    }
    elsif (&ProbeMSendRC($curaddr)) {
	$NotAppendMsendRc = 1;
    }
    else { # modify ?
	# $NotAppendMsendRc = 1;
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
	&Mesg(*e, $NULL, 'amctl.msend_rehash.send', $l, $r);
    }
    else { # if $l == $r, no article must be left
	$s = "Rehash: no article to send you is left in spool.";
	&Log($s);
	&Mesg(*e, "\n$s\n");
	&Mesg(*e, $NULL, 'amctl.msend_rehash.send_nothing');
	return;
    }

    # make an entry ; XXX: "# command" is internal represention
    local(@fld) = ('#', 'mget', "$l-$r", 10, $mode);

    if ($l <= $r) {
	# avoid to reset "mget3" already registerd request.
	local(%backup_mget_list) = %mget_list;
	local($addr2reply)       = $Envelope{'Addr2Reply:'};

	# reset
	undef %mget_list;
	$Envelope{'Addr2Reply:'} = $adr;

	# run mget3 routine asap since aggregation in the same mode occurs
	# in mget routine. So we need hash mget request now.
	&ProcMgetMakeList('Rehash:EntryIn', *fld);
	&use('sendfile');
	&MgetCompileEntry(*Envelope);
	eval '&mget3_SendingEntry;';
	undef %mget_list;

	# back again
	%mget_list               = %backup_mget_list;
	$Envelope{'Addr2Reply:'} = $addr2reply;
    }

    1;
}


sub ProbeMSendRC
{
    local($a) = @_;

    if (-f $MSEND_RC) {
	&Lookup($a, $MSEND_RC) ? 1 : 0;
    }
    else {
	0;
    }
}


# for matomeokuri control
# added the infomation to MSEND_RC
# return NONE
sub ConfigMSendRC
{
    local($curaddr) = @_;
    local($ID)      = &GetID;

    &Log("\$NotAppendMsendRc = $NotAppendMsendRc");

    # append $ID >> $MSEND_RC (overwrite) if new comer comes in.
    return $NULL if $NotAppendMsendRc;

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


package ResourceLimit;

sub Log 
{ 
    &main'Log(@_); #';
} 


sub main'MemberLimitP #';
{
    local(*e) = @_;
    local($total, @a);

    @a = @main'ACTIVE_LIST; #';

    for (@a) {
	 next unless -f $_;
	 $total += &CountEffectiveMember($_);
    }

    $total;
}


sub CountEffectiveMember
{
    local($f) = @_;
    local($count) = 0;

    if (open(LIST, $f)) {
	while (<LIST>) {
	    next if /^\#/;
	    next if /^\s*$/;
	    next if /s=/;	# skip

	    $count++;
	}
	close(LIST);
    }
    else {
	&Log("CountEffectiveMember: cannot open $f [$@]");
    }

    $count;
}


1;
