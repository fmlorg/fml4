# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;

sub ConfirmationModeInit
{
    &Log("Mode Confirmation") if $debug;

    # save the request and given identifier;
    # The concept of KEYWORD and ADDRESS suggeted (irc:-) by ando@iij-mc.co.jp
    $CONFIRMATION_KEYWORD = $CONFIRMATION_KEYWORD || "confirm";
    $CONFIRMATION_RESET_KEYWORD = 
	$CONFIRMATION_RESET_KEYWORD || "confirm reset";

    $CONFIRMATION_FILE    = $CONFIRMATION_FILE || "$DIR/confirm";
    $CONFIRMATION_LIST    = $CONFIRMATION_LIST || "$FP_VARLOG_DIR/confirm";
    $CONFIRMATION_ADDRESS = $CONFIRMATION_ADDRESS || $e{'CtlAddr:'};
    $CONFIRMATION_EXPIRE  = $CONFIRMATION_EXPIRE || 7*24; # unit is "hour"
    $CONFIRMATION_SUBSCRIBE = $CONFIRMATION_SUBSCRIBE ||
	$REQUIRE_SUBSCRIBE || $DEFAULT_SUBSCRIBE || 'subscribe';

    # touch
    -f $CONFIRMATION_LIST || &Touch($CONFIRMATION_LIST);

    # transfer main to Confirm NameSpace;
    for (CONFIRMATION_KEYWORD,
	 CONFIRMATION_RESET_KEYWORD,
	 CONFIRMATION_FILE,
	 CONFIRMATION_LIST,
	 CONFIRMATION_ADDRESS,
	 CONFIRMATION_SUBSCRIBE, 
	 CONFIRMATION_EXPIRE) {
	eval("\$Confirm'$_ = \$main'$_;");
    }
}


