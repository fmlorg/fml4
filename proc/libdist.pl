# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


sub DoDistribute
{
    local(*e) = @_;

    $0 = "${FML}: Distributing <$MyProcessInfo>";
    local($status, $s, $id);

    # DECLARE: Global Rcpt Lists; and the number of recipients;   
    @Rcpt = (); $Rcpt = 0;

    $DISTRIBUTE_START_HOOK && 
	&eval($DISTRIBUTE_START_HOOK, 'DISTRIBUTE_START_HOOK');

    # Cut off multipart or reject by mail's Content-Type handler
    # The existence of $AGAINST_HTML_MAIL and $HTML_MAIL_DEFUALT_HANDLER
    # are backward compatible.
    if (@MailContentHandler > 0) {
	&use('disthack'); 
    	my ($status) = &ContentHandler(*e);
	if ($status eq 'reject') { return $NULL;}
    }

    # PGP Encryption
    if ($USE_ENCRYPTED_DISTRIBUTION) {
	if ($ENCRYPTED_DISTRIBUTION_TYPE eq 'pgp'  ||
	    $ENCRYPTED_DISTRIBUTION_TYPE eq 'pgp2' ||
	    $ENCRYPTED_DISTRIBUTION_TYPE eq 'pgp5' ||
	    $ENCRYPTED_DISTRIBUTION_TYPE eq 'gpg') {
	    require 'libpgp.pl';
	    &EncryptedDistributionInit0;

	    $_PCB{'asymmetric_key'}{'keyring_dir'} = 
		$DIST_ENCRYPT_KEYRING_DIR;

	    # check PGP signature
	    if (&PGPGoodSignatureP(*e, 1)) {
		&Log("PGP encryption mode sets in");
		undef $PGPError;
		&PGPDecode(*e);
		&PGPEncode(*e);

		if ($PGPError) {
		    &Log("no delivery for something errors of PGP");
		    &Mesg(*e, 
			  "something PGP error occors, ". 
			  "so it seems encrpytion fails.\n",
			  "pgp.encryption.error");
		    &Mesg(*e, 'not authenticated', 'EAUTH');
		    return 0;
		}
	    }
	    else {
		&Log("invalid PGP signature, no delivery");
		&Mesg(*e, 
		      "Your PGP signature seems incorrect. ".
		      "ML delivery is not allowed.",
		      "pgp.incorrect_signature");
		&Mesg(*e, 'not authenticated', 'EAUTH');
		return 0;
	    }
	}
	else {
	    &Log("unknown \$ENCRYPTED_DISTRIBUTION_TYPE = $ENCRYPTED_DISTRIBUTION_TYPE");
	}
    }

    if ($DO_NOTHING) { return 0;}

    ### declare distribution mode (see libsmtp.pl) # (preamble, trailer);
    $e{'mode:dist'} = 1;

    ##### ML Preliminary Session Phase 01: set and save ID
    # Define the curren time 
    &GetTime;

    # Date: type
    if ($DATE_TYPE eq 'distribute-date+x-posted') {
	$e{'h:Date:'}     = $MailDate;
	$e{'h:X-Posted:'} = $e{'h:date:'} || $e{'h:Date:'};
    }
    elsif ($DATE_TYPE eq 'distribute-date+x-original-date') {
	$e{'h:Date:'}     = $MailDate;
	$e{'h:X-Original-Date:'} = $e{'h:date:'} || $e{'h:Date:'};
    }
    elsif (($DATE_TYPE eq 'distribute-date') ||
	   ($DATE_TYPE eq 'distribute-date+posted')) {
	$e{'h:Date:'}   = $MailDate;
	$e{'h:Posted:'} = $e{'h:date:'} || $e{'h:Date:'};
    }

    # Get the present ID
    if (! open(IDINC, $SEQUENCE_FILE)) { return;} # test
    $ID = &GetFirstLineFromFile($SEQUENCE_FILE);
    $ID++;			# increment, GLOBAL!

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $SEQUENCE_FILE) || return;

    # wait for sync against duplicated ID for slow IO or broken calls
    {
	local($newid, $waitc);
	while (1) {
	    $newid = &GetFirstLineFromFile($SEQUENCE_FILE);
	    last if $newid == $ID;
	    last if $waitc++ > 10;
	    sleep 1;
	}

	&Log("FYI: $waitc secs for \$SEQUENCE_FILE sync") if $waitc > 1;

	# to fix duplicated ID's; ?(but how we can detect all cases)
	# if (-f "$FP_SPOOL_DIR/$ID") { &use('er'); &FixID;}
    }

    ##### ML Preliminary Session Phase 02: $DIR/summary
    # save summary and put log
    $s = $e{'h:Subject:'};
    while ($s =~ s/\n(\s+)/$1/g) { 1;} # against multiple lines

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($e{'MIME'}) { &use('MIME'); $s = &DecodeMimeStrings($s);}

    # fml-support: 02007
    $s =~ s/^\s*//; # required???

    if ($DISTRIBUTE_SUMMARY_HOOK) {
	eval $DISTRIBUTE_SUMMARY_HOOK;
	&Log($@) if $@;
    }
    else {
	&Append2(sprintf("%s [%d:%s] %s", 
			 $Now, $ID, substr($From_address, 0, 15), $s),
		 $SUMMARY_FILE) || return;
    }

    # Original is for 5.67+1.6W, but R8 requires no MX tuning tricks.
    # So version 0 must be forever(maybe) :-)
    # RMS = Relay, Matome, Skip; C = Crosspost;
    $Rcsid =~ s/^(.*)(\#\d+\s+.*)/$1.($USE_CROSSPOST?"(rmsc)":"(rms)").$2/e;
    $Rcsid =~ s/\)\(/,/g;

    # plural active_list available (97/03/26)
    # Global Rcpt is already initialized;
    # Set @Rcpt if not DLA; usually (in DLA), only scan [mrs]= options;
    {
	local(@a) = (@ACTIVE_LIST, $ACTIVE_LIST); 
	&Uniq(*a); # here uniqed
	for (@a) { &ReadActiveRecipients($_);}
    }

    ##### ML Distribute Phase 01: Fixing and Adjusting *Header
    # Run-Hooks. when you require to change header fields...
    $SMTP_OPEN_HOOK && &eval($SMTP_OPEN_HOOK, 'SMTP_OPEN_HOOK:');

    # set Reply-To:, use "ORIGINAL Reply-To:" if exists ??? (96/2/18, -> Reply)
    $e{'h:Reply-To:'} = 
	$e{'fh:reply-to:'} || $e{'h:Reply-To:'} || $MAIL_LIST;

    # get ID (the current sequence of the Mailing List)
    # 96/05/07 set $id here for each mode 
    $id = $SUBJECT_FORM_LONG_ID ?
	&LongId($ID, $SUBJECT_FORM_LONG_ID) : sprintf("%05d", $ID);

    # Subject ReConfigure;
    { 
	# strip off trailing \s+ against lame MUA ;-)
	$e{'h:Subject:'} =~ s/\s+$//;

	local($pat);
	local($subject) = $e{'h:Subject:'} || $Subject; # original
	$subject =~ s/^\s*//;

	if ($SUBJECT_HML_FORM) {# FIX (95/07/03) kise@ocean.ie.u-ryukyu.ac.jp;
	    if ($HML_FORM_LONG_ID || $SUBJECT_FORM_LONG_ID) {
		$id = &LongId($ID, $HML_FORM_LONG_ID || $SUBJECT_FORM_LONG_ID);
	    }
	    $pat = "[$BRACKET:$id]";
	    $e{'h:Subject:'} = "[$BRACKET:$id] $subject";
	}
	elsif ($SUBJECT_FREE_FORM) {
	    if ($SUBJECT_FORM_LONG_ID) {
		$id = &LongId($ID, $SUBJECT_FORM_LONG_ID);
	    }

	    if ($BRACKET_SEPARATOR ne '') {
		$pat = $BEGIN_BRACKET.$BRACKET.$BRACKET_SEPARATOR.$id.$END_BRACKET;
	    }
	    else {
		if ($BRACKET) {
		    $pat = $BEGIN_BRACKET.$BRACKET.$END_BRACKET;
		}
		else {
		    $pat = $BEGIN_BRACKET.$id.$END_BRACKET;
		}
	    }

	    $e{'h:Subject:'} = "$pat $subject";
	}

	if ($USE_MIME && $e{'h:Subject:'} =~ /=\?ISO-2022-JP\?/i) {
	    $e{'h:Subject:'} = &DecodeMimeStrings($e{'h:Subject:'});
	    $e{'h:Subject:'} = &mimeencode($e{'h:Subject:'});
	}

	if ($AGAINST_MAIL_WITHOUT_REFERENCE) {
	    if ($pat) {
		&use('disthack');
		&AgainstReplyWithNoRef(*e, $pat);
	    }
	    else {
		&Log("\$AGAINST_MAIL_WITHOUT_REFERENCE not work of no defined subject tag");

	    }
	}
    }

    # Run-Hooks
    $HEADER_ADD_HOOK && &eval($HEADER_ADD_HOOK, 'Header Add Hook');

    # Message ID: e.g. 199509131746.CAA14139@axion.phys.titech.ac.jp
    # 95/09/14 add the fml Message-ID for more powerful loop check
    # /etc/sendmail.cf H?M?Message-Id: <$t.$i@$j>
    # <>fix by hyano@cs.titech.ac.jp 95/9/29
    # e.g. for the change of $e{'h:Message-Id:'} in HOOK...
    if (! $USE_ORIGINAL_MESSAGE_ID) {
	$e{'h:Message-Id:'}  = 
	    ($e{'h:Message-Id:'} ne $e{'h:message-id:'}) ?
		$e{'h:Message-Id:'} : &GenMessageId;
 	&CacheMessageId(*e);
    }
		      
    # STAR TREK SUPPORT:-);
    if ($APPEND_STARDATE) { &use('stardate'); $e{'h:X-Stardate:'} = &Stardate;}

    # Server info to add
    $e{'h:X-MLServer:'}  = $Rcsid if $Rcsid;
    $e{'h:X-MLServer:'} .= "\n\t($rcsid)" if $debug && $rcsid;
    $e{"h:$XMLCOUNT:"}   = $id || sprintf("%05d", $ID); # 00010;
    $e{"h:X-ML-Info:"}   = &GenXMLInfo;

    # XXX smtpfeed -1 -F hack
    # See smtpfeed/ML-ADMIN for more details
    if ($USE_SMTPFEED_F_OPTION) {
	if (($ID % 100) == 0) { 
	    push(@HdrFieldsOrder, 'X-Smtpfeed');
	    $e{"h:X-Smtpfeed:"} = 1;
	}
    }

    ##### ML Distribute Phase 02: Generating Hdr
    # This is the order recommended in RFC822, p.20. But not clear about X-*
    local(%dup);
    for (@HdrFieldsOrder) {
	&Debug("DoDistribute:DUP FIELD\t$_") if $dup{$_} && $debug;
	next if $dup{$_}; $dup{$_} = 1; # duplicate check;

	# for more readability
	$e{"h:$_:"} =~ s/^(\S)/ $1/;

	# print STDERR "\$e{'h:$_:'}\t". $e{"h:$_:"} ."\n";
	$lcf = $_; $lcf =~ tr/A-Z/a-z/; # lower case field name

	if ($debug_dist && ($e{"fh:$lcf:"} || $e{"oh:$lcf:"})) {
	    print STDERR "$_:\n   force:\t$e{\"fh:$lcf:\"}\n";
	    print STDERR "   original:\t$e{\"oh:$lcf:\"}\n";
	    print STDERR "   \t\t$e{\"h:$_:\"}\n";
	}

	if ($e{"fh:$lcf:"}) {	# force some value to a field
	    $e{'Hdr'} .= "$_: ". $e{"fh:$lcf:"} ."\n";
	}
	elsif ($e{"oh:$lcf:"}) { # original fields
	    $e{'Hdr'} .= "$_:". $e{"h:$lcf:"} ."\n" if $e{"h:$lcf:"};
	}
	elsif (/^:body:$/o && $body) {
	    $e{'Hdr'} .= $body;
	}
	elsif (/^:any:$/ && $e{'Hdr2add'}) {
	    $e{'Hdr'} .= $e{'Hdr2add'};
	}
	# ALREADY EXIST?
	elsif (/^Message\-Id/i && ($body =~ /Message\-Id:/i)) { 
	    ;
	}
	elsif (/^:XMLNAME:$/o) {
	    $e{'Hdr'} .= "$XMLNAME\n";
	}
	elsif (/^:XMLCOUNT:$/o) {
	    $e{'Hdr'} .= "$XMLCOUNT: $e{\"h:$XMLCOUNT:\"}\n";
	}
	elsif ($e{"h:$_:"}) {
	    $e{'Hdr'} .= "$_:".($e{"fh:$lcf:"} || $e{"h:$_:"})."\n";
	}
    }

    # fixing;
    $e{'Hdr'} =~ s/[\s\n]*$/\n/;

    ##### ML Distribute Phase 03: Spooling
    # spooling, check dupulication of ID against e.g. file system full
    # not check the return value, ANYWAY DELIVER IT!
    # IF THE SPOOL IS MIME-DECODED, NOT REWRITE %e, so reset %me <- %e;
    # 
    local($umask) = umask(027) if $USE_FML_WITH_FMLSERV;

    if ($NOT_USE_SPOOL) {
	&Log("ARTICLE $ID");
    }
    elsif (! -f "$FP_SPOOL_DIR/$ID") {	# not exist
	&Log("ARTICLE $ID");
	&Write3(*e, "$FP_SPOOL_DIR/$ID");
    } 
    else { # if exist, warning and forward againt DISK-FULL;
	&Log("ARTICLE $ID", "ID[$ID] dupulication");

	local($f) = "$FP_VARLOG_DIR/DUP$CurrentTime";
	&HashValueAppend(*Envelope, "Hdr", $f);
	&Append2("\n", $f);
	&HashValueAppend(*Envelope, "Body", $f);

	&WarnFile("ERROR:ARTICLE ID dupulication $ML_FN", $f,
		  "FYI: saved in $FP_VARLOG_DIR/DUP$CurrentTime\n\n");
    }

    umask($umask) if $USE_FML_WITH_FMLSERV;

    ##### ML Distribute Phase 04: SMTP
    # IPC. when debug mode or no recipient, no distributing 
    &Deliver;

    ##### ML Distribute Phase 05: ends
    $DISTRIBUTE_END_HOOK .= $SMTP_CLOSE_HOOK;
    $DISTRIBUTE_END_HOOK .= $DISTRIBUTE_CLOSE_HOOK;
    if ($DISTRIBUTE_END_HOOK) {
	&eval($DISTRIBUTE_END_HOOK, 'DISTRIBUTE_END_HOOK');
    }

    if ($USE_DATABASE) {
	&use('databases');

	my (%mib, %result, %misc, $error);
	&DataBaseMIBPrepare(\%mib, 'store_article');
	$mib{'_article_id'} = $ID;
	&DataBaseCtl(\%Envelope, \%mib, \%result, \%misc); 
	if ($mib{'error'}) { return 0;}
    }
}


