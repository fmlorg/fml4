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

&FmlLocalInitilize;		# preliminary

chdir $HOME || die("Cannot chdir \$HOME=$OME\n"); # meaningless but for secure

&FmlLocalReadCF($CONFIG_FILE);	# set %VAR, %CF, %_cf
&FmlLocalGetEnv;		# set ENV vars, $DIR, ...

&Parsing;			# Get $MailHeaders and $MailBody
&FmlLocalGetFields;		# set %FIELD

&FmlLocalSearch;		# pattern matching, and default set
&FmlLocalAdjustVariable;		# e.g. for $F1 ... and Reply-to: ...

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
    @s = split(/\n/, $MailHeaders);
    while(@s) {
	$_ = shift @s;
	next if (/^From /i && $cut_unix_from);

	print MBOX $_,"\n";
    }

    print MBOX "X-FML-LOCAL: ENFORCE MAIL.LOCAL\n";

    # separator between Header and Body
    print MBOX "\n";

    ### Body
    @s = split(/\n/, $MailBody);
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


sub FmlLocalInitilize
{
    # DEFAULTS
    $UNMATCH_P = 1;
    $AUTH      = 0;
    $NOT_TRACE_SMTP = 1;
    $FS = '\s+';			# DEFAULT field separator
    $CONFIG_FILE = '';
    $_Ds = 'localhost';

    @VAR = (HOME, DIR, LIBDIR, FML_PL, USER, MAIL_SPOOL, LOG, 
	    PASSWORD, DEBUG, AND, ARCHIVE_DIR, VACATION,
	    MAINTAINER, MAINTAINER_SIGNATURE, FS,
	    MY_FUNCTIONS, CASE_INSENSITIVE);

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

    ### Special pattern /$sp_pat\s+(.*)/
    $sp_pat = '(PASSWORD|MAINTAINER_SIGNATURE)';

    #### read config file
    CF: while(<CF>) {
	# Skip e.g. comments, null lines
	/^\s*$/o && $entry++ && next CF;
	next CF if /^\#/o;
	chop;

	# Set environment variables
	/^DEBUG/i && $debug++ && next CF;
	/^$sp_pat\s+(.*)/ && (eval "\$$1 = '$2';", $@ eq "") && next CF;
	/^$pat\s+(\S+)/   && (eval "\$$1 = '$2';", $@ eq "") && next CF;

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

    $DIR     = $DIR    || $HOME;
    $LIBDIR  = $LIBDIR || $DIR;
    $LOGFILE = $LOG    || "$DIR/log";
    $ARCHIVE_DIR = $ARCHIVE_DIR || "$DIR/.archive";
    
    $FML_PL = $FML_PL || 
	(-f "$LIBDIR/fml.pl" && "$LIBDIR/fml.pl") ||
	    (-f "$DIR/fml.pl" && "$DIR/fml.pl") ||
		(-f "$ENV{'FML'}/fml.pl" && "$ENV{'FML'}/fml.pl") ||
		    ($NOT_EXIST_FML_PL = 1);

    $USER   = $USER || getlogin || (getpwuid($<))[0] || 
	die "USER not defined\n";

    $MAIL_SPOOL = $MAIL_SPOOL || 
	(-r "/var/mail/$USER"       && "/var/mail/$USER") ||
	    (-r "/var/spool/mail/$USER" && "/var/spool/mail/$USER") ||
		(-r "/usr/spool/mail/$USER" && "/usr/spool/mail/$USER");

    $VACATION_RC = $VACATION   || "$HOME/.vacationrc";

    if (! $DOMAIN) {
	$DOMAIN = (gethostbyname('localhost'))[1];
	($DOMAIN)    = ($DOMAIN =~ /(\S+)\.$/i) if $DOMAIN =~ /\.$/i;
	($DOMAIN)    = ($DOMAIN =~ /localhost\.(\S+)/i); 
    }

    $MAINTAINER  = $MAINTAINER || $USER .'@'. $DOMAIN;
    
    # include ~/.vacationrc
    &FmlLocalReadCF($VACATION_RC) if -f $VACATION_RC;

    1;
}


# $FIELD{$_} = $contents;
sub FmlLocalGetFields
{
    # IF WITHOUT UNIX FROM e.g. for slocal bug??? 
    if (! ($MailHeaders =~ /^From\s+\S+/i)) {
	$MailHeaders = "From $USER $MailDate\n".$MailHeaders;
    }

    local($s) = $MailHeaders;
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g;
    local(@MailHeaders) = split(/\n\n/, $s, 999);

    while (@MailHeaders) {
	$_ = shift @MailHeaders;
	next if /^\s*$/;

        # UNIX FROM is a special case.
	# 1995/06/01 check UNIX FROM LoopBack
	if (/^from\s+(\S+)/io) {
	    $Unix_From = $1;
	    next;
	}

	$contents = shift @MailHeaders;
	$contents =~ s/^\s+//; # cut the first spaces of the contents.

	next if /^\s*$/o;	# if null, skip. must be mistakes.

	tr/A-Z/a-z/;		# lower
	$FIELD{$_} = $contents;
    }# WHILE @MAILHAEDERS;

    # TRICK! deal MailBody like a body: field.
    # has-body-pat is against useless malloc 
    $FIELD{'body:'} = $MailBody if $_cf{'has-body-pat'};
    
    if ($debug) {
	while (($key, $value) = each %FIELD) {
	    print STDERR "[$key]=[$value]\n";
	}
    }
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

	if ($FIELD{"$f:"} =~ /$p/ || 
	    ($CASE_INSENSITIVE && $FIELD{"$f:"} =~ /$p/)) {
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

    $_;
}

sub FmlLocalAdjustVariable
{
    # Headers
    $Reply_to              = &Expand_mailbox($FIELD{'reply-to:'});
    $Original_To_address   = $To_address 
	                   = $FIELD{'to:'};
    $Original_From_address = $FIELD{'from:'};
    $From_address          = &Expand_mailbox($FIELD{'from:'});

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
    if (($FIELD{'x-fml-local:'} =~ /ENFORCE\s+MAIL.LOCAL/i)) {
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

# one pass to cut out the header and the body
sub Parsing
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";

    # Guide Request Check within in the first 3 lines
    $GUIDE_CHECK_LIMIT || ($GUIDE_CHECK_LIMIT = 3);
    
    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    if (/^$/o) { #required for split(tricky)
		$MailHeaders .= "\n";
		next;
	    } 

	    $MailHeaders .= $_;

	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$GUIDE_REQUEST = 1 if /\#\s*guide\s*$/io;
	    }

	    # Command or not is checked within the first 3 lines.
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$CommandMode = 'on' if /^\#/o;
	    }

	    $MailBody .= $_;
	    $BodyLines++;
	    $_cf{'cl'}++ if /^\#/o; # the number of command lines 
	}
    }# END OF WHILE LOOP;
}

