#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#
$Rcdid   = "fml_local $rcsid";

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

### MAIN ###
umask(077);

&FmlLocalInitialize;		# preliminary

chdir $HOME || die("Cannot chdir \$HOME=$HOME\n"); # meaningless but for secure

&FmlLocalReadCF($ConfigFile);	# set %Var, %Config, %_cf
&FmlLocalGetEnv;		# set %ENV, $DIR, ...

chdir $DIR  || die("Cannot chdir \$DIR=$DIR\n");

&FmlLocalFixEnv;
&Parse;				# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers
&FixHeaderFields(*Envelope);	# Phase 3, fixing fields information
&CheckCurrentProc(*Envelope);	# Phase 4, fixing environment and check loops

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
	    /^\#\.USAGE:(.*)/ && ($UsageOfBuiltInFunctions .= "$1\n");
	}
	close(F);
    }

    # variables
    foreach (@Var) { 
	$variables .= " $_ ";
	$variables .= "\n" if (length($variables) % 65) < 3;
    }

    print STDERR <<"EOF";

$rcsid

USAGE: fml_local.pl [-Ddh] [-f ConfigFile] [-user username]
    -h     this help
    -d     debug mode on
    -D     dump variable 
    -f     configuration file for \~/.fmllocalrc
    -user  username

FILE:  \$HOME/.fmllocalrc

                  Please read FAQ for the details.

variables (set in \$HOME/.fmllocalrc):
$variables

BUILT-IN FUNCTIONS:
$UsageOfBuiltInFunctions

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
    # first match version
    if ($0 =~ /fml_local2/) { $FIRST_MATCH  = 1;}

    # DEFAULTS
    $UnmatchP = 1;
    $NOT_TRACE_SMTP = 1;
    $NOT_USE_UNIX_FROM_LOOP_CHECK = 1;
    $FS = '\s+';			# DEFAULT field separator
    $ConfigFile = '';
    $HOST = 'localhost';

    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)

    @Var = (HOME, DIR, LIBDIR, FML_PL, USER, MAIL_SPOOL, LOG, TMP,
	    TMP_DIR, PASSWORD, DEBUG, AND, ARCHIVE_DIR, VACATION,
	    MAINTAINER, MAINTAINER_SIGNATURE, FS,
	    LOG_MESSAGE_ID, SECURE_FML_LOCAL,
	    FIRST_MATCH, SLOCAL,
	    MY_FUNCTIONS, CASE_INSENSITIVE, MAIL_LENGTH_LIMIT);

    # getopts
    while(@ARGV) {
	$_ =  shift @ARGV;
	/^\-user/ && ($USER = shift @ARGV) && next; 
	/^\-f/    && ($ConfigFile = shift @ARGV) && next; 
	/^\-h/    && &USAGE && exit(0);
	/^\-d/    && ($debug++,   next);
	/^\-D/    && ($DUMPVAR++, next);
	-d $_     && push(@INC, $_);
    }

    # DEBUG
    if ($debug) {
	print STDERR "Getopt:\n";
	print STDERR "\$USER\t$USER\n";
	print STDERR "\$ConfigFile\t$ConfigFile\n\n";
    }

    # a few variables
    $USER = $USER || (getpwuid($<))[0];
    $HOME = (getpwnam($USER))[7] || $ENV{'HOME'};
    $FmlLocalRc   = "$HOME/.fmllocalrc";
    $FIRST_MATCH  = $SLOCAL;
    $LOGFILE      = "$HOME/fmllocallog"; # anyway logging

    if ($debug) {
	for (USER, HOME, FML_LOCAL_RC) {
	    eval "printf STDERR \"%-20s %s\\n\", '$_', \$$_;";
	}
    }
}


