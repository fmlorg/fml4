# Library of fml.pl
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libuid   = q$Id$;
($libuid) = ($libuid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libuid";

# Aliases
sub SendFileMajority  { &SendFile('#dummy', @_);}
sub SendFile2Majority { &SendFile('#dummy', @_);}

# Auto registraion procedure
# Subject: subscribe
#        or 
# subscribe ... in Body.
# return 0 or 1 to use the return of &MLMemberCheck
sub AutoRegist
{
    local($from, $s, $b);

    if ($REQUIRE_SUBSCRIBE && (! $REQUIRE_SUBSCRIBE_IN_BODY)) {
	# Syntax e.g. "Subject: subscribe"...
	# 
	# [\033\050\112] is against a bug in cc:Mail
	# patch by yasushi@pier.fuji-ric.co.jp
	$s = $Subject;
	$s =~ s/^\#\s*//;
	$s =~ s/^\033\050\112\s*($REQUIRE_SUBSCRIBE.*)/$1/;

	if ($s =~ /^\s*$REQUIRE_SUBSCRIBE\s+(\S+)\s*$/i ||
	   $s =~ /^\s*$REQUIRE_SUBSCRIBE\s*$/i) {
	    $from = $1;
	}
	else {
	    $s = "Bad Syntax on subject in autoregistration";
	    &Log($s);
	    &Warn("$s $ML_FN", &WholeMail);
	    $b  = "Subject: $REQUIRE_SUBSCRIBE [your-email-address]\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";
	    &Sendmail($From_address, "$s $ML_FN", $b); return 0;
	}

    }
    elsif ($REQUIRE_SUBSCRIBE && $REQUIRE_SUBSCRIBE_IN_BODY) {
	# Syntax e.g. "subscribe" in body
	$s = $MailBody;
	$s =~ s/^\#\s*//;

	if ($s =~ /^\s*$REQUIRE_SUBSCRIBE\s+(\S+)\s*\n/i ||
	    $s =~ /^\s*$REQUIRE_SUBSCRIBE\s*\n/i) {
	    $from = $1;
	}
	else {
	    $s = "Bad Syntax in mailbody in autoregistration";
	    &Log($s);
	    &Warn("$s $ML_FN", &WholeMail);
	    $b  = "In the first line of your mail body\n\n";
	    $b .= "$REQUIRE_SUBSCRIBE [your-email-address]\n\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";
	    &Sendmail($From_address, "$s $ML_FN", $b); return 0;
	}
    }
    else {
	# DEFAULT
	# Determine the address to check
	# In default, when changing your registerd address
	# use "subscribe your-address" in body.

	$DEFAULT_SUBSCRIBE || ($DEFAULT_SUBSCRIBE = "subscribe");
	($MailBody =~ /^\s*$DEFAULT_SUBSCRIBE\s*(\S+)/i) && ($from = $1);
    }# end of REQUIRE_SUBSCRIBE;
	
    &Debug("AUTO REGIST CANDIDATE>$from<") if $debug;
    $from = ($from || $From_address);
    &Debug("AUTO REGIST FROM     >$from<") if $debug;
    return 0 if 1 == &LoopBackWarn($from); # loop back check

    # ADD the newcomer to the member list
    open(TMP, ">> $MEMBER_LIST") || do {
	select(TMP); $| = 1; select(stdout);
	&Logging($!);
	&Warn("Auto-Regist: cannot open member file", &WholeMail);
	return 0;
    };
    print TMP $from, "\n";
    close(TMP);

    # Log and Notify 
    &Logging("Added: $from");
    &Warn("New added member: $from $ML_FN", &WholeMail);
    &SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);
    
    # WHETHER DELIVER OR NOT?
    # 7 is body 3 lines and signature 4 lines, appropriate?
    $AUTO_REGISTRATION_LINES_LIMIT||($AUTO_REGISTRATION_LINES_LIMIT=8);
    if ($BodyLines < $AUTO_REGISTRATION_LINES_LIMIT) { 
	$AUTO_REGISTERD_UNDELIVER_P = 1;
    }

    return ($AUTO_REGISTERD_UNDELIVER_P ? 0 : 1);
}


