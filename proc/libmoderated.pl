# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

#
# CmpPasswdInFile($file, $from, $passwd);
#
sub ModeratedDelivery
{
    local(*e, $already_auth) = @_;
    local($passwd); 

    if ($MODERATOR_FORWARD_TYPE == 1 || !$MODERATOR_FORWARD_TYPE) {
	return &ModeratedDeliveryTypeI(@_);
    }
    elsif ($MODERATOR_FORWARD_TYPE == 2) {
	return &ModeratedDeliveryTypeII(@_);
    }
    elsif ($MODERATOR_FORWARD_TYPE == 3) {
	return &ModeratedDeliveryTypeI(@_);
    }
}


######### TYPE I

sub ModeratedDeliveryTypeI
{
    local(*e, $already_auth) = @_;
    local($passwd, $auth); 

    if ($already_auth) {
	$auth = 1; 
    }
    elsif ($passwd = &moderated'GetPasswd(*e)) { #';
	$passwd =~ s/^\s*(\S+)\s*$/$1/;

	&use('crypt');
	if (&CmpPasswdInFile($PASSWD_FILE, $From_address, $passwd)) {
	    $auth = 1; 
	    &Log("Moderated: Approval Certified");
	}
	else {
	    $auth = 0; 
	    &Log("Moderated: Approval FAILED");
	    &Warn("Moderated: Approval FAILED $ML_FN", &ForwMail);

	    $DO_NOTHING = 1;	# PASS TO THE USUAL ROUTINE;
	}
    }
    # no Apporoval: field
    else {
	# TYPE I
	if ($MODERATOR_FORWARD_TYPE == 1) {
	    $e{'h:Reply-To:'} = $MAIL_LIST;
	    &Log("Moderated: Forwarded to maintainer");
	    &Warn("Forwarded Message: [MODERATED MODE] $ML_FN",
		  &GenModeratorInfo .
		  "Please check the following mail.\n".
		  &ForwMail);
	}
	# TYPE III, do nothing

	$auth = 0; 
	$DO_NOTHING = 1;	# PASS TO THE USUAL ROUTINE;
    }

    ### TYPE III
    if ($MODERATOR_FORWARD_TYPE == 3) {
	# If authenticated, passes it through.
	# If not, passes argv to type II; 
	if (!$auth) { return &ModeratedDeliveryTypeII(@_);}
    }

    ### TYPE I
    ### MAIN ###
    if ($DO_NOTHING) {		# Do nothing. Tricky. Please ignore 
	;
    }
    ### IF UNDER MODERATED
    ### moderator can use commands but this is meaningful???
    elsif ($LOAD_LIBRARY) {	# to be a special purpose server
	require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
    } 
    else {			# distribution 
	# PASSED TO the usual routine &Distribute(*e) in fml.pl;
	# $Rcsid .= "(distribute + commands available mode)";
	&Distribute(*e, 'permit from moderator');	# the main of the main
    }
    ### UNDER MODERATED ENDS
}


######### TYPE II

sub InitModeratedQueueDir
{
    # moderated articles queue
    $ModeratedQueueDir = "$VAR_DIR/mqueue";
    &Mkdir($ModeratedQueueDir) if !-d $ModeratedQueueDir;
}


