# Library of fml.pl
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libuid   = q$Id$;
($libuid) = ($libuid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libuid";

sub AutoRegist
{
    local($from, $s, $b);

    if($REQUIRE_SUBSCRIBE && (! $REQUIRE_SUBSCRIBE_IN_BODY)) {
	# Syntax e.g. "Subject: subscribe"...

	if($Subject =~ /^\s*$REQUIRE_SUBSCRIBE\s+(.*)\s*$/i ||
	   $Subject =~ /^\s*$REQUIRE_SUBSCRIBE\s*$/i ) {
	    $from = $1;
	}else {
	    $s = "Bad Syntax on subject in autoregistration";
	    &Log($s);
	    &Warn("$s $ML_FN", &ReCreateWholeMail);
	    $b  = "Subject: $REQUIRE_SUBSCRIBE [your-email-address]\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";
	    &Sendmail($From_address, "$s $ML_FN", $b); return 0;
	}

    }elsif($REQUIRE_SUBSCRIBE && $REQUIRE_SUBSCRIBE_IN_BODY) {
	# Syntax e.g. "subscribe" in body

	if($MailBody =~ /^\s*$REQUIRE_SUBSCRIBE\s+(.*)\s*$/i ||
	   $MailBody =~ /^\s*$REQUIRE_SUBSCRIBE\s*$/i) {
	    $from = $1;
	}else {
	    $s = "Bad Syntax in mailbody in autoregistration";
	    &Log($s);
	    &Warn("$s $ML_FN", &ReCreateWholeMail);
	    $b  = "In the first line of your mail body\n\n";
	    $b .= "$REQUIRE_SUBSCRIBE [your-email-address]\n\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";
	    &Sendmail($From_address, "$s $ML_FN", $b); return 0;
	}
    }else {
	# DEFAULT
	# Determine the address to check
	# In default, when changing your registerd address
	# use "subscribe your-address" in body.

	$DEFAULT_SUBSCRIBE || ($DEFAULT_SUBSCRIBE = "subscribe");
	($MailBody =~ /^\s*$DEFAULT_SUBSCRIBE\s*(\S+)/i) && ($from = $1);
    }# end of REQUIRE_SUBSCRIBE;
	
    print STDERR "AUTO REGIST CANDIDATE>$from<\n" if $debug;
    $from = ($from || $From_address);
    print STDERR "AUTO REGIST FROM     >$from<\n" if $debug;
    return 0 if(1 == &LoopBackWarning2($from)); # loop back check

    # ADD the unknown to the member list
    open(TMP, ">> $MEMBER_LIST") || do {
	select(TMP); $| = 1; select(stdout);
	&Logging($!);
	&Warn("Auto-Regist: cannot open member file", &ReCreateWholeMail);
	return 0;
    };
    print TMP $from, "\n";
    close(TMP);

    # Log and Notify 
    &Logging("Added: $from");
    &Warn("New added member: $from $ML_FN", &ReCreateWholeMail);
    &SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);
    
    # WHETHER DELIVER OR NOT?
    # 7 is body 3 lines and signature 4 lines, appropriate?
    $AUTO_REGISTRATION_LINES_LIMIT||($AUTO_REGISTRATION_LINES_LIMIT=8);
    if($BodyLines < $AUTO_REGISTRATION_LINES_LIMIT) { 
	$AUTO_REGISTERD_UNDELIVER_P = 1;
    }

    return ($AUTO_REGISTERD_UNDELIVER_P ? 0 : 1);
}


sub MemberStatus
{
    local($who) = @_;
    local($s);

    open(ACTIVE_LIST) || 
	(&Log("cannot open $ACTIVE_LIST when $ID:$!"), return "No Match");

    in: while (<ACTIVE_LIST>) {
	chop;

	$sharp = 0;
	/^\#\s*(.*)/ && do { $_ = $1; $sharp = 1;};

	# Backward Compatibility.	
	s/\smatome\s+(\S+)/ m=$1 /i;
	s/\sskip\s*/ s=skip /i;
	local($rcpt, $opt) = split(/\s+/, $_, 2);
	$opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

	if($rcpt =~ /$who/) {
	    $s .= "$rcpt:\n";
	    $s .= "\tpresent not participate in. (OFF)\n" if $sharp;

	    $_ = $opt;
	    /\sr=(\S+)/     && ($s .= "\tRelay server is $1\n"); 
	    /\ss=/          && ($s .= 
				"\tNOT delivered here, but can post to $ML_FN\n");
	    /\sm=/          && ($s .= "\tMatome Okuri, every other ");
	    /\sm=(\d+)\s/o  && ($s .= "$1 hour as GZIPed\n");
	    /\sm=(\d+)i\s/o && ($s .= "$1 hour as LHA+ISH\n");
	    /\sm=(\d+)u\s/o && ($s .= "$1 hour as PLAIN TEXT\n");
	    /\s*/           && ($s .= "\tdeliverd immediately\n");

	    $s .= "\n\n";
	}
    }

    close(ACTIVE_LIST);

    return $s ? $s : "$who is NOT matched\n";
}