# Open FILEHANDLE 'OUT'.
# PACK_P is backward compatibility since 
# PACK_P is always 0!
# return 1 if succeed;
sub OpenStream_OUT { &OpenStream(@_);}
sub OpenStream
{
    local($WHERE, $PACK_P, $FILE, $TOTAL) = @_;

    &Debug("&OpenStream($WHERE, $PACK_P, $FILE, $TOTAL)") if $debug;

    if ($PACK_P) {
	# MEANINGLESS since always called as 0 .

	### Here NOT CALLED !(Must be)###
	open(OUT, "|$COMPRESS|$UUENCODE $FILE > $WHERE.$TOTAL") || return 0;
    }
    else {
	open(OUT, "> $WHERE.$TOTAL") || return 0;
    }

    select(OUT); $| = 1; select(stdout);

    1;
}


# Aliases for symmetry. close FILEHANDLE 'OUT'
sub CloseStream     { close(OUT);}
sub CloseStream_OUT { close(OUT);}


# Word Counting of the gigen file
# return lines
sub WC
{
    local($lines) = 0;

    open(TMP, "< @_") || return 0;
    while (<TMP>) { 
	$lines++;
    }
    close(TMP);

    $lines;
}


# Split files and unlink the original
# $file - split -> $file.1 .. $file.$TOTAL files 
# return the number of splitted files
sub SplitFiles
{
    local($file, $totallines, $TOTAL) = @_;
    local($unit)  = int($totallines/$TOTAL); # equal lines in each file
    local($lines) = 0;
    local($i)     = 1;		# split to (1 .. $TOTAL)

    open(BUFFER,"< $file") || do { &Logging("$!"); return 0;};
    open(OUT,   "> $file.$i") || do { &Logging("$!"); exit 1;};
    select(OUT); $| = 1; select(stdout);

    while (<BUFFER>) {
	print OUT $_; $lines++;

	# Reset
	if ($lines > $unit) { 
	    $lines = 0; 
	    close OUT; 
	    $i++;

	    &Debug("open(OUT, > $file.$i)") if $debug;

	    # Next file
	    open(OUT, "> $file.$i") || do { &Log($!); return 0;};
	    select(OUT); $| = 1; select(stdout);
	}
    }# WHILE;

    close(OUT);

    # delete original source
    unlink $file unless $_cf{'splitfile', 'NOT unlink'}; 

    $i;
}


