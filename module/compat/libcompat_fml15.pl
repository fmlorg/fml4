# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id: libcompat_fml15.pl,v 2.2 2000/01/05 14:03:37 fukachan Exp $


###############################################
### ### BACKWARD COMPATIBILITY LIBRARIES ###### 
###############################################
# $Id: libcompat_fml15.pl,v 2.2 2000/01/05 14:03:37 fukachan Exp $;

sub CompatFML15_Post
{
    $Envelope{'macro:s'}        = $_Ds;

    # TO:
    $Envelope{'to:'}	        = $Original_To_address;
    $Envelope{'trap:rcpt_fields'}	= $To_address;

    # FROM:
    # $Envelope{'h:From:'}      = $Original_From_address;
    $Envelope{'h:reply-to:'}    = $Reply_to;

    # OTHER
    $Envelope{'h:Date:'}	= $Date;
    $Envelope{'h:Errors-To:'}	= $Errors_to;
    $Envelope{'h:Sender:'}	= $Sender;
    $Envelope{'h:Message-Id:'}	= $Message_Id;
    $Envelope{'h:Cc:'}	        = $Cc;
    $Envelope{'h:Subject:'}	= $Subject;

    # SUPERFLUOUS
    if ($SUPERFLUOUS_HEADERS) {
	$Envelope{'Hdr2add'}    = $SuperfluousHeaders;
    }

    # misc
    $Envelope{'mode:uip'}       = $CommandMode;
    $Envelope{'mode:req:guide'} = $GUIDE_REQUEST;
    $Envelope{'Header'}         = $MailHeaders;
    $Envelope{'Body'}           = $MailBody;

    # though too many PLAY_TO ...
    push(@PLAY_TO, @Playing_to);
}


sub CompatFML15_Pre
{
    $_Ds                 = $Envelope{'macro:s'};

    # TO:
    $Original_To_address = $Envelope{'to:'};
    $To_address          = $Envelope{'trap:rcpt_fields'};

    # FROM:
    # $From_address      = $Envelope{'h:From:'};
    $Reply_to            = $Envelope{'h:reply-to:'};

    # OTHER
    $Date                = $Envelope{'h:Date:'};
    $Errors_to           = $Envelope{'h:Errors-To:'};
    $Sender              = $Envelope{'h:Sender:'};
    $Message_Id          = $Envelope{'h:Message-Id:'};
    $Cc                  = $Envelope{'h:Cc:'};
    $Subject             = $Envelope{'h:Subject:'};

    # SUPERFLUOUS
    if ($SUPERFLUOUS_HEADERS) {
	$SuperfluousHeaders = $Envelope{'Hdr2add'};
    }

    # misc
    $CommandMode   = $Envelope{'mode:uip'};
    $GUIDE_REQUEST = $Envelope{'mode:req:guide'};
    $MailHeaders   = $Envelope{'Header'};
    $MailBody      = $Envelope{'Body'};
    $BodyLines     = $Envelope{'nlines'};
}

##############################################################################

##### STARTREK FORM ##### 
$SMTP_OPEN_HOOK .= q#
    if ($STAR_TREK_FORM) {
	local($mon, $year) = (localtime(time))[4..5];
	local($ID) = sprintf("%02d%02d.%05d", ($year - 90) % 100, $mon + 1, $ID);
	$Envelope{'h:Subject:'} = "[$ID] $Subject";
    }
#;


##############################################################################

##### PLAY of TO: (95/10/3) ##### 
# $To_address is obsolete
$SMTP_OPEN_HOOK .= q#
    $To_address = $Envelope{"to:"};
#;
$SMTP_OPEN_HOOK .= $Playing_to;
push(@PLAY_TO, @Playing_to);


##############################################################################

###### ($host, $headers, $body) #####
sub OldSmtp
{
    local($host, $body, @headers) = @_;
    local(%e, @rcpt, @tmp);

    local($h, $b) = split(/\n\n/, $body);
    $e{'Hdr'}  = $h;
    $e{'Body'} = $b;
    @tmp       = grep(/'RCPT TO:'/, @headers);
    foreach (@tmp) { s/RCPT TO://; push(@rcpt, $_);}

    &Smtp(*e, *rcpt);
}

##############################################################################

1;