sub OpenStream_OUT
{
    local($WHERE, $PACK_P, $FILE, $TOTAL) = @_;

    print STDERR "OpenStream_OUT($WHERE, 0, $FILE, $TOTAL)\n" if $debug;

    if($PACK_P) {
	open(OUT, "|$COMPRESS|$UUENCODE $FILE > $WHERE.$TOTAL") || return 0;
    }else {
	open(OUT, "> $WHERE.$TOTAL") || return 0;
    }

    select(OUT); $| = 1; select(stdout);
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
    select(OUT); $| = 1; select(stdout);
    while(<BUFFER>) {
	print OUT $_; $lines++;
	
	if($lines > $limit) { # reset
	    $lines = 0; close OUT; $i++;
	    print STDERR "open(OUT, > $returnfile.$i)\n" if $debug;
	    open(OUT, "> $returnfile.$i") || 
		do { &Logging("$!"); return 0;};
	    select(OUT); $| = 1; select(stdout);
	}
    }# WHILE;
    close(OUT);

    unlink $file unless $SplitFiles_NOT_DELETE_ORIGINAL;
    return 1;
}

# if PACK_P >0(PACKING),
# packed one is > "$WHERE.0"
# if plain,
# $WHERE.1 -> $WHERE.$TOTAL(>=1) that is .1, .2, .3...
sub MakeFilesWithUnixFrom { &MakeFileWithUnixFrom(@_);}
sub MakeFileWithUnixFrom
{
    local($WHERE, $PACK_P, $FILE, @filelist) = @_;
    local($linecounter, $NEW, $PUNC);
    local($TOTAL)      = $PACK_P ? 0: 1;
    local($PUNC_FLAG)  = 1;	# trick flag
    local($s);

    if($USE_RFC934) {
	$PUNC = "\n------- Forwarded Message\n\n";
    }elsif($USE_RFC1153) {	# 30 lines followed by blank lines
	if(! $_cf{'rfc1153', 'in'}) {
	    require 'rfc1153.ph';
	    ($PREAMBLE, $TRAILER) =	&CustomRFC1153(@filelist);
	}
	$PUNC = "\n\n------------------------------\n\n";
	$PUNC_FLAG = 0;
    }else {
	$PUNC = "From $MAINTAINER\n";
    }

    # Open Stream
    if(0 == &OpenStream_OUT($WHERE, 0, 0, $TOTAL)) { return 0;}

    $USE_RFC1153 && (print OUT $PREAMBLE);

    # Get files
    foreach $file (@filelist) {
	local($lines) = &WC($file);

	# Get
	open(FILE, $file) || next;
	print OUT $PUNC if $PUNC_FLAG;
	$PUNC_FLAG++;
	$linecounter++;
	if($_cf{'readfile', 'hook'}) {
	    $s = "while(<FILE>) { $_cf{'readfile', 'hook'}; print OUT \$_; \$linecounter++;}";
	    print STDERR ">>$s<<\n";
	    &eval($s, 'Readfile hook');
	}else {
	    while(<FILE>) { print OUT $_; $linecounter++;}
	}
	close(FILE);
	print OUT "\n"; $linecounter++;
	$NEW++;

	# reset
	if((0 == $PACK_P) && ($linecounter + $lines) > $MAIL_LENGTH_LIMIT) {
	    close(OUT);
	    $TOTAL++;
	    $linecounter = 0;
	    if(0 == &OpenStream_OUT($WHERE, 0, 0, $TOTAL)) { return 0;}
	    $NEW = 0;
	}
    }

    $USE_RFC1153 && (print OUT $TRAILER);
    close(OUT);
    $TOTAL-- unless $NEW;

    # Exceptional action for e.g. gzip
    if($PACK_P) {
	$TOTAL = int($linecounter/$MAIL_LENGTH_LIMIT + 1);

	if($_cf{'ish'}) {
	    $FILE =~ s/\.gz$/.lzh/;
	    $LHA = $LHA ? $LHA : "$LIBDIR/bin/lha";
	    $ISH = $ISH ? $ISH : "$LIBDIR/bin/aish";
	    $COMPRESS = "$LHA a $TMP_DIR/$FILE ". join(" ", @filelist);
	    $UUENCODE = "$ISH -s7 -o $WHERE $TMP_DIR/$FILE";
	    system "$COMPRESS; $UUENCODE";
	    unlink "$TMP_DIR/$FILE";
	}else {
	    system "$COMPRESS $WHERE.0|$UUENCODE $FILE > $WHERE";
	}
	$totallines = &WC($WHERE);
	$TOTAL = int($totallines/$MAIL_LENGTH_LIMIT + 1);

	if(($TOTAL > 1) && 0 == &SplitFiles($WHERE, $totallines, $TOTAL)) {
	    &Logging("MakeFileWithUnixFrom: Cannot split $WHERE");
	    return 0;
	}elsif(1 == $TOTAL) {	# trick for &SendingBackOrderly 
	    rename($WHERE, "$WHERE.1"); 
	}
    }

    return $TOTAL;
}

