#!/usr/local/bin/perl
#
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

### MAIN ###
umask(077);

&FmlLocalInitilize;
&FmlLocalConfigure;
&FmlLocalMainProc;

exit 0;
################# LIBRALY ################# 


sub MailLocal
{
    # UMASK
    umask(077);

    # FLOCK paremeters
    $LOCK_SH = 1;
    $LOCK_EX = 2;
    $LOCK_NB = 4;
    $LOCK_UN = 8;

    # Do FLOCK
    if ( open(MBOX, ">> $MAIL_SPOOL") ) {
 	flock(MBOX, $LOCK_EX);
	seek(MBOX, 0, 2);
    }
    elsif ( open(MBOX, ">> $HOME/dead.letter") ) {
	flock(MBOX, $LOCK_EX);
	seek(MBOX, 0, 2);
    }
    else {
	&Log("Can't open mailbox: $!");
	return 0;
    }

    # APPEND!
    select(MBOX); $| = 1;
    &Log("> $MAIL_SPOOL") if $debug;

    print MBOX $MailHeaders;
    local(@s) = split(/\n/, $MailBody);
    while(@s) {
	$_ = shift @s;
	print MBOX ">" if /^From /i; # '>From'
	print MBOX $_;
    }

    # not newline terminated
    print MBOX "\n" unless $_ =~ /\n$/;

    # "\n"; allow empty message
    print MBOX "\n";

    # Unlock
    flock(MBOX, $LOCK_UN);
    close(MBOX);
}


sub MailProc
{
    local($type, $exec) = @_;

    if ($exec =~ /^mail\.local$/i) {
	&Log("mail.local") if $debug;
	&MailLocal;
    }

    if ($type =~ /^\|$/o) {
	&Log("|$exec") if $debug;
	open(EXEC,"|$exec");
	select(EXEC); $| = 1; 
	print EXEC &WholeMail;
	close(EXEC);
    }

    if ($type =~ /^>$/o) {
	&Log(">>$exec") if $debug;
	open(EXEC,">> $exec");	# APPEND!
	select(EXEC); $| = 1; 
	print EXEC &WholeMail;
	close(EXEC);
    }

    if ($type =~ /^&$/o) {
	&Log("&$exec") if $debug;
	if ($exec =~ /(\S+)\((.*)\)/) {
	    $exec  = $1;
	    $param = $2;
	    &$exec($param);
	}
	else {
	    &$exec;
	}
    }

}


sub FmlLocalInitilize
{
    $UNMATCH_P = 1;
    $AUTH      = 0;
    $NOT_TRACE_SMTP = 1;
    
    @VAR = (HOME, DIR, LIBDIR, FML_PL, USER, MAIL_SPOOL, LOG, 
	    PASSWORD, DEBUG, AND, ARCHIVE_DIR);

    local($ARGV_STR) = join(" ", @ARGV);
    undef @ARGV;
    if ($ARGV_STR =~ /\-user\s+(\S+)/) {
	$USER = $1;
    }

    $USER = $USER || (getpwuid($<))[0];

    $HOME = (getpwnam($USER))[7] || $ENV{'HOME'};

    $FML_LOCAL_RC = "$HOME/.fmllocalrc";
}


sub FmlLocalReadCF
{
    local($INFILE) = @_;
    local($eval);
    local($field, $pattern, $type, @exec);

    $INFILE = $INFILE || $FML_LOCAL_RC;
    
    open(CF, "< $INFILE") || do {
	&Log("fail to open $INFILE");
	die "FmlLocalReadCF:$!\n";
    };

    CF: while(<CF>) {
	# Skip e.g. comments, null lines
	next CF if /^\s*$/o;
	next CF if /^\#/o;
	chop;

	# debug options
	$debug  = 1 if /^DEBUG/i;
	$debug  = $debug2 = 1 if /^DEBUG2/i;

	# Set environment variables
	foreach $VAR (@VAR) { 
	    /^$VAR\s+(\S+)/ && ($VAR{$VAR} = $1) && (next CF);
	}

	# store configurations
	push(@CF, $_);
    }
    close(CF);
    
    "$eval\n1;\n";
}


