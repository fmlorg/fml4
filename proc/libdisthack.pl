# Copyright (C) 1993-2001,2003 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001,2003 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#


# ContentHandler() by <t-nakano@imasy.or.jp>
# see fml-support ML articles for more details. For example, 
# 6229 6230 6233 6234 6235 6242 6243 6244 6245 6246 6247 6248 6253 6257
# 6263 6265 6270 6276 6313 6314 6331 6332 6333 6346 6348 6349 6350 6374
# 6379 6381 6393 6396 6397 6408 ...
sub ContentHandler
{
    local(*e) = @_;

    # PR by fml-help/1208, hmm ;) dirty fix but least change is good ;)
    local($boundary) = $e{'MIME:boundary'}; $boundary =~ s/^--//;
    local($type, $subtype, $paramaters);
    local($xtype, $xsubtype);
    local($ptr, $header, $body, $prevp);
    local($reject, $multipart, $cutoff);
    local(@actions) = ();
    local($nonMime) = 0;
    
    # Split Bodie's Content-Type($paramaters is dummy) '
    ($type, $subtype, $paramaters) = split(/[\/;]/, $e{'h:content-type:'}, 3);
    $type    =~ s/\s//g;
    $subtype =~ s/\s//g;
    $nonMime = 1 if ($type eq '');

    if ($debug_ch) {
	print STDERR "Content-Type: $e{'h:content-type:'}\n";
	print STDERR "boundary: $boundary\n";
	print STDERR "{ $type, $subtype, $paramaters\t}\n";
    }
    
    $ptr       = 0;
    $multipart = 1;

  MSG:
    while ($multipart) {
	local($bodiesp, $action);
	my $is_empty = 0;
	
	# Check Content-Type Header
	# not MIME case (no content-type:)
	if ($nonMime) {
	    # Non MIME mail
	    $type      = '!MIME';
	    $subtype   = '';
	    $xtype     = '';
	    $xsubtype  = '';
	    $multipart = 0;
	    $header    = $type;
	    $bodiesp   = -1;
	}
	# MIME case
	else {
	    # not MIME/multipart: text/* et.al.
	    if ($type ne 'multipart') {
		$xtype     = '';
		$xsubtype  = '';
		$multipart = 0;
		$header    = $type;
		$bodiesp   = -1;
	    }
	    # MIME/multipart 
	    else {
		local(@xheader, $str);
		
		# MIME mail
		$prevp = $ptr;
		($header, $body, $ptr) = &GetNextMultipartBlock(*e, $ptr);
		print STDERR "($header, \$body, $ptr)\n" if $debug_ch;

		if ($CONTENT_HANDLER_CUTOFF_EMPTY_MESSAGE) {
		    if ($body =~ /^\s*$/) {
			Log("ContentHandler: part($ptr -) looks empty");
			$is_empty = 1;
		    }
		}

		if ($header eq '' && $body eq '' && $ptr == 0) {
		    # No more part/break do-while
		    last MSG;
		}
		$bodiesp = $prevp;

		# Get Content-Type
		@xheader = split(/\n/, $header);

	      HDRFIELD:
		foreach (@xheader) {
		    if (/^Content-Type:/io) {
			$str = $_;
			$str =~ s/^Content-Type:\s*//i;
			($xtype, $xsubtype, $paramaters) =
			    split(/[\/;]/, $str, 3);
			$xtype =~ s/\s//g;
			$xsubtype =~ s/\s//g;
			last HDRFIELD;
		    }
		}
	    } # multipart case in MIME 
	} # MIME case

	# Decide action to this part
	$action = 'allow'; # enforce default action to be "allow".

	# XXX first match !!!
	# We check @MailContentHandler (ADD_CONTENT_HANDLER() order)
	# and apply the action by first match
      RULE:
	foreach (@MailContentHandler) {
	    local($t, $st, $xt, $xst, $act) = split(/\t/);
	    
	    if ($type  =~ /^$t$/i  && $subtype  =~ /^$st$/i &&
		$xtype =~ /^$xt$/i && $xsubtype =~ /^$xst$/i) {
		$action = $act;
		last RULE;
	    }
	}

	if ($is_empty) {
	    Log("ContentHandler: strip part($ptr -) due to empty");
	    $action = 'strip';
	    push (@actions, join("\t", $bodiesp, $action));
	}
	else {
	    push (@actions, join("\t", $bodiesp, $action));
	}
    }

    #
    # XXX end of use of $xtype and $xsubtype
    # XXX pass off @actions into the latter part hereafter. 
    # XXX @actions knows pointer of the part beginning and the action
    # XXX for the part.
    #
    
    # Check the existence of rules for REJECT, MULTIPART, CUTOFF
    $reject    = grep(/^.*\treject$/, @actions);
    $multipart = grep(/^.*\tallow\+multipart$/, @actions);
    $cutoff    = grep(/^.*\tstrip$/, @actions);

    if ($debug_ch) {
	print STDERR "\nMailContentHandler:\n   RULES\n";

	my $i = 0;
	for (@MailContentHandler) { $i++; print STDERR "   ${i}: ",$_,"\n";}

	print STDERR "\n";
	$i = 0;
	for (@actions) { $i++; print STDERR "   part(${i})->action($_)\n";}

	print STDERR "
         reject: $reject
      multipart: $multipart 
         cutoff: $cutoff\n\n";
    }
    
    # reject
    if ($reject) {
	&Mesg(*e, "We deny non plaintext mails", 'filter.reject_non_text_mail');
	&MesgMailBodyCopyOn;
	&Log("reject multipart mail");
	return "reject";
    } 
    else { # rebuild message body
	local($outputbody) = '';
	local($deletebody) = '';
	
	if ($multipart) {
	    if ($boundary eq '') {
		$boundary = 'simpleboundary==';
	    }
	    foreach (@actions) {
		local($bodiesp, $action) = split(/\t/);
		
		if ($bodiesp == -1) {
		    $body = $e{'Body'};
		    $header = '!MIME';
		} 
		else {
		    ($header, $body, $ptr) =
			&GetNextMultipartBlock(*e, $bodiesp);
		    print STDERR "($header, \$body, $ptr)\n" if $debug_ch;
		}
		if ($action eq 'allow' ||
		    $action eq 'allow+multipart' ||
		    $action eq '') {
		    if ($header eq '!MIME') {
			$outputbody .= '--' . $boundary . "\n" .
			    "Content-Type:" . $e{'h:content-type:'} . "\n\n" .
				$body;
		    } 
		    else {
			$outputbody .= $header . $body;
		    }
		} 
		elsif ($action eq 'strip+notice') {
		    if ($header eq '!MIME') {
			$deletebody .= $body . "\n";
		    }
		    else {
			$deletebody .= $header . $body . "\n";
		    }
		}
		# strip is do-nothing
	    }
	    $outputbody .= '--' . $boundary . "--\n";
	    # Fix mail header
	    if ($nonMime) {
		$e{'h:Content-Type:'} =
		    "multipart/mixed; boundary=\"$boundary\"";
		$e{'h:Mime-Version:'} = '1.0';
		$e{'h:Content-Transfer-Encoding:'} = '7bit';
	    }
	} 
	else {
	    local($singlepart) = 0;
	    
	    foreach (@actions) {
		local($bodiesp, $action) = split(/\t/);
		
		if ($bodiesp == -1) {
		    $body       = $e{'Body'};
		    $header     = '!MIME';
		    $singlepart = 1;
		} 
		else {
		    ($header, $body, $ptr) =
			&GetNextMultipartBlock(*e, $bodiesp);
		    print STDERR "($header, \$body, $ptr)\n" if $debug_ch;
		}
		if ($action eq 'allow' || $action eq '') {
		    $outputbody .= $body;
		} elsif ($action eq 'strip+notice') {
		    if ($header eq '!MIME') {
			$deletebody .= $body . "\n";
		    } 
		    else {
			$deletebody .= $header . $body . "\n";
		    }
		}
		# strip is do-nothing
	    }
	    # Fix mail header, if original is multipart.
	    if (!$singlepart) {
		$e{'h:Content-Type:'} = 'text/plain';
		$e{'h:Mime-Version:'} = '1.0';
		$e{'h:Content-Transfer-Encoding:'} = '7bit';
	    }
	}

	$e{'Body'} = $outputbody;

	if ($CONTENT_HANDLER_REJECT_EMPTY_MESSAGE) {
	    if ($e{'Body'} =~ /^\s*$/o) {
		Log("ContentHandler: reject has no effective mesage");
		return "reject";
	    }
	}

	if ($deletebody ne '') {
	    # Notice
	    &Mesg(*e, "strip attachments", 
		  'filter.strip_notice_non_text_mail');
	    &Mesg(*e, $deletebody);
	    &Log("Strip multipart mail and return notice");
	    return ('strip+notice');
	}

	if ($cutoff) {
	    &Log("Strip multipart mail");
	    return ('strip');
	}

	return ($NULL);
    } # rebuild message

    return $NULL;
}


