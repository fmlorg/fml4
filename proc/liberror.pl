# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#


sub NotifyMailSizeOverFlow
{
    local(*e) = @_;
    local($subj, $body);

    &Log("ERROR: in-coming mail body size > $INCOMING_MAIL_SIZE_LIMIT bytes.");

    $subj = 
	"ERROR: In-coming mail body size > $INCOMING_MAIL_SIZE_LIMIT $ML_FN";
	
    $body = "--- Error ---\n";
    $body .= 
	"In-coming mail size exceeds $INCOMING_MAIL_SIZE_LIMIT bytes.\n\n";

    if ($NOTIFY_MAIL_SIZE_OVERFLOW) { 
	$body .= "I'll warn it to the sender (since \$NOTIFY_MAIL_SIZE_OVERFLOW is set).\n";
    }
    if ($ANNOUNCE_MAIL_SIZE_OVERFLOW) {
	$body .= "I'll announce it to ML if the content seems a posted article.\n";
	$body .= "(since \$ANNOUNCE_MAIL_SIZE_OVERFLOW is set).\n";
    }

    $body .= "Here is the received mail.\n";
    $body .= ("-" x 60). "\n";

    # forwarded to maintainer
    $e{'ctl:smtp:stdin2socket'} = 1;
    &Log("Forwarded to \$MAINTAINER");

    # XXX malloc() too much? though restricted by upper bound here.
    &Warn($subj, $body.$e{'Header'}."\n".$e{'Body'});
    undef $e{'ctl:smtp:stdin2socket'};

    if ($NOTIFY_MAIL_SIZE_OVERFLOW) { &NotifyMailSizeOver2Sender;}
}


sub NotifyMailSizeOver2Sender
{
    my ($s);
    $s .= "ATTENTION! Your mail is too big, so not processed!!!\n";
    $s .= "This ML <$MAIL_LIST> restricts the maximum mail size,\n";
    $ s.= "so pay attention to the mail with e.g. attachments.";
    &Mesg(*e, $s, 'resource.too_big');
}


sub AnnounceMailSizeOver
{
    local(*e) = @_;
    local($h, $body);

    $body  = "Hello, I am fml ML manager.\n";
    $body .= "This ML restricts the MAXIMUM MAIL SIZE.\n";
    $body .= "I\'ve received the following mail and reject it\n";
    $body .= "since it is ***** TOO BIG ***** !!!\n";
    $body .= "\n";
	
    undef $e{'Body'};

    # MIME decode
    if ($h =~ /=\?ISO\-2022\-JP\?/io) {
	$h = &DecodeMimeStrings($e{'Header'});
    }
    else {
	$h = $e{'Header'};
    }

    $h =~ s/^/   /g;
    $h =~ s/\n/\n   /g;
    $e{'Body'} = "$body$h\n   ... (body is suppressed since too big) ...\n";

    # reset header
    $e{'h:Subject:'}  = "REJECT TOO BIG MAIL ($e{'h:Subject:'})";
    $e{'h:From:'}     = $MAINTAINER;
    $e{'h:Reply-To:'} = $MAIL_LIST;
}


1;
