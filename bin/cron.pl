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

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

# For the insecure command actions
undef %ENV;
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# Now for the exist-check (DIR, LIBDIR), "free order is available"
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || '/home/axion/fukachan/work/spool/EXP';
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);

#################### MAIN ####################
eval(' chop ($PWD = `pwd`); ');
$PWD = $ENV{'PWD'} || $PWD || '.'; # '.' is the last resort;)

$EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
push(@INC, $EXEC_DIR) if -d $EXEC_DIR;
push(@INC, $PWD) if -d $PWD;
require 'libloadconfig.pl'; &__LoadConfiguration;

###### Customizable Varaibles
$From_address   = "Cron.pl";
$NOT_TRACE_SMTP = 1;
$CRON_NOTIFY    = 1;		# if you want to know cron's log, set 1;
$NOT_USE_TIOCNOTTY = 1;		# no ioctl
##### 

# GETOPT
$Eternal      = 1 if $Opt{'opt:a'};
$debug        = 1 if $Opt{'opt:d'};
$CRON_NOTIFY  = 0 if $Opt{'opt:b'} eq '43';
$CRONTAB      = $Opt{'opt:f'} || $CRONTAB || "etc/crontab";
$Daemon       = 1 if $Opt{'opt:b'} eq 'd';
$NOT_USE_TIOCNOTTY = 0 if $Opt{'opt:o'} eq 'notty';

### chdir HOME;
$Opt{'opt:h'} && die(&USAGE);
chdir $DIR || die "Can't chdir to $DIR\n";
$ENV{'HOME'} = $DIR;

### MAIN
print STDERR "DEBUG MODE ON\n" if $debug;

print STDERR "Become Daemon\n" if $debug && $Daemon;
&daemon if $Daemon;
 
$pid = &GetPID;

if ($pid > 0 && 1 == kill(0, $pid) && (! &RestartP)) {
    print STDERR "cron.pl Already Running, exit 0\n";
}
else {
    &Log((&RestartP ? "New day.! " : "")."cron.pl Restart!");
    &OutPID;
    &Cron;
}

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####
sub USAGE 
{
    ($command = $0) =~ s#.*/##;

    local($s) = qq#syntax: $command DIR [LIBDIR] [options];
    options;
    -d                debug mode;
    -a                run eternally(default: 180sec. = 60sec. * 3times);
    -mtimes           run from now to (60 * times) sec. after;
    -fcrontab-file    alternative crontab;
    -h                show this help and exit;
    -bd		      daemon (Become Daemon);
    -bOSTYPE          -b43(OSTYPE = 43): 4.3BSD Like. not mailed to you;
    ;                  default(4.4BSD): when anything done, mailed to you;
    -oOPTION	      OPTOIN:;
    ;		       notty (ioctl)	
#;

    $s =~ s/;//g;		#for perl-mode;
    $s;
}

sub GetPID
{
    local($pid);

    open(F, $CRON_PIDFILE) || return 0;
    chop( $pid = <F> );
    close(F);

    $pid;
}

sub OutPID
{
    open(F, "> $CRON_PIDFILE") || return 0;
    select(F); $| = 1; select(STDOUT);	
    print F "$$\n";
    close(F);
}

# the last modify time
sub GetDayofTime { (localtime((stat($_[0]))[9]))[3];}

# If the day changes, restart cron.pl
sub RestartP { (localtime(time))[3] != &GetDayofTime($CRON_PIDFILE);}

sub Opt
{ 
    ($_[0] =~ /^\-(\S)/)      && ($Opt{"opt:$1"} = 1);
    ($_[0] =~ /^\-(\S)(\S+)/) && ($Opt{"opt:$1"} = $2);
}


sub MailTo
{
    &use('smtp');
    local(*to, *e, *rcpt);
    local($body) = @_;

    # From: and To:. when Environmental varialbe MAILTO, send to it.
    if ($ENV{'MAILTO'}) {
	push(@to, $ENV{'MAILTO'});
    }
    else {
	push(@to, $MAINTAINER);
    }

    # Subject 
    local($hostname, $user);
    $user = (getpwuid((stat($CRONTAB))[4]))[0];
    $ENV{'USER'}    = $user unless $ENV{'USER'};
    $ENV{'LOGNAME'} = $user unless $ENV{'LOGNAME'};

    chop($hostname = `hostname`);
    $e{'subject:'} = "Cron <$user\@$hostname>";

    # Header Generator
    &GenerateHeaders(*to, *e, *rcpt);

    # Environment
    while (($k, $v) = each %ENV) { $e{'Hdr'} .= "X-Cron-Env: <$k=$v>\n";}

    # Body
    $e{'Body'}     .= $body;

    # Smtp
    $e = &Smtp(*e, *rcpt);
    &Log("Sendmail:$e") if $e;
}


