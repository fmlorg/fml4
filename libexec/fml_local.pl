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
    local($mail) = &WholeMail;

    # fix UNIX FROM if not exists.
    if (! ($mail =~ /^From\s+/i)) {
	&FmlLocal'GetTime;
	$mail = "From $USER $MailDate\n$mail";
    }

    # UMASK
    umask(077);

    # FLOCK paremeters
    $LOCK_SH = 1;
    $LOCK_EX = 2;
    $LOCK_NB = 4;
    $LOCK_UN = 8;

    # Do FLOCK
    flock(MBOX, $LOCK_EX);
    seek(MBOX, 0, 2);

    # APPEND!
    if ( open(MBOX, ">> $MAIL_SPOOL") ) {
	print MBOX &WholeMail;
    }
    elsif ( open(MBOX, ">> $HOME/dead.letter") ) {
	print MBOX &WholeMail;
    }
    else {
	&Log("Can't open mailbox: $!");
	return 0;
    }

    flock(MBOX, $LOCK_UN);
    close(MBOX);
}


sub MailProc
{
    local($type, $exec) = @_;

    if ($exec =~ /^mail\.local$/i) {
	&MailLocal;
    }

    if ($type =~ /^\|$/o) {
	open(EXEC,"|$exec");
	select(EXEC); $| = 1; 
	print EXEC &WholeMail;
	close(EXEC);
    }

    if ($type =~ /^>$/o) {
	open(EXEC,">> $exec");	# APPEND!
	select(EXEC); $| = 1; 
	print EXEC &WholeMail;
	close(EXEC);
    }

    if ($type =~ /^&$/o) {
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
    
    @VAR = (HOME, DIR, LIBDIR, FML_PL, USER, MAIL_SPOOL, LOG, 
	    PASSWORD, DEBUG, AND);

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

    open(CF, "< $INFILE") || die "FmlLocalReadCF:$!\n";
    CF: while(<CF>) {
	# Skip e.g. comments, null lines
	next CF if /^\s*$/o;
	next CF if /^\#/o;
	chop;

	# debug options
	$debug  = 1 if /^DEBUG/i;
	$debug2 = 1 if /^DEBUG2/i;
	
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

    # include ~/.vacationrc
    if (-f "$HOME/.vacationrc") {
	&FmlLocalReadCF("$HOME/.vacationrc");
    }

    1;
}


sub FmlLocalPatternMatch
{
    local($field, $pattern, $type, $exec, $pat);
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
	    ($field, $pattern, $type, $exec) = 
		($pat =~ /(\S+)\s+(\S+)\s+(\S+)\s+(.*)/);

	    next CF unless /$field/i;

	    # debug
	    print STDERR "($field, $pattern, $type, $exec)\n" if $debug;

	    # MATCHING PATTERN
	    if (/^$field:$/i && ($contents =~ /$pattern/)) {
		undef $TYPE, $EXEC, $F1, $F2, $F3;
		$TYPE = $type;
		$EXEC = $exec;
		$F1  = $1;
		$F2  = $2;
		$F3  = $3;
		undef $UNMATCH_P;

		if ($debug) {
		    print STDERR "MATCH\t$field =~ /$pattern/\n";
		    print STDERR "DO\t$TYPE$EXEC\n";
		    print STDERR "F1\t$F1\n" if $F1;
		    print STDERR "F2\t$F2\n" if $F2;
		    print STDERR "F3\t$F3\n" if $F3;
		}
	    }
	}# FOREACH;

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

    local(@MailBody) = split(/\n/, $MailBody);

    while(@MailBody) {
	  $_ = shift @MailBody;

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
	&MailLocal;
    }
    else {
	print STDERR "\n&MailProc($TYPE, $EXEC);\n\n" if $debug;
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


package FmlLocal;

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

1;
