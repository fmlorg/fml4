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
    return 0 if &LoopBackWarn($from); # loop back check

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


# Parameters:
# $tmpf     : a temporary file
# $mode     : mode 
# $file     : filename of encode e.g. uuencode , ish ...
# @filelist : filelist of packing and encodeing
#
# INSIDE VARIABLES:
# *conf : input 
# *r    : output
# *misc : output as an additional
sub DraftGenerate
{
    local(*conf, *r, *misc);
    local($prog, $proc);
    local($tmpf, $mode, $file, @conf) = @_; # attention! *conf above
    $conf = $tmpf;
    $r    = $file;
    $conf{'total'} = 0;

    print STDERR "&DraftGenerate ($tmpf, $mode, $file, @conf)\n" if $debug;

    &InitDraftGenerate;

    # INCLUDE
    require $_fp{'inc', $mode} if $_fp{'inc', $mode};

    foreach $proc ( # order 
		    'hdr',
		    'cnstr', 
		    'retrieve',
		    'split',
		    'destr'
		    ) {

	$prog = $_fp{$proc, $mode};
	print STDERR "Call &$prog(*conf, *r, *misc)\n" if $debug;
	&$prog(*conf, *r, *misc) if $prog;
    }

    $r{'total'};
}


# Get a option value for msend..
# Parameter = opt to parse
# If required e.g. 3mp, parse to '3' and 'mp', &ParseM..('mp')
# return option name || NULL (fail)
sub ParseMSendOpt
{
    local($opt) = @_;

    foreach $OPT (keys %MSendOpt) {
	return $MSendOpt{$OPT} if $opt eq $OPT;
    }

    return $NULL;
}