# %Var
# %Config 
sub FmlLocalReadCF
{
    local($infile) = @_;
    local($entry)  = 0;

    $infile = $infile || $FmlLocalRc;
    open(CF, $infile) || do {
	&Log("fail to open $infile");
	die "FmlLocalReadCF:$!\n";
    };

    ### make a pattern /$pat\s+(\S+)/
    foreach (@Var) { 
	$pat .= $pat ? "|$_" : $_;

	# for FmlLocal_get and 
	# next CF if $Var{$FIELD} in FmlLocalEntryMatch
	tr/A-Z/a-z/; # lower
	$Var{$_} = 1;
    }
    $pat = "($pat)";

    # FOR ARRAY
    $array_pat = "(INC)";

    ### Special pattern /$sp_pat\s+(.*)/
    # thanks to hirono@torii.nuie.nagoya-u.ac.jp (97/04/21)
    $sp_pat  = 'PASSWORD|MAINTAINER_SIGNATURE';
    $sp_pat .= '|TAR|UUENCODE|RM|CP|COMPRESS|ZCAT'; # system (.*) for "gzip -c"
    $sp_pat .= '|LHA|ISH'; # system (.*) for "gzip -c"
    $sp_pat  = "($sp_pat)";

    #### read config file
    CF: while(<CF>) {
	# Skip e.g. comments, null lines
	/^\s*$/o && $entry++ && next CF;
	next CF if /^\#/o;
	chop;

	# Set environment variables
	/^DEBUG/i && ($debug++, next CF);
	/^$sp_pat\s+(.*)/    && (eval "\$$1 = '$2';", $@ eq "") && next CF;
	/^$array_pat\s+(.*)/ && 
	    (eval "push(\@$1, '$2');", $@ eq "") && next CF;
	/^$pat\s+(\S+)/      && (eval "\$$1 = '$2';", $@ eq "") && next CF;

	# already must be NOT ENV VAR
	# AND OPERATION
	next CF if /^AND/i;
	$Config{$entry} .= $_."\n";

	# for later trick
	/^body/i && ($_PCB{'has-body-pat'} = 1);
    }

    close(CF);

    # record the number of matched entry
    $_PCB{'entry'} = $entry + 1;	# +1 is required for anti-symmetry
}


sub FmlLocalGetEnv
{
    # include ~/.fmllocalrc

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

    $VacationRc   = $VACATION || "$HOME/.vacationrc";

    if (! $domain) {
	$domain   = (gethostbyname('localhost'))[1];
	($domain) = ($domain =~ /(\S+)\.$/i) if $domain =~ /\.$/i;
	($domain) = ($domain =~ /localhost\.(\S+)/i); 
    }

    $MAINTAINER  = $MAINTAINER || $USER .'@'. $domain;
    
    # include ~/.vacationrc
    &FmlLocalReadCF($VacationRc) if -f $VacationRc;

    # logs message id against loopback
    $LOG_MESSAGE_ID = $LOG_MESSAGE_ID || "$TMP_DIR/log.msgid";

    if ($debug) {
	print STDERR "**********\n";
	for (@Var) { 
	    eval "printf STDERR \"%-20s %s\\n\", '$_', \$$_ if \$$_;";
	}
	print STDERR "**********\n";
    }

    1;
}


# FIX TO BE FIXED AFTER CHDIR $DIR;
sub FmlLocalFixEnv
{
    -d $TMP_DIR || &Mkdir($TMP_DIR, 0700);
}


# Predicate whether match or not 
# by comparing %Envelope{h:*} and $_CF
# trick:
#      body is 'body:' field :-) 
# this makes the code simple
#
# if has no 3rd entry, NOT ILLEGAL
# it must be AND OPERATION, REQUIRE 'multiple matching'
#
sub FmlLocalSearchMatch
{
    local($s, $entry)   = @_;
    local($f, $p, $type, $exec, @opt, $ok, $cnt);
    local($match) = 0;

    # $s = $_CF{$entry}; so "rc" entry;
    local(@pat) = split(/\n/, $s);

    # for multiple lines. the entry to match is within "one line"
    $* = 0;

    # compare %Envelope patterns given by "rc" entry ($s)
    foreach $pat (@pat) {
	$cnt++;			# counter

	# field pattern type exec
	# ATTENTION! @OPT is GLOBAL
	($f, $p, $type, $exec, @opt) = split(/$FS/, $pat);
	print STDERR "  pat[$entry]:\t($f, $p, $type, $exec, @opt)\n" if $debug;

	$f =~ tr/A-Z/a-z/;	# lower

	if ($Envelope{"$f:"} =~ /$p/ || 
	    ($CASE_INSENSITIVE && $Envelope{"$f:"} =~ /$p/i)) {
	    print STDERR "MatchPat:\t[$f:$`($&)$']\n" if $debug;
	    &Log("Match [$f:$`($&)$']") if $debug;
	    $f1 = $1; $f2 = $2; $f3 = $3;
	    $ok++;

	    # MULTIPLE MATCH
	    if ($type && ($ok == $cnt)) {
		$match++;
		&FmlLocalSetVar($type, $exec, $f1, $f2, $f3);
		@OPT = @opt; # @opt eval may fail;
	    }
	}

	($f =~ /^default/i) && ($_PCB{'default'} = $pat);
    }

    $match;# return value;
}


