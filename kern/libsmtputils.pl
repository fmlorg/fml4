# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


sub DoSmtpFiles2Socket
{
    local(*f, *e) = @_;
    local($autoconv, $count, $boundary);

    $count = scalar(@f) > 1 ? 1 : 0;

    foreach $f (@f) {
	&Debug("SmtpFiles2Socket::($f)") if $debug;

	if ($f{$f, 'zcat'}) {
	    open(FILE,"-|") || exec($ZCAT, $f) || 
		(&Log("SmtpFiles2Socket: cannot zcat $f"), close(FILE), next);
	}
	elsif ($f{$f, 'uuencode'}) {
	    open(FILE,"-|") || exec($UUENCODE, $f, $f) || 
		(&Log("SmtpFiles2Socket: cannot uuencode $f"), close(FILE), next);
	}
	else {
	    open(FILE, $f) || (&Log("SmtpFiles2Socket: cannot open $f"), close(FILE), next);
	}

	$autoconv = $f{$f, 'autoconv'};

	if ($count) {		# if more than two files;
	    $boundary = ('-' x 20).$f.('-' x 20)."\n";
	    print S $boundary;
	    print SMTPLOG $boundary;
	}

	while (<FILE>) { 
	    s/^\./../; 
	    &jcode'convert(*_, 'jis') if $autoconv;#';

	    # guide, help, ...
	    if (/dev/ && $Envelope{'mode:doc:repl'}) {
		s/dev\.null\@domain.uja/$MAIL_LIST/g;
		s/dev\.null\-admin\@domain.uja/$MAINTAINER/g;
		s/dev\.null\-ctl\@domain.uja/$CONTROL_ADDRESS/g;
	    }

	    print S $_;
	    print SMTPLOG $_;
	    $LastSmtpIOString = $_;
	};

	close(FILE);
    }
}


# NEW VERSION FOR MULTIPLE @to and @files
# return NONE
sub NeonSendFile
{
    local(*to, *subject, *files) = @_;
    local(@info) = caller;
    local($le, %le, @rcpt, $error, $f, @f, %f);

    ### INFO
    &Debug("NeonSendFile[@info]:\n\nSUBJECT\t$subject\nFILES\t@files\n") if $debug;
	

    ### check again $file existence
    foreach $f (@files) {
	next if $f =~ /^\s*$/;

	if (-f $f) {		# O.K. anyway exists!
	    push(@f, $f);	# store it as a candidate;

	    # Anyway copy each entry of each subject(%files) to %f
	    $f{$f, 'subject'} = $files{$f, 'subject'} if $files{$f, 'subject'};

	    next if $SENDFILE_NO_FILECHECK; # Anytime O.K. if no checked;

	    # Check whether JIS or not
	    if (-B $f) {
		&Log("ERROR: NeonSendFile: $f != JIS ?");

		# AUTO CONVERSION 
		$ExistJcode = eval "require 'jcode.pl';", $@ eq "";

		if ($ExistJcode) {
		    &Log("NeonSendFile: $f != JIS ? Try Auto Code Conversion");
		    $f{$f, 'autoconv'} = 1;
		}
	    }

	    # misc checks
	    &Log("NeonSendFile: \$ZCAT not defined") unless $ZCAT;
	    &Log("NeonSendFile: cannot read $file")  unless -r $f;
	}
	### NOT EXISTS 
	else {
	    &Log("NeonSendFile: $f is not found.", "[ @info ]");
	    $f =~ s/$DIR/\$DIR/;
	    $error .=  "$f is not found.\n[ @info ]\n\n";
	    &Mesg(*Envelope, "Sorry.\nError NeonSendFile: $f is not found.\n");
	}

	$error && &Warn("ERROR NeonSendFile", $error);
	return $NULL if $error;	# END if only one error is found. Valid?
    }

    ### DEFAULT SUBJECT. ABOVE, each subject for each file
    $le{'GH:Subject:'} = $subject;
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

    push(@files, $file);
    (1 == $zcat) && ($files{$f, 'zcat'} = 1);
    (2 == $zcat) && ($files{$f, 'uuencode'} = 1);

    &NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
}


# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local(@to, %le, @rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeader

    $le{'GH:Subject:'} = $subject;
    &GenerateHeader(*to, *le, *rcpt);
    
    $le{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $le{'Body'}     .= $body;
    $le{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $le = &Smtp(*le, *rcpt);
    &Log("Sendmail:$le") if $le;
}


# Generating Headers, and SMTP array
sub GenerateMail    { &GenerateHeaders(@_);}
sub GenerateHeaders { &GenerateHeader(@_);}
sub GenerateHeader
{
    # old format == local(*to, $subject) 
    # @Rcpt is passed as "@to" even if @to has one addr;
    # WE SHOULD NOT TOUCH "$to" HERE;
    local(*to, *le, *rcpt) = @_;
    local($tmpto);

    # @to is required; but we can make $from appropriatedly;
    @to || do { &Log("GenerateHeader:ERROR: NO \@to"); return;};

    # prepare: *rcpt for Smtp();
    foreach (@to) {
	push(@rcpt, $_); # &Smtp(*le, *rcpt);
	$tmpto .= $tmpto ? ", $_" : $_; # a, b, c format
    }

    $Rcsid  =~ s/\)\(/,/g;

    # fix *le(local) by *Envelope(global)
    $le{'macro:s'}    = $Envelope{'macro:s'};
    $le{'mci:mailer'} = $Envelope{'mci:mailer'};

    $le{'GH:To:'}          = $tmpto;
    $le{'GH:From:'}        = $MAINTAINER ||((getpwuid($<))[0])."\@$DOMAINNAME";
    $le{'GH:Date:'}        = $MailDate;
    $le{'GH:X-MLServer:'}  =  $Rcsid;
    $le{'GH:X-MLServer:'} .= "\n\t($rcsid)" if $debug;
    $le{'GH:From:'}      .= " ($MAINTAINER_SIGNATURE)" if $MAINTAINER_SIGNATURE;

    # MEMO:
    # MIME (see RFC1521)
    # $_cf{'header', 'MIME'} => $Envelope{'GH:MIME:'}
    # 
    for (@HdrFieldsOrder) {
	if ($Envelope{"GH:$_:"} || $le{"GH:$_:"}) {
	    $le{'Hdr'} .= "$_: ".($Envelope{"GH:$_:"} || $le{"GH:$_:"})."\n";
	}
    }
}


1;