sub AgainstReplyWithNoRef
{
    local(*e, $pat) = @_;
    local($buf, @buf);

    # no $SUBJECT_FREE_FORM_REGEXP defined
    if ($SUBJECT_FREE_FORM_REGEXP eq '') {
	&Log("ERROR: \$AGAINST_MAIL_WITHOUT_REFERENCE not work "
	     ."without \$SUBJECT_FREE_FORM_REGEXP");
	return $NULL;
    }

    # add "forced Messasge-ID:";
    &ADD_FIELD('X-Original-Message-Id');
    $e{'h:X-Original-Message-Id:'} = $e{'h:message-id:'};
    $e{'h:Message-Id:'} = "<mid-". $ID . "-". $MAIL_LIST.">";

    # fml-support: 6219; add by kokubo776@okisoft.co.jp 05/15/1999
    # check subject tag in mis-encoded ASCII char
    if ($e{'h:subject:'} =~ /=\?ISO\-2022\-JP\?/io
	&& ($e{'h:subject:'} !~ /($SUBJECT_FREE_FORM_REGEXP)/)) {
	&use('MIME');
        $e{'h:subject:'} = &DecodeMimeStrings($e{'h:subject:'});
        $e{'h:subject:'} = &mimeencode($e{'h:subject:'});
        $e{'h:subject:'} =~ s/\n$//;
    }

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