# &ModeLookup($d+$S+) -> $d+ and $S+. 
# return ($d+, $S+) or a NULL list
sub ModeLookup
{
    local($opt) = @_;    
    local($when, $mode);

    print STDERR "&ModeLookup($opt)\n" if $debug;

    # Require called by anywhere
    &InitDraftGenerate;

    # Parse option 
    # return NULL LIST if fails
    if ($opt =~ /(\d+)(.*)/) {
	$when = $1;
	$mode = $2;
    }
    elsif ($opt =~ /(\d+)/) {
	$when = $1;
	$mode = '';
    }else {
	return ($NULL, $NULL);
    }

    # try to find 
    $mode = $MSendOpt{$mode};

    # Not match or document
    $mode || do { return ($NULL, $NULL);};
    ($mode =~ /^\#/) &&  do { return ($NULL, $NULL);};

    # O.K. 
    return ($when, $mode);
}


# &ModeLookup($d+$S+) -> $d+ and $S+. 
# return DOCUMENT string
sub DocModeLookup
{
    local($opt) = @_;    
    $opt =~ s/\#\d+/\#/g;

    print STDERR "&DocModeLookup($opt)\n" if $debug;

    # Require called by anywhere
    &InitDraftGenerate;

    if ($opt =~ /^\#/ && ($opt = $MSendOpt{$opt})) {
	($opt =~ /^\#(.*)/) && (return $1);
    }
    else {
	return '[No document]';
    }
}


sub InitDraftGenerate
{
    #            KEY        MODE
    # DOCUMENT   #KEY       #MODE 
    %MSendOpt = (
		 '#gz', '#gzipped(UNIX FROM)', 
		 '',        'gz',
		 'gz',      'gz',


		 '#mp', '#MIME/multipart', 
		 'mp',      'mp',


		 '#uf', '#PLAINTEXT(UNIX FROM)', 
		 'u',       'uf', 
		 'uf',      'uf',
		 'unpack',  'uf',


		 '#lhaish', '#LHA+ISH', 
		 'i',       'lhaish',
		 'ish',     'lhaish',


		 '#rfc954', '#RFC954(mh-burst)', 
		 'b',       'rfc954', 
		 'rfc954',  'rfc954',


		 '#rfc1153', '#Digest (RFC1153)',
		 'd',       'rfc1153',
		 'rfc1153', 'rfc1153'

		 );


    # PLAIN TEXT with UNIX FROM
    $_fp{'cnstr',    'uf'} = 'Cnstr_uf';
    $_fp{'retrieve', 'uf'} = 'f_RetrieveFile';
    $_fp{'split',    'uf'} = '';
    $_fp{'destr',    'uf'} = '';

    # PLAINTEXT by RFC954
    $_fp{'cnstr',    'rfc954'} = 'Cnstr_rfc954';
    $_fp{'retrieve', 'rfc954'} = 'f_RetrieveFile';
#    $_fp{'split',    'rfc954'} = 'f_SplitFile';

    # PLAINTEXT by RFC1153
    $_fp{'cnstr',    'rfc1153'} = 'Cnstr_rfc1153';
    $_fp{'retrieve', 'rfc1153'} = 'f_RetrieveFile';
#    $_fp{'split',    'rfc1153'} = 'f_SplitFile';

    # PLAINTEXT by MIME/Multipart
    $_fp{'cnstr',    'mp'} = 'Cnstr_mp';
    $_fp{'retrieve', 'mp'} = 'f_RetrieveFile';
#    $_fp{'split',    'mp'} = 'f_SplitFile';

    # Gzipped UNIX FROM
    $_fp{'cnstr',    'gz'} = 'Cnstr_gz';
    $_fp{'retrieve', 'gz'} = 'f_gz';
    $_fp{'split',    'gz'} = 'f_SplitFile';

    # PACK: TAR + GZIP
    $_fp{'cnstr',    'tgz'} = 'Cnstr_tgz';
    $_fp{'retrieve', 'tgz'} = 'f_tgz';

    # PACK: LHA + ISH
    $_fp{'cnstr',    'lhaish'} = '';
    $_fp{'retrieve', 'lhaish'} = 'f_LhaAndEncode2Ish';
    $_fp{'split',    'lhaish'} = 'f_SplitFile';

}

				# 
sub Cnstr_uf
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "From $MAINTAINER\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub Cnstr_rfc1153
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n\n".('-' x 30)."\n\n";

    require 'librfc1153.pl';
    local($PREAMBLE, $TRAILER) = &Rfc1153Custom(@conf);

    $conf{'rfhook'}   = &Rfc1153ReadFileHook;
    $conf{'preamble'} = $PREAMBLE;
    $conf{'trailer'}  = $TRAILER;

    $_cf{'Destr'} .= "&Rfc1153Destructer;\n";
}


sub Cnstr_rfc954
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n------- Forwarded Message\n\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub Cnstr_mp
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;

    if (! $MIME_MULTIPART_BOUNDARY) {
	$MIME_MULTIPART_BOUNDARY = "simple boundary\nContent-Type: message/rfc822\n";
    }
    else {
	&eval($MIME_MULTIPART_BOUNDARY, 'MIME/Multipart:');
    }

    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n--$MIME_MULTIPART_BOUNDARY\n";
    $conf{'preamble'} = q#
      This is the preamble.  It is to be ignored, though it
      is a handy place for mail composers to include an
      explanatory note to non-MIME conformant readers.
#;

    $conf{'trailer'} = "\n--$MIME_MULTIPART_BOUNDARY--\n";
    $conf{'trailer'} .= "This is the epilogue.  It is also to be ignored.\n";

    undef $_cf{'header', 'MIME'};
    $_cf{'header', 'MIME'} .= "MIME-Version: 1.0\n";
    $_cf{'header', 'MIME'} .= "Content-type: multipart/mixed;\n";
    $_cf{'header', 'MIME'} .= "\tboundary=\"$MIME_MULTIPART_BOUNDARY\"\n";
}