# Making files encoded and compressed for the given @filelist
# if PACK_P >0(PACKING),
# packed one is > "$WHERE.0"
# $FILE is an finally encoded name 
# if plain,
# $WHERE.1 -> $WHERE.$TOTAL(>=1) that is .1, .2, .3...
# return $TOTAL
sub MakeFilesWithUnixFrom { &MakeFileWithUnixFrom(@_);}
sub MakeFileWithUnixFrom
{
    local($TMPF, $PACK_P, $FILE, @filelist) = @_;
    local($linecounter, $NEW, $PUNC, $s);
    local($PLAINTEXT)  = local($TOTAL) = $PACK_P ? 0: 1;
    local($PUNC_FLAG)  = 1;	# trick flag

    &Debug("local($TMPF, $PACK_P, $FILE, @filelist)") if $debug;

    if ($USE_RFC934) {
	$PUNC = "\n------- Forwarded Message\n\n";
    }
    elsif ($USE_RFC1153) {	# 30 lines followed by blank lines
	if (! $_cf{'rfc1153', 'in'}) {
	    require 'rfc1153.ph';
	    ($PREAMBLE, $TRAILER) =	&CustomRFC1153(@filelist);
	}
	$PUNC = "\n\n------------------------------\n\n";
	$PUNC_FLAG = 0;
    }
    else {
	$PUNC = "From $MAINTAINER\n";
    }

    # If PLAINTEXT, split files
    # Open $TMPF.(0 or 1(plain text)), return if fails;
    if (0 == &OpenStream($TMPF, 0, 0, $TOTAL)) { return 0;}
    
    # 1153 preamble
    if ($USE_RFC1153) { print OUT $PREAMBLE;}
    
    foreach $file (@filelist) {
	local($lines) = &WC($file);
	
	# open the next file
	open(FILE, $file) || next;
	print OUT $PUNC if $PUNC_FLAG;
	$PUNC_FLAG++;	$linecounter++;
	
	if ($_cf{'readfile', 'hook'}) {
	    $s = qq#
		while (<FILE>) { 
		    $_cf{'readfile', 'hook'}; 
		    print OUT \$_; \$linecounter++;
		}
	    #;
	    &Debug(">>$s<<") if $debug;
	    &eval($s, 'Readfile hook');
	}
	else {
	    while (<FILE>) { 
		print OUT $_; 
		$linecounter++;
	    }
	}
	close(FILE);
	
	print OUT "\n"; $linecounter++;
	$NEW++;		# the number of files
	
	# If PLAIN TEXT, reset!
	if ($PLAINTEXT && ($linecounter + $lines) > $MAIL_LENGTH_LIMIT) {
	    close(OUT);
	    $TOTAL++;
	    $linecounter = 0;
	    &OpenStream($TMPF, 0, 0, $TOTAL) || (return 0);
	    $NEW = 0;
	}
    }
    
    if ($USE_RFC1153) { print OUT $TRAILER;}
    close(OUT);
    ###### end of foreach #####
    
    $TOTAL-- unless $NEW;
    
    ###############################################################
    # at this stage, 
    # 
    # $TMPF.0 file                               when packed.
    # $TMPF.$TOTAL .. files are already splitted when plain text.
    #
    # when PACK 
    #      spool/files or archive/files -> tmpf.0
    #      split tmpf.0 -> tmpf.1 .. tmpf.$TOTAL
    # 

    # IF PLAIN TEXT, already ends.
    # PACKING ...
    # Exceptional action for e.g. gzip
    if ($PACK_P) {
	if ($_cf{'ish'}) {
	    &LhaAndEncode2Ish($TMPF, $FILE, @filelist);
	}
	elsif ($_cf{'MakeFile', 'spool.tar.gz'}) {
	    &system("$TAR ".join(" ", @filelist)."|$COMPRESS|$UUENCODE $FILE", $TMPF);
	}
	else {			# uuencode + gzip
	    &system("$COMPRESS $TMPF.0|$UUENCODE $FILE", $TMPF);
	}

	# $TMPF is a encoded file(a master file of multiple-sending)
	# Split is below...
	local($totallines) = &WC($TMPF);
	$TOTAL = int($totallines/$MAIL_LENGTH_LIMIT + 1);
	&Debug("$TOTAL = int($totallines/$MAIL_LENGTH_LIMIT + 1);") if $debug;

	if ($TOTAL > 1) {
	    local($s) = &SplitFiles($TMPF, $totallines, $TOTAL);
	    if ($s == 0) {
		&Log("MakeFileWithUnixFrom: Cannot split $TMPF");
		return 0;
	    }
	}
	elsif (1 == $TOTAL) {# a trick for &SendingBackInOrder;
	    &Debug("rename($TMPF, $TMPF.1)") if $debug; 
	    rename($TMPF, "$TMPF.1"); 
	}
    }

    $TOTAL;
}


