# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id: libcompat_fml20.pl,v 1.3 2001/04/08 07:05:42 fukachan Exp $


sub ProcRetrieveFileInSpool_FML_20
{
    local($proc, *Fld, *e, *misc, *cat, $ar, $mail_file) = @_;
    
    $cat{"$SPOOL_DIR/$ID"} = 1;
    if ($ar eq 'TarZXF') {  
	&use('utils');
	# XXX malloc() ...
	&Sendmail($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		  &TarZXF("$DIR/$mail_file", 1, *cat));
    }
    else {
	&SendFile($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		  "$DIR/$mail_file", 
		  $_PCB{'libfml', 'binary'});
	undef $_PCB{'libfml', 'binary'}; # destructor
    }

    &Log("Get $ID, Success");
}


# check mail from members or not? return 1 go on to Distribute or Command!
sub MLMemberNoCheckAndAdd { &DoMLMemberCheck;}; # backward compatibility
sub DoMLMemberCheck
{
    local($k, $v, $file);

    $0 = "${FML}: Checking Members or not <$LOCKFILE>";

    &AdjustActiveAndMemberLists; # tricky

    while (($k, $v) = each %SEVERE_ADDR_CHECK_DOMAINS) {
	print STDERR "/$k/ && ADDR_CHECK_MAX += $v\n" if $debug; 
	($From_address =~ /$k/) && ($ADDR_CHECK_MAX += $v);
    }

    return 1 if $Envelope{'mode:anyoneok'}; # --anyoneok == '+';

    print STDERR "ChAddrModeP $Envelope{'mode:uip:chaddr'} ? " if $debug;

    ### if "chaddr old-addr new-addr " is a special case of
    # $Envelope{'mode:uip:chaddr'} is the line "# chaddr old-addr new-addr"
    if ($Envelope{'mode:uip:chaddr'}) {
	&use('utils');
	&ChAddrModeOK($Envelope{'mode:uip:chaddr'}) && 
	    (return $Envelope{'mode:uip'} = 'on');
    }

    &Debug("NOT") if $debug;

    ### WHETHER a member or not?, Go ahead! if a member
    # AUTHENTICATED Even if the admin member is not a member of MEMBER_LIST
    &MailListMemberP($From_address) && (return 1);

    # here not authenticated;
    $Envelope{'mode:stranger'} = 1;

    # Hereafter must be mail from not member
    # Crosspost extension.
    if ($USE_CROSSPOST && $Envelope{'crosspost'}) {
	&Log("Crosspost from not member");	    
	&WarnE("Crosspost from not member: $From_address $ML_FN", $NULL);
	return 0;
    }

    if ($ML_MEMBER_CHECK) {
	# When not member, return the deny file.
	&Reject;
	return 0;
    } 
    else {
	# original designing is for luna ML (Manami ML)
	# If failed, add the user as a new member of the ML	
	$0 = "${FML}: Checking Members and add if new <$LOCKFILE>";

	&use('amctl');
	return &AutoRegist(*Envelope);
    }
}    


1;
