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
}


######### TYPE I

sub ModeratedDeliveryTypeI
{
    local(*e, $already_auth) = @_;
    local($passwd); 

    if ($already_auth) {
	;
    }
    elsif ($passwd = $e{'h:approval:'}) {
	$passwd =~ s/^\s*(\S+)\s*$/$1/;

	&use('crypt');
	if (&CmpPasswdInFile($PASSWD_FILE, $From_address, $passwd)) {
	    &Log("Moderated: Approval Certified");
	    undef $e{'h:approval:'}; # delete the passwd entry;
	    undef $e{'h:Approval:'}; # delete the passwd entry;
	}
	else {
	    &Log("Moderated: Approval FAILED");
	    &Warn("Moderated: Approval FAILED $ML_FN", &ForwMail);

	    $DO_NOTHING = 1;	# PASS TO THE USUAL ROUTINE;
	}
    }
    else {
	$e{'h:Reply-To:'} = $MAIL_LIST;
	&Log("Moderated: Forwarded to maintainer");
	&Warn("Forwarded Message: [MODERATED MODE] $ML_FN",
	      "Please check the following mail\n".&ForwMail);

	$DO_NOTHING = 1;	# PASS TO THE USUAL ROUTINE;
    }

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
#
sub ModeratedDeliveryTypeII
{
    local(*e) = @_;
    local($passwd, $id, $f, $h, $info);

    # if --ctladdr, eval a queued commands mail.
    if (($PERMIT_COMMAND_FROM eq "moderator")
	&& $e{'Body'} =~ /^[\s\n]*\# moderator/) {
	&Log("moderator: eval queue as a command");
	require($LOAD_LIBRARY = $LOAD_LIBRARY || 'libfml.pl');
	return;
    }

    &GetTime;
    &InitModeratedQueueDir;

    # file identifier
    srand(time|$$);
    $id = int(rand(1000000));
    $id = "$CurrentTime.$id";
    $f      = "$ModeratedQueueDir/mq$id";
    $f_info = "$ModeratedQueueDir/mi$id";

    # log
    &Log("moderator: a submit is queued as id=$id");

    $subject = "a submit to moderators";

    $info  = "Dear moderators\n\n";
    $info .= "Moderated \$MAIL_LIST ($MAIL_LIST) receives a submit from\n\n";
    $info .= "   $From_address.\n\n";
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

sub ModeratorProcedure
{
    local(*Fld, *e, *misc) = @_;
    local($id) = $Fld[3];

    &InitModeratedQueueDir;

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


sub ModeratorResend
{
    local(*e, $f) = @_;

    &GetTime;

    if (open(STDIN, $f)) {
	# reset
	%org_e = %Envelope;
	undef %Envelope;
    
	&Parse;                         # Phase 1, pre-parsing here
	&GetFieldsFromHeader;           # Phase 2, extract fields
    }
    else {
	&Log("ModeratorResend: cannot open $f");
	&Mesg(*e, "Error: cannot open the moderated article queue id=$id");
	return 0;
    }

    # append
    $Envelope{"h:Resent-From:"} = $From_address;
    $Envelope{"h:Resent-To:"}   = "$MAIL_LIST (moderated)";
    $Envelope{"h:Resent-Date:"} = $MailDate;
    $Envelope{"h:Resent-Message-Id:"} = &GenMessageId;
    for ('Resent-From','Resent-To', 'Resent-Date', 'Resent-Message-Id') {
	push(@HdrFieldsOrder, $_);
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
	&FixHeaderFields(*Envelope); # e.g. checking MIME

	# distribute
	&Distribute(*Envelope, 'permit from members_only');
    }

    undef %Envelope;
    %Envelope = %org_e;

    unlink $f;
}

1;
