#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$


&Init;

while (1) {
    $init_time = time;

    &GetConf;

    # determine slot
    $Counter++;
    $Counter = $Counter % $SlotSize;

    # kill the 3600 sec. after
    $next = ($Counter + 1) % $SlotSize;


    &Info("start new session") if $debug;

    foreach $ml (keys %IncludeFile) {
	next unless $ml;

	&Info("call $ml session") if $debug;

	$Process  = "perl $PopFmlProg ";
	$Process .= "-d " if $debug;
	$Process .= "$ML_DIR/popfml $EXEC_DIR ";
	$Process .= "-user $ml -host $POP_SERVER ";
	$Process .= "-include_file $IncludeFile{$ml} ";
	$Process .= "-pop_passwd $ML_DIR/etc/pop_passwd ";
	$Process .= "-perl_prog $PerlProgram ";
	$Process .= "-arch $COMPAT_ARCH";

	if ($debug) {
	    print STDERR "Perl   \t$PerlProgram\n";
	    print STDERR "Process\t$Process\n";
	}

	### 
	### *** ATTENTION! ***
	### Create() CANNOT READ "/" path syntax;
	### Only in this call, we need to user 'c:\perl' .. syntax ;_;
	### 
	# create processes
	&Win32::Process::Create($ProcessObj, 
				$PerlProgram, 
				$Process, 
				0,
				NORMAL_PRIORITY_CLASS, ".") || 
				    die ErrorReport();

	$ProcessObj{$ml, $Counter} = $ProcessObj;

	if ($ProcessObj{$ml, $next}) {
	    print STDERR "kill \$ProcessObj{$ml, $next}\n" if $debug;
	    $ProcessObj = $ProcessObj{$ml, $next};
	    $ProcessObj->Kill(1);
	}
    }


    &GetTime;

    # e.g. 18:00 
    if ($min == 0 || $debug_msend) {
	# Matome Okuri
	foreach $ml (keys %IncludeFile) {
	    next unless $ml;

	    &Info("call $ml msend session") if $debug;

	    $Process  = "perl $EXEC_DIR/msend.pl ";
	    $Process .= "$ML_DIR/$ml $EXEC_DIR ";
	    $Process .= "-d " if $debug;
	    $Process .= "--COMPAT_ARCH=$COMPAT_ARCH " if $COMPAT_ARCH;

	    &Win32::Process::Create($ProcessObj, 
				    $PerlProgram, 
				    $Process, 
				    0,
				    NORMAL_PRIORITY_CLASS, ".") || 
					die ErrorReport();

	    $MSendProcessObj{$ml, $Counter} = $ProcessObj;

	    if ($MSendProcessObj{$ml, $next}) {
		print STDERR "kill \$MSendProcessObj{$ml, $next}\n" if $debug;
		$ProcessObj = $MSendProcessObj{$ml, $next};
		$ProcessObj->Kill(1);
	    }
	}
    } # $min == 0

    # sleep time
    &GetTime;
    $sleep = (60 - $sec) - (time - $init_time) + 1;
    &Info("sleep for $sleep sec.") if $debug;

    if ($time <= 60) {
	sleep($sleep);
    }
    elsif ($debug) {
	print STDERR "Oops, the execution costs > 60 secs.\n";
	print STDERR "Do the next scan as soon as possible.\n";
    }

    &Info('go to next loop') if $debug;
}


exit 0;