# Lha + uuencode for $FILE
# &Lha..( outputfile, encode-name, @list ) ;
# return ENCODED_FILENAME
sub LhaAndEncode2Ish
{
    local($TMPF, $FILE, @filelist) = @_;
    local($COMPRESS, $UUENCODE); # locally define!

    &Debug("LhaAndEncode2Ish($TMPF, $FILE, @filelist)") if $debug;

    # Variable setting
    $FILE =~ s/\.gz$/.lzh/;
    local($tmp) = "$TMP_DIR/$FILE";
    local($LHA) = $LHA ? $LHA : "$LIBDIR/bin/lha";
    local($ISH) = $ISH ? $ISH : "$LIBDIR/bin/aish";

    # SJIS ENCODING
    if ($USE_SJIS_in_ISH) {
	require 'jcode.pl';
	@filelist = &Convert2Sjis(*filelist);
    }

    # O.K. here we go
    unlink $tmp if -f $tmp;# for lha
    $COMPRESS = "$LHA a $tmp ". join(" ", @filelist);
    $UUENCODE = "$ISH -s7 -o $TMPF $tmp";

    &system($COMPRESS);
    &system($UUENCODE);

    $TMPF;
}


# Convert @filelist -> 
# return filelist(may be != given filelist e.g. spool -> tmp/spool)
# &system 's parameter is ($cmd , $out, $in)
# 
sub Convert2Sjis
{
    local(*f) = @_;
    local(*r);
    local($tmp)  = $TMP_DIR;
    local($tmpf) = "$TMP_DIR/$$";
    $tmp =~ s/^\.\///; # spool/,  tmp/, ..

    &Debug("\$tmp = $tmp") if $debug;

    # temporary directory
    if (! -d "$TMP_DIR/spool") {
	mkdir("$TMP_DIR/spool", 0700);
    }

    # GO!
    foreach $r (@f) { 
	$r =~ s/^\.\///; # spool/,  tmp/, ..

	&Debug("&file2sjis($r, $tmpf)") if $debug;
	&file2sjis($r, $tmpf) || next;

	if ($r =~ /^spool/) {
	    rename($tmpf, "$TMP_DIR/$r") || &Log("cannot rename $tmf $TMP_DIR/$r");
	    push(@r, "$TMP_DIR/$r");
	}
	elsif ($r =~ /^$tmp/) {
	    rename($tmpf, $r) || &Log("cannot rename $tmf $r");
	    push(@r, $r);
	}
    }

    return @r;
}


# using jcode.pl and add ^M and ^Z
# return 1 if succeed
sub file2sjis 
{
    local($in, $out) = @_;
    local($line);

    if (open(IN, $in)) {
	;
    }
    else {
	&Log("file2sjis: $in: $!");
	return 0;
    }

    if (open(OUT, "> $out")) {
	select(OUT); $| = 1; select(stdout);
    }
    else {
	&Log("file2sjis: $out: $!");
	return 0;
    }

    while (<IN>) {
	$line = $_;
	&jcode'convert(*line, 'sjis');#';
	$line =~ s/\012$/\015\012/; # ^M^J
	print OUT $line;
    }

    print OUT "\032\012";	# ^Z
    close(OUT);

    1;
}


# Sending files back, Orderly is [a], not [ad] _o_
# $returnfile not include $DIR PATH
# return NONE
sub SendingBackOrderly { &SendingBackInOrder(@_);}
sub SendingBackInOrder
{
    local($returnfile, $TOTAL, $SUBJECT, $SLEEPTIME, @to) = @_;

    foreach $now (1..$TOTAL) {
	local($file) = "$DIR/$returnfile.$now";
	$0 = ($PS_TABLE || "--SendingBackInOrder $FML"). 
	    " Sending Back $now/$TOTAL";
	&Logging("SBO:[$$] Send $now/$TOTAL ($to)", 1);
	&SendFile2Majority("$SUBJECT ($now/$TOTAL) $ML_FN", $file, 0, @to);

	unlink $file unless $debug;
	sleep($SLEEPTIME ? $SLEEPTIME : 3);
    }

    unlink $returnfile if ((! $_cf{'splitfile', 'NOT unlink'}) && (! $debug));
    unlink "$returnfile.0" unless $debug; # a trick for MakeFileWithUnixFrom
}


