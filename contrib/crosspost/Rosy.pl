#!/usr/local/bin/perl
#
# copyright (c) 1994-1995 fukachan@phys.titech.ac.jp
# please obey gnu public licence(see ./copying)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

# for the insecure command actions
$env{'path'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$env{'shell'} = '/bin/sh' if $env{'shell'} ne '';
$env{'ifs'}   = '' if $env{'ifs'} ne '';

#################### MAIN ####################
# CONFIGURATION
$ML_SPOOL    = "/home/axion/fukachan/work/spool";
$CACHE_DIR   = "/home/axion/fukachan/work/spool/Cache";
$PASSWD_FILE = "$CACHE_DIR/etc/passwd";
$LOGFILE     = "/home/axion/fukachan/work/spool/Crosspost/log";

# PRELIMINARY CONFIGBURATION
#&ReadEval("$CACHE_DIR/Config.fml");
&ReadEval("$CACHE_DIR/Cache");

# a little configuration before the action
umask (077);			# rw-------

$SIG{'INT'} = 'dokill';
sub dokill { kill 9,$child if $child; }

chdir $CACHE_DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..

$|=1;
$AUTH = 0;

print "220 ML-Crosspost Primary Data Server($rcsid) listen\n"; 

in: while(<STDIN>) {
    chop;
    &Log($_);

	if(/^QUIT/oi) {
	    print  "221 closing connection\n";
	    last in;
	} 

	if(/^USER\s+(\S+)/oi || /^FROM\s+(\S+)/oi) {
	    $from = $1;
	    print  "250 FROM $from... O.K.\n";
	    next in;
	}

	if(/^PASS\s+(\S+)/oi) {
	    $passwd = $1;
	    if(&Crypt($from, $passwd)) {
		$AUTH = 1;
		print  "250 PASSWD AUTHENTICATED... O.K.\n";
	    }else {
		print  "554 Illegal Passwd\n";
	    }
	    next in;
	}

	if($AUTH) {
	    if(/^PASSWD\s+(\S+)/oi) {
		$passwd = $1;
		if(&passwd($from, $passwd)) {
		    print  "250 PASSWD CHANGED... O.K.\n";
		}else {
		    print  "554 PASSWD UNCHANGED\n";
		}
		next in;
	    }

	    if(/^GET (\S+)/oi) {
		print  "354 data connection\n";
		$ml = $1;

		if($ml =~ /^CONFIG$/oi) {
		    &Retrieve("$CACHE_DIR/Cache");
		} elsif($ml =~ /^ALL$/oi) {
		    foreach(keys %Crosspost) { 
			&Retrieve($Crosspost{$_});
		    }
		} else {
		    &Retrieve($Crosspost{$ml});
		}

		print  "250 Retrieve done\n";
		next in;
	    }

	    print  "500 Command not found\n";
	} else {
	    print  "554 Not Authenticated\n";
	    print  "221 closing connection\n";
	    last in;
	}#AUTH;

	print  "500 Command not found\n";
}

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0700);}
    $TMP_DIR = $TMP_DIR ? $TMP_DIR : "$DIR/tmp"; # backward compatible
    if(!-d $TMP_DIR)       { mkdir($TMP_DIR,0700);}
    for($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	$SEQUENCE_FILE, $SUMMARY_FILE) {
	if(!-f $_) { 
	    open(TOUCH,"> $_"); close(TOUCH);
	}
    }

    &GetTime;
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
    print LOGFILE "$Now $str ". ((!$e)? "($From_address)\n": "\n");
    close(LOGFILE);
}

# lock algorithm using flock system call
# if lock does not succeed,  fml process should exit.
sub Flock
{
    $0 = "--Locked(flock) and waiting <$FML $LOCKFILE>";

    open(LOCK, $SPOOL_DIR); # spool is also a file!
    flock(LOCK, $LOCK_EX);
}

