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

&FmlLocalInitialize;		# preliminary

chdir $HOME || die("Cannot chdir \$HOME=$HOME\n"); # meaningless but for secure

&FmlLocalReadCF($CONFIG_FILE);	# set %VAR, %CF, %_cf
&FmlLocalGetEnv;		# set %ENV, $DIR, ...

chdir $DIR  || die("Cannot chdir \$DIR=$DIR\n");

&FmlLocalFixEnv;
&Parsing;			# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers

&FmlLocalSearch;		# pattern matching, and default set
&FmlLocalAdjustVariable;	# e.g. for $F1 ... and Reply-to: ...

&FmlLocalMainProc;		# calling the matched procedure && do default

exit 0;
################# LIBRALY ################# 



sub USAGE
{
    # Built in functions
    if (open(F, __FILE__)) {
	while(<F>) { 
	    /^\#\.USAGE:(.*)/ && ($USAGE_OF_BUILT_IN_FUNCTIONS .= "$1\n");
	}
	close(F);
    }

    # Variables
    foreach (@VAR) { 
	$VARIABLES .= " $_ ";
	$VARIABLES .= "\n" if (length($VARIABLES) % 65) < 3;
    }

    print STDERR <<"EOF";

$rcsid

USAGE: fml_local.pl [-Ddh] [-f config_file] [-user username]
    -h     this help
    -d     debug mode on
    -D     dump variable 
    -f     configuration file for \~/.fmllocalrc
    -user  usename

FILE:  \$HOME/.fmllocalrc

                  Please read FAQ for the details.

VARIABLES (set in \$HOME/.fmllocalrc):
$VARIABLES

BUILT-IN FUNCTIONS:
$USAGE_OF_BUILT_IN_FUNCTIONS

EXAMPLES for \~/.fmllocalrc
#field		pattern		type	exec

# "Subject: get filename"
# send \$ARCHIVE_DIR/filename to Reply-to: or From:
Subject    get\s+(\S+)            &       sendback

# MailBody is 
# "getmyspool password"
# send the owner's mailspool to the owner
body       getmyspool\s+(\S+)     &       getmyspool_pw

# Subject: guide
# send a \$ARCHIVE_DIR/guide to "From: address"
Subject    (guide)                  &       sendback

EOF

}


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
    if (open(MBOX, ">> $MAIL_SPOOL")) {
 	flock(MBOX, $LOCK_EX);
	seek(MBOX, 0, 2);
    }
    elsif (open(MBOX, ">> $HOME/mbox")) {
	flock(MBOX, $LOCK_EX);
	seek(MBOX, 0, 2);
    }
    elsif (open(MBOX, ">> $HOME/dead.letter")) {
	flock(MBOX, $LOCK_EX);
	seek(MBOX, 0, 2);
    }
    else {
	&Log("Can't open mailbox: $!");
	return 0;
    }

    # APPEND!
    &Log(">> $MAIL_SPOOL") if $debug;
    &Append2MBOX(0);

    # Unlock
    flock(MBOX, $LOCK_UN);
    close(MBOX);
}


sub Append2MBOX
{
    local($cut_unix_from) = 0;
    ($cut_unix_from) = @_;	# against "eval scalar of @_" context
    local(@s);

    # fflush()
    select(MBOX); $| = 1;

    ### Header
    @s = split(/\n/, $Envelope{'Header'});
    while(@s) {
	$_ = shift @s;
	next if (/^From /i && $cut_unix_from);

	print MBOX $_,"\n";
    }

    print MBOX "X-FML-LOCAL: ENFORCE MAIL.LOCAL\n";

    # separator between Header and Body
    print MBOX "\n";

    ### Body
    @s = split(/\n/, $Envelope{'Body'});
    while(@s) {
	$_ = shift @s;
	print MBOX ">" if /^From /i; # '>From'
	print MBOX $_,"\n";
    }

    # not newline terminated
    print MBOX "\n" unless $_ =~ /\n$/;

    # "\n"; allow empty message
    print MBOX "\n";
}


sub MailProc
{
    local($type, $exec) = @_;

    &Log("[$type]$exec") if $debug;

    # defaults
    if ($exec =~ /^mail\.local$/i) {
	&MailLocal || &Log($!);
    }

    # call "PERL" procedure
    elsif ($type =~ /^&$/o) { 
	# ($exec, @Fld) = split(/\s+/, $exec);
	(eval "&$exec();", $@ eq "") || &Log($@);
    }

    # cut unix from and PIPE OPEN
    elsif ($type =~ /^mh$/io) { 
	$exec .= " ". join(" ",@OPT);
	open(MBOX, "|-") || exec $exec || &Log($!);
    }

    # PIPE OPEN
    elsif ($type =~ /^\|$/o) { 
	$exec .= " ". join(" ",@OPT);
	open(MBOX, "|-") || exec $exec || &Log($!);
    }

    # APPEND!
    elsif ($type =~ /^>$/o) { 
	open(MBOX, ">>$exec") || &Log($!);
    }

    # GO! fflush() is done in sub Append2MBOX. 
    if ($type =~ /^mh$/i) {
	&Append2MBOX(1);
    }
    else {
	&Append2MBOX(0);
    }

    # CLOSE
    close(MBOX);
}


sub FmlLocalInitialize
{
    # DEFAULTS
    $UNMATCH_P = 1;
    $AUTH      = 0;
    $NOT_TRACE_SMTP = 1;
    $NOT_USE_UNIX_FROM_LOOP_CHECK = 1;
    $FS = '\s+';			# DEFAULT field separator
    $CONFIG_FILE = '';
    $_Ds = 'localhost';

    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)

    @VAR = (HOME, DIR, LIBDIR, FML_PL, USER, MAIL_SPOOL, LOG, TMP,
	    TMP_DIR, PASSWORD, DEBUG, AND, ARCHIVE_DIR, VACATION,
	    MAINTAINER, MAINTAINER_SIGNATURE, FS,
	    LOG_MESSAGE_ID,
	    MY_FUNCTIONS, CASE_INSENSITIVE, MAIL_LENGTH_LIMIT);

    # getopts
    while(@ARGV) {
	$_ =  shift @ARGV;
	/^\-user/ && ($USER = shift @ARGV) && next; 
	/^\-f/    && ($CONFIG_FILE = shift @ARGV) && next; 
	/^\-h/    && &USAGE && exit(0);
	/^\-d/    && $debug++;
	/^\-D/    && $DUMPVAR++;
    }

    # DEBUG
    if ($debug) {
	print STDERR "GETOPT:\n";
	print STDERR "\$USER\t$USER\n";
	print STDERR "\$CONFIG_FILE\t$CONFIG_FILE\n\n";
    }

    # a few variables
    $USER = $USER || (getpwuid($<))[0];
    $HOME = (getpwnam($USER))[7] || $ENV{'HOME'};
    $FML_LOCAL_RC = "$HOME/.fmllocalrc";
}