sub Cron
{
    local($max_wait) = ($Opt{'opt:m'} || 3);
    local($exec, $pid);

    # FOR PROCESS TABLE
    $FML .= "[".substr($MAIL_LIST, 0, 8)."]"; # Trick for tracing

  CRON: while ($Eternal || $max_wait--> 0) {
      $0 = "--Cron <$FML $LOCKFILE>";
      $0 = "--Cron [$max_wait] times <$FML $LOCKFILE>" unless $Eternal; 
      ### Restart if cron may be running over 24 hours
      $pid = &GetPID;
      if ($$ != $pid) { last CRON;};

      ### TIME
      ($sec,$min,$hour,$mday,$mon,$year,$wday) = 
	  (localtime($init_t = time))[0..6];

      undef $ErrStr;		# new logging;

      ### ANYTHING TO DO?
      if ($exec = &ReadCrontab) {
	  $ErrStr .= "[Output from execed processes]\n";

	  open(READ);
	  &system($exec, "", "", 'READ'); # very slow why?
	  while (<READ>) { $ErrStr .= $_;} # < STDOUT;
	  close(READ);

	  if ($debug) {
	      print STDERR "\n[Date $hour:$min:$sec]\n($exec)\n}\n"; 
	      print STDERR "\n[Debug Info]\n$ErrStr\n"; 
	  }

	  &MailTo($ErrStr) if $CRON_NOTIFY;
      }
      ### NOTHING!
      else {
	  print STDERR "DO NOTHING\n" if $debug;
      }

      # next 60sec.
      $0 = "--Cron Sleeping <$FML $LOCKFILE>";
      $0 = "--Cron Sleeping [$max_wait] times <$FML $LOCKFILE>" 
	  unless $Eternal; 
      $time = (time() - $init_t);

      print STDERR "$time = (time() - $init_t) <= 60) \n" if $debug;

      if ($time <= 60) {
	  $time = 60 - $time;
	  print STDERR "Sleeping $time\n" if $debug;
	  sleep $time;
      }
      else {
	  print STDERR "Hmm exec costs over 60sec... go the next step now!\n"
	      if $debug;
	  next CRON;
      }
  }#END OF WHILE;

    print STDERR "cron.pl \$max_wait == 0. exit\n" unless $Eternal;
}


sub Match
{
    local($m, $h, $d, $M, $w) = @_;
    local($nomatch);

    # WEEK
    print STDERR "($w eq '*') || ($w eq $wday) || (7==$w && 0==$wday)\n" 
	if $debug;
    (($w eq '*') || ($w eq $wday) || (7==$w && 0==$wday)) || $nomatch++; 

    # MONTH
    print STDERR "($M eq '*') || ($M eq ($mon + 1))\n" if $debug;
    (($M eq '*') || ($M eq ($mon + 1))) || $nomatch++; 

    # DAY
    print STDERR "($d eq '*') || ($d eq $mday)\n" if $debug;
    (($d eq '*') || ($d eq $mday)) || $nomatch++; 

    # HOUR
    print STDERR "($h eq '*') || ($h eq $hour)\n" if $debug;
    (($h eq '*') || ($h eq $hour)) || $nomatch++; 

    # MINUTE
    print STDERR "($m eq '*') || ($m eq $min)\n" if $debug;
    (($m eq '*') || ($m eq $min)) || $nomatch++; 

    # O.K.
    print STDERR "($nomatch ? 0 : 1);\n" if $debug;
    ($nomatch ? 0 : 1);
}


# Crontab is 4.4BSD syntax 
#
#minute	hour	mday	month	wday	command
#
sub ReadCrontab
{
    local($org, $exec, $s) = ();

    open(CRON, $CRONTAB) || (&Log("Cannot Read crontab:$!"), return 0);

    while (<CRON>) {
	chop;

	next if /^\#/o;
	next if /^\s*$/o;

	$s .= "CRONTAB ENTRY> $_\n" if $debug;
	$org  = $_;

	local(*m, *h, *d, *M, *w, *com, *e);
	($m, $h, $d, $M, $w, @com) = split(/\s+/, $_);

	@m = &CrontabExpand($m, 59) unless $m =~ /^\d+$/;
	@h = &CrontabExpand($h, 23) unless $h =~ /^\d+$/;
	@d = &CrontabExpand($d, 31) unless $d =~ /^\d+$/;
	@M = &CrontabExpand($M, 12) unless $M =~ /^\d+$/;
	@w = &CrontabExpand($w, 7)  unless $w =~ /^\d+$/;
	$e = join(" ", @com);

	for $w (@w) { 
	    for $M (@M) { 
		for $d (@d) { 
		    for $h (@h) { 
			for $m (@m) { 
			    if (&Match($m, $h, $d, $M, $w)) {
				$exec .= "$e;\n";
				$s .= "MATCH Entry [$org]:\n";
				$s .= "      <=>   [$m $h $d $M $w]\n";
			    }
			}
		    }
		}
	    }
	}

    }# while;

    close(CRON);

    $s =~s/\t/ /g;
    $ErrStr .= "ReadCrontab Entry Summary:\n$s\n" if $debug;
    $exec;
}