# return 1 if we can regist $addr (replied and confirmed);
# return 0 if first-time, expired, confirmation yntax error;
sub Confirm
{
    local(*e, $addr, $buffer) = @_;
    local($id, $r, @r, %r, $time, $m, $gh_subject);

    $e{"GH:Subject:"} = "Subscribe request result $ML_FN";

    # current time
    $time = time;

    # result code; @r is the identifier;
    $r = &Confirm'FirstTimeP(*r, $addr, $time);#';

    &Log("Confirm::FirstTimeP r=$r");

    if ($debug_confirm) {
	&Warn("Confirm Request[$r] $ML_FN", 
	      "Confirm::FirstTimeP r=$r\n\n". &WholeMail);
    }

    if ($r eq 'first-time' || $r eq 'expired') {
	if ($r eq 'expired') {
	 $m .= "Your confirmation for \"subscribe request to $MAIL_LIST\"\n";
	 $m .= "is TOO LATE (ALREADY EXPIRED).\n";
	 $m .= "So we treat you request is the first time request.\n";
	 $m .= "Please try it from the first time as follows\n\n";
	}

	# $name == "Elena Lolabrigita";
	($name = &Confirm'BufferSyntax(*e, $buffer)) || return 0; #';

	 # required info format 
	 # [addr id time(for expire) signature]
	 $id   = &Confirm'GenKey($from);#';

	 # var/log/confirm;
	 &Append2("$time\t$addr\t$id\t$name", $CONFIRMATION_LIST);

	 # Header
	 $e{"GH:Subject:"} = "Subscribe confirmation request $ML_FN";
	 $m .= "To confirm your subscribe request to $MAIL_LIST,\n";
	 $m .= "please send the following phrase to $CONFIRMATION_ADDRESS\n\n";
	 $m .= "$CONFIRMATION_KEYWORD $id $name\n";
	 &Mesg(*e, $m);
	 $e{'message:append:files'} = $CONFIRMATION_FILE;
	 return 0;
    }
    elsif ($r eq 'confirmed') { # @r == identifier;
	$e{"GH:Subject:"} = "Subscribe and confirmation result $ML_FN";
	$r = &Confirm'IdCheck(*e, *r, $addr, $buffer);#';
	undef $e{"GH:Subject:"};# subject: welcome file;
	return $r;
    }
    else {
    $e{"GH:Subject:"} = "Subscribe with confirmation error $ML_FN";
	&Log("Confirm: Error exception");
	return 0;
    }
}


package Confirm;


sub AddressMatch { &main'AddressMatch(@_);} #';
sub Log          { &main'Log(@_);} #';
sub Mesg         { &main'Mesg(@_);} #';
sub Open         { &main'Open(@_);} #';


sub IdCheck
{
    local(*e, *r, $addr, $buffer) = @_;
    local($time, $a, $id, $name, $m);
    ($time, $a, $id, $name) = @r;

    # reset anyway;
    if ($buffer =~ /$CONFIRMATION_RESET_KEYWORD/) {
	&Log("confirm[confirm] reset request");

	if (&RemoveAddrInConfirmFile($addr)) {
	    &Mesg(*e, "I throw away your subscription request from $addr.");
	    &Mesg(*e, "Please do it again from the first step.");
	    $e{'message:append:files'} = $CONFIRMATION_FILE;
	}
	
	return 0;
    }


    if ($buffer =~ /$CONFIRMATION_KEYWORD $id $name/) {
	return 1;
    }
    else {
	&Log("confirm[confirm] syntax error");
	&Log("confirm request[$buffer]");
	$m .= "Confirmation Syntax Error:\n";
	$m .= "The Syntax is following style, check again\n\n";
	$m .= "$CONFIRMATION_KEYWORD password $name\n";
	$m .= "\nwhere this \"password\" can be seen\n";
	$m .= "in the confirmation request mail from $main'MAIL_LIST.\n";
	&Mesg(*e, $m);
	$e{'message:append:files'} = $CONFIRMATION_FILE;
	return 0;
    }
}

sub BufferSyntax
{
    local(*e, $buffer) = @_;
    local($name, $_);

    if ($buffer =~ /$CONFIRMATION_SUBSCRIBE\s+(\S+.*)/) { # require anything;
	$name = $1;
    }
    else {
	&Log("confirm[firstime] syntax error");
	&Log("confirm request[$buffer]");
	$_ .= "Syntax Error! Please use the following syntax\n";
	$_ .= "\n   $CONFIRMATION_SUBSCRIBE Your-Name ";
	$_ .= "(Name NOT E-Mail Address)\n";
	$_ .= "\nwhere \"Your Name\" for clearer identification. ";
	$_ .= "For example,\n\n";
	$_ .= "   $CONFIRMATION_SUBSCRIBE Elena Lolabrigita";
	&Mesg(*e, $_);
	$e{'message:append:files'} = $CONFIRMATION_FILE;
	return 0;
    }

    if ($buffer =~ /\@/) {
	&Mesg(*e, "Please use your name NOT E-Mail Address!");
	&Mesg(*e, "For Example:");
	&Mesg(*e, "\t\"$CONFIRMATION_SUBSCRIBE Elena Lolabrigita\"");

	$e{'message:append:files'} = $CONFIRMATION_FILE;
	return 0;
    }
    else {
	return $name;
    }
}

sub FirstTimeP
{
    local(*r, $addr, $cur_time) = @_;
    local($time, $key_addr, $a, $id, $name, $match, $addr_found);
    local($status);

    # init variables;
    $cur_time   = time;
    ($key_addr) = split(/\@/, $addr);

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return $NULL);
    while (<FILE>) {
	chop;
	($time, $a, $id, $name) = split(/\s+/, $_, 4);

	# pre-match for faster code;
	next if $a !~ /^$key_addr/i;

	# address match
	&AddressMatch($addr, $a) || next;

	# already address is OK;
	if ($time + ($CONFIRMATION_EXPIRE*3600) < $cur_time) {
	    &Log("Confirmation [id=$id] is already Expired");
	    $status = 'expired';
	}
	else {
	    @r = ($time, $a, $id, $name);
	    $status = 'confirmed';
	}
    }
    close(FILE);

    @r = ($time, $a, $id, $name);
    return ($status ? $status : 'first-time');
}


sub RemoveAddrInConfirmFile
{
    local($addr) = @_;
    local($time, $key_addr, $a, $id, $name, $match, $addr_found);
    local($status);

    # init
    ($key_addr) = split(/\@/, $addr);

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return $NULL);
    open(BAK, "> $CONFIRMATION_LIST.bak") || 
	(&Log("cannot open $CONFIRMATION_LIST.bak"), return $NULL);
    select(OUT); $| = 1; select(STDOUT);
    open(OUT, "> $CONFIRMATION_LIST.new") || 
	(&Log("cannot open $CONFIRMATION_LIST.new"), return $NULL);
    select(OUT); $| = 1; select(STDOUT);

    while (<FILE>) {
	print BAK $_;

	chop;

	($time, $a, $id, $name) = split(/\s+/, $_, 4);

	# address match
	&AddressMatch($addr, $a) && ($status++, next);

	print OUT "$_\n";
    }
    close(BAK);
    close(OUT);
    close(FILE);

    if ($status) {
	&Log("remove $addr in confirmation queue");
    }

    if (! rename("$CONFIRMATION_LIST.new", $CONFIRMATION_LIST)) {
	&Log("fail to rename $CONFIRMATION_LIST");
	return $NULL;
    }

    1;
}


sub GenKey
{
    local($seed) = @_;
    local($key)  = time|$$;

    srand($key);
    int(rand($seed + $key));
}

1;