# %VAR
# %CF 
sub FmlLocalReadCF
{
    local($INFILE) = @_;
    local($entry)  = 0;

    $INFILE = $INFILE || $FML_LOCAL_RC;
    open(CF, "< $INFILE") || do {
	&Log("fail to open $INFILE");
	die "FmlLocalReadCF:$!\n";
    };

    ### make a pattern /$pat\s+(\S+)/
    foreach (@VAR) { 
	$pat .= $pat ? "|$_" : $_;

	# for FmlLocal_get and 
	# next CF if $VAR{$FIELD} in FmlLocalEntryMatch
	tr/A-Z/a-z/; # lower
	$VAR{$_} = 1;
    }
    $pat = "($pat)";

    # FOR ARRAY
    $array_pat = "(INC)";

    ### Special pattern /$sp_pat\s+(.*)/
    $sp_pat  = 'PASSWORD|MAINTAINER_SIGNATURE';
    $sp_pat .= 'TAR|UUENCODE|RM|CP|COMPRESS|ZCAT'; # system (.*) for "gzip -c"
    $sp_pat .= '|LHA|ISH'; # system (.*) for "gzip -c"
    $sp_pat  = "($sp_pat)";

    #### read config file
    CF: while(<CF>) {
	# Skip e.g. comments, null lines
	/^\s*$/o && $entry++ && next CF;
	next CF if /^\#/o;
	chop;

	# Set environment variables
	/^DEBUG/i && $debug++ && next CF;
	/^$sp_pat\s+(.*)/    && (eval "\$$1 = '$2';", $@ eq "") && next CF;
	/^$array_pat\s+(.*)/ && 
	    (eval "push(\@$1, '$2');", $@ eq "") && next CF;
	/^$pat\s+(\S+)/      && (eval "\$$1 = '$2';", $@ eq "") && next CF;

	# already must be NOT ENV VAR
	# AND OPERATION
	next CF if /^AND/i;
	$CF{$entry} .= $_."\n";

	# for later trick
	/^body/i && ($_cf{'has-body-pat'} = 1);
    }

    close(CF);

    # record the number of matched entry
    $_cf{'entry'} = $entry + 1;	# +1 is required for anti-symmetry
}


sub FmlLocalGetEnv
{
    # include ~/.fmllocalrc
    print STDERR $EVAL if $debug;

    $HOME = $HOME || (getpwnam($USER))[7] || 
	    $ENV{'HOME'} || $ENV{'LOGDIR'} || (getpwuid($<))[7] ||
		die("You are homeless!\n");

    $DIR         = $DIR         || $HOME;
    $LIBDIR      = $LIBDIR      || $DIR;
    $LOGFILE     = $LOG         || "$DIR/log";
    $ARCHIVE_DIR = $ARCHIVE_DIR || "$DIR/.archive";

    # Fix
    $USER = $USER || getlogin || (getpwuid($<))[0] || 
	die "Cannot define USER, exit\n";

    # Fix, after "chdir $DIR" 
    $TMP_DIR = $TMP_DIR || $TMP || "./tmp";
    $TMP_DIR =~ s/$DIR//g;
    &Log("TMP_DIR = $TMP_DIR") if $debug;

    if (! $MAIL_SPOOL) {
	for ("/var/mail", "/var/spool/mail", "/usr/spool/mail") {
	    $MAIL_SPOOL = "$_/$USER" if -r "$_/$USER";
	}
    }

    $VACATION_RC = $VACATION || "$HOME/.vacationrc";

    if (! $DOMAIN) {
	$DOMAIN = (gethostbyname('localhost'))[1];
	($DOMAIN)    = ($DOMAIN =~ /(\S+)\.$/i) if $DOMAIN =~ /\.$/i;
	($DOMAIN)    = ($DOMAIN =~ /localhost\.(\S+)/i); 
    }

    $MAINTAINER  = $MAINTAINER || $USER .'@'. $DOMAIN;
    
    # include ~/.vacationrc
    &FmlLocalReadCF($VACATION_RC) if -f $VACATION_RC;

    # logs message id against loopback
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$TMP_DIR/log.msgid";

    1;
}


# FIX TO BE FIXED AFTER CHDIR $DIR;
sub FmlLocalFixEnv
{
    -d $TMP_DIR || mkdir($TMP_DIR, 0700);
}


# Predicate whether match or not
# trick:
#      body is 'body:' field :-) 
# this makes the code simple
#
# if has no 3rd entry, NOT ILLEGAL
# it must be AND OPERATION, REQUIRE 'multiple matching'
#
sub FmlLocalMatch_and_Set
{
    local($s, $entry)   = @_;
    local($f, $p, $type, $exec, @opt);
    local($ok, $cnt);
    local(@pat) = split(/\n/, $s);

    # for multiple lines. the entry to match is within "one line"
    $* = 0;

    foreach $pat (@pat) {
	$cnt++;			# counter

	# field pattern type exec
	# ATTENTION! @OPT is GLOBAL
	($f, $p, $type, $exec, @opt) = split(/$FS/, $pat);
	print STDERR "  pat[$entry]:\t($f, $p, $type, $exec)\n";

	$f =~ tr/A-Z/a-z/;	# lower

	if ($Envelope{"$f:"} =~ /$p/ || 
	    ($CASE_INSENSITIVE && $Envelope{"$f:"} =~ /$p/)) {
	    print STDERR "MatchPat:\t[$f:$`($&)$']\n" if $debug;
	    &Log("Match [$f:$`($&)$']") if $debug;
	    $ok++;

	    # MULTIPLE MATCH
	    $type && ($ok == $cnt) && 
		&FmlLocalSetVar($type, $exec, $1, $2, $3);
	    $type && ($ok == $cnt) && (@OPT = @opt); # @opt eval may fail
	}

	($f =~ /^default/i) && ($_cf{'default'} = $pat);
    }
}


sub FmlLocalSearch
{
    local($i);

    # TRICK! deal MailBody like a body: field.
    # has-body-pat is against useless malloc 
    $Envelope{'body:'} = $Envelope{'Body'} if $_cf{'has-body-pat'};

    # try to match pattern in %entry(.fmllocalrc) and *Envelope{Hdr,Body}
    for($i = 0; $i < $_cf{'entry'}; $i++) {
	$_ = $CF{$i};
	next if /^\s*$/o;
	next if /^\#/o;

	&FmlLocalMatch_and_Set($_, $i);
    }
}


sub FmlLocalUnSetVar 
{ 
    ($package,$filename,$line) = caller;

    print STDERR "UNSET called from $line\n" if $debug;
    undef $TYPE, $EXEC, $F1, $F2, $F3;
    undef @OPT;
}