# Sending files back, Orderly is [a], not [ad] _o_
sub SendingBackOrderly { &SendingBackInOrder(@_);}
sub SendingBackInOrder
{
    local($returnfile, $TOTAL, $SUBJECT, $SLEEPTIME, @to) = @_;

    foreach $now (1..$TOTAL) {
	local($file) = "$DIR/$returnfile.$now";
	$0 = ($PS_TABLE ? $PS_TABLE : "SendingBackOrderly"). " Sending Back $now/$TOTAL";
	&Logging("SBO:[$$] Send $now/$TOTAL ($to)", 1);
	&SendFileMajority("$SUBJECT ($now/$TOTAL) $ML_FN", $file, 0, @to);

	unlink $file unless $debug;
	sleep($SLEEPTIME ? $SLEEPTIME : 3);
    }
    
    unlink $returnfile if((!$SplitFiles_NOT_DELETE_ORIGINAL) && (! $debug));
    unlink "$returnfile.0" unless $debug; # a trick for MakeFileWithUnixFrom
}

sub Whois
{
    local($sharp, $_, @who) = @_;
    local($REQUEST);

    # Request
    if(! /whois/oi) { &Logging($_." is not implemented"); return;} 

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

    # &Sendmail($to, $Subject, $REQUEST);
    return "$Subject\n$REQUEST\n";
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
    } else { &Logging("whois:Cannot connect $host");}
}

# Trick
sub SendFileMajority { &SendFile('#dummy', @_);}

# I learn "how to extract from a tar file " from taro-1.3 by
# utashiro@sra.co.jp.
# So several codes are stolen from taro-1.3.
sub TarZXF
{
    local($tarfile, $total, *cat, $outfile) = @_;
    local($header_size)   = 512;
    local($header_format) = "a100 a8 a8 a8 a12 a12 a8 a a100 a*";
    local($nullblock)     = "\0" x $header_size;
    local($BUF, $SIZE);
    local($TOTAL) = 1;
    
    print STDERR "TarZXF local($tarfile, $total, ". 
	join(" ", keys %cat) .", $outfile)\n\n" if $debug;
    
    # check the setting on ZCAT
    if(! defined($ZCAT)) { return "ERROR of ZCAT";}
    
    open(TAR, $tarfile) || &Log("TarZXF: Cannot open $tarfile: $!");
    open(TAR, '-|') || exec($ZCAT, $tarfile) || die("zcat: $!\n")
	if ($tarfile =~ /\.gz$/);
    select(TAR); $| = 1; select(stdout);

    if($outfile) {
	&OpenStream_OUT($outfile, 0, 0, $TOTAL) 
	    || do { &Log("TarZXF: Cannot Open $outfile"); return "";};
    };
    
    while (($s = read(TAR, $header, $header_size)) == $header_size) {
	if ($header eq $nullblock) {
	    last if (++$null_count == 2);
	    next;
	}
	$null_count = 0;
	
	@header = unpack($header_format, $header);
	
	($name = $header[0]) =~ s/\0*$//;
	local($catit) = $cat{$name};

	local($bufsize) = 8192;
	local($size)    = oct($header[4]);
	$SIZE          += $size; # total size?
	$size = 0 if ($header[7] =~ /1/);

	# suppose 80 char/line
	if($outfile && $catit && $SIZE > 80 * $MAIL_LENGTH_LIMIT) { 
	    close(OUT);
	    $TOTAL++; 
	    $outfile && &OpenStream_OUT($outfile, 0, 0, $TOTAL) 
		|| do { &Log("TarZXF: Cannot Open $outfile"); return "";};    
	    $SIZE = 0;
	}
	
	while ($size > 0) {
	    $bufsize = 512 if ($size < $bufsize);
	    if (($s = read(TAR, $buf, $bufsize)) != $bufsize) {
		&Log("TarZXF: Illegal EOF: bufsize:$bufsize, size:$size");
	    }

	    if($catit) {	    
		if($outfile) {
		    $B = substr($buf, 0, $size);
		    $B =~ s/Return\-Path:.*\n/From $MAINTAINER\n/;
		    print OUT $B;
		}else {
		    $BUF .= substr($buf, 0, $size);
		}
	    }

	    $size -= $bufsize;
	}
	
	print OUT "\n" if $catit;# \nFrom UNIX-FROM;

	if($catit && ! --$total) {
	    close TAR, OUT;
	    return $outfile ? $TOTAL: $BUF;
	}
    }# end of Tar extract
    
    close TAR, OUT;
    return $outfile ? $TOTAL: $BUF;
}


# Return 1 if Loopback
sub LoopBackWarning2
{
    local($to) = @_;

    foreach($MAIL_LIST, $CONTROL_ADDRESS, @Playing_to) {
	next if /^$/oi;		# for null control addresses
	if(&AddressMatching($to, $_)) {
	    &Log("LoopBack Warning: ", "[$From_address] or [$to]");
	    &Warn("Warning: $ML_FN", &ReCreateWholeMail);
	    return 1;
	}
    }

    return 0;
}

1;
