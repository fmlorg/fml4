# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$


sub AgainstOutLook
{
    local(*e) = @_;
    local($boundary) = $e{'MIME:boundary'};
    local($buf, $p, $sp);

    if ($e{'h:content-type:'} =~ /multipart/i) {
	$p  = index($e{'Body'}, $boundary, 0);
	$p  = index($e{'Body'}, $boundary, $p + 1);
	$sp = $p;

	$buf .= substr($e{'Body'}, 0, $sp);
	$p    = index($e{'Body'}, "$boundary--", 0);
	$buf .= substr($e{'Body'}, $p);

	if ($buf) {
	    $e{'Body'} = 
		"-- Fml automatically cuts off duplicated HTML parts.\n\n";
	    $e{'Body'} .= $buf;
	}
    }
}


sub AgainstEudora
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
    
	# append it to References:.
	if ($buf) {
	    $e{'h:References:'} .= " <mid-${buf}-$MAIL_LIST>";
	}
    }
    else {
	&Log("AgainstEudora: subject has no tag") if $debug;
    }
}


1;