sub FmlLocalSetVar
{
    local($type, $exec, $f1, $f2, $f3) = @_;

    undef $TYPE, $EXEC, $F1, $F2, $F3;

    $TYPE = $type;
    $EXEC = $exec;
    $F1  = $f1;
    $F2  = $f2;
    $F3  = $f3;

    if ($debug) {
	print STDERR "\tDO\t$TYPE$EXEC\n";
	print STDERR "\tF1\t$F1\n" if $F1;
	print STDERR "\tF2\t$F2\n" if $F2;
	print STDERR "\tF3\t$F3\n" if $F3;
    }

    undef $UNMATCH_P;
}


sub FmlLocalReplace
{
    local($_) = @_;

    s/\$F1/$F1/g;
    s/\$F2/$F2/g;
    s/\$F3/$F3/g;
    s/\$From_address/$From_address/g;
    s/\$To_address/$To_address/g;
    s/\$Subject/$Subject/g;
    s/\$Reply_to/$Reply_to/g;
    s/\$HOME/$HOME/g;
    s/\$DIR/$DIR/g;
    s/\$LIBDIR/$LIBDIR/g;
    s/\$ARCHIVE_DIR/$ARCHIVE_DIR/g;
    s/\$TMP_DIR/$TMP_DIR/g;

    $_;
}

sub FmlLocalAdjustVariable
{
    # Headers
    $Reply_to              = $Envelope{'h:Reply-To:'};
    $Original_To_address   = $Envelope{'to:'};
    $To_address            = $Envelope{'to:'};
    $Original_From_address = $Envelope{'from:'};
    $Subject               = $Envelope{'subject:'};
    
    # variable expand
    $EXEC = &FmlLocalReplace($EXEC);
    for ($i = 0; $i < scalar(@OPT); $i++) {
	$OPT[$i] = &FmlLocalReplace($OPT[$i]);
    }

    1;
}


sub FmlLocalMainProc
{
    # SECURITY CHECK
    for $x ($F1, $F2, $F3) {
	if (&InSecureP($x)|| &MetaCharP($x)) {
	    &Log("INSECURE, hence STOP!");
	    return;
	}
    }
	    
    # Load user-defined-functions
    if (-f $MY_FUNCTIONS) {
	(eval "do '$MY_FUNCTIONS';", $@ eq "") || 
	    &Log("Cannot load $MY_FUNCTIONS");
    }

    # DEBUG OPTION
    if ($DUMPVAR) {
	require 'dumpvar.pl';
	&dumpvar('main');
    }

    # ENFORCE DROP TO THE MAIL SPOOL AGAINST INFINITE LOOP
    if (($Envelope{'x-fml-local:'} =~ /ENFORCE\s+MAIL.LOCAL/i)) {
	&Log("X-FML-LOCAL: ENFORCE mail.local") if $debug;
	&MailLocal;	
    }
    # IF UNMATCHED ANYWHERE, 
    # Default action equals to /usr/libexec/mail.local(4.4BSD)
    elsif ($UNMATCH_P) {
	print STDERR "\n&MailLocal;\n\n" if $debug;
	&Log("Default::mail.local") if $debug;
	&MailLocal;
    }
    else {
	if ($debug) {
	    $s  = "\n&MailProc($TYPE, $EXEC);\n";
	    $s .= "\twith F1=$F1 F2=$F2 F3=$F3\n"; 
	    $s .= "\twith \@OPT=(". join(" ", @OPT) .")\n";
	    print STDERR $s;
	}
	&Log("MailProc($TYPE, $EXEC)") if $debug;
	&MailProc($TYPE, $EXEC);
    }

    # default is "ALWAYS GO!"
    local($a, $b, $type, $exec);
    undef @OPT;
    ($a, $b, $type, $exec, @OPT) = split(/\s+/, $_cf{'default'});
    if ($type) {
	print STDERR "\n *** ALWAYS GO! *** \n" if $debug;
	&FmlLocalSetVar($type, $exec);
	&MailProc($TYPE, $EXEC);
    }
}


sub FmlLocalAppend2CF
{
    local($s) = @_;

    open(CF, ">> $FML_LOCAL_RC") || (return 'open fail ~/.fmllocalrc');
    select(CF); $| = 1;
    print CF "$s\n";
    close(CF);

    print CF "\n";

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


##################################################################
#:include: fml.pl
#:sub GetTime Parsing Expand_mailbox WholeMail eval Logging Log Append2
#:sub GetFieldsFromHeader Conv2mailbox Debug
#:sub Debug CheckMember AddressMatch Warn FieldsDebug use
#:sub Touch Write2
#:~sub
##################################################################
#:replace
sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}



# one pass to cut out the header and the body
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($nlines, $nclines);

    # Guide Request Check within in the first 3 lines
    $GUIDE_CHECK_LIMIT || ($GUIDE_CHECK_LIMIT = 3);
    
    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    $Envelope{'Header'} .= $_ unless /^$/o;
	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$Envelope{'req:guide'} = 1      if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	    }

	    # Command or not is checked within the first 3 lines.
	    # '# help\s*' is OK. '# guide"JAPANESE"' & '# JAPANESE' is NOT!
	    # BUT CANNOT JUDGE '# guide "JAPANESE CHARS"' SYNTAX;-);
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:uip'} = 'on'    if /^\#\s*\w+\s|^\#\s*\w+$/;
		$Envelope{'mode:uip:chaddr'}=$_ if /^\#\s*$CHADDR_KEYWORD\s+/i;
	    }

	    $Envelope{'Body'} .= $_; # save the body
	    $nlines++;               # the number of bodylines
	    $nclines++ if /^\#/o;    # the number of command lines
	}
    }# END OF WHILE LOOP;

    $Envelope{'nlines'}  = $nlines;
    $Envelope{'nclines'} = $nclines;
}