sub FmlLocalConfigure
{
    # include ~/.fmllocalrc
    $EVAL = &FmlLocalReadCF;
    print STDERR $EVAL if $debug;

    $HOME = $VAR{'HOME'} || (getpwnam($USER))[7] || 
	    $ENV{'HOME'} || $ENV{'LOGDIR'} || (getpwuid($<))[7] ||
		die("You are homeless!\n");

    $DIR    = $VAR{'DIR'}    || $HOME;

    $LIBDIR = $VAR{'LIBDIR'} || $DIR;

    $LOGFILE = $VAR{'LOG'} || "$DIR/log";
    $ARCHIVE_DIR = $VAR{'ARCHIVE_DIR'} || $DIR;
    
    $FML_PL = $VAR{'FML_PL'} || 
	(-f "$LIBDIR/fml.pl" && "$LIBDIR/fml.pl") ||
	    (-f "$DIR/fml.pl" && "$DIR/fml.pl") ||
		(-f "$ENV{'FML'}/fml.pl" && "$ENV{'FML'}/fml.pl") ||
		    ($NOT_EXIST_FML_PL = 1);
#die "Please set where is fml.pl!\n";

    $USER   = $USER || $VAR{'USER'} || getlogin || 
	(getpwuid($<))[0] || "Somebody";

    $MAIL_SPOOL 
	= $VAR{'MAIL_SPOOL'} || 
	    (-r "/var/mail/$USER"       && "/var/mail/$USER") ||
		(-r "/var/spool/mail/$USER" && "/var/spool/mail/$USER") ||
		    (-r "/usr/spool/mail/$USER" && "/usr/spool/mail/$USER");

    $PASSWORD = $VAR{'PASSWORD'};

    # field separator
    $FS = $VAR{'FS'} || '\s+';

    # include ~/.vacationrc
    if (-f "$HOME/.vacationrc") {
	&FmlLocalReadCF("$HOME/.vacationrc");
    }

    1;
}


sub FmlLocalPatternMatch
{
    # IF WITHOUT UNIX FROM e.g. for slocal bug??? 
    if (! ($MailHeaders =~ /^From\s+\S+/i)) {
	local($USER) = 
	    $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;
	$MailHeaders = "From $USER $MailDate\n".$MailHeaders;
    }

    local($field, $pattern, $type, $exec, $pat);
    local($MATCH_P, $AND, $PREV_MATCH);
    local($s) = $MailHeaders;
    
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g;
    local(@MailHeaders) = split(/\n\n/, $s, 999);

    while (@MailHeaders) {
	$_ = shift @MailHeaders;

        # UNIX FROM is a special case.
	# 1995/06/01 check UNIX FROM LoopBack
	if (/^from\s+(\S+)/io) {
	    $Unix_From = $1;
	    next;
	}

	$contents = shift @MailHeaders;
	$contents =~ s/^\s+//; # cut the first spaces of the contents.

	next if /^\s*$/o;	# if null, skip. must be mistakes.

	printf STDERR "=> %-10s %-60s\n", $_, $contents if $debug;

	CF: foreach $pat (@CF) {
	    ($field, $pattern, $type, $exec) = split(/$FS/, $pat);
	    next CF unless /$field/i;

	    if ($field =~ /^AND$/i || (!$exec)) {
		$AND++;
	    }
	    else {
		undef $AND;
	    }

	    # debug
	    print STDERR "($field, $pattern, $type, $exec)\n" if $debug;

	    # MATCHING PATTERN
	    if (/^$field:$/i && ($contents =~ /$pattern/)) {
		&FmlLocalSet($type, $exec, $1, $2, $3);
		$MATCH_P++;

		($MATCH_P == $AND) && &FmlLocalSet($type, $exec, $1, $2, $3);
		($MATCH_P == $AND) && &Log("AND $type, $exec, $1, $2, $3");
	    }

	    if($field =~ /^body$/i) {
		&FmlLocalMatchInBody($pattern, $type, $exec);
		$MATCH_P++;

		($MATCH_P == $AND) && &FmlLocalSet($type, $exec, $1, $2, $3);
		($MATCH_P == $AND) && &Log("AND $type, $exec, $1, $2, $3");
	    }

	    if ($debug && $MATCH_P) {
		&Log("MATCH $field =~ /$pattern/ && Do $TYPE$EXEC");
		print STDERR "MATCH\t$field =~ /$pattern/\n";
		print STDERR "DO\t$TYPE$EXEC\n";
		print STDERR "F1\t$F1\n" if $F1;
		print STDERR "F2\t$F2\n" if $F2;
		print STDERR "F3\t$F3\n" if $F3;
		undef $MATCH_P;
	    }

	}# FOREACH;


	##### GET FIELD VALUE #####

	# Fields to skip. Please custumize below.
	next if /^Received:/io;
	next if /^In-Reply-To:/io && (! $SUPERFLUOUS_HEADERS);
	next if /^Return-Path:/io;
	next if /^X-MLServer:/io;
	next if /^X-ML-Name:/io;
	next if /^X-Mail-Count:/io;
	next if /^Precedence:/io;
	next if /^Lines:/io;

	# filelds to use later.
	/^Date:$/io           && ($Date = $contents, next);
	/^Reply-to:$/io       && do { 
	    $Reply_to = &Expand_mailbox($contents);
	    next;};
	/^Errors-to:$/io      && ($Errors_to = $contents, next);
	/^Sender:$/io         && ($Sender = $contents, next);
	/^X-Distribution:$/io && ($Distribution = $contents, next);
	/^Apparently-To:$/io  && ($Original_To_address = $To_address = $contents, 
				  next);
	/^To:$/io             && ($Original_To_address = $To_address = $contents, 
				  next);
	/^Cc:$/io             && ($Cc = $contents, next);
	/^Message-Id:$/io     && ($Message_Id = $contents, next);

	# get subject (remove [Elena:id]
	# Now not remove multiple Re:'s),
	# which actions may be out of my business though...
	if (/^Subject:$/io && $STRIP_BRACKETS) {
	    # e.g. Subject: [Elena:001] Uso...
	    $contents =~ s/\[$BRACKET:\d+\]\s*//g;

	    local($r)  = 10;	# recursive limit against infinite loop
	    while (($contents =~ s/Re:\s*Re:\s*/Re: /g) && $r-- > 0) {;}

	    $Subject = $contents;
	    next;
	}
	/^Subject:$/io        && ($Subject = $contents, next); # default
	
	if (/^From:$/io) {
	    # From_address is modified for e.g. member check, logging, commands
	    # Original_From_address is preserved.
	    $_ = $Original_From_address = $contents;
	    $From_address = &Expand_mailbox($_);
	    next;
	}
	
	# Special effects for MIME, based upon rfc1521
	if (/^MIME-Version:$/io || 
	    /^Content-Type:$/io || 
	    /^Content-Transfer-Encoding:$/io) {
	    $_cf{'MIME', 'header'} .= "$field $contents\n";
	    next;
	}

	# when encounters unknown headers, hold if $SUPERFLUOUS_HEADERS is 1.
	$SuperfluousHeaders .= "$field $contents\n" if $SUPERFLUOUS_HEADERS;

    }# WHILE @MAILHAEDERS;

    1;
}