# Expand mailbox in RFC822
# From_address is modified for e.g. member check, logging, commands
# Original_From_address is preserved.
# return "1#mailbox" form ?(anyway return "1#1mailbox" 95/6/14)
sub Expand_mailbox
{
    local($mb) = @_;

    $mb =~ s/\n(\s+)/$1/g;

    # Hayakawa Aoi <Aoi@aoi.chan.panic>
    ($mb =~ /^\s*.*\s*<(\S+)>.*$/io) && (return $1);

    # Aoi@aoi.chan.panic (Chacha Mocha no cha nu-to no 1)
    ($mb =~ /^\s*(\S+)\s*.*$/io)     && (return $1);

    # Aoi@aoi.chan.panic
    return $mb;
}	

# Recreation of the whole mail for error infomation
sub WholeMail
{
    "$MailHeaders\n$MailBody";
}

# eval and print error if error occurs.
sub eval
{
    local($exp, $s) = @_;

    eval $exp; 
    &Log("$s:".$@) if $@;

    return 1 unless $@;
}

# Log: Logging function
# ALIAS:Logging(String as message) (OLD STYLE: Log is an alias)
# delete \015 and \012 for seedmail return values
# $s for ERROR which shows trace infomation
sub Logging { &Log(@_);}	# BACKWARD COMPATIBILITY
sub Log { 
    local($str, $s) = @_;
    local($package,$filename,$line) = caller; # called from where?

    &GetTime;

    $str =~ s/\015\012$//;	# FIX for SMTP
    $str = "$filename:$line% $str" if $debug_log;

    &Append2("$Now $str ($From_address)", $LOGFILE);
    &Append2("$Now    $filename:$line% $s", $LOGFILE) if $s;
}

# append $s >> $file
sub Append2
{
    local($s, $file) = @_;

    if (open(S, ">> $file")) {	# APPEND!
	select(S); $| = 1; select(STDOUT);
	print S $s."\n";
	close(S);
    }

    $s;
}


########### libsmtp.pl 
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