# Phase 2(2nd pass), extract several fields 
# Here is in 1.2-current the local rule to define header fileds.
# Original form  -> $Subject                 -> distributed mails
#                -> $Original_From_address   -> distributed mails(obsolete)
#                95/10/01 $Original_From_address == $Envelope{'h:from:'}
# parsed headers -> $Summary_Subject(a line) -> summary file
sub GetFieldsFromHeader
{
    $0 = "--GetFieldsFromHeader <$FML $LOCKFILE>";

    # Local Variables
    local($field, $contents, $skip_fields, $use_fields, *Hdr, $Message_Id, $u);

    ###### FORMER PART is just 'extraction'

    # IF WITHOUT UNIX FROM e.g. for slocal bug??? 
    if (! ($Envelope{'Header'} =~ /^From\s+\S+/i)) {
	$u = $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;
	$Envelope{'Header'} = "From $u $MailDate\n".$Envelope{'Header'};
    }

    # MIME
    $Envelope{'MIME'}= 1 if $Envelope{'Header'} =~ /ISO\-2022\-JP/o;

    # preliminary to get fields
    local($s) = $Envelope{'Header'}."\n";
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.
    
    ### PLEASE CUSTOMIZE BELOW FOR 'FIELDS TO SKIP'
    $skip_fields  = 'Received|Return-Path|X-MLServer|X-ML-Name|';
    $skip_fields .= 'X-Mail-Count|Precedence|Lines';
    $skip_fields .= $SKIP_FIELDS if $SKIP_FIELDS;

    ### PLEASE CUSTOMIZE BELOW FOR 'FIELDS TO USE IN DISTRIBUTION'
    $use_fields   = 'Date|Errors-to|Sender|Reply-to|To|Apparently-To|Cc|';
    $use_fields  .= 'Message-Id|Subject|From|';
    $use_fields  .= 'MIME-Version|Content-Type|Content-Transfer-Encoding';
    $use_fields  .= $USE_FIELDS if $USE_FIELDS;

    ### Parsing main routines
    for (@Hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {

	print STDERR "FIELD:          >$field<\n" if $debug;

        # UNIX FROM is a special case.
	# 1995/06/01 check UNIX FROM against loop and bounce
	/^from\s+(\S+)/io && ($Envelope{'UnixFrom'} = $Unix_From = $1, next);
	
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^\s*$/o;		# if null, skip. must be mistakes.

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/;
	$Envelope{$field} .= $contents;

	# Fields to skip. Please custumize $skip_fields above
	next if /^($skip_fields):/io;

	# filelds for later use. Please custumize $use_fields above
	$Envelope{"h:$field"} = $contents;
	next if /^($use_fields):/io;

	# hold fields without in use_fields if $SUPERFLUOUS_HEADERS is 1.
	$Envelope{'Hdr2add'} .= "$_ $contents\n" if $SUPERFLUOUS_HEADERS;
    }# FOR;



    ###### LATTER PART is to fix extracts

    ### Set variables
    $Envelope{'h:Return-Path:'} = "<$MAINTAINER>";        # needed?
    $Envelope{'h:Date:'}        = $Envelope{'h:date:'} || $Date;
    $Envelope{'h:From:'}        = $Envelope{'h:from:'};	  # original from
    $Envelope{'h:Sender:'}      = $Envelope{'h:sender:'}; # orignal
    $Envelope{'h:To:'}          = "$MAIL_LIST $ML_FN";    # rewrite TO:
    $Envelope{'h:Cc:'}          = $Envelope{'h:cc:'};     
    $Envelope{'h:Message-Id:'}  = $Envelope{'h:message-id:'}; 
    $Envelope{'h:Posted:'}      = $MailDate;
    $Envelope{'h:Precedence:'}  = $PRECEDENCE || 'list';
    $Envelope{'h:Lines:'}       = $Envelope{'nlines'};
    $Envelope{'h:Subject:'}     = $Envelope{'h:subject:'}; # anyway save

    # Some Fields need to "Extract the user@domain part"
    # $Envelope{'h:Reply-To:'} is "reply-to-user"@domain FORM
    $From_address            = &Conv2mailbox($Envelope{'h:from:'});
    $Envelope{'h:Reply-To:'} = &Conv2mailbox($Envelope{'h:reply-to:'});
    $Envelope{'Addr2Reply:'} = $Envelope{'h:Reply-To:'} || $From_address;

    # Subject:
    # 1. remove [Elena:id]
    # 2. while ( Re: Re: -> Re: ) 
    # Default: not remove multiple Re:'s),
    # which actions may be out of my business
    if (($_ = $Envelope{'h:Subject:'}) && $STRIP_BRACKETS) {
	local($r)  = 10;	# recursive limit against infinite loop

	# e.g. Subject: [Elena:003] E.. U so ...
	s/\[$BRACKET:\d+\]\s*//g;

	#'/gi' is required for RE: Re: re: format are available
	while (s/Re:\s*Re:\s*/Re: /gi && $r-- > 0) { ;}

	$Envelope{'h:Subject:'} = $_;
    } 

    # Obsolete Errors-to:, against e.g. BBS like a nifty
    if ($AGAINST_NIFTY) {
	$Envelope{'h:Errors-To:'} = $Envelope{'h:errors-to:'} || $MAINTAINER;
    }

    ### For CommandMode Check(see the main routine in this flie)
    $Envelope{'mode:chk'} = 
	$Envelope{'h:to:'} || $Envelope{'h:apparently-to:'};
    $Envelope{'mode:chk'} .= ", $Envelope{'h:Cc:'}, ";
    $Envelope{'mode:chk'} =~ s/\n(\s+)/$1/g;

    # Correction. $Envelope{'req:guide'} is used only for unknown ones.
    if ($Envelope{'req:guide'} && &CheckMember($From_address, $MEMBER_LIST)) {
	undef $Envelope{'req:guide'}, $Envelope{'mode:uip'} = 'on';
    }

    # Set Control-Address for reply, notify and message
    $Envelope{'Reply2:'} = $CONTROL_ADDRESS ? do {
	($CONTROL_ADDRESS =~ /\@/o) ? $CONTROL_ADDRESS :
	    "$CONTROL_ADDRESS\@".(split(/\@/, $MAIL_LIST))[1];
    } : $MAINTAINER;

    ### SUBJECT: GUIDE SYNTAX 
    if ($USE_SUBJECT_AS_COMMANDS) {
	($Envelope{'h:Subject'} =~ /^\#\s*$GUIDE_KEYWORD\s*$/i) && 
	    $Envelope{'req:guide'}++;
	$COMMAND_ONLY_SERVER &&	
	    ($Envelope{'h:Subject'} =~ /^\s*$GUIDE_KEYWORD\s*$/i) && 
		$Envelope{'req:guide'}++;
    }    
    

    ### DEBUG 
    $debug && &eval(&FieldsDebug, 'FieldsDebug');
    
    ###### LOOP CHECK PHASE 1
    ($Message_Id) = ($Envelope{'h:Message-Id:'} =~ /\s*\<(\S+)\>\s*/);

    if ($CHECK_MESSAGE_ID && &CheckMember($Message_Id, $LOG_MESSAGE_ID)) {
	&Log("WARNING: Message ID Loop");
	&Warn("WARNING: Message ID Loop", &WholeMail);
	exit 0;
    }

    # If O.K., record the Message-Id to the file $LOG_MESSAGE_ID);
    &Append2($Message_Id, $LOG_MESSAGE_ID);
    
    ###### LOOP CHECK PHASE 2
    # now before flock();
    if ((! $NOT_USE_UNIX_FROM_LOOP_CHECK) && 
	&AddressMatch($Unix_From, $MAINTAINER)) {
	&Log("WARNING: UNIX FROM Loop[$Unix_From == $MAINTAINER]");
	&Warn("WARNING: UNIX FROM Loop",
	      "UNIX FROM[$Unix_From] == MAINTAINER[$MAINTAINER]\n\n".
	      &WholeMail);
	exit 0;
    }
}



# Expand mailbox in RFC822
# From_address is user@domain syntax for e.g. member check, logging, commands
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
sub Conv2mailbox
{
    local($mb) = @_;

    # NULL is given, return NULL
    ($mb =~ /^\s*$/) && (return $NULL);

    # RFC822 unfolding
    $mb =~ s/\n(\s+)/$1/g;

    # Hayakawa Aoi <Aoi@aoi.chan.panic>
    ($mb =~ /^\s*.*\s*<(\S+)>.*$/io) && (return $1);

    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
    ($mb =~ /^\s*(\S+)\s*.*$/io)     && (return $1);

    # Aoi@aoi.chan.panic
    return $mb;
}	



# Recreation of the whole mail for error infomation
sub WholeMail { $Envelope{'Header'}."\n".$Envelope{'Body'};}


# CheckMember(address, file)
# return 1 if a given address is authentified as member's
#
# performance test example 1 (100 times for 158 entries)
# fastest case
# old 1.880u 0.160s 0:02.04 100.0% 74+34k 0+1io 0pf+0w
# new 1.160u 0.160s 0:01.39 94.9% 73+36k 0+1io 0pf+0w
# slowest case
# old 20.170u 1.520s 0:22.76 95.2% 74+34k 0+1io 0pf+0w
# new 9.050u  0.190s 0:09.90 93.3% 74+36k 0+1io 0pf+0w
#
# the actual performance is the average between values above 
# but the new version is stable performance
#
sub CheckMember
{
    local($address, $file) = @_;
    local($addr) = split(/\@/, $address);

    open(FILE, $file) || return 0;

  getline: while (<FILE>) {
      chop; 

      $ML_MEMBER_CHECK || do { /^\#\s*(.*)/ && ($_ = $1);};

      next getline if /^\#/o;	# strip comments
      next getline if /^\s*$/o; # skip null line
      /^\s*(\S+)\s*.*$/o && ($_ = $1); # including .*#.*

      # member nocheck(for nocheck but not add mode)
      # fixed by yasushi@pier.fuji-ric.co.jp 95/03/10
      # $ENCOUNTER_PLUS             by fukachan@phys 95/08
      # $Envelope{'mode:anyone:ok'} by fukachan@phys 95/10/04
      if (/^\+/o) { 
	  $Envelope{'mode:anyone:ok'} = 1;
	  close(FILE); 
	  return 1;
      }

      # for high performance
      next getline unless /^$addr/i;

      # This searching algorithm must require about N/2, not tuned,
      if (1 == &AddressMatch($_, $address)) {
	  close(FILE);
	  return 1;
      }
  }# end of while loop;

    close(FILE);
    return 0;
}


# sub AddressMatching($addr1, $addr2)
# return 1 given addresses are matched at the accuracy of 4 fields
sub AddressMatching { &AddressMatch(@_);}
sub AddressMatch
{
    local($addr1, $addr2) = @_;

    # canonicalize to lower case
    $addr1 =~ y/A-Z/a-z/;
    $addr2 =~ y/A-Z/a-z/;

    # try exact match. must return here in a lot of cases.
    if ($addr1 eq $addr2) {
	&Debug("\tAddr::match { Exact Match;}") if $debug;
	return 1;
    }

    # for further investigation, parse account and host
    local($acct1, $addr1) = split(/@/, $addr1);
    local($acct2, $addr2) = split(/@/, $addr2);

    # At first, account is the same or not?;    
    if ($acct1 ne $acct2) { return 0;}

    # Get an array "jp.ac.titech.phys" for "fukachan@phys.titech.ac.jp"
    local(@d1) = reverse split(/\./, $addr1);
    local(@d2) = reverse split(/\./, $addr2);

    # Check only "jp.ac.titech" part( = 3)(default)
    # If you like to strict the address check, 
    # change $ADDR_CHECK_MAX = e.g. 4, 5 ...
    local($i);
    while ($d1[$i] && $d2[$i] && ($d1[$i] eq $d2[$i])) { $i++;}

    &Debug("\tAddr::match { $i >= ($ADDR_CHECK_MAX || 3);}") if $debug;

    ($i >= ($ADDR_CHECK_MAX || 3));
}



# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub LogWEnv { local($s, *e) = @_; &Log($s); $e{'message'} .= "$s\n";}
sub Log { 
    local($str, $s) = @_;
    local($package,$filename,$line) = caller; # called from where?
    local($status);

    &GetTime;
    $str =~ s/\015\012$//;	# FIX for SMTP
    $str = "$filename:$line% $str" if $debug_log;

    &Append2("$Now $str ($From_address)", $LOGFILE, 0, 1);
    &Append2("$Now    $filename:$line% $s", $LOGFILE, 0, 1) if $s;
}


# append $s >> $file
# $w   if 1 { open "w"} else { open "a"}(DEFAULT)
# $nor "set $nor"(NOReturn)
# if called from &Log and fails, must be occur an infinite loop. set $nor
# return NONE
sub Append2
{
    local($s, $f, $w, $nor) = @_;

    if (! open(APP, $w ? "> $f": ">> $f")) {
	local($r) = -f $f ? "cannot open $f" : "$f not exists";
	$nor ? (print STDERR "$r\n") : &Log($r);
	return $NULL;
    }
    select(APP); $| = 1; select(STDOUT);
    print APP $s . ($nonl ? "" : "\n") if $s;
    close(APP);

    1;
}


sub Touch  { &Append2("", @_, 1);}


sub Write2 { &Append2(@_, 1);}


# Warning to Maintainer
sub Warn { &Sendmail($MAINTAINER, $_[0], $_[1]);}


# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    &CompatFML15_Post if $COMPAT_FML15;

    $@ ? (&Log("$_[1]:$@"), 0) : 1;
}


# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
Mailing List:        $MAIL_LIST
UNIX FROM:           $Envelope{'UnixFrom'}
From(Original):      $Envelope{'from:'}
From_address:        $Envelope{'h:From:'}
Original Subject:    $Envelope{'subject:'}
To:                  $Envelope{'mode:chk'}
Reply-To:            $Envelope{'h:Reply-To:'}

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip:              $Envelope{'mode:uip'}

Another Header:     >$Envelope{'Hdr2add'}<
	
LOAD_LIBRARY:        $LOAD_LIBRARY

"#;

"print STDERR $s";
}


sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $message_debug;
}


sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $message_debug;
}



1;
#:~replace
##################################################################
#:include: libsmtp.pl all
#:~sub
##################################################################
#:replace
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)


$rcsid .= " :smtp[1.6.1.2]";


##### local scope in Calss:Smtp #####
local($SMTP_TIME); 
local($SENDMAIL) = $SENDMAIL || "/usr/lib/sendmail -bs ";


# sys/socket.ph is O.K.?
sub SmtpInit
{
    local(*e, *rcpt, *smtp) = @_;

    # IF NOT SPECIFIED, [IPC]
    $e{'mci:mailer'} = $e{'mci:mailer'} || 'ipc';

    @smtp = ("HELO $e{'macro:s'}", "MAIL FROM: $MAINTAINER");

    # Set Defaults (must be "in $DIR" NOW)
    $SMTP_TIME = time() if $TRACE_SMTP_DELAY;
    $SMTP_LOG0  = $SMTP_LOG0  || "_smtplog"; # Backward compatibility;
    $SMTP_LOG   = $SMTP_LOG   || "$VARLOG_DIR/_smtplog";

    # LOG: on IPC
    # Recovery for the universal use
    if ($NOT_TRACE_SMTP) {
	$SMTP_LOG = '/dev/null';
    }
    elsif (!defined($VAR_DIR) || !defined($VARLOG_DIR)) {
	$SMTP_LOG = -e '/dev/stderr' ? '/dev/stderr': '/dev/null';
    }
    else {
	(-d $VAR_DIR)    || mkdir($VAR_DIR, 0700);
	(-d $VARLOG_DIR) || mkdir($VARLOG_DIR, 0700);

	if (! -l $SMTP_LOG0) {
	    $symlink_exists = (eval 'symlink("", "");', $@ eq "");
	    unlink $SMTP_LOG0;

	    # When link cut $DIR 
	    # but absolute link is required for e.g. ftp..
	    if ($symlink_exists) {
		local($pwd);
		chop( $pwd = `pwd` );
		$SMTP_LOG  =~ s/$DIR/\./g; $SMTP_LOG0 =~ s/$DIR/\./g; 

		chdir $DIR if $DIR ne $pwd; # chdir ML's HOME;
		$symlink_exists && symlink($SMTP_LOG, $SMTP_LOG0);
		chdir $pwd if $DIR ne $pwd; # return the original directory;

		&Log("ln -s $SMTP_LOG $SMTP_LOG0");
	    }
	    else {# already unlinked above;
		&Log("unlink $SMTP_LOG0, log -> $SMTP_LOG");
	    }
	}
    }

    return &SocketInit;
}