sub FmlLocalSet
{
    local($type, $exec, $f1, $f2, $f3) = @_;

    undef $TYPE, $EXEC, $F1, $F2, $F3;

    $TYPE = $type;
    $EXEC = $exec;
    $F1  = $f1;
    $F2  = $f2;
    $F3  = $f3;

    undef $UNMATCH_P;
}


sub FmlLocalMatchInBody
{
    local($pat, $type, $exec) = @_;
    local(@MailBody) = split(/\n/, $MailBody);

    while(@MailBody) {
	  $_ = shift @MailBody;

	  if (/$pat/) {
	      &FmlLocalSet($type, $exec, $1, $2, $3);
	  }

	  if ($MailBody =~ /^#\s*PASS\s+(\S+)/ || 
	      $MailBody =~ /^#\s*PASSWORD\s+(\S+)/) {
	      $AUTH++ if $password eq $PASSWORD;
	      next;
	  }

	  if ($AUTH && /^#\s*PASSWD\s+(\S+)/) {
	      &FmlLocalAppend2CF("PASSWORD $1");
	      next;
	  }
      }

    1;
}


sub FmlLocalAdjust
{
    # adjustment
    $EXEC =~ s/\$F1/$F1/g;
    $EXEC =~ s/\$F2/$F2/g;
    $EXEC =~ s/\$F3/$F4/g;
    $EXEC =~ s/\$From_address/$From_address/g;
    $EXEC =~ s/\$To_address/$To_address/g;
    $EXEC =~ s/\$Subject/$Subject/g;
    $EXEC =~ s/\$Reply_to/$Reply_to/g;
    $EXEC =~ s/\$HOME/$HOME/g;
    $EXEC =~ s/\$DIR/$DIR/g;
    $EXEC =~ s/\$LIBDIR/$LIBDIR/g;

    1;
}