# Split the given file and send back them
# ($f, $PACK_P, $subject, @to)
# $f          the target file
# $PACK_P
# $subject
# @to 
# return NONE
sub SendFilebySplit
{
    local($f, $PACK_P, $enc, @to) = @_;
    local($TOTAL, $s);
    local($tmp) = "$TMP_DIR/$$";

    $0 = "--Split and Sendback $f to $to $ML_FN <$FML $LOCKFILE>";
    local($s)   = ($enc || "Matomete Send");

    if ($_cf{'ish'}) {
	$s .= ' [Ished]';
	$enc =~ /ish$/ || ($enc .= '.ish');
    }     
    elsif ($PACK_P) {
	$s .= ' [Gziped]';
	$enc =~ /gz$/ || ($enc .= '.tar.gz');
    }
    elsif ($PACK_P == 0) {
	$s .= ' [PLAINTEXT]';
    }

    $TOTAL  = &MakeFileWithUnixFrom($tmp, $PACK_P, $enc, $f);
    if ($TOTAL) {
	&SendingBackInOrder($tmp, $TOTAL, $s, ($SLEEPTIME || 3), @to);
    }
}


# WHOIS INTERFACE using IPC
# return the answer
sub Whois
{
    local($sharp, $_, @who) = @_;
    local($REQUEST, $h);

    if (! /whois/oi) { 
	&Log($_." is not implemented"); 
	return "Sorry, $_ is not implemented";
    }
 

    # Parsing
    foreach (@who) { 
	/^-h/ && (undef $h, next);
	$h || ($h = $_, next); 
	$REQUEST .= " $_";
    }

    # IPC
    $ipc{'host'}   = ($host || $DEFAULT_WHOIS_SERVER);
    $ipc{'pat'}    = 'S n a4 x8';
    $ipc{'serve'}  = 'whois';
    $ipc{'proto'}  = 'tcp';

    &Log("whois -h $host: $REQUEST");

    # Go!
    require 'jcode.pl';
    &jcode'convert(*REQUEST, 'euc'); #'(trick) -> EUC

    # After code-conversion!
    # '#' is a trick for inetd
    @ipc = ("$REQUEST#\n");
    local($r) = &ipc(*ipc);

    &jcode'convert(*r, 'jis'); #'(trick) -> JIS

    "Whois $host $REQUEST $ML_FN\n$r\n";
}



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
    
    &Debug("TarZXF local($tarfile, $total, ". 
	join(" ", keys %cat) .", $outfile)\n") if $debug;
    
    # check the setting on ZCAT
    if (! defined($ZCAT)) { return "ERROR of ZCAT";}
    
    open(TAR, $tarfile) || &Log("TarZXF: Cannot open $tarfile: $!");
    open(TAR, '-|') || exec($ZCAT, $tarfile) || die("zcat: $!\n")
	if ($tarfile =~ /\.gz$/);
    select(TAR); $| = 1; select(stdout);

    if ($outfile) {
	&OpenStream($outfile, 0, 0, $TOTAL) 
	    || do { &Log("TarZXF: Cannot Open $outfile"); return "";};
    };
    
    while (($s = read(TAR, $header, $header_size)) == $header_size) {
	if ($header eq $nullblock) {
	    last if ++$null_count == 2;
	    next;
	}
	$null_count = 0;
	
	@header = unpack($header_format, $header);
	
	($name = $header[0]) =~ s/\0*$//;
	local($catit) = $cat{$name};

	local($bufsize) = 8192;
	local($size)    = oct($header[4]);
	$SIZE          += $size; # total size?
	$size = 0 if $header[7] =~ /1/;

	# suppose 80 char/line
	if ($outfile && $catit && $SIZE > 80 * $MAIL_LENGTH_LIMIT) { 
	    close(OUT);
	    $TOTAL++; 
	    $outfile && &OpenStream($outfile, 0, 0, $TOTAL) 
		|| do { &Log("TarZXF: Cannot Open $outfile"); return "";};    
	    $SIZE = 0;
	}
	
	while ($size > 0) {
	    $bufsize = 512 if $size < $bufsize;
	    if (($s = read(TAR, $buf, $bufsize)) != $bufsize) {
		&Log("TarZXF: Illegal EOF: bufsize:$bufsize, size:$size");
	    }

	    if ($catit) {	    
		if ($outfile) {
		    $B = substr($buf, 0, $size);
		    $B =~ s/Return\-Path:.*\n/From $MAINTAINER\n/;
		    print OUT $B;
		}
		else {
		    $BUF .= substr($buf, 0, $size);
		}
	    }

	    $size -= $bufsize;
	}
	
	print OUT "\n" if $catit;# \nFrom UNIX-FROM;

	if ($catit && ! --$total) {
	    close TAR, OUT;
	    return $outfile ? $TOTAL: $BUF;
	}
    }# end of Tar extract
    
    close TAR; close OUT;
    return $outfile ? $TOTAL: $BUF;
}