sub Funlock {
    $0 = "--Unlock <$FML $LOCKFILE>";

    close(LOCK);
    flock(LOCK, $LOCK_UN);
}

sub ReadEval
{
    local($f, $m) = @_;

    open(f) || do { &Log("Cannot open $f"); return 0;};
    while(<f>) {
	next if(/^\#/o);	# skip comment and off member
	next if(/^\s*$/o);	# skip null line
	($a, $b) = split;
	if(&EvalReadFile($a, $b)) {
	    ;
	}else {
	    $Crosspost{$a} = "$CACHE_DIR/$b";
	}
    }
    close(f);
}

# Consider auto-registration or not? and get %Crosspost
sub EvalReadFile
{
    local($ml, $dir)   = @_;
    local($dir)        = "$ML_SPOOL/$dir"; 
    local($configfile) = "$dir/config.ph"; 
    local($MCHECK)     = 0;

    open(FILE, $configfile) || return 0;
    $configfile = join("", <FILE>);
    close(FILE);

    if($configfile  =~ /\$ML_MEMBER_CHECK\s*=\s*(\S)/) {
	$MCHECK = $1;# auto-registration check;
    }

    # Already auto-regist or not has been determined.
    $Crosspost{$ml} = "$dir/". ($MCHECK ? "actives": "members");

    return 1;
}

sub Crypt
{
    local($from, $passwd) = @_;
    local($uja);

    open(FILE, "< $PASSWD_FILE") || return 0;
    while(<FILE>) {
	chop;

	local($a, $b) = split(/\s+/, $_, 99);
	if($a eq $from) { $uja = $b;}
    }
    close(FILE);

    $uja || return 0;

    local($salt) = ($uja =~ /^(\S\S)/ && $1);
    $passwd      = crypt($passwd, $salt);

    return 1 if($passwd eq $uja); 
    return 0;
}

sub passwd
{
    local($from, $passwd) = @_;
    local($salt) = rand(64);
    local($uja);

    $passwd      = crypt($passwd, $salt);

    open(FILE, "< $PASSWD_FILE")      || return 0;
    open(OUT,  "> $PASSWD_FILE.new")  || return 0;
    open(BAK,  ">> $PASSWD_FILE.bak") || return 0;

    print BAK "--- $Now ---\n";
    while(<FILE>) {
	print BAK $_;

	local($a, $b) = split;
	if($a eq $from) {
	    print OUT "$a $passwd\n";
	    $uja = 1;
	}
    }

    print OUT "$a $passwd\n" unless $uja;
    close(FILE);

    if(rename("$PASSWD_FILE.new", $PASSWD_FILE)) {
	return 1;
    }else {
	return 0;
    }
}

sub Retrieve
{
    local($ff) = local($f) = @_;

    $ff =~ s/$CACHE_DIR//g;
    $ff =~ s/\///g;
    print  "FILE:$ff\n";

    open(FILE, "< $f") || do {
	print  "500 Cannot access data connection\n";
	return ;
    };

    while(<FILE>) { 
	print  $_;
    }
    close(FILE);
}

1;

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0700);}
    for($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	$SEQUENCE_FILE, $SUMMARY_FILE) {
	if(!-f $_) { open(TOUCH,"> $_"); close(TOUCH);}
    }

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}


# Logging(String as message)
sub Logging
{
# $STRUCT_SOCKADDR = $STRUCT_SOCKADDR || 'n n a4 x8';
# local($family, $port, $addr) = unpack($STRUCT_SOCKADDR, getpeername(STDIN));
# local($clientaddr) = gethostbyaddr($addr, 2);

    if (! defined($clientaddr)) {
	$clientaddr = sprintf("%d.%d.%d.%d", unpack('C4', $addr));
    }

    open(LOGFILE, ">> $LOGFILE");
    printf LOGFILE "$Now @_ ($clientaddr)\n";
    close(LOGFILE);
}

1;
