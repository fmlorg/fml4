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


sub AgainstHtmlMail
{
    local(*e) = @_;
    local($boundary) = $e{'MIME:boundary'};
    local($buf, $p, $sp);

    if ($e{'h:content-type:'} =~ /multipart/i) {
	if ($HTML_MAIL_DEFAULT_HANDLER eq 'reject') {
	    &Mesg(*e, $NULL, 'filter.reject_html_mail');
	    &Mesg(*e, "This mailing list <$MAIL_LIST> denies HTML mail.");
	    &Mesg(*e, "Please send your mail by PLAIN TEXT!");
	    &Mesg(*e, &WholeMail);
	    &Log("reject HTML mail");
	    return "reject";
	}
	# not defined case (compatible)
	elsif (($HTML_MAIL_DEFAULT_HANDLER eq 'strip') ||
	       (!$HTML_MAIL_DEFAULT_HANDLER)) {
	    $p  = index($e{'Body'}, $boundary, 0);
	    $p  = index($e{'Body'}, $boundary, $p + 1);
	    $sp = $p;

	    $buf .= substr($e{'Body'}, 0, $sp);
	    $p    = index($e{'Body'}, "$boundary--", 0);
	    $buf .= substr($e{'Body'}, $p);

	    if ($buf) {
		$e{'Body'} = 
		    "FYI: FML automatically cuts off HTML part(s).\n\n";
		$e{'Body'} .= $buf;
	    }

	    &Log("cut off HTML part");
	    return "strip";
	}
    }

    $NULL;
}


sub AgainstReplyWithNoRef
{
    local(*e, $pat) = @_;
    local($buf, @buf);

    # no $SUBJECT_FREE_FORM_REGEXP defined
    if ($SUBJECT_FREE_FORM_REGEXP eq '') {
	&Log("Error: \$AGAINST_MAIL_WITHOUT_REFERENCE not work "
	     ."without \$SUBJECT_FREE_FORM_REGEXP");
	return $NULL;
    }

    # add "forced Messasge-ID:";
    &ADD_FIELD('X-Original-Message-Id');
    $e{'h:X-Original-Message-Id:'} = $e{'h:message-id:'};
    $e{'h:Message-Id:'} = "<mid-". $ID . "-". $MAIL_LIST.">";

    # extract/speculate referenced Message-ID:
    # IF BOTH Message-ID: and In-Reply-To: DO NOT EXIST!
    # e.g. [Elena 00100] => 00100 => 100
    if ($e{'h:subject:'} =~ /($SUBJECT_FREE_FORM_REGEXP)/) {
	$buf = $1;
	if ($BRACKET_SEPARATOR ne '') {
	    @buf = split($BRACKET_SEPARATOR, $buf);
	}

	# we need to extrace the ID part only to generate virtual Message-ID.
	# e.g. [Elena 00100] => 00100 => 100
	$buf = $buf[1] || $buf[0] || $buf;
	$buf =~ s/\D//g;
	$buf =~ s/^0+//;

	local($xref) = "<mid-${buf}-$MAIL_LIST>";

	# append it to References:.
	# If we can emulate Message-ID: and the references: does not
	# contain it, we add it. fml-support: 05852
	if ($buf &&
	    ($e{'h:references:'} !~ /$xref/i) &&
	    ($e{'h:in-reply-to:'} !~ /$xref/i)) {
	    $e{'h:References:'} .= " ". $xref;
	}
    }
    else {
	&Log("AgainstEudora: subject has no tag") if $debug;
    }
}


1;
