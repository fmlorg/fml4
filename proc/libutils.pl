# Library of fml.pl 
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

sub GetFileWithUnixFrom
{
    local(@filelist) = @_;
    local(@tmp);
    local($linecounter);

    foreach $file (@filelist) {
	open(FILE, $file) || next;
	push(@tmp, "From $MAINTAINER\n");
	while(<FILE>) { push(@tmp, $_); $linecounter++;}
	close(FILE);
	push(@tmp, "\n");
    }

    return ($linecounter > 0) ? @tmp : ();
}

# Sending Given buffer cut by cut adjusting the location of UNIX FROM.
# so this routine is for plain text.
sub OrderedSendingOnMemory 
{
    local($to, $Subject, $MAIL_LENGTH_LIMIT, $SLEEP_TIME, @BUFFER) = @_;
    local($TOTAL) = int( scalar(@BUFFER) / $MAIL_LENGTH_LIMIT + 1);
    local($mails) = 1;
    local($ReturnBuffer, $mailbuffer);

    foreach (@BUFFER) {
	# UNIX FROM, when plain text
	if(/^From\s+/oi){ $ReturnBuffer .= $mailbuffer; $mailbuffer = "";}

	# add the current line to the buffer
	$mailbuffer .= $_; $totallines++;

	# send and sleep
	if($totallines > $MAIL_LENGTH_LIMIT) {
	    $totallines = 0; 
	    &Sendmail($to, "$Subject ($mails/$TOTAL) $ML_FN", $ReturnBuffer);
	    $ReturnBuffer = "";
	    $mails++;
	    sleep($SLEEP_TIME);
	}
    }# foreach;

    # final mail
    $ReturnBuffer .= $mailbuffer;
    &Logging("SendFile: Send a $_/$TOTAL to $to");
    &Sendmail($to, "$Subject ($mails/$TOTAL) $ML_FN", $ReturnBuffer);
}

sub Whois
{
    local($sharp, $_, @who) = @_;
    local($REQUEST);

    # Request
    if(! /whois/oi) { &Logging("$_ is not implemented"); return;} 

    while(@who, $_ = $who[0]) { 
	/^-h/oi && do { shift @who; $host = $who[0]; shift @who; next;}; 
	$REQUEST .= $_;
	shift @who;	
    }
    local($Subject) = "Whois $host $REQUEST $ML_FN";

    $host = $host ? $host : $DEFAULT_WHOIS_SERVER, $REQUEST;
    &Logging("whois -h $host: $REQUEST");

    require 'jcode.pl';
    &jcode'convert(*REQUEST, 'euc'); #'(trick) -> EUC

    $REQUEST = &talkWhois($host, $REQUEST); # connect whois server
    &jcode'convert(*REQUEST, 'jis'); #'(trick) -> JIS
    
    &Sendmail($to, $Subject, $REQUEST);
}

sub talkWhois # ($host, $headers, $body)
{
    local($host, $body) = @_;
    local($pat)  = 'S n a4 x8';
    local($ANSWER);

    # check variables
    $DIR  = $DIR ? $DIR : $ENV{'PWD'};
    $HOST = $host ? $host : 'localhost';

    # DNS. $HOST is global variable
    # it seems gethostbyname does not work if the parameter is dirty?
    local($name,$aliases,$addrtype,$length,$addrs) = 
	gethostbyname($HOST ? $HOST : $host);
    local($name,$aliases,$port,$proto) = getservbyname('whois', 'tcp');
    $port = 25 unless defined($port); # default port
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, 6) && connect(S, $target)) {
	select(S); $| = 1; select(stdout); # need flush of sockect <S>;
	print S $body,"#\n";
	while(<S>) { $ANSWER .= $_;}
	close S;
	return $ANSWER;
    } else { &Logging("Cannot connect $host");}
}

if($0 =~ __FILE__) {
    @test = ("./spool/1", "./spool/2");

    $MAINTAINER = "Elena@phys.titech.ac.jp";
    print  &GetFileWithUnixFrom(@test);
}

1;