# saved in var/mqueue/YYYYMMDD.rand()
#
# moderator resend
# resending is by &ModeratorResend;
#
sub ModeratedDeliveryTypeII
{
    local(*e) = @_;
    local($passwd, $id, $f, $h);

    # if --ctladdr, eval a queued commands mail.
    if (($PERMIT_COMMAND_FROM eq "moderator")
	&& $e{'Body'} =~ /^[\s\n]*\# moderator/) {
	&Log("moderator: eval queue as a command") if $debug;
	require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
	return;
    }

    &GetTime;
    &InitModeratedQueueDir;

    # file identifier
    &SRand();
    $id = int(rand(1000000));
    $id = "$PCurrentTime$$.$id";
    $f      = "$ModeratedQueueDir/mq$id";
    $f_info = "$ModeratedQueueDir/mi$id";

    # log
    &Log("moderator: a submit is queued as id=$id");

    $subject = "a submit to moderators";

    $info  = &GenModeratorInfo;
    $info .= "Please check it. If you certify the following article, \n";
    $info .= "please send to $e{'CtlAddr:'}\n";
    $info .= "the following line (only this line!)\n";
    $info .= "\n\# moderator certified $id\n\n";

    $h = $e{'Header'};
    $h =~ s/^From .*\n//;

    # open
    open(APP, "> $f") || (&Log("cannot open $f"), return '');
    select(APP); $| = 1; select(STDOUT);
    print APP $h;
    print APP "\n$e{'Body'}\n";
    close(APP);

    open(APP, "> $f_info") || (&Log("cannot open $f"), return '');
    select(APP); $| = 1; select(STDOUT);
    print APP "\n$info\n";
    print APP &ForwMail;
    close(APP);

    &ModeratorNotify(*MODERATOR_MEMBER_LIST, $subject, $f_info);

    unlink $f_info;
}


sub GenModeratorInfo
{
    local($info, $m_p, $a_p);

    $a_p = &MailListActiveP($From_address);
    $m_p = &MailListMemberP($From_address);

    $info  = "Dear moderators\n\n";
    $info .= "Moderated \$MAIL_LIST <$MAIL_LIST> receives a submit from\n\n";
    $info .= "   $From_address\n";
    $info .= "   (who is ";
    if ($a_p && $m_p) {
	$info .= "a receiver and a member";
    }
    elsif ($a_p && (!$m_p)) {
	$info .= "a receiver but NOT A MEMBER";
    }
    elsif ((!$a_p) && $m_p) {
	$info .= "NOT A RECEIVER but a member";
    }
    else {
	$info .= "NOT A RECEIVER NOR A MEMBER";
    }
    $info .= ").\n\n";

    $info;
}

sub ModeratorNotify
{
    local(*distfile, $subject, $f_info, $preamble) = @_;
    local($cp, %misc);

    $cp = $Envelope{'preamble'};
    $Envelope{'preamble'} = $preamble;

    if (-f $distfile) {
	$misc{'hook'} = q#;
	$le{'GH:Reply-To:'} = $Envelope{'CtlAddr:'}
	#;

	&SendFile3(*distfile, *subject, *f_info, *misc);
    }
    else {
	&SendFile($MAINTAINER, $subject, $f_info);
    }

    $Envelope{'preamble'} = $cp;
}


# '# moderator' command
sub ModeratorProcedure
{
    local(*Fld, *e, *misc) = @_;
    local($id) = $Fld[3];

    &InitModeratedQueueDir;

    if ($moderated'Fld{$id}) { #';
	&Log("moderator: duplicated input [@Fld]");
	&Warn("fml Moderator routine error $ML_FN",
	      "We trap the duplicated input. Please check \n".
	      &ForwMail);
	return $NULL;
    }
    else {
	$moderated'Fld{$id} = 1;
    }

    if ($Fld[2] eq 'certified') {
	if ($id =~ /^[\d\.]+$/) {
	    if (-f "$ModeratedQueueDir/mq$id") {
		&Log("moderator: resend id=$id to ML");
		
		&ModeratorNotify(*MODERATOR_MEMBER_LIST, 
				 "moderated article[$id] is resent $ML_FN",
				 "$ModeratedQueueDir/mq$id",
				 "moderator: resend id=$id to ML\n\n");
		
		&ModeratorResend(*e, "$ModeratedQueueDir/mq$id");
	    }
	    else {
		&Log("Error: moderator: no such id=$id");
		&Mesg(*e, ">>> $Fld");
		&Mesg(*e, "Error: moderator: no such id=$id");
	    }
	}
	else {
	    &Log("Error: moderator: id=$id syntax is illegal");
	    &Mesg(*e, ">>> $Fld");
	    &Mesg(*e, "Error: moderator: id=$id syntax is illegal");
	}
    }
    else {
	&Log("Error: moderator: $Fld[2] is unknown command.");
	&Mesg(*e, ">>> $Fld");
	&Mesg(*e, "Error: moderator: $Fld[2] is unknown command.");
    }
}