sub Cnstr_gz
{
    local(*conf, *r, *misc) = @_;

    $conf{'total'} = 0;
    $conf{'delimiter'} = "From $MAINTAINER\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub f_RetrieveFile
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($file, $lines, $linecounter, $total, $new_p);
    local($total) = $conf{'total'};

    # OPEN
    &OpenStream($tmpf, 0, 0, $total) || (return 0);

    # PREAMBLE
    if ($conf{'preamble'}) {
	print OUT $conf{'preamble'};
	$new_p++;
    }

    # Retrieve files
    foreach $file (@conf) {
	$lines = &WC($file);
	
	# open the next file
	open(FILE, $file) || next; 
	print OUT $conf{'delimiter'} if $conf{'delimiter'};

 	if ($conf{'rfhook'}) {
	    $s = qq#
		while (<FILE>) { 
		    \$conf{'rfhook'};
		    print OUT \$_; \$linecounter++;
		}
	    #;
	    &Debug(">>$s<<") if $debug;
	    &eval($s, 'Retreive file hook');
	}
	else {
	    while (<FILE>) { 
		print OUT $_; $linecounter++;
	    }
	}
	close(FILE);
	
	print OUT "\n"; $linecounter++;
	$new_p++;	# the number of files
	
	# If PLAIN TEXT, reset!
	if ($conf{'plain'} && ($linecounter + $lines) > $MAIL_LENGTH_LIMIT) {
	    # e.g. in the format of RFC1153, 
	    # each mail is perfect format is appropriate?
	    print OUT $conf{'trailer'} if $conf{'trailer'};

	    # Close Output
	    &CloseStream;

	    # Reconfig
	    $total++;
	    $linecounter = 0;

	    # Open new file(OUTPUT)
	    &OpenStream($tmpf, 0, 0, $total) || (return 0);

	    # if preamble only, not need to deliver, so new_p = 0
	    print OUT $conf{'preamble'} if $conf{'preamble'}; 
	    $new_p = 0;
	}
    }

    # TRAILER
    if ($conf{'trailer'}) {
	print OUT $conf{'trailer'};
	$new_p++ ;
    }

    # CLOSE
    &CloseStream;

    # if write filesize=0, decrement TOTAL.
    $total-- unless $new_p;

    $r{'total'} = $total;
}


sub f_LhaAndEncode2Ish
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &LhaAndEncode2Ish($tmpf, $r, @conf);
}


sub f_gz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &f_RetrieveFile(*conf, *r, *misc);
    &system("$COMPRESS $tmpf.0|$UUENCODE $r", $tmpf);
}


sub f_tgz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &system("$TAR ".join(" ", @conf)."|$COMPRESS|$UUENCODE $r", $tmpf);
}


sub f_gzuu
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &system("$COMPRESS $tmp.0|$UUENCODE $r", $tmpf);
}


sub f_SplitFile
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($total) = $r{'total'};

    print STDERR "f_SplitFile: $tmpf -> $r \n" if $deubg;

    local($totallines) = &WC($tmpf);
    $total = int($totallines/$MAIL_LENGTH_LIMIT + 1);
    &Debug("$total = int($totallines/$MAIL_LENGTH_LIMIT + 1);") if $debug;

    if ($total > 1) {
	local($s) = &SplitFiles($tmpf, $totallines, $total);
	if ($s == 0) {
	    &Log("f_SplitFile: Cannot split $tmpf");
	    return 0;
	}
    }
    elsif (1 == $total) {# a trick for &SendingBackInOrder;
	&Debug("rename($tmpf, $tmpf.1)") if $debug; 
	rename($tmpf, "$tmpf.1"); 
    }

    $r{'total'} = $total;
}
######################################################################


# Open FILEHANDLE 'OUT'.
# PACK_P is backward compatibility since 
# PACK_P is always 0!
# return 1 if succeed;
sub OpenStream_OUT { &OpenStream(@_);}
sub OpenStream
{
    local($WHERE, $PACK_P, $FILE, $TOTAL) = @_;

    &Debug("&OpenStream: open OUT > $WHERE.$TOTAL;") if $debug;
    open(OUT, "> $WHERE.$TOTAL") || do { 
	&log("OpenStream: cannot open $WHERE.$TOTAL");
	return $NULL;
    };
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
sub MakeFilesWithUnixFrom { &DraftGenerate(@_);}
sub MakeFileWithUnixFrom  { &DraftGenerate(@_);}

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

    unlink @filelist if $debug;

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
    undef $_cf{'header', 'MIME'}; # destructor
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
    undef $_cf{'header', 'MIME'}; # destructor
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