sub ReadActiveRecipients
{
    local($active) = @_;

    &Log("ReadActiveRecipients:$active") if $debug_active;

    ##### ML Preliminary Session Phase 03: get @Rcpt
    if (! open(ACTIVE_LIST, $active)) { return 0;}

    # Under DLA_HACK PreProcessing Section;
    # Get a member list to deliver
    # After 1.3.2, inline-code is modified for further extentions.
    {
	local($rcpt, $lc_rcpt, $opt, $w, $relay);
	local($who, $domain, $mxhost, $k, $v);

	# default setting %SKIP and compat (obsolete %Skip);
	# append something to the current %SKIP;
	for $k (keys %Skip) { $k =~ tr/A-Z/a-z/; $SKIP{$_} = 1;}

	for ($MAIL_LIST, $CONTROL_ADDRESS) {
	    $k = $_; $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	    ($who) = split(/\@/, $_);
	    $k = "$who\@$DOMAINNAME"; $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	    $k = "$who\@$FQDN";   $k =~ tr/A-Z/a-z/; $SKIP{$k} = 1;
	}

      line: while (<ACTIVE_LIST>) {
	  chop;

	  next line if /^\#/o;	 # skip comment and off member
	  next line if /^\s*$/o; # skip null line

	  # strip comment, not \S+ for mx;
	  s/(\S+)\s+\#.*$/$1/;

	  # Backward Compatibility; tricky "^\s".Code above need no /^\#/o;
	  s/\smatome\s+(\S+)/ m=$1 /i;
	  s/\sskip\s*/ s=skip /i;

	  ($rcpt, $opt) = split(/\s+/, $_, 2);
	  $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

	  $lc_rcpt = $rcpt;
	  $lc_rcpt =~ tr/A-Z/a-z/; # lower case;

	  printf STDERR "%-30s %s\n", $rcpt, $opt if $debug;

	  next line if $opt =~ /\s[ms]=/i;	# tricky "^\s";
	  next line if $SKIP{$lc_rcpt}; # SKIP FIELD;

	  # Relay server (RFC821 syntax 97/02/01)
	  # % relay hack is not refered in RFC, but effective in Sendmail's;
	  if ($opt =~ /\sr=(\S+)/i || $DEFAULT_RELAY_SERVER) {
	      $relay = $1 || $DEFAULT_RELAY_SERVER;
	      # % hack
	      #($who, $mxhost) = split(/@/, $rcpt, 2);
	      # DLA_HACK: $rcpt is original "addr" in ACTIVE_LIST;
	      # $RelayRcpt{$rcpt} = "${who}\%${mxhost}\@${relay}";
	      # $rcpt = "${who}\%${mxhost}\@${relay}";
	      # "Key" of %RclayRcpt is lower case for convenice;
	      $RelayRcpt{$lc_rcpt} = "\@${relay}:$rcpt";
	      $rcpt = "\@${relay}:$rcpt";
	  }

	  $Rcpt++; # count the number of recipients;
      }

	close(ACTIVE_LIST);
    }
}


