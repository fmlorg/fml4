# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993 fukachan@phys.titech.ac.jp
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
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
    if (socket(S, &PF_INET, &SOCK_STREAM, 6)) { 
	print SMTPLOG  "socket ok\n";
    }else { return "Smtp:sockect:$!"; }
    if (connect(S, $target)) { 
	print SMTPLOG  "connect ok\n"; 
    } else { return "Smtp:connect:$!";}
    select(S); $| = 1; select(stdout); # need flush of sockect <S>;

    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>;} while(/^\d\d\d\-/o);
    while(@headers) {
	$_ = $headers[0], shift @headers;
	print SMTPLOG "$_<INPUT\n";
	print S "$_\n";
	do { print SMTPLOG $_ = <S>;} while(/^\d\d\d\-/o);
    }
    print SMTPLOG "-------------\n";
    if($SEND_FILE_TRICK) {
	chop $body; chop $body; chop $body; # trick
	print S $body;
	while(<file>) { print S $_; print SMTPLOG $_;};
	print S ".\n";
    }else {
	print SMTPLOG "$body-------------\n";
	print S $body;
    }
    do { print SMTPLOG $_ = <S>;} while(/^\d\d\d\-/o);
    print S "QUIT\n";
    do { print SMTPLOG $_ = <S>;} while(/^\d\d\d\-/o);
    close S, SMTPLOG;
    return 0;
}

# SendFile is just an interface of Sendmail to send a file.
# require $zcat = non-nil and ZCAT is set.
sub SendFile
{
    local($to, $subject, $file, $zcat) = @_;
    local($body);

    if(-T $file && open(file)) { 
    }elsif((1 == $zcat) && $ZCAT && -r $file && open(file, "$ZCAT $file|")) {
    }elsif((2 == $zcat) && $ZCAT && -r $file && open(file, "$UUENCODE $file spool.tar.gz|")) {
    }else { 
	&Logging("no $file in sub SendFile"); return;
    }

    # trick for using smaller memory!
    $SEND_FILE_TRICK = 1;
    &Sendmail($to, $subject, ""); 

    # while(<file>) { print S $_;}     -> in sub Smtp
    close(file);
}

# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local($to, $subject, $MailBody) = @_;
    local($body) = '';
    local($whom, @tmp) = split(/:/, getpwuid($<), 999);
    local($from) = $MAINTAINER ? $MAINTAINER: $whom;
    local($host) = $host ? $host : 'localhost';
    local($Status) = 0;

    if($debug) {
	print STDERR "from = ", $from, "\nto = ", $to, "\n";
	print STDERR "sendmail: missing address" if( !$from || !$to ); 
    }
    return if(!$from || !$to);

    @headers  = ("HELO", "MAIL FROM: $from", "RCPT TO: $to", "DATA");

    # the order below is recommended in RFC822 
    $body .= "Date: $MailDate\n" if $MailDate;
    $body .= "From: $from\n";
    $body .= "Subject: $subject\n";
    $body .= "Sender: $Sender\n" if $Sender; # Sender is additional.
    $body .= "To: $to\n";
    $body .= "Reply-to: $Reply_to\n" if $Reply_to;
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "\n";
    $body .= "$MailBody" unless($SEND_FILE_TRICK); # trick for SendFile
    $body .= "\n" if(! ($MailBody =~ /\n$/o));
    $Status = &Smtp($host, "$body.\n", @headers);
    &Logging("Sendmail:$Status") if $Status;
}

1;