sub FmlLocalSearch
{
    local($i, $r);

    # TRICK! deal MailBody like a body: field.
    # has-body-pat is against useless malloc 
    $Envelope{'body:'} = $Envelope{'Body'} if $_PCB{'has-body-pat'};

    # try to match pattern in %entry(.fmllocalrc) and *Envelope{Hdr,Body}
    for($i = 0; $i < $_PCB{'entry'}; $i++) {
	$_ = $Config{$i};
	next if /^\s*$/o;
	next if /^\#/o;

	# default is an exception
	if ($FIRST_MATCH && $r && (!/^default/i)) { next;}

	$r = &FmlLocalSearchMatch($_, $i);
    }
}


sub FmlLocalUnSetVar 
{ 
    for (TYPE, EXEC, F1, F2, F3) { eval "undef \$$_;";}
    undef @OPT;
}


# &FmlLocalSetVar($type, $exec, $F1, $F2, $F3, *opt);
sub FmlLocalSetVar
{
    local(@caller) = caller;

    &FmlLocalUnSetVar;

    # tricky global variable
    ($TYPE, $EXEC, $F1, $F2, $F3) = @_; 

    &Log("FmlLocalSetVar called at the line $caller[2]") if $debug;
    &Log("FmlLocalSetVar::($type, $exec, $f1, $f2, $f3)\n") if $debug;

    if ($debug) {
	for (TYPE, EXEC, F1, F2, F3) { eval "print \"$_ \$$_\\n\";";}
    }

    undef $UnmatchP;
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
    $Original_To_address   = $Envelope{'h:to:'};
    $To_address            = $Envelope{'h:to:'};
    $Original_From_address = $Envelope{'h:from:'};
    $Subject               = $Envelope{'h:subject:'};
    
    # variable expand
    $EXEC = &FmlLocalReplace($EXEC);
    for ($i = 0; $i < scalar(@OPT); $i++) {
	$OPT[$i] = &FmlLocalReplace($OPT[$i]);
    }

    1;
}


sub FmlLocalMainProc
{
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
    elsif ($UnmatchP) {
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
    ($a, $b, $type, $exec, @OPT) = split(/\s+/, $_PCB{'default'});
    if ($type) {
	print STDERR "\n *** ALWAYS GO! *** \n" if $debug;
	&FmlLocalSetVar($type, $exec, @OPT);
	&MailProc($TYPE, $EXEC);
    }
}


sub FmlLocalAppend2CF
{
    local($s) = @_;

    open(CF, ">> $FmlLocalRc") || (return 'open fail ~/.fmllocalrc');
    select(CF); $| = 1;
    print CF $s, "\n";
    close(CF);

    print CF "\n";

    return 'ok';
}


sub FmlLocalReadFML
{
    local($sepkey) = "\#\#\#\#\# SubRoutines \#\#\#\#\#";
    local($s);

    return '1;' unless -f $FML_PL;

    open(FML, $FML_PL) || 
	(print STDERR "Cannot load $FML_PL\n"  , return 0);

    while(<FML>) {
	next if 1 .. /^$sepkey/;
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



############################################################
##### INCLUDE Libraries
############################################################
if ($debug_fml_local) {
    eval(' chop ($PWD = `pwd`); ');
    $PWD = $ENV{'PWD'} || $PWD || '.'; # '.' is the last resort;)
    push(@INC, $PWD);
    push(@INC, "$PWD/proc");
    require 'libsmtp.pl'; 
    require 'libsmtputils.pl';
    require 'libkern.pl'; 
    require 'libdebug.pl';
}

#.include kern/libloadconfig.pl
#.include kern/libsmtp.pl
#.include kern/libsmtputils.pl
#.include proc/libkern.pl
#.include proc/libdebug.pl



############################################################
##### Built-In Functions
############################################################
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
	$s .= "please contact $MAINTAINER\n";
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
    undef $F1; undef $F2; undef $F3;
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
#.USAGE:    echo getmyspool password uf |Mail (大学|会社)のアドレス 
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
    require 'libfop.pl';

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
    local($body, @rcpt, $status);
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

    &SetDefaults;
    &GetTime;

    for (@HdrFieldsOrder) {
	$Envelope{'Hdr'} .= "$_: $Envelope{\"h:$_:\"}\n" if $Envelope{"h:$_:"};
    }

    $Envelope{'Hdr'} .= "X-FML-LOCAL: ENFORCE MAIL.LOCAL\n";
    $Envelope{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
    $Envelope{'Hdr'} .= "Precedence: ".($PRECEDENCE || 'list')."\n"; 

    foreach $rcpt (@OPT) { push(@rcpt, $rcpt);}

    $status = &Smtp(*Envelope, *rcpt);
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