sub GetConf
{
    local($ml);

    opendir(DIRD, $ML_DIR) || die("Error: cannot open ML_DIR[$ML_DIR];$!");
    for $ml (readdir(DIRD)) {
	next if /^\./;

	# special
	next if $ml eq 'etc';
	next if $ml eq 'popfml';

	$cf = "$ML_DIR/$ml/config.ph";

	if (-f $cf) {
	    $ctladdr = &Grep('^\$CONTROL_ADDRESS', $cf);
	    eval $ctladdr;

	    ($ctladdr) = split(/\@/, $CONTROL_ADDRESS);

	    # alloc
	    if (-f "$ML_DIR/$ml/include" && &GetPopPasswd($ml, $cf)) {
		$IncludeFile{$ml}       = "$ML_DIR/$ml/include";
		$MsendList{$ml}         = "$ML_DIR/$ml";
	    }

	    if ($ctladdr ne $ml) {
		if (-f "$ML_DIR/$ml/include-ctl" && 
		    &GetPopPasswd($ctladdr, $cf)) {
		    $IncludeFile{$ctladdr} = "$ML_DIR/$ml/include-ctl";
		}
	    }
	}
    } 
    closedir(DIRD);

    undef $CONTROL_ADDRESS;
}


sub ReadNTConfig
{
    local($arg, $exec);

    ### read configuration file
    open(CONFIG, "_fml\\nt") || die("Error: cannot open _fml\\nt [$!]\n");
    while (<CONFIG>) {
	chop;
	next if /^\s*$/;
	next if /^\#/;

	(@buf) = split;
	$arg   = shift @buf;
	$exec  = join(" ", @buf);

	$Config{$arg} = $exec;
    }
    close(CONFIG);
}


sub Init
{
    require 'getopts.pl';
    &Getopts("d");

    $debug = $opt_d;

    ### COMPAT CODE ###
    if ($ENV{'OS'} =~ /Windows_NT/) {
	$HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 0;
	$COMPAT_ARCH = "WINDOWS_NT4";
	$COMPAT_WIN32 = 1;
    }
    
    if ($COMPAT_ARCH eq "WINDOWS_NT4") {
	# $ProcessObj
	# $ProcessObj->Suspend();
	# $ProcessObj->Resume();
	# $ProcessObj->Wait(10);
	# $ProcessObj->Kill(1);
	use Win32::Process;
	use Win32;

	### perl
	$PerlProgram = &search_path('perl.exe') || "c:\\perl\\bin\\perl.exe";

	# load config (once at first)
	require "_fml\\system" || die("Error: cannot load _fml\\system [$!]");
	require "_fml\\pop"    || die("Error: cannot load _fml\\pop [$!]");

	# perl perl\popfml.pl h:\w h:\fml 
	# -pwfile h:\perl\pw -user elena -host iris.sapporo.iij.ad.jp -f h:\cf
	$PopFmlProg = $EXEC_DIR.'\libexec\popfml.pl';
    }
    else {
	$PerlProgram = &search_path('perl');
	require '.fml/system';
    }


    ### default values;
    $|        = 1;
    $WaitUnit = 60;
    $TimeOut  = 3600;
    $SlotSize = int($TimeOut/$WaitUnit);
}


sub ErrorReport
{
    print Win32::FormatMessage( Win32::GetLastError() );
}


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



sub Info
{
    $count++;
    &GetTime;
    print STDERR "\#\#\#[$count]\#\#\# $MailDate: @_\n";
}


sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};
    local(@path) = split(/:/, $path);

    # too pesimistic?
    for ("/usr/local/bin", "/usr/share/bin", 
	 "/usr/contrib/bin", "/usr/gnu/bin", 
	 "/usr/bin", "/bin", "/usr/gnu/bin", "/usr/ucb",
	 # NT Extention
	 "/perl5/bin", 
	 "c:\\perl\\bin", "d:\\perl\\bin", "e:\\perl\\bin"
	 ) {
	push(@path, $_);
    }

    for (@path) { if (-f "$_/$f") { return "$_/$f";}}
}


sub Grep
{
    local($key, $file) = @_;

    print STDERR "Grep $key $file\n" if $debug;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/i;}
    close(IN);

    $NULL;
}


sub GetPopPasswd
{
    local($ml) = @_;
    local($buf, @buf);

    $buf = &Grep("^$ml\\s+", "$ML_DIR/etc/pop_passwd");
    $buf =~ s/^[\r\n]+$//g;
    (split(/\s+/, $buf, 2))[1];
}


sub Log
{
    print STDERR "Log: @_\n";
}


1;
