# $Author$
# $State$
# $rcsid = "$Id$";
$smtpid = q$Id$;
($smtpid) = ($smtpid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$smtpid";
# smtp library functions, 
# smtp does just connect and put characters to the sockect.

require 'sys/socket.ph';

sub Smtp # ($host, $headers, $body)
{
    local($host, $body, @headers) = @_;
    local($pat)  = 'S n a4 x8';
    local($smtp) = 25;

    $DIR = $DIR ? $DIR : $ENV{'PWD'};
    $host = $host ? $host : 'localhost';

    local($SMTP_LOG) = "$DIR/_smtplog";
    local($SMTP_ERRLOG) = "$DIR/__smtp_errlog";
    if($Smtp_logging_hook) { 
	$SMTP_LOG    .= ".".$Smtp_logging_hook; 
	$SMTP_ERRLOG .= ".".$Smtp_logging_hook;
    }

    # for logging of IPC
    open(SMTPLOG, "> $SMTP_LOG") || 
	(print STDERR "$MailDate: cannot open $SMTP_LOG", return);

    open(SMTPERRLOG, ">> $SMTP_ERRLOG") ||
	(print STDERR "$MailDate: cannot open $SMTP_ERRLOG", return);

    ($name,$aliases,$addrtype,$length,$addrs) = gethostbyname("localhost");
    $this = pack($pat, &AF_INET, 0, $addrs);
    ($name,$aliases,$addrtype,$length,$addrs) = gethostbyname("$host");
    $that = pack($pat, &AF_INET, $smtp, $addrs);

    # IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, 6)) { 
	print SMTPLOG  "socket ok\n"; 
    }else {print SMTPERRLOG "sockect:$!"; return;}
    if (connect(S, $that)) { print SMTPLOG  "connect ok\n"; } 
    else {print SMTPERRLOG "connect:$!"; return;}
    
    select(S); $| = 1; select(stdout); # need flush of sockect <S>;

    print SMTPLOG "-----------------------\n";
    while($_ = $headers[0], shift @headers) {
	print SMTPLOG "$_<INPUT\n";
	print S "$_\n";
	do { 
	    print SMTPLOG $_ = <S>;
	} while(/^\d\d\d\-/o);
    }
    print SMTPLOG "-----------------------\n$body-----------------------\n";
    print S $body;
    do { 
	print SMTPLOG $_ = <S>;
    } while(/^\d\d\d\-/o);

    print S "QUIT\n";
    do { 
	print SMTPLOG $_ = <S>;
    } while(/^\d\d\d\-/o);

    close S,SMTPLOG, SMTPERRLOG;
}

# SendFile is just a pre part of Sendmail to send a file.
sub SendFile
{
    local($to, $subject, $file) = @_;
    local($body);
    open(file) || return;
    while(<file>) { $body .= $_;}    
    &Sendmail($to, $subject, $body);
}

# sendmail($to, $subject, $MailBody) paramters are only three.
# Sendmail is a preprocess of Smtp, and accept strings as a mailbody.
sub Sendmail
{
    local($to, $subject, $MailBody) = @_;
    local($body) = '';
    local($whom, @tmp) = split(':', getpwuid($<), 999);
    local($from) = $MAINTAINER ? 
	$MAINTAINER: $whom . $domain;
    local($host) = $host ? $host : 'localhost';

    if($debug) {
	print STDERR "from = ", $from, "\nto = ", $to, "\n";
	print STDERR "sendmail: missing address" if( !$from || !$to ); 
    }
    return if(!$from || !$to);

    @headers  = ("HELO", "MAIL FROM: $from", "RCPT TO: $to", "DATA");

    # the order recommended in RFC822 
    $body .= "Date: $MailDate\n" if $MailDate;
    $body .= "From: $from\n";
    $body .= "Subject: $subject\n";
    $body .= "Sender: $Sender\n" if $Sender; # Sender is just additional. 
    $body .= "To: $to\n";
    $body .= "Reply-to: $Reply_to\n" if $Reply_to;
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "\n";
    $body .= "$MailBody";
    &Smtp($host, "$body.\n", @headers);
    return;
}

1;