sub FmlLocalMainProc
{
    # include fml.pl if needed
    eval &FmlLocalReadFML || &Log("Loading fml.pl:$@");
    eval $EVAL            || &Log("ReadCF::eval:$@");

    &Parsing;
    &FmlLocalPatternMatch;
    &FmlLocalAdjust;

    # IF UNMATCHED ANYWHERE, 
    # Default action equals to /usr/libexec/mail.local(4.4BSD)
    if ($UNMATCH_P) {
	print STDERR "\n&MailLocal;\n\n" if $debug;
	&Log("Default::mail.local") if $debug;
	&MailLocal;
    }
    else {
	print STDERR "\n&MailProc($TYPE, $EXEC);\n\n" if $debug;
	&Log("MailProc($TYPE, $EXEC)") if $debug;
	&MailProc($TYPE, $EXEC);
    }

}


sub FmlLocalAppend2CF
{
    local($s) = @_;

    open(CF, ">> $FML_LOCAL_RC") || (return 'open fail ~/.fmllocalrc');
    select(CF);
    print CF "$s\n";
    close(CF);

    return 'ok';
}


sub FmlLocalReadFML
{
    local($SEP_KEY) = "\#\#\#\#\# SubRoutines \#\#\#\#\#";
    local($s);

    return '1;' unless -f $FML_PL;

    open(FML, $FML_PL) || 
	(print STDERR "Cannot load $FML_PL\n"  , return 0);

    while(<FML>) {
	next if 1 .. /^$SEP_KEY/;
	$s .= $_;
    }

    close(FML);

    $s;
}


sub FmlLocalReadFile
{
    local($file, $package) = $_;
    local($s);

    open(FML, $file) || &Log("Cannot load $file\n");
    while(<FML>) { $s .= $_; }
    close(FML);

    $package = $package || 'main';
    "package $package;\n$s";
}


########## ########## ########## ########## ########## ########## 
########## Built-In Functions

sub getback
{
    local($ARCHIVE_DIR) = $ARCHIVE_DIR || $DIR;

    chdir $ARCHIVE_DIR || do {
	&Log("cannot chdir $DIR");
	return 0;
    };

    print STDERR "&SendFile($Reply_to ? $Reply_to : $From_address,
		  \"Send $F1\",
		  $F1);\n" if $debug;

    if (-f $F1 && (! &MetaCharP($F1))) {
	&Log("getback $F1");
	&SendFile($Reply_to ? $Reply_to : $From_address,
		  "Send $F1",
		  $F1);
    }
    else {
	&Log("fail to getback $F1");
    }

    1;
}


########## ########## ########## ########## ########## ########## 


########## fml.pl
sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, 
		   $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

# Recreation of the whole mail for error infomation
sub WholeMail
{
    "$MailHeaders\n$MailBody";
}

# Alias but delete \015 and \012 for seedmail return values
sub Log { 
    local($str, $s) = @_;
    $str =~ s/\015\012$//;
    &Logging($str);
    &Logging("   ERROR: $s", 1) if $s;
}

# Logging(String as message)
# $errf(FLAG) for ERROR
sub Logging
{
    local($str, $e) = @_;

    &GetTime;

    open(LOGFILE, ">> $LOGFILE");
    select(LOGFILE); $| = 1; select(STDOUT);
    print LOGFILE "$Now $str ". ((!$e)? "($From_address)\n": "\n");
    close(LOGFILE);
}


########### libsmtp.pl 
sub InitSmtp
{
    $EXIST_SOCKET_PH = eval "require 'sys/socket.ph';", $@ eq "";
    &Log("sys/socket.ph is O.K.") if $EXIST_SOCKET_PH && $debug;

    if ((! $EXIST_SOCKET_PH) && $COMPAT_SOLARIS2) {
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
	undef $eval;
    }
    elsif (! $EXIST_SOCKET_PH) {	# 4.4BSD
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
	undef $eval;
    }
}


