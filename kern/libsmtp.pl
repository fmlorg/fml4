# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$smtpid   = q$Id$;
($smtpid) = ($smtpid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid   .= "/$smtpid";

require 'sys/socket.ph';

# delete logging errlog file and return error strings.
sub Smtp # ($host, $headers, $body)
{
    local($host, $body, @headers) = @_;
    local($pat)  = 'S n a4 x8';

    # check variables
    $DIR  = $DIR ? $DIR : $ENV{'PWD'};
    $host = $host ? $host : 'localhost';

    # for logging of IPC
    local($SMTP_LOG) = "$DIR/_smtplog";
    $SMTP_LOG .= ".$Smtp_logging_hook" if($Smtp_logging_hook);
    open(SMTPLOG, "> $SMTP_LOG") || 
	(return "$MailDate: cannot open $SMTP_LOG");

    # DNS. $HOST is global variable
    # it seems gethostbyname does not work if the parameter is dirty?
    local($name,$aliases,$addrtype,$length,$addrs) = 
	gethostbyname($HOST ? $HOST : $host);
    local($name,$aliases,$port,$proto) = getservbyname('smtp', 'tcp');
    $port = 25 unless defined($port); # default port
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, $proto)) { 
	print SMTPLOG  "socket ok\n";
    } 
    else { 
	return "Smtp:sockect:$!";
    }

    if (connect(S, $target)) { 
	print SMTPLOG  "connect ok\n"; 
    } 
    else { 
	return "Smtp:connect:$!";
    }

    # need flush of sockect <S>;
    select(S);       $| = 1; select(stdout);
    select(SMTPLOG); $| = 1; select(stdout);

    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d\d\d\-/o);
    foreach $s (@headers) {
#.if	
	&GetTime, $prev = 60*$min + $sec;
#.endif	
	print SMTPLOG "$s<INPUT\n";
	print S "$s\n";
	do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
	while(/^\d\d\d\-/o);
#.if	
	&GetTime, $time = 60*$min + $sec;
	($time - $prev > 2) && &Log("SMTP:$s [".($time - $prev)." sec]");
	print STDERR "SMTP:$s [$time - $prev > 1]\n";
#.endif	
    }

    # rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
    $body =~ s/\n\./\n../g;	# enough for body ^. syntax
    $body =~ s/\.\.$/./g;	# trick the last "."

    # BODY INPUT
    print SMTPLOG "-------------\n";
    if ($_cf{'Smtp', 'readfile'}) { # For FILE INPUT
	print SMTPLOG $body;
	print S $body;
	while(<file>) { s/^\./../; print S $_; print SMTPLOG $_;};
	print SMTPLOG "-------------\n";
	print S ".\n";
    } 
    else {			# $body has both header and body.
	print SMTPLOG "$body-------------\n";
	print S $body;
    }

    $s = "BODY";		#CONVENIENCE: infomation for errlog
    do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} while(/^\d\d\d\-/o);
    $s = "QUIT";		#CONVENIENCE: infomation for errlog
    print S "QUIT\n";
    print SMTPLOG "$s<INPUT\n";
    do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} while(/^\d\d\d\-/o);

    close S; 
    close SMTPLOG;

    0;#return status
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub SendFile
{
    local($to, $subject, $file, $zcat, @to) = @_;
    local($body, $enc);

    # extention for GenerateHeaders
    @to || push(@to, $to);

    if ($_cf{'SendFile', 'Subject'}) {
	$enc = $_cf{'SendFile', 'Subject'};
    } 
    elsif($file =~ /tar\.gz$/||$file =~ /tar\.z$/||$file =~ /tar\.Z$/) {
	$enc = "spool.tar.gz";
    }
    elsif($file =~ /\.gz$/||$file =~ /\.z$/||$file =~ /\.Z$/) {
	$enc = "uja.gz";
    }

    if (open(file) && ($SENDFILE_NO_FILECHECK ? 1 : -T $file)) { 
    }
    elsif((1 == $zcat) && $ZCAT && -r $file && open(file, "$ZCAT $file|")) {
    }
    elsif((2 == $zcat) && $ZCAT && -r $file && open(file, "$UUENCODE $file $enc|")) {
    }
    else { 
	&Logging("sub SendFile: no $file") if !-f $file;
	&Logging("sub SendFile: binary?O.K.?: $file [zcat=$zcat]") if (!$zcat) && -B $file;
	&Logging("sub SendFile: \$ZCAT not defined") unless $ZCAT; 	
	&Logging("sub SendFile: cannot read $file")  unless -r $file;
	&Logging("sub SendFile: must be cannot open $file") unless open(file);
	return;
    }

    # trick for using smaller memory!
    $_cf{'Smtp', 'readfile'} = 1;
    ($host, $body, @headers) = &GenerateHeaders(*to, $subject);

    $Status = &Smtp($host, $body, @headers);
    &Logging("SendFile:$Status") if $Status;
    undef $_cf{'Smtp', 'readfile'};

    close(file);
}


# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local($to, $subject, $MailBody) = @_;
    push(@to, $to);		# extention for GenerateHeaders
    local($host, $body, @headers) = &GenerateHeaders(*to, $subject);

    $body .= $MailBody;
    $body .= "\n" if(! ($MailBody =~ /\n$/o));

    $Status = &Smtp($host, "$body.\n", @headers);
    &Logging("Sendmail:$Status") if $Status;
}


# Generating Headers, and SMTP array
sub GenerateMail { &GenerateHeaders(@_);}
sub GenerateHeaders
{
    local(*to, $subject) = @_;
    undef $to;
    local($body);
    local($from) = $MAINTAINER ? $MAINTAINER : (getpwuid($<))[0];
    local($host) = $host ? $host : 'localhost';

    if ($debug) {
	print STDERR "from = $from\nto   = ".join(" ",@to)."\n";
	print STDERR "GenerateHeaders: missing from||to\n" if(! ($from && @to));
    }
    return if(! ($from && @to));

    @headers  = ("HELO $_Ds", "MAIL FROM: $from");
    foreach (@to) {	
	push(@headers, "RCPT TO: $_"); 
	$to .= $to ? ", $_" : $_; # for header
    }
    push(@headers, "DATA");

    # for later use(calling once more)
    undef @to;

    # the order below is recommended in RFC822 
    $body .= "Date: $MailDate\n" if $MailDate;
    if ($MAINTAINER_SIGNATURE) {
	$body .= "From: $from ($MAINTAINER_SIGNATURE)\n";
    }
    else {
	$body .= "From: $from\n";
    }

    $body .= "Subject: $subject\n";
    $body .= "Sender: $Sender\n" if $Sender; # Sender is additional.
    $body .= "To: $to\n";
    $body .= "Reply-to: $Reply_to\n" if $Reply_to;
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "\n";

    print STDERR "GenerateHeaders:($host\n-\n$body\n-\n@headers);\n" if $debug;

    return ($host, $body, @headers);
}

1;
