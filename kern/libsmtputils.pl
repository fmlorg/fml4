# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
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

sub DoSmtpFiles2Socket
{
    local(*f, *e) = @_;
    local($autoconv, $count, $boundary, $fn, $ml);
    local($hdr_found) = 0;

    $ml    = (split(/\@/, $MAIL_LIST))[0];
    $count = scalar(@f) > 1 ? 1 : 0;

    for $f (@f) {
	next if $f =~ /^\s*$/;
	&Debug("SmtpFiles2Socket::($f)") if $debug;

	if ($f{$f, 'zcat'}) {
	    &Log("SmtpFiles2Socket: \$ZCAT not defined") unless $ZCAT;
	}

	if ($f{$f, 'zcat'} && open(FILE, " $ZCAT $f|")) {
	    &Log("SmtpFiles2Socket: cannot zcat $f"); close(FILE); next;
	}
	elsif ($f{$f, 'uuencode'} && open(FILE, "$UUENCODE $f $f|")) {
	    &Log("SmtpFiles2Socket: cannot uuencode $f"); close(FILE); next;
	}
	else {
	    &Open(FILE, $f) || 
		(&Log("SmtpFiles2Socket: cannot open $f"), close(FILE), next);
	}

	$autoconv = $f{$f, 'autoconv'};

	if ($count) { # append the separator if more than two files;
	    $boundary = ('-' x 60)."\r\n";
	    print S $boundary;
	    print SMTPLOG $boundary;
	}

	$hdr_found = 0;
	while (<FILE>) { 
	    s/^\./../; 
	    &jcode'convert(*_, 'jis') if $autoconv;#';

	    # header
	    $hdr_found  = 1 if /^\#\.FML HEADER/;
	    
	    # guide, help, ...
	    if ($Envelope{'mode:doc:ignore#'}) {
		next if $hdr_found && (1 .. /^\#\.endFML HEADER/);
		next if /^\#/   && $Envelope{'mode:doc:ignore#'} eq 'a';
		next if /^\#\#/ && $Envelope{'mode:doc:ignore#'} eq 'm';
		if ($Envelope{'mode:doc:ignore#'} eq 'm') {
		    s/^\#\s+//;
		}
	    }

	    # guide, help, ...
	    if ($Envelope{'mode:doc:repl'}) {
		s/_DOMAIN_/$DOMAINNAME/g;
		s/_FQDN_/$FQDN/g;

		s/_ML_/$ml/g;
		s/_CTLADDR_/$Envelope{'CtlAddr:'}/g;
		s/_MAIL_LIST_/$MAIL_LIST/g;

		s/_ARG0_/$Envelope{'doc:repl:arg0'}/g;
		s/_ARG1_/$Envelope{'doc:repl:arg1'}/g;
		s/_ARG2_/$Envelope{'doc:repl:arg2'}/g;
		s/_ARG3_/$Envelope{'doc:repl:arg3'}/g;
		s/_ARG4_/$Envelope{'doc:repl:arg4'}/g;
		s/_ARG5_/$Envelope{'doc:repl:arg5'}/g;
		s/_ARG6_/$Envelope{'doc:repl:arg6'}/g;
		s/_ARG7_/$Envelope{'doc:repl:arg7'}/g;
		s/_ARG8_/$Envelope{'doc:repl:arg8'}/g;
		s/_ARG9_/$Envelope{'doc:repl:arg9'}/g;
	    }

	    s/\n/\r\n/;
	    print S $_;
	    print SMTPLOG $_;
	    $LastSmtpIOString = $_;
	};

	close(FILE);
    }
}


# NEW VERSION FOR MULTIPLE @to and @files (required @files NOT $files) 
# return NONE
sub DoNeonSendFile
{
    local(*to, *subject, *files) = @_;
    local(@info) = caller;
    local($le, %le, @rcpt, $error, $n, $f, @f, %f);

    # backward compat;
    $SENDFILE_NO_FILECHECK = 1 if $SUN_OS_413;

    ### DEBUG INFO;
    &Debug("NeonSendFile[@info]:\n\nSUBJECT\t$subject\nFILES:\t") if $debug;
    &Debug(join(" ", @files)) if $debug;
	
    ### check again $file existence
    for $f (@files) {
	next if $f =~ /^\s*$/;
	$n = $f; $n =~ s#^/*$DIR/##;

	if (-f $f) {		# O.K. anyway exists!
	    push(@f, $f);	# store it as a candidate;

	    # Anyway copy each entry of each subject(%files) to %f
	    $f{$f, 'subject'} = $files{$f, 'subject'} if $files{$f, 'subject'};

	    next if $SENDFILE_NO_FILECHECK; # Anytime O.K. if no checked;

	    # Check whether JIS or not
	    if (-z $f) {
		&Log("NeonSendFile::Error $n is 0 bytes");
	    }
	    elsif (-B $f) {
		&Log("NeonSendFile::Error $n is not JIS");

		# AUTO CONVERSION 
		eval "require 'jcode.pl';";
		$ExistJcode = $@ eq "" ? 1 : 0;

		if ($ExistJcode) {
		    &Log("NeonSendFile::AutoConv $n to JIS");
		    $f{$f, 'autoconv'} = 1;
		}
	    }

	    # misc checks
	    &Log("NeonSendFile: cannot read $n") if !-r $f;
	}
	### NOT EXISTS 
	else {
	    &Log("NeonSendFile: $n is not found.", "[ @info ]");
	    $f =~ s/$DIR/\$DIR/;
	    $error .=  "$f is not found.\n[ @info ]\n\n";
	    &Mesg(*Envelope, "NeonSendFile Error:\n\t$f is not found.\n");
	}

	$error && &Warn("ERROR NeonSendFile", $error);
	return $NULL if $error;	# END if only one error is found. Valid?
    } # for loop;

    ### DEFAULT SUBJECT. ABOVE, each subject for each file
    $le{'GH:Subject:'} = $subject;
    $le{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $le{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    &GenerateHeader(*to, *le, *rcpt);

    $le = &Smtp(*le, *rcpt, *f);
    &Log("NeonSendFile:$le") if $le;
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub DoSendFile
{
    local(@to, %le, @rcpt, @files, %files);
    local($to, $subject, $file, $zcat, @to) = @_;

    @to || push(@to, $to); # extention for GenerateHeader

    # (before it, checks whether the return address is not ML nor ML-Ctl)
    if (! &CheckAddr2Reply(*Envelope, $to, @to)) { return;}

    push(@files, $file);
    (1 == $zcat) && ($files{$f, 'zcat'} = 1);
    (2 == $zcat) && ($files{$f, 'uuencode'} = 1);

    &DoNeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
}

# Interface for sending plural files;
sub DoSendPluralFiles
{
    local(*to, *subject, *files) = @_;
    if (! &CheckAddr2Reply(*Envelope, $to, @to)) { return;}
    &DoNeonSendFile(*to, *subject, *files);
}

# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub DoSendmail
{
    local(@to, %le, @rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeader

    # (before it, checks whether the return address is not ML nor ML-Ctl)
    if (! &CheckAddr2Reply(*Envelope, $to, @to)) { return;}

    $le{'GH:Subject:'} = $subject;
    &GenerateHeader(*to, *le, *rcpt);
    
    $le{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $le{'Body'}     .= $body;
    $le{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $le = &Smtp(*le, *rcpt);
    &Log("Sendmail:$le") if $le;
}


sub DoSendmail2
{
    local(*distfile, $subject, $body) = @_;
    local(@a, $a);

    if (-f $distfile && open(DIST, $distfile)) {
	while (<DIST>) {
	    next if /^\s*$/;
	    next if /^\#/;

	    ($a) =split(/\s+/, $_);
	    push(@a, $a);
	}
	close(DIST);

	$a = shift @a; # Hmm... tricky and dirty ;D
	&DoSendmail($a, $subject, $body, @a);
    }
    else {
	&Log("cannot open $distfile");
	0;
    }
}

# SendFile2(*to, *subject, *files);
sub DoSendFile2 { &DoNeonSendFile(@_);}

# SendFile2(*distfile, *subject, *files);
# import $misc{'hook'}
sub DoSendFile3
{
    local(*distfile, *subject, *files, *misc) = @_;
    local(@to, $to, @f2s);

    $REPORT_HEADER_CONFIG_HOOK = qq#;
    $misc{'hook'};
    \$le{'mode:delivery:list'} = \"$distfile\";
    #;

    @to = ($MAINTAINER); # dummy
    push(@f2s, $files);
    push(@f2s, @files);
    &DoNeonSendFile(*to, *subject, *f2s);
}


# Generating Headers, and SMTP array
sub GenerateMail    { &DoGenerateHeaders(@_);}
sub GenerateHeaders { &DoGenerateHeader(@_);}
sub DoGenerateHeader
{
    # old format == local(*to, $subject) 
    # @Rcpt is passed as "@to" even if @to has one addr;
    # WE SHOULD NOT TOUCH "$to" HERE;
    local(*to, *le, *rcpt) = @_;
    local($tmpto, %dup);

    # Resent (RFC822)
    @ResentHdrFieldsOrder = ("Resent-Reply-To", "Resent-From", "Resent-Sender",
			     "Resent-Date", 
			     "Resent-To", "Resent-Cc", "Resent-Bcc", 
			     "Resent-Message-Id");

    # @to is required; but we can make $from appropriatedly;
    @to || do { &Log("GenerateHeader:ERROR: NO \@to"); return;};

    # prepare: *rcpt for Smtp();
    for (@to) {
	# Address Representation Range Check
	&ValidAddrSpecP($_) || /^[^\@]+$/ || do {
	    &Log("GenerateHeaders: <$_> is invalid");
	    next;
	};

	push(@rcpt, $_); # &Smtp(*le, *rcpt);
	$tmpto .= $tmpto ? ", $_" : $_; # a, b, c format
    }

    $Rcsid  =~ s/\)\(/,/g;

    # fix *le(local) by *Envelope(global)
    $le{'macro:s'}    = $Envelope{'macro:s'};
    $le{'mci:mailer'} = $Envelope{'mci:mailer'};

    local($m);
    $m = $HAS_GETPWUID ? (getpwuid($<))[0] : 
	($ENV{'USER '}|| $ENV{'USERNAME'});

    $le{'GH:From:'}        = $MAINTAINER || "$m\@$DOMAINNAME";
    $le{'GH:To:'}          = $tmpto;
    $le{'GH:Date:'}        = $MailDate;
    $le{'GH:References:'}  = $Envelope{'h:message-id:'};
    $le{'GH:X-MLServer:'}  = $Rcsid;
    $le{'GH:X-MLServer:'} .= "\n\t($rcsid)" if $debug && $rcsid;
    $le{'GH:X-ML-Info:'}   = $URLComInfo if $URLComInfo;
    $le{'GH:From:'}       .= " ($MAINTAINER_SIGNATURE)"
	if $MAINTAINER_SIGNATURE;

    $le{'GH:Message-Id:'}  = &GenMessageId;

    # Run-Hooks. when you require to change header fields...
    if ($REPORT_HEADER_CONFIG_HOOK) {
	&eval($REPORT_HEADER_CONFIG_HOOK, 'REPORT_HEADER_CONFIG_HOOK');
    }

    # MEMO:
    # MIME (see RFC1521)
    # $_cf{'header', 'MIME'} => $Envelope{'GH:MIME:'}
    # 
    if (@ResentForwHdrFieldsOrder) { 
	for (@ResentForwHdrFieldsOrder, @ResentHdrFieldsOrder) {
	    &Debug("DUP FIELD\t$_") if $dup{$_} && $debug;
	    next if $dup{$_}; $dup{$_} = 1; # duplicate check;

	    if ($Envelope{"GH:$_:"} || $le{"GH:$_:"}) {
		$le{'Hdr'} .= "$_: ".($Envelope{"GH:$_:"}||$le{"GH:$_:"})."\n";
	    }
	}
    }
    else {
	for (@HdrFieldsOrder, @ResentHdrFieldsOrder) {
	    &Debug("DUP FIELD\t$_") if $dup{$_} && $debug;
	    next if $dup{$_}; $dup{$_} = 1; # duplicate check;

	    if ($Envelope{"GH:$_:"} || $le{"GH:$_:"}) {
		$le{'Hdr'} .= "$_: ".($Envelope{"GH:$_:"}||$le{"GH:$_:"})."\n";
	    }
	}
    }
}


1;