# delete logging errlog file and return error strings.
sub Smtp # ($host, $headers, $body)
{
    local($host, $body, @headers) = @_;
    local($pat)  = 'S n a4 x8';
    # local($pat)  = 'S n C4 x8'; # which is correct?

    # 
    &InitSmtp;

    # VARIABLES:
    $host       = $HOST       || 'localhost';

    if ($NOT_TRACE_SMTP) {
	open(SMTPLOG, "> /dev/null") || &Log("Cannot open /dev/null");
    }
    else {
	open(SMTPLOG, "> $SMTP_LOG") || 
	    (return "$MailDate: cannot open $SMTP_LOG");
    }

#.IF SMTP
    # DNS. $HOST is global variable
    # it seems gethostbyname does not work if the parameter is dirty?
    # 
    local($name,$aliases,$addrtype,$length,$addrs) = gethostbyname($HOST);
    local($name,$aliases,$port,$proto) = getservbyname('smtp', 'tcp');
    $port = 25 unless defined($port); # default port
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC open
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
    select(S);       $| = 1; select(STDOUT);
    select(SMTPLOG); $| = 1; select(STDOUT);
#.ELSE SMTP
#.    require 'open2.pl';
#.    &open2(OUT, S, $SENDMAIL) || return "Cannot exec $SENDMAIL";
#.FI SMTP

    ###### Here We go! ##### 
    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d\d\d\-/o);
    foreach $s (@headers) {
	if ($TRACE_DNS_DELAY) { &GetTime; $prev = 60*$min + $sec;};
	print SMTPLOG ($s . "<INPUT\n");
	if (! $debug0) {
	    print S ($s . "\n");
	    do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
	    while(/^\d\d\d\-/o);
	}
	if ($TRACE_DNS_DELAY) {
	    &GetTime, $time = 60*$min + $sec;
	    $time -= $prev;
	    ($time > 2) && &Log("SMTP DELAY[$time sec.]:$s");
	}
    }

    # rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
    $body =~ s/\n\./\n../g;	# enough for body ^. syntax
    $body =~ s/\.\.$/./g;	# trick the last "."

    # BODY INPUT
    print SMTPLOG "-------------\n";
    if ($_cf{'Smtp', 'readfile'}) { # For FILE INPUT
	print SMTPLOG $body;
	print S $body unless $debug0;
	while(<FILE>) { 
	    s/^\./../; 
	    print S $_ unless $debug0;
	    print SMTPLOG $_;
	};
	print SMTPLOG "-------------\n";
	print S ".\n" unless $debug0;
    } 
    else {			# $body has both header and body.
	print SMTPLOG "$body-------------\n";
	print S $body unless $debug0;
    }

    $s = "BODY";		#CONVENIENCE: infomation for errlog
    if (! $debug0) {
	do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
	while(/^\d\d\d\-/o);
    }
    $s = "QUIT";		#CONVENIENCE: infomation for errlog
    print S "QUIT\n" unless $debug0;
    print SMTPLOG "$s<INPUT\n";
    if (! $debug0) {
	do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
	while(/^\d\d\d\-/o);
    }

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

    if (open(FILE, $file) && ($SENDFILE_NO_FILECHECK ? 1 : -T $file)) { 
	;
    }
    elsif ((1 == $zcat) && 
	   $ZCAT && -r $file && open(FILE, "$ZCAT $file|")) {
	;
    }
    elsif ((2 == $zcat) 
	   && $ZCAT && -r $file && open(FILE, "$UUENCODE $file $enc|")) {
	;
    }
    else { 
	&Log("sub SendFile: no $file") if !-f $file;
	&Log("sub SendFile: binary?O.K.?: $file [zcat=$zcat]") 
	    if (!$zcat) && -B $file;
	&Log("sub SendFile: \$ZCAT not defined") unless $ZCAT; 	
	&Log("sub SendFile: cannot read $file")  unless -r $file;
	&Log("sub SendFile: must be cannot open $file") unless open(FILE, $file);
	return;
    }

    # trick for using smaller memory!
    $_cf{'Smtp', 'readfile'} = 1;
    ($host, $body, @headers) = &GenerateHeaders(*to, $subject);

    $Status = &Smtp($host, $body, @headers);
    &Log("SendFile:$Status") if $Status;
    undef $_cf{'Smtp', 'readfile'};

    close(FILE);
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
	print STDERR "from = $from\nto   = ".join(" ", @to)."\n";
	print STDERR "GenerateHeaders: missing from||to\n" if(! ($from && @to));
    }
    return if(! ($from && @to));

    @headers  = ("HELO $_Ds", 'MAIL FROM: '.$from);
    foreach (@to) {	
	push(@headers, 'RCPT TO: '.$_); 
	$to .= $to ? (', '.$_) : $_; # for header
    }
    push(@headers, 'DATA');

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
    $body .= $_cf{'header', 'MIME'} if $_cf{'header', 'MIME'};
    $body .= "\n";

    print STDERR "GenerateHeaders:($host\n-\n$body\n-\n\@headers);\n" if $debug;

    return ($host, $body, @headers);
}


########## libfml.pl
# Check the string contains Shell Meta Characters
# return 1 if match
sub MetaCharP
{
    local($r) = @_;

    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Log("Match: $r -> $`($&)$'");
	return 1;
    }

    0;
}


1;
