# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

sub ConfirmationModeInit
{
    # save the request and given identifier;
    # The concept of KEYWORD and ADDRESS suggeted (irc:-) by ando@iij-mc.co.jp
    $CONFIRMATION_KEYWORD = $CONFIRMATION_KEYWORD || "confirm";
    $CONFIRMATION_LIST    = $CONFIRMATION_LIST || "$FP_VARLOG_DIR/confirm";
    $CONFIRMATION_ADDRESS = $CONFIRMATION_ADDRESS || $e{'CtlAddr:'};
    $CONFIRMATION_EXPIRE  = $CONFIRMATION_EXPIRE || 7*24; # unit is "hour"

    # touch
    -f $CONFIRMATION_LIST || &Touch($CONFIRMATION_LIST);

    # transfer main to Confirm NameSpace;
    for (CONFIRMATION_KEYWORD,
	 CONFIRMATION_LIST,   
	 CONFIRMATION_ADDRESS,
	 CONFIRMATION_EXPIRE) {
	#print STDERR "$_\t";eval("print STDERR \$$_;");print STDERR "\n";
	eval("\$Confirm'$_ = \$main'$_;");
    }
}


sub DoConfirmation
{
    local(*e, $addr) = @_;
    local($id, %r);

    &ConfirmationModeInit;
    &Confirm'FirstTimeP(*e, *r, $addr);#';

    if ($r{'first_time'}) {#';
	# save infromation;
	# required info: addr id time(for expire)
	$id   = &Confirm'GenKey($from);#';
	$time = time;

	# log
	&Append2("$time\t$addr\t$id", $CONFIRMATION_LIST);

	# Header
	$Envelope{"GH:Subject:"} = "Command confirmation request ($id)";
    }
    else {
	&Log("SEDOND:: id=$r{'id'} addr=$r{'addr'}");
    }
}


package Confirm;


sub AddressMatch { &main'AddressMatch(@_);} #';
sub Log          { &main'Log(@_);} #';
sub Open         { &main'Open(@_);} #';


sub FirstTimeP
{
    local(*e, *r, $addr) = @_;
    local($cur_time, $time, $key_addr, $a, $id, $match);

    # reset %r (result);
    undef %r;

    # init variables;
    $cur_time   = time;
    ($key_addr) = split(/\@/, $addr);

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return "");
    while (<FILE>) {
	chop;
	($time, $a, $id) = split;

	# pre-match for faster code;
	next if $a !~ /^$key_addr/i;

	if (&AddressMatch($addr, $a)) {
	    $r{'addr'} = $addr;
	}
	else {
	    next;
	}

	# already address is OK;
	if ($time + ($CONFIRMATION_EXPIRE*3600) < $cur_time) {
	    &Log("Confirmation of $addr [id=$id] is already Expired");
	}
	else {
	    $r{'id'} = $id;
	}
    }
    close(FILE);

    # if %r has id, all is OK.
    $r{'first_time'} = $r{'id'} ? 0 : 1;
}


sub Save
{
    local($addr, $id, $time, $file) = @_;
}
 

sub GenKey
{
    local($seed) = @_;
    local($key)  = time|$$;

    srand($key);
    int(rand($seed + $key));
}

1;
