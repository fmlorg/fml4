# Library of fml.pl 
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

sub AutoRegistP
{
    local($from) = @_;		
    local($SubjectM, $SubjectF, $CheckString);

    # mailbody is "subscribe"
    if($REQUIRE_SUBSCRIBE && 
       $REQUIRE_SUBSCRIBE_IN_BODY) {

	if(! ($MailBody =~ /^\s*$REQUIRE_SUBSCRIBE\s*/i)) {
	    $SubjectM = "Illegal Subject in auto-regist $ML_FN";
	    $SubjectF = 
		"Auto-Regist requires top of body is $REQUIRE_SUBSCRIBE";
	}

	$CheckString = $MailBody;

	# "Subject: subscribe"
    }elsif($REQUIRE_SUBSCRIBE) {
	if(! ($Subject =~ /^\s*$REQUIRE_SUBSCRIBE/i)) {
	    $SubjectM = "Illegal Subject in auto-regist $ML_FN";
	    $SubjectF = "Auto-Regist requires Subject:$REQUIRE_SUBSCRIBE";
	}

	$CheckString = $Subject;
    }	    

    if("" ne $SubjectM) {
	&Warning($from, $SubjectM, $SubjectF);
	return 0;
    }else {
	# O.K. Go! e.g. Subject: subscribe or subscribe E-mail-address
	if($CheckString =~ /^\s*$REQUIRE_SUBSCRIBE\s*(\S+)\s*/i){ $from = $1;}

	# LoopBack Check;
	if(($from =~ /$MAIL_LIST/io) || &AddressMatching($from, $MAIL_LIST)) {
	    return 0;
	}else {
	    return $from;
	}
    }
}

sub OpenStream_OUT
{
    local($WHERE, $PACK_P, $FILE, $TOTAL) = @_;

    if($PACK_P) {
	open(OUT, "|$COMPRESS|$UUENCODE $FILE > $WHERE.$TOTAL") || return 0;
    }else {
	open(OUT, "> $WHERE.$TOTAL") || return 0;
    }

    return 1;
}

sub CloseStream_OUT { close(OUT);}

# Word Count
sub WC
{
    local($lines) = 0;

    open(TMP, "< @_") || return 0;
    while(<TMP>) { last if(eof(TMP)); $lines++;}
    close(TMP);

    return $lines;
}

sub SplitFiles
{
    local($file, $totallines, $TOTAL) = @_;
    local($returnfile) = $file;
    local($lines) = 0;
    local($limit) = int($totallines/$TOTAL); # equal lines in each file
    local($i) = 1;

    open(BUFFER,"< $file") || do { &Logging("$!"); return 0;};
    open(OUT,   "> $file.$i") || do { &Logging("$!"); exit 1;};
    while(<BUFFER>) {
	print OUT $_; $lines++;
	
	if($lines > $limit) { # reset
	    $lines = 0; close OUT; $i++;
	    print STDERR "open(OUT, > $returnfile.$i)\n" if $debug;
	    open(OUT, "> $returnfile.$i") || 
		do { &Logging("$!"); return 0;};
	}
    }# WHILE;

    unlink $file unless $SplitFiles_NOT_DELETE_ORIGINAL;
    return 1;
}