# InterProcessCommunication
# return the answer from <S>(socket)
sub ipc
{
    local(*ipc) = @_;
    local($a);
    local($err) = "Error of IPC";

    local($name,$aliases,$addrtype,$length,$addrs) = 
	gethostbyname($ipc{'host'} || "localhost");
    local($name,$aliases,$port,$proto) = 
	getservbyname($ipc{'serve'}, $ipc{'tcp'});
    $port = 13 unless defined($port); # default port:-)
    local($target) = pack($ipc{'pat'}, &AF_INET, $port, $addrs);

    if ($debug) {
	&Debug("ipc:");
	&Debug("\t%ipc". join(",", %ipc));
	&Debug("\tpack($ipc{pat}, &AF_INET, $port, $addrs)");
    }

    socket(S, &PF_INET, &SOCK_STREAM, 6) || (&Log($!), return $err);
    connect(S, $target)                  || (&Log($!), return $err);
    select(S); $| = 1; select(stdout); # need flush of sockect <S>;

    foreach (@ipc) {
	&Debug("IPC S>$_") if $debug;
	print S $_;
	while (<S>) { 
	    $a .= $_;
	}
    }

    close S;
    $a;
}


# Pseudo system()
# fork and exec
# $s < $in > $out
# 
# PERL:
# When index("$&*(){}[]'\";\\|?<>~`\n",*s)) > 0, 
#           which implies $s has shell metacharacters in it, 
#      execl sh -c $s
# if not in it, (automatically)
#      execvp($s) 
# 
# and wait untile the child process dies
# 
sub system
{
    local($s, $out, $in) = @_;

    &Debug("&system ($s, $out, $in)") if $debug;

    # Metacharacters check, but we permit only '|' and ';'.
    local($r) = $s;
    $r =~ s/[\|\;]//g;		

    if ( &MetaP($r) ) {
	&Log("$s matches the shell metacharacters, exit");
	return 0;
    }

    # Go!;
    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	if ($in){
	    open(STDIN, $in) || die "in";
	}
	else {
	    close(STDIN);
	}

	if ($out){
	    open(STDOUT, '>'. $out)|| die "out";
	    $| = 1;
	}
	else {
	    close(STDOUT);
	}

	exec $s;
	&Log("Cannot exec $s:$@");
    }

    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}


# Check the string contains Shell Meta Characters
# return 1 if match
sub MetaP
{
    local($r) = @_;

    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Log("Match: $ID  -> $`($&)$'");
	return 1;
    }

    0;
}

### may be a DUPLICATED SUBROLUTINE ###

# Return 1 if Loopback
if ( (! defined(&LoopBackWarn))
   &&
   (! defined(&LoopBackWarning))
   ) {
local($hook) = q!
sub LoopBackWarning { &LoopBackWarn(@_);}
sub LoopBackWarn
{
    local($to) = @_;

    foreach ($MAIL_LIST, $CONTROL_ADDRESS, @Playing_to) {
	next if /^$/oi;		# for null control addresses
	if (&AddressMatching($to, $_)) {
	    &Log("LoopBack Warning: ", "[$From_address] or [$to]");
	    &Warn("Warning: $ML_FN", &WholeMail);
	    return 1;
	}
    }

    return 0;
}
!;

&eval($hook, 'Duplicate hook');
}

1;