sub SocketInit
{
    ##### PERL 5  
    local($eval, $ok);
    if ($_cf{'perlversion'} == 5) { 
	eval "use Socket;", ($ok = $@ eq "");
	&Log($ok ? "Socket O.K.": "Socket fails. Try socket.ph") if $debug;
	return 1 if $ok;
    }

    ##### PERL 4
    local($ExistSocket_ph) = eval("require 'sys/socket.ph';"), ($@ eq "");
    &Log("sys/socket.ph is O.K.") if $ExistSocket_ph && $debug;

    if ((! $ExistSocket_ph) && $COMPAT_SOLARIS2) {
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
    }
    elsif (! $ExistSocket_ph) {	# 4.4BSD
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
    }
}



# delete logging errlog file and return error strings.
sub Smtp 
{
    local(*e, *rcpt) = @_;
    local($pat)  = 'S n a4 x8'; # 'S n C4 x8'? which is correct? 
    local($time, *smtp);

    ### Initialize, e.g. use Socket, sys/socket.ph ...
    &SmtpInit(*e, *rcpt, *smtp);
    
    ### open LOG;
    open(SMTPLOG, "> $SMTP_LOG") || (return "Cannot open $SMTP_LOG");

    ### IPC 
    if ($e{'mci:mailer'} eq 'ipc') {
	local($addrs) = (gethostbyname($HOST || 'localhost'))[4];
	local($proto) = (getprotobyname('tcp'))[2];
	local($port)  = (getservbyname('smtp', 'tcp'))[2];

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
    }
    ### not IPC, try popen(sendmail) ...
    elsif($e{'mci:mailer'} eq 'prog') {
	&Log("open2") if $debug;
	require 'open2.pl';
	&open2(OUT, S, $SENDMAIL) || return "Cannot exec $SENDMAIL";
    }

    ### need flush of sockect <S>;
    select(S);       $| = 1; select(STDOUT);
    select(SMTPLOG); $| = 1; select(STDOUT);

    ### Do talk with sendmail via smtp connection
    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    foreach $s (@smtp, @rcpt, 'DATA') {
	$0 = "-- $s <$FML $LOCKFILE>";

	print SMTPLOG ($s . "<INPUT\n");
	print S ($s . "\n");
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

	# Approximately correct :-)
	if ($TRACE_SMTP_DELAY) {
	    $time = time() - $SMTP_TIME;
	    $SMTP_TIME = time();
	    &Log("SMTP DELAY[$time sec.]:$s") if $time > $TRACE_SMTP_DELAY;
	}
    }
    ### (HELO .. DATA) sequence ends



    ### BODY INPUT
    # putheader()
    $0 = "-- BODY <$FML $LOCKFILE>";
    print SMTPLOG ('-' x 30)."\n";
    print SMTPLOG $e{'Hdr'}."\n";
    print S $e{'Hdr'}."\n";	# "\n" == separator between body and header;

    # Preamble
    if ( (! $e{'mode:dist'}) && $e{'preamble'}) {
	$e{'preamble'} =~ s/\n\./\n../g;
	$e{'preamble'} =~ s/\.\.$/./g;
	print SMTPLOG $e{'preamble'};
	print S       $e{'preamble'};
    }

    # putfile
    if ($e{'file'}) { 
	while(<FILE>) { 
	    s/^\./../; 
	    &jcode'convert(*_, 'jis') if $AutoConv;#';
	    print S $_;
	    print SMTPLOG $_;
	};
	print S "\n" if (!/\n$/); # fix the lost '\012'
    } 
    # ON MEMORY
    else {
	# rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
	$e{'Body'} =~ s/\n\./\n../g;               # enough for body ^. syntax
	$e{'Body'} =~ s/\.\.$/./g;	           # trick the last "."
	$e{'Body'} .= "\n" unless $e{'Body'} =~ /\n$/o;	# without the last "\n"
	print SMTPLOG $e{'Body'};
	print S       $e{'Body'};
    }

    # Trailer
    if ( (! $e{'mode:dist'}) && $e{'trailer'}) {
	$e{'trailer'} =~ s/\n\./\n../g;
	$e{'trailer'} =~ s/\.\.$/./g;
	print SMTPLOG $e{'trailer'};
	print S       $e{'trailer'};
    }

    # close smtp with '.'
    print SMTPLOG ('-' x 30)."\n";
    print S ".\n";
    $s = "BODY";		#CONVENIENCE: infomation for errlog
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    ### close connection 
    $s = "QUIT";		#CONVENIENCE: infomation for errlog
    $0 = "-- $s <$FML $LOCKFILE>";

    print S "$s\n";
    print SMTPLOG "$s<INPUT\n";
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    close S; 
    close SMTPLOG;

    0; # return status
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub SendFile
{
    local(*to, *e, *rcpt);
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

    ### check again $file existence
    if (! -f $file) {
	local(@info) = caller;
	&Log("sub SendFile: $file is not found.", "[ @info ]");
	&Warn("ERROR in SendFile", "$file is not found.\n[ @info ]\n");
	$file =~ s/$DIR/\$DIR/;
	$Envelope{'message'} .= "Sorry.\nError SendFile: $file is not found.";
	return $NULL;
    }

    ### AUTO CONVERSION 
    $ExistJcode = eval "require 'jcode.pl';", $@ eq "";

    # $SENDFILE_NO_FILECHECK ? 1 : -T $file;
    if (open(FILE, $file) && ($SENDFILE_NO_FILECHECK || $ExistJcode)) {
	if (-T $file) {
	    ;
	} 
	elsif (-B $file && $ExistJcode) {
	    &Log("sub SendFile: $file == NOT JIS ? Try Auto Code Conversion");
	    $AutoConv = 1;
	}
	elsif (-B $file) {
	    &Log("ERROR: sub SendFile: $file == NOT JIS ?");
	}
    }
    elsif ((1 == $zcat) && 
	   $ZCAT && -r $file && 
	   (open(FILE,"-|") || exec $ZCAT, $file)) {
	;
    }
    elsif ((2 == $zcat) 
	   && $ZCAT && -r $file && 
	   (open(FILE,"-|") || exec $UUENCODE, $file, $enc)) {
	;
    }
    else { 
	&Log("sub SendFile: no $file") if !-f $file;
	&Log("sub SendFile: binary? or just NOT JIS?: $file [zcat=$zcat]") 
	    if (!$zcat) && -B $file;
	&Log("sub SendFile: \$ZCAT not defined") unless $ZCAT; 	
	&Log("sub SendFile: cannot read $file")  unless -r $file;
	&Log("sub SendFile: must be cannot open $file") unless open(FILE, $file);
	return;
    }


    $e{'file'} = 1;    # trick for using smaller memory!
    $e{'subject:'} = $subject;
    &GenerateHeaders(*to, *e, *rcpt);

    $e = &Smtp(*e, *rcpt);
    &Log("SendFile:$e") if $e;
    undef $_cf{'Smtp', 'readfile'};

    close(FILE);
}


# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local(*to, *e, *rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeaders

    $e{'subject:'} = $subject;
    &GenerateHeaders(*to, *e, *rcpt);
    
    $e{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $e{'Body'}     .= $body;
    $e{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $e = &Smtp(*e, *rcpt);
    &Log("Sendmail:$e") if $e;
}


# Generating Headers, and SMTP array
sub GenerateMail { &GenerateHeaders(@_);}
sub GenerateHeaders
{
    # old format == local(*to, $subject) 
    local(*to, *e, *rcpt) = @_;
    local($from) = $MAINTAINER ? $MAINTAINER : (getpwuid($<))[0];

    undef $to;			# required 

    if ($debug) {
	print STDERR "from = $from\nto   = ".join(" ", @to)."\n";
	print STDERR "GenerateHeaders: missing from||to\n" if(! ($from && @to));
    }
    return unless ($from && @to);

    foreach (@to) {	
	push(@rcpt, "RCPT TO: $_"); 
	$to .= $to ? (', '.$_) : $_; # a, b, c format
    }

    # fix by *Envelope
    $e{'macro:s'}    = $Envelope{'macro:s'};
    $e{'mci:mailer'} = $Envelope{'mci:mailer'};

    # the order below is recommended in RFC822 
    $e{'Hdr'} .= "Date: $MailDate\n";

    # From
    $e{'Hdr'} .= "From: $from";
    $e{'Hdr'} .= " ($MAINTAINER_SIGNATURE)" if $MAINTAINER_SIGNATURE;
    $e{'Hdr'} .= "\n";

    $e{'Hdr'} .= "Subject: $e{'subject:'}\n" if $e{'subject:'};
    $e{'Hdr'} .= "To: $to\n";
    $e{'Hdr'} .= 
	"Reply-to: $Envelope{'h:Reply-To:'}\n" if $Envelope{'h:Reply-To:'};

    # MIME (see RFC1521)
    $e{'Hdr'} .= $_cf{'header', 'MIME'} if $_cf{'header', 'MIME'};

    # ML info
    $e{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
}

1;
#:~replace
##################################################################
#:include: libfml.pl
#:sub InSecureP MetaCharP
#:~sub
##################################################################
#:replace
# the syntax is insecure or not
# return 1 if insecure 
sub InSecureP
{
    local($ID) = @_;
    if ($ID =~ /..\//o || $ID =~ /\`/o){ 
	local($s)  = "INSECURE and ATTACKED WARNING";
	local($ss) = "Match: $ID  -> $`($&)$'";
	&Log($s, $ss);
	&Warn("Insecure $ID from $From_address. $ML_FN", 
	      "$s\n$ss\n".('-' x 30)."\n". &WholeMail);
	return 1;
    }

    0;
}



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
#:~replace
############################################################
############################################################
############################################################
##### Built-In Functions

#.USAGE: sendback
#.USAGE:     内部定義関数としては &sendback(ファイル) は
#.USAGE:     ファイル を送り返します
#.USAGE:     引数なしに sendback を使うと
#.USAGE:        e.g. .fmllocalrc で from uja & sendback
#.USAGE:     正規表現でマッチした第一フィールドのファイルを送り返す
#.USAGE:     .fmllocalrcの例:
#.USAGE:     subject get (\S+) & sendback
#.USAGE: 
sub sendback
{
    local($file, $fullpath) = @_;
    $file = $file || $F1;
    local($to)   = $Reply_to ? $Reply_to : $From_address;
    local($ok)   = 1;
    local($dir)  = $ARCHIVE_DIR;

    if (! $fullpath) {
	chdir $dir || (&Log("cannot chdir $dir, STOP!"), undef $ok);
    }
    elsif ($fullpath) {
	undef $dir;
    }

    if ($ok && -f $file) {
	&Log("sendback $dir/$file");
	&SendFile($to, "Send $file", $file);
    }
    else {
	$s  = "I cannot find $file\n\n";
	$s .= "If you have a problem\n";
	$s .= "please make a contact with $MAINTAINER\n";
	&Sendmail($to, "Cannot find $file", $s);
	&Log("cannot find $dir/$file");
    }

    1;
}


#.USAGE: getmyspool_nopasswd
#.USAGE:     メールスプールを送り返します
#.USAGE:     パスワードは必要ありません。
#.USAGE:     内部定義関数として使うべきです
#.USAGE: 
sub getmyspool_nopasswd
{
    undef $F1,$F2,$F2;
    &Log("getmyspool");
    &sendback($MAIL_SPOOL, 1);
}


#.USAGE: getmyspool 
#.USAGE:     メールスプールを送り返します
#.USAGE:     正規表現でマッチした第一フィールドをパスワードとして認証します
#.USAGE:     認証した場合 送り返します。
#.USAGE:    .fmllocalrcの例:
#.USAGE:    body get my spool (\.*) & getmyspool
#.USAGE:
sub getmyspool
{
    if ($F1 eq $PASSWORD) {
	&getmyspool_nopasswd;
    }
    else {
	&Log("ILLEGAL PASSWORD [$F1] != [$PASSWORD]");
    }
}

#.USAGE: getmyspool2
#.USAGE:     メールスプールを送り返します
#.USAGE:     正規表現でマッチした
#.USAGE:            第１フィールドをパスワードとして認証します
#.USAGE:            第２フィールドを配送のモードとして使います。
#.USAGE:            第２フィールドがないときはspoolのファイルの形のままです。
#.USAGE:    
#.USAGE:    .fmllocalrcの例:
#.USAGE:    body getmyspool\s+(\S+)\s+(.*) & getmyspool2
#.USAGE:    body getmyspool password mode & getmyspool2
#.USAGE:    
#.USAGE:    e.g.
#.USAGE:    eecho getmyspool password uf |Mail (大学|会社)のアドレス 
#.USAGE: 
#.USAGE:    使えるモード(第２フィールド)は
#.USAGE:                指定しないときは uf に設定
#.USAGE: 	uf	PLAINTEXT(UNIX FROM)
#.USAGE:    	tgz	tar+gzip で spool.tar.gz
#.USAGE: 	gz	GZIP(UNIX FROM)
#.USAGE: 	b	lha + ish 
#.USAGE: 	ish	lha + ish 
#.USAGE: 	rfc934	RFC934 format 	PLAINTEXT
#.USAGE: 	unpack	PLAINTEXT(UNIX FROM)
#.USAGE: 	uu	UUENCODE
#.USAGE: 	d	RFC1153 format 	PLAINTEXT
#.USAGE: 	rfc1153	RFC1153 format 	PLAINTEXT
#.USAGE: 
#.USAGE:     ＊＊＊注意＊＊＊
#.USAGE:     libutils.pl を使うので、このファイルのDirectoryを
#.USAGE:     .fmllocalrc で 
#.USAGE:     INC Directory 
#.USAGE:     のように書いてください（INC=include-path）
#.USAGE: 
#.USAGE:     それから、圧縮等のためにはシステムのコマンドを使います。
#.USAGE:     fml本体ではインストールプログラムが自動的に探しますが、
#.USAGE:     fml_local のみを使う場合はこれらの設定をしてください。
#.USAGE: 
#.USAGE:     例: .fmllocalrc に COMPRESS /usr/local/bin/gzip -c
#.USAGE:         のようにです。
#.USAGE: 
#.USAGE:	$TAR		= "/usr/local/bin/tar cf -";
#.USAGE:	$UUENCODE	= "/bin/uuencode";
#.USAGE:	$RM		= "/sbin/rm -fr";
#.USAGE:	$CP		= "/bin/cp";
#.USAGE:	$COMPRESS	= "/usr/local/bin/gzip -c";
#.USAGE:	$ZCAT		= "/usr/local/bin/zcat";
#.USAGE: 
#.USAGE:    ＊自分で自動的に探すようにもできるけど危険だからしない
#.USAGE: 
sub getmyspool2
{
    umask(077);		       
    require 'libutils.pl';

    local($d, $mode, $tmpf, $tmps, $to);

    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 2850;

    $mode       = $F2 || 'uf';
    ($d, $mode) = &ModeLookup("3$mode");
    $to         = $Envelope{'Addr2Reply:'};

    # ($f, $mode, $subject, @to)
    &SendFilebySplit($MAIL_SPOOL, $mode, 'getmyspool2', $to);
}



#.USAGE: forward
#.USAGE:     メールを特定のアドレスへフォワードする
#.USAGE:     アドレスは forward の後に空白で続けて 
#.USAGE:     \@OPT の中に入ってます。
#.USAGE:     簡単なメーリングリストですね
#.USAGE:    .fmllocalrcの例:
#.USAGE:    To (uja) & forward address-1 address-2 ..
#.USAGE:        or
#.USAGE:    file の中にアドレスが書いてある（一行一アドレス）場合
#.USAGE:    To (uja) & forward :include:file
#.USAGE: 
sub forward
{
    local($host) = 'localhost';
    local($body, *Rcpt, $status);
    &Log("Forward");

    # :include: form
    if ($OPT[0] =~ /^:include:(\S+)/) {
	$file = $1;
	undef @OPT;
	open(F, $file) || (&Log("cannot open $file"), return);
	while (<F>) {
	    chop;
	    next line if /^\#/o;	# skip comment and off member
	    next line if /^\s*$/o;	# skip null line
	    push(@OPT, $_);	    
	}
	close(F);
    }

    &GetTime;

    for ('Return-Path', 'Date', 'From', 'Subject', 'Sender', 'To', 
	 'Errors-To', 'Cc', 'Reply-To', 'Posted') {
	$Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
    }

    $Envelope{'Hdr'} .= "X-FML-LOCAL: ENFORCE MAIL.LOCAL\n";
    $Envelope{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
    $Envelope{'Hdr'} .= "Precedence: ".($PRECEDENCE || 'list')."\n"; 

    foreach $rcpt (@OPT) {
	push(@Rcpt, "RCPT TO: $rcpt");
    }

    $status = &Smtp(*Envelope, *Rcpt);
    &Log("Sendmail:$status") if $status;
}

#.USAGE: discard
#.USAGE:   何もしない。ダミー関数 ＝＝ 入力を捨てる関数ともいう
#.USAGE:    .fmllocalrcの例:
#.USAGE:    From    (uja)      & discard
#.USAGE:    要するに
#.USAGE:    From    (uja)      > /dev/null
#.USAGE:    と同じですね〜
#.USAGE: 
sub discard{ 1;}

#.USAGE: 
#.USAGE: ALIASES:
#.USAGE: getback       は sendback と同じ
#.USAGE: 
sub getback { &sendback(@_);}

#.USAGE: getmyspool_pw は getmyspool と同じ
#.USAGE: 
sub getmyspool_pw { &getmyspool(@_);}






1;