sub MakeFilesWithUnixFrom { &MakeFileWithUnixFrom(@_);}
sub MakeFileWithUnixFrom
{
    local($WHERE, $PACK_P, $FILE, @filelist) = @_;
    local($linecounter);
    local($TOTAL)      = $PACK_P ? 0: 1;
    
    print STDERR "MakeFileWithUnixFrom:($WHERE, $PACK_P, @filelist)\n"
	if $debug;

    # Open Stream
    if(0 == &OpenStream_OUT($WHERE, 0, $FILE, $TOTAL)) { return 0;}

    # Get files
    foreach $file (@filelist) {
	local($lines) = &WC($file);

	# reset
	if((0 == $PACK_P) && ($linecounter + $lines) > $MAIL_LENGTH_LIMIT) {
	    close(OUT);
	    $TOTAL++;
	    if(0 == &OpenStream_OUT($WHERE, 0, $FILE, $TOTAL)) { return 0;}
	}

	# Get
	open(FILE, $file) || next;
	print OUT $USE_RFC934 ? 
	    "\n------- Forwarded Message\n\n" : "From $MAINTAINER\n";
	$linecounter++;
	while(<FILE>) { print OUT $_; $linecounter++;}
	close(FILE);
	print OUT "\n"; $linecounter++;
    }
    close(OUT);

    # Exceptional action for gzip
    if($PACK_P) {
	$TOTAL = int($linecounter/$MAIL_LENGTH_LIMIT + 1);

	system "$COMPRESS $WHERE.0|$UUENCODE $FILE > $WHERE";
	$totallines = &WC($WHERE);
	$TOTAL = int($totallines/$MAIL_LENGTH_LIMIT + 1);

	if(($TOTAL > 1) && 0 == &SplitFiles($WHERE, $totallines, $TOTAL)) {
	    &Logging("SendFile: Cannot split $WHERE");
	    return 0;
	}elsif(1 == $TOTAL) {	# tricky
	    rename($WHERE, "$WHERE.1"); 
	}
    }

    return $TOTAL;
}

# Sending files back 
sub SendingBackOrderly
{
    local($returnfile, $TOTAL, $SUBJECT, $SLEEPTIME, @to) = @_;

    foreach $now (1..$TOTAL) {
	local($file) = "$DIR/$returnfile.$now";
	
	&Logging("SendFile: Send a $now/$TOTAL to $to");
	&SendFileMajority("$SUBJECT ($now/$TOTAL) $ML_FN", $file, 0, @to);

	unlink $file unless $debug;
	sleep($SLEEPTIME ? $SLEEPTIME : 3);
    }

    unlink $returnfile unless $debug;
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

sub SendFileMajority
{
    local($subject, $file, $zcat, @to) = @_;
    local($body);

    if(-T $file && open(file)) { 
    }elsif((1 == $zcat) && $ZCAT && -r $file && open(file, "$ZCAT $file|")) {
    }elsif((2 == $zcat) && $ZCAT && -r $file && open(file, "$UUENCODE $file spool.tar.gz|")) {
    }else { 
	&Logging("no $file in sub SendFile"); return;
    }

    # trick for using smaller memory!
    $SEND_FILE_TRICK = 1;
    ($host, $body, @headers) = &GenerateMailMajority($subject, @to);

    $Status = &Smtp($host, $body, @headers);
    &Logging("SendFile:$Status") if $Status;

    close(file);
}

sub GenerateMailMajority
{
    local($subject, @to) = @_;
    local($body) = '';
    local($whom, @tmp) = split(/:/, getpwuid($<), 999);
    local($from) = $MAINTAINER ? $MAINTAINER: $whom;
    local($host) = $host ? $host : 'localhost';
    local($Status) = 0;

    @headers  = ("HELO", "MAIL FROM: $from");
    foreach $to (@to) {
	push(@headers, "RCPT TO: $to");
    }
    push(@headers, "DATA");

    # the order below is recommended in RFC822 
    $body .= "Date: $MailDate\n" if $MailDate;
    $body .= "From: $from\n";
    $body .= "Subject: $subject\n";
    $body .= "Sender: $Sender\n" if $Sender; # Sender is additional.
    $body .= "To: $to\n";
    $body .= "Reply-to: $Reply_to\n" if $Reply_to;
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "\n";

    return ($host, $body, @headers);
}

# FOR DEBUG
if($0 =~ __FILE__) {
    @test = ("./spool/1", "./spool/2");
    $MAINTAINER = "Elena@phys.titech.ac.jp";
}

1;