# sys/socket.ph is O.K.?
sub SmtpInit
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

    &SmtpInit;			# sys/socket.ph

    # VARIABLES:
    $host       = $HOST       || $host || 'localhost';
    $VAR_DIR    = $VAR_DIR    || "$DIR/var";
    $VARLOG_DIR = $VARLOG_DIR || "$DIR/var/log";  # absolute for ftpmail
    $SMTP_LOG0  = $SMTP_LOG0  || "$DIR/_smtplog"; # Backward compatibility;
    $SMTP_LOG   = $SMTP_LOG   || "$VARLOG_DIR/_smtplog";

    # LOG: on IPC
    (-d $VAR_DIR)    || mkdir($VAR_DIR, 0700);
    (-d $VARLOG_DIR) || mkdir($VARLOG_DIR, 0700);
    (-l $SMTP_LOG0)  || do {
	$symlink_exists = (eval 'symlink("", "");', $@ eq "");
	unlink $SMTP_LOG0;
	$symlink_exists && symlink($SMTP_LOG, $SMTP_LOG0);
	if ($symlink_exists) {
	    &Log("ln -s $SMTP_LOG $SMTP_LOG0");
	}
	else {
	    &Log("unlink $SMTP_LOG0, log -> $SMTP_LOG");
	}
    };
    $SMTP_LOG .= ".$Smtp_logging_hook" if $Smtp_logging_hook;

    if ($NOT_TRACE_SMTP) {
	open(SMTPLOG, "> /dev/null") || &Log("Cannot open /dev/null");
    }
    else {
	open(SMTPLOG, "> $SMTP_LOG") || 
	    (return "$MailDate: cannot open $SMTP_LOG");
    }

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

    ###### Here We go! ##### 
    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d\d\d\-/o);
    foreach $s (@headers) {
	$0 = "-- $s <$FML $LOCKFILE>";
	if ($TRACE_DNS_DELAY) { &GetTime; $prev = 60*$min + $sec;};

	print SMTPLOG ($s . "<INPUT\n");
	print S ($s . "\n");
	do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
	while(/^\d\d\d\-/o);

	if ($TRACE_DNS_DELAY) {
	    &GetTime, $time = 60*$min + $sec;
	    $time -= $prev;
	    ($time > 2) && &Log("SMTP DELAY[$time sec.]:$s");
	}

	sleep(3) if (!$_);	# DIRTY HACK;_; WHY NO ANSWER from <S>?
    }
    ### ALREADY, (HELO .. DATA) sequence ends

    # rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
    $body .= $PREAMBLE_MAILBODY 
	if $_cf{'ADD2BODY'} && $PREAMBLE_MAILBODY;#(smtp:1.5.7)
    $body  =~ s/\n\./\n../g;	# enough for body ^. syntax
    $body  =~ s/\.\.$/./g;	# trick the last "."

    # BODY INPUT
    $0 = "-- BODY <$FML $LOCKFILE>";
    print SMTPLOG "-------------\n";
    if ($_cf{'Smtp', 'readfile'}) { # For FILE INPUT
	print SMTPLOG $body;
	print S $body;
	while(<FILE>) { 
	    s/^\./../; 
	    print S $_;
	    print SMTPLOG $_;
	};
	
	print S ($_ = $TRAILER_MAILBODY) 
	    if $_cf{'ADD2BODY'} &&  $TRAILER_MAILBODY;
	print S "\n" if (!/\n$/); # fix the lost '\012'
	print SMTPLOG "-------------\n";
	print S ".\n";
    } 
    else {			# $body has both header and body.
	print SMTPLOG "$body-------------\n";
	print S $body;
    }

    $s = "BODY";		#CONVENIENCE: infomation for errlog
    do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
    while(/^\d\d\d\-/o);

    $s = "QUIT";		#CONVENIENCE: infomation for errlog
    $0 = "-- $s <$FML $LOCKFILE>";
    print S "QUIT\n";
    print SMTPLOG "$s<INPUT\n";
    do { print SMTPLOG $_ = <S>; &Log($_,$s) if /^[45]/o;} 
    while(/^\d\d\d\-/o);

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
    
    $body .= $PREAMBLE_MAILBODY if $_cf{'ADD2BODY'} && $PREAMBLE_MAILBODY;
    $body .= $MailBody;
    $body .= $TRAILER_MAILBODY  if $_cf{'ADD2BODY'} && $TRAILER_MAILBODY;
    $body .= "\n" if(! ($MailBody =~ /\n$/o));

    $Status = &Smtp($host, "$body.\n", @headers);
    &Log("Sendmail:$Status") if $Status;
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

1;



########## libfml.pl
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
    local($body);
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

    $body .= "Date: $MailDate\n";
    $body .= "From: $Original_From_address\n";
    $body .= "Subject: $Subject\n" if $Subject;
    $body .= "To: $To_address \n"; # since against no infinite loop
    $body .= $Reply_to ? "Reply-To: $Reply_to\n" : "Reply-To: $MAIL_LIST\n";
    $body .= "Errors-To: $MAINTAINER\n";
    $body .= "X-FML-LOCAL: ENFORCE MAIL.LOCAL\n";
    $body .= "X-MLServer: $rcsid\n" if $rcsid;
    $body .= "Precedence: ".($PRECEDENCE || 'list')."\n"; 
    $body .= $MailBody;

    @headers = ("HELO $_Ds", "MAIL FROM: $MAINTAINER");
    foreach $rcpt (@OPT) {
	push(@headers, "RCPT TO: $rcpt");
    }
    push(@headers, "DATA");

    $Status = &Smtp($host, "$body.\n", @headers);
    &Log("Sendmail:$Status") if $Status;
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