# Thoreticaly all file IO have been done and needed info are on the memory.
# So we must be able to do UNLOCK our current process.
sub Deliver
{
    local($status, $smtp_time);

    if ($debug) {
	if ($debug & $DEBUG_OPT_DELIVERY_ENABLE) {
	    &Log("info: debug mode but deliver article");
	}
	else {
	    &Log("DEBUG MODE: NO DELIVER rcpt=[$Rcpt] debug=[$debug]");
	    return 1;
	}
    }
    elsif ($Envelope{'mode:article_spooling_only'}) {
	&Log("not deliver in article spooling only mode");
	return 1;
    }

    if ($Rcpt == 0) { return;} # NO RCPT

    $Envelope{'mode:__deliver'} = 1; # notify the &Smtp deliver mode;

    $smtp_time = time;
    $status = &Smtp(*Envelope, *Rcpt);
    &Log("Smtp:$status") if $status;
    &StatDelivery($smtp_time, $Rcpt) if $debug_stat;

    undef $Envelope{'mode:__deliver'};
}

sub StatDelivery
{
    local($smtp_time, $nrcpt) = @_;

    $smtp_time = time - $smtp_time;
    $pdt = $smtp_time/$nrcpt;
    &Log("Delivery Stat[$ID]: ${smtp_time}/${nrcpt} = ${pdt} sec./rcpts");
}

# return Long ID FORM
sub LongId
{
    local($id, $howlong) = @_;
    local($s);

    # require '< 2' condition to ensure backward compatibility
    if ($howlong > 0) {
	$howlong = $howlong < 2 ? 5 : $howlong; # default is 5;
	$id = sprintf("%0".$howlong."d", $id)
    }
    else {
	$id;
    }
}

1;
