#-*- perl -*-
#
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libsmtputils.pl,v 2.15 2001/08/25 12:11:05 fukachan Exp $
#

use vars qw($debug);
use vars qw($Rcsid $URLComInfo);
use vars qw(%RelayRcpt);  # special recipient forwarded to specified relay
use vars qw($SUN_OS_413); # obsolete but defined for compatibility 
use vars qw($SENDFILE_NO_FILECHECK); # obsolete

# NEW VERSION FOR MULTIPLE @to and @files (required @files NOT $files) 
# return NONE
sub DoNeonSendFile
{
    local(*to, *subject, *files) = @_;
    local($le, %le, @rcpt, $f, @f, %f);
    my (@info) = caller;
    my ($n, $error);

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
		unless ($@) {
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
	    $error .= &Translate(*Envelope, 
				 "$f is not found.",
				 'not_found', $f);
	    $error .= "\n[ @info ]\n\n";
	    &Log("ERROR: NeonSendFile: $f is not found");
	    &Mesg(*Envelope, "$f is not found.", 'not_found', $f);
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
    my ($xto, $subject, $body, @xto) = @_;
    push(@to, @xto);
    push(@to, $xto); # extention for GenerateHeader

    # (before it, checks whether the return address is not ML nor ML-Ctl)
    if (! &CheckAddr2Reply(*Envelope, $xto, @to)) { return;}

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

    if (-f $distfile && open(DIST, $distfile)) {
	my (@a, $a);
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
    my ($tmpto, %dup);

    # Resent (RFC822)
    @ResentHdrFieldsOrder = ("Resent-Reply-To", "Resent-From", "Resent-Sender",
			     "Resent-Date", 
			     "Resent-To", "Resent-Cc", "Resent-Bcc", 
			     "Resent-Message-Id");

    # @to is required; but we can make $from appropriatedly;
    @to || do { &Log("GenerateHeader: ERROR: NO \@to"); return;};

    # prepare: *rcpt for Smtp();
    my ($lc_rcpt);
    for (@to) {
	# Address Representation Range Check
	&ValidAddrSpecP($_) || /^[^\@]+$/ || do {
	    &Log("GenerateHeaders: <$_> is invalid");
	    next;
	};

	push(@rcpt, $_); # &Smtp(*le, *rcpt);
	$tmpto .= $tmpto ? ", $_" : $_; # a, b, c format

	# always relay
	if ($DEFAULT_RELAY_SERVER) {
	    $lc_rcpt = $_;
	    $lc_rcpt =~ tr/A-Z/a-z/; # lower case;
	    $RelayRcpt{$lc_rcpt} = "\@${DEFAULT_RELAY_SERVER}:$_";
	}
    }

    $Rcsid  =~ s/\)\(/,/g;

    # fix *le(local) by *Envelope(global)
    $le{'macro:s'}    = $Envelope{'macro:s'};
    $le{'mci:mailer'} = $Envelope{'mci:mailer'};

    my $m = $HAS_GETPWUID ? (getpwuid($<))[0] : 
	($ENV{'USER '}|| $ENV{'USERNAME'});

    $le{'GH:From:'}        = $MAINTAINER || "$m\@$DOMAINNAME";
    $le{'GH:To:'}          = $tmpto;
    $le{'GH:Date:'}        = $MailDate;
    $le{'GH:References:'}  = $Envelope{'h:message-id:'};
    $le{'GH:References:'}  =~ s/^\s+//;
    $le{'GH:X-MLServer:'}  = $Rcsid;
    $le{'GH:X-ML-Info:'}   = $URLComInfo if $URLComInfo;
    $le{'GH:From:'}       .= " ($MAINTAINER_SIGNATURE)"
	if $MAINTAINER_SIGNATURE;

    $le{'GH:Message-Id:'}  = &GenMessageId;

    if ($LANGUAGE eq 'Japanese') {
	$le{'GH:Mime-Version:'} = '1.0';
	$le{'GH:Content-Type:'} = 'text/plain; charset=iso-2022-jp';
    }
	
    # Run-Hooks. when you require to change header fields...
    if ($REPORT_HEADER_CONFIG_HOOK) {
	&eval($REPORT_HEADER_CONFIG_HOOK, 'REPORT_HEADER_CONFIG_HOOK');
    }

    # MEMO:
    # MIME (see RFC1521)
    # $_PCB{'header', 'MIME'} => $Envelope{'GH:MIME:'}
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