sub CrontabExpand
{
    local($_, $max) = @_;
    local($m,  $unit, $start, *s, *r);

    return $_ if /^\d+$/;
    return $_ if /^\*$/;

    s#^(\S+)/(\d+)$#$m = $1, $unit = $2#e;

    $ErrStr .= "Expand [$_] => \$m = $m, \$unit = $unit;\n" if $debug;

    for (split(/,/, $m)) {
	if (/^(\d+)$/) {
	    push(@s, $_);
	}
	elsif (/^(\d+)\-(\d+)$/) {
	    for ($1 .. $2) { push(@s, $_);}
	}
	else {# e.g. "*", "1?";
	    s/\*/.\*/g;
	    s/\?/.\+/g;
	    for $s (0 .. $max) { push(@s, $s) if $s =~ /^$_$/;} 
	}
    }

    @s = sort {$a <=> $b} @s;

    for ($start = $_ = shift @s, push(@s, $_), $i = 0; 
	 $_ = shift @s; 
	 $i++) {
	push(@r, $_) if (($_ - $start) % $unit) == 0;
    }

    @r;
}


########## 
# include: libutils.pl 
# BUT MODIFILED
# Pseudo system()
# fork and exec
# $s < $in(file) > $out(file)
#          OR
# $s < $write(file handle) > $read(file handle)
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
    local($s, $out, $in, $read, $write) = @_;
    local($c_w, $c_r) = ("cw$$", "cr$$"); # for child handles

    &Debug("system ($s, $out, $in, $read, $write)") if $debug;

    # File Handles "pipe(READHANDLE,WRITEHANDLE)"
    $read  && (pipe($read, $c_w)  || (&Log("ERROR pipe(pr, wr)"), return));
    $write && (pipe($c_r, $write) || (&Log("ERROR pipe(cr, pw)"), return));

    # Go!;
    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	if ($write){
	    open(STDIN, "<& $c_r") || die "child in";
	}
	elsif ($in){
	    open(STDIN, $in) || die "in";
	}
	else {
	    close(STDIN);
	}

	if ($read) {
	    open(STDOUT, ">& $c_w") || die "child out";
	    $| = 1;
	}
	elsif ($out){
	    open(STDOUT, '>'. $out) || die "out";
	    $| = 1;
	}
	else {
	    close(STDOUT);
	}

	exec $s || &Log("Cannot exec $s:".$@);
    }

    close($c_w) if $c_w;# close child's handles.
    close($c_r) if $c_r;# close child's handles.
    
    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}


########## 
#:include: fml.pl
#:sub Log Debug Logging LogWEnv GetTime Append2 use 
#:~sub 
#:replace
sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, 
			$isdst ? $TZONE_DST : $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
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
    if ($debug_sendmail_error && ($str =~ /^5\d\d\s/)) {
	$Envelope{'error'} .= "Sendmail ERROR:\n";
	$Envelope{'error'} .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }
    
    $str = "$filename:$line% $str" if $debug_caller;

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


# eval and print error if error occurs.
# which is best? but SHOULD STOP when require fails.
sub use { require "lib$_[0].pl";}


sub Debug 
{ 
    print STDERR "$_[0]\n";
    $Envelope{'message'} .= "\nDEBUG $_[0]\n" if $message_debug;
}



1;
#:~replace
########## 
#:include: proc/libutils.pl
#:sub daemon
#:~sub 
#:replace
# NAME
#      daemon - run in the background
# 
# SYNOPSIS
#     #include <stdlib.h>
#     daemon(int nochdir, int noclose)
#
# C LANGUAGE
#  f = open( "/dev/tty", O_RDWR, 0);
#  if( -1 == ioctl(f ,TIOCNOTTY, NULL))
#    exit(1);
#  close(f);
sub daemon
{
    local($nochdir, $noclose) = @_;
    local($s, @info);

    if ($ForkCount++ > 1) {	# the precautionary routine
	$s = "WHY FORKED MORE THAN ONCE"; 
	&Log($s, "[ @info ]"); 
	die($s);
    }

    if (($pid = fork) > 0) {	# parent dies;
	exit 0;
    }
    elsif (0 == $pid) {		# child is new process;
	if (! $NOT_USE_TIOCNOTTY) {
	    eval "require 'sys/ioctl.ph';";

	    if (defined &TIOCNOTTY) {
		require 'sys/ioctl.ph';
		open(TTY, "+> /dev/tty")   || die("$!\n");
		ioctl(TTY, &TIOCNOTTY, "") || die("$!\n");
		close(TTY);
	    }
	}

	close(STDIN);
	close(STDOUT);
	close(STDERR);
	return 1;
    }
    else {
	&Log("daemon: CANNOT FORK");
	return 0;
    }
}





1;