# Interface to &Distribute in Type II
sub ModeratorResend
{
    local(*e, $f) = @_;
    local($org_fa) = $From_address; # save global variable

    &GetTime;

    if (open(STDIN, $f)) {
	# reset
	%org_e = %Envelope;

	# remove except for header info but pass "[of]h:field:"
	for (keys %Envelope) { /^\w+h:\S+:$/ || (undef $Envelope{$_});}
    
	&Parse;                         # Phase 1, pre-parsing here
	&GetFieldsFromHeader;           # Phase 2, extract fields
    }
    else {
	&Log("ModeratorResend: cannot open $f");
	&Mesg(*e, "Error: cannot open the moderated article queue id=$id");
	return 0;
    }

    # append
    if (@ModeratedHdrFieldsOrder) {
	@HdrFieldsOrder = @ModeratedHdrFieldsOrder;
    }
    else {
	$Envelope{"h:Resent-From:"} = $org_fa;
	$Envelope{"h:Resent-To:"}   = "$MAIL_LIST (moderated)";
	$Envelope{"h:Resent-Date:"} = $MailDate;
	$Envelope{"h:Resent-Message-Id:"} = &GenMessageId;
	for ('Resent-From','Resent-To', 'Resent-Date', 'Resent-Message-Id') {
	    push(@HdrFieldsOrder, $_);
	}
    }

    #if  --ctladdr, eval commands
    if ($PERMIT_COMMAND_FROM eq "moderator") {
	# save and reset
	$ppf = $PERMIT_POST_FROM;
	$pcf = $PERMIT_COMMAND_FROM;
	$mlac = $MAIL_LIST_ACCEPT_COMMAND;
        $PERMIT_POST_FROM = $PERMIT_COMMAND_FROM  = "anyone";

	&FixHeaderFields(*Envelope);

	$CheckCurrentProcUpperPartOnly = 1;
	$MAIL_LIST_ACCEPT_COMMAND = 1;
	&CheckCurrentProc(*Envelope);
	$CheckCurrentProcUpperPartOnly = 0;

	$ForceKickOffCommand = 1;
	&ModeBifurcate(*Envelope);      # Main Procedure
	$ForceKickOffCommand = 0;

	# reset
	$PERMIT_POST_FROM    = $ppf;
	$PERMIT_COMMAND_FROM = $pcf;
	$MAIL_LIST_ACCEPT_COMMAND = $mlac;
    }
    else {
	&FixHeaderFields(*e); # e.g. checking MIME

	# distribute
	&Distribute(*e, 'permit from members_only');
    }

    # exception for html generation 
    if ($AUTO_HTML_GEN) { %SavedEnvelope = %Envelope;}

    undef %Envelope;
    %Envelope = %org_e;
    $From_address = $org_fa;

    unlink $f;
}


package moderated;

# COMMON ROUTINE
# SIDE EFFECT; remove the passwd entry;
sub GetPasswd
{
    local(*e) = @_;
    local($p);

    if ($e{'h:approval:'}) {
	$p = $e{'h:approval:'};
	undef $e{'h:approval:'};
	undef $e{'h:Approval:'};
    }
    elsif ($e{'Body'} =~ /^[\s\n\#]*approval\s+(\S+)\s+forward\n/) {
	$e{'Body'} =~ s/^[\s\n\#]*approval\s+(\S+)\s+forward\n//;
	$p = $1;
    }

    $p;
}


1;
