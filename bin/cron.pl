#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.



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
require 'config.ph';

###### Customizable Varaibles

$From_address   = "Cron.pl";
$NOT_TRACE_SMTP = 1;
$CRON_NOTIFY    = 1;		# if you want to know cron's log, set 1;
$NOT_USE_TIOCNOTTY = 1;		# no ioctl

##### 

### chdir HOME;
$_cf{'opt:h'} && die(&USAGE);
chdir $DIR || die "Can't chdir to $DIR\n";
$ENV{'HOME'} = $DIR;

### MAIN
&CronInit; 

print STDERR "DEBUG MODE ON\n" if $debug;

print STDERR "Become Daemon\n" if $debug && $Daemon;
&daemon if $Daemon;

$pid = &GetPID;

if ($pid > 0 && 1 == kill(0, $pid) && (! &RestartP)) {
    print STDERR "cron.pl Already Running, exit 0\n";
}
else {
    if (! $NoRestart) {
	&Log((&RestartP ? "New day.! " : "")."cron.pl Restart!");
	&OutPID;
    }
    
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
    -n                working all times without RESTART;
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

sub abs { $_[0] > 0 ? $_[0]: - $_[0];}

sub Opt 
{ 
    ($_[0] =~ /^\-(\S)/)      && ($_cf{"opt:$1"} = 1);
    ($_[0] =~ /^\-(\S)(\S+)/) && ($_cf{"opt:$1"} = $2);
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



sub CronInit
{
    # GETOPT
    $Eternal      = 1 if $_cf{'opt:a'};
    $NoRestart    = 1 if $_cf{'opt:n'};
    $debug        = 1 if $_cf{'opt:d'};
    $CRON_NOTIFY  = 0 if $_cf{'opt:b'} eq '43';
    $CRONTAB      = $_cf{'opt:f'} || $CRONTAB || "etc/crontab";
    $Daemon       = 1 if $_cf{'opt:b'} eq 'd';
    $NOT_USE_TIOCNOTTY = 0 if $_cf{'opt:o'} eq 'notty';

    $VAR_DIR        = $VAR_DIR    || "./var"; # LOG is /var/log (4.4BSD)
    $VARRUN_DIR     = $VARRUN_DIR || "./var/run"; 
    $CRON_PIDFILE   = $CRON_PIDFILE || "$VARRUN_DIR/cron.pid"; # default;
}


sub Cron
{
    local($max_wait) = ($_cf{'opt:m'} || 3);
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
#           which impli#!/bin/sh

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           