#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: ntfml.pl,v 1.3 2001/05/09 15:23:00 fukachan Exp $
#

### MAIN
&Init;

$msend_watch_dog = &SetMSendWatchDog;

# main loop
for (;;) { 
    $slt = time;		# start loop time

    # A new ml may has been created a little ago, 
    # We scan $MAIL_LIST_DIR to check it.
    &GetConf; 

    &Log("===== start new session =====") if $debug;

    # POP
    for $ml (keys %IncludeFile) {
	next unless -f $IncludeFile{$ml};
	next unless $ml;

	&Log("start $ml pop session") if $debug;

	sleep($SLEEP_UNIT) if $SLEEP_UNIT;
	$p = &ArrangeProc($ml, " -mode POP_ONLY");
	system $p;
    }

    # EXEC
    for $ml (keys %IncludeFile) {
	next unless -f $IncludeFile{$ml};
	next unless $ml;

	&Log("start $ml exec session") if $debug;

	sleep($SLEEP_UNIT) if $SLEEP_UNIT;
	$p = &ArrangeProc($ml, " -mode EXEC_ONLY_ONCE");
	system $p;
    }

    &GetTime;

    # Matome Okuri (e.g. 18:00)
    # We do msend.pl if $min == 0. 
    # But this check may be ineffective if each loop is over 60 secs.
    # So we need to run another watch dog variable.
    if (($msend_watch_dog < 0) || $min == 0 || $debug_msend) {
	$debug_org = $debug; 
	$debug = 1 if $debug_msend;

	for $ml (keys %IncludeFile) {
	    next unless $ml;
	    next if !-f "$ML_DIR/$ml/config.ph";
	    next if !-f $MsendRc{$ml};
	    
	    &Log("start $ml msend session") if $debug;

	    sleep($SLEEP_UNIT) if $SLEEP_UNIT;
	    $p = &ArrangeMSendProc($ml);
	    system $p;
	}

	$msend_watch_dog = &SetMSendWatchDog;
	$debug = $debug_org if $debug_msend;
    } # $min == 0


    ### loop cost time 
    $loop_cost       = time - $slt;
    $msend_watch_dog = $msend_watch_dog - $loop_cost;

    # debug watch dog expire 
    if ($opt_o eq 'watch_dog') {
	print STDERR "msend_watch_dog: $msend_watch_dog\n";
    }

    # fml-support: 04286 <ssk@pfu.co.jp>
    if (-f "$ML_DIR/exit.sts") {
	exit 1;
    }

    # if loop cost time over $unit, sleep 3 anyway
    if ($loop_cost >= $LOOP_UNIT) {
	sleep(3);
    }
    else {
	sleep($LOOP_UNIT - $loop_cost);
    }
} # infinite loop;


exit 0; # not reached here


sub GetConf
{
    local($ml, $eval, $ctladdr, $pat);

    $pat = 
	'^\$(FQDN|DOMAINNAME|CONTROL_ADDRESS|MAINTAINER|MSEND_RC|[A-Z_]+DIR)';

    opendir(DIRD, $ML_DIR) || die("Error: cannot open ML_DIR[$ML_DIR];$!");
    for $ml (readdir(DIRD)) {
	next if /^\./;

	# special virtual ML directory
	next if $ml eq 'etc';
	next if $ml eq 'popfml';

	$cf = "$ML_DIR/$ml/config.ph";

	if (-f $cf) {
	    undef $eval;

	    # evaluate
	    $eval  = q#$DIR = "$ML_DIR/$ml";#;
	    $eval .= "\n";
	    $eval .= &Grep($pat, "$EXEC_DIR/default_config.ph");
	    $eval .= &Grep($pat, $cf);
	    eval $eval; &Log($@) if $@;

	    $MSEND_RC = $MSEND_RC =~ /$DIR/ ? $MSEDN_RC : "$DIR/$MSEND_RC";

	    ($ctladdr) = split(/\@/, $CONTROL_ADDRESS);

	    # alloc
	    if (-f "$ML_DIR/$ml/include" && &GetPopPasswd($ml, $cf)) {
		$IncludeFile{$ml}       = "$ML_DIR/$ml/include";
		$MsendList{$ml}         = "$ML_DIR/$ml";
		$MsendRc{$ml}           = $MSEND_RC;
		$Maintainer{$ml}        = $MAINTAINER;
	    }

	    # Consider null $CONTROL_ADDRESS !
	    if ($ctladdr && ($ctladdr ne $ml)) {
		if (-f "$ML_DIR/$ml/include-ctl" && 
		    &GetPopPasswd($ctladdr, $cf)) {
		    $IncludeFile{$ctladdr} = "$ML_DIR/$ml/include-ctl";

		    # reverse pointer
		    $ML{$ctladdr} = $ml;
		    $Maintainer{$ctladdr} = $MAINTAINER;
		}
	    }
	}
    } 
    closedir(DIRD);

    undef $CONTROL_ADDRESS;
}


sub SetMSendWatchDog
{
    3600 - (time % 3600);
}


sub Init
{
    require 'getopts.pl';
    &Getopts("do:xu:");

    $debug       = $opt_d;
    $debug_msend = $opt_o eq 'debug_msend' ? 1 : 0;
    $LOOP_UNIT   = $opt_u || 60*3;
    $SLEEP_UNIT  = int($LOOP_UNIT /100); # 1 by default

    ### COMPAT CODE ###
    if ($ENV{'OS'} =~ /Windows_NT/) {
	$HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 0;
	$COMPAT_ARCH = "WINDOWS_NT4";
	$COMPAT_WIN32 = 1;
    }
    
    if ($COMPAT_ARCH eq "WINDOWS_NT4") {
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

	# wrapper for timeout
	$Wrapper = $EXEC_DIR.'\wrapper.pl';
    }
    else {
	$PerlProgram = &search_path('perl');
	require '.fml/system';
    }


    ### default values ###
    $|          = 1;
    $TIME_SLICE = 5; # 5 sec.
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


sub search_path
{
    local($f) = @_;
    local($p, @path);

    # cache on
    if ($PathCache{$f}) { return $PathCache{$f};}

    if ($COMPAT_ARCH eq "WINDOWS_NT4") { 
	@path = split(/;/, $ENV{'PATH'});
    }
    else {
	@path = split(/:/, $ENV{'PATH'});
    }

    # too pesimistic?
    for ("/usr/local/bin", "/usr/share/bin", 
	 "/usr/contrib/bin", "/usr/gnu/bin", 
	 "/usr/bin", "/bin", "/usr/gnu/bin", "/usr/ucb",
	 # NT Extention
	 "/perl5/bin", 
	 "c:\\perl\\bin", "d:\\perl\\bin", "e:\\perl\\bin",
	 ) {
	push(@path, $_);
    }

    for (@path) { 
	$p = $_ ; $p =~ s#\\#/#g;
	if (-f "$p/$f") { 
	    $PathCache{$f} = "$_/$f";
	    return "$_/$f";
	}
    }

    print STDERR "$f is not found\n";
    $f; # try anyway 
}


sub ArrangeProc
{
    local($ml, $ap) = @_;
    local($p, $qd);

    # each queue directory for each ML.
    $m = $ML{$ml} || $ml;
    $qd = "$ML_DIR/$m/var/mq.$ml";

    # make queue directory
    -d $qd || &MkDirHier($qd);

    $p  = "$PerlProgram $Wrapper -p $PerlProgram ";
    $p .= "$PopFmlProg ";
    $p .= "-d " if $debug;
    $p .= "$ML_DIR/popfml $EXEC_DIR ";
    $p .= "-user $ml -host $POP_SERVER ";
    $p .= "-include_file $IncludeFile{$ml} ";
    $p .= "-pop_passwd $ML_DIR/etc/pop_passwd ";
    $p .= "-perl_prog $PerlProgram ";
    $p .= "-arch $COMPAT_ARCH ";
    $p .= "-queue_dir $qd ";
    $p .= "-M $Maintainer{$ml} ";
    $p .= "$ap";

    if ($debug) {
	print STDERR "\n\nArrangeProc:\n";
	print STDERR "Perl   \t$PerlProgram\n";
	print STDERR "Process\t$p\n";
    }

    $p;
}


sub ArrangeMSendProc
{
    local($ml) = @_;
    local($p);

    $p  = "$PerlProgram $Wrapper -p $PerlProgram ";
    $p .= "$EXEC_DIR/msend.pl ";
    $p .= "$ML_DIR/$ml $EXEC_DIR ";
    $p .= "-d " if $debug;
    $p .= "--COMPAT_ARCH=$COMPAT_ARCH " if $COMPAT_ARCH;

    if ($debug) {
	print STDERR "\nArrangeProc:\n";
	print STDERR "Perl   \t$PerlProgram\n";
	print STDERR "Process\t$p\n\n";
    }

    $p;
}


sub Grep
{
    local($key, $file) = @_;
    local($s);

    &Log("Grep $key $file") if $debug;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { $s .= $_ if /$key/i;}
    close(IN);

    $s;
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
    &GetTime;
    print STDERR ">>> $Now @_\n";
}


sub MkDirHier
{
    local($pat) = $UNISTD ? '/|$' : '\\\\|/|$'; # on UNIX or NT4

    while ($_[0] =~ m:$pat:g) {
	next if (!$UNISTD) && $` =~ /^[A-Za-z]:$/; # ignore drive letter on NT4

	if ($` ne "" && !-d $`) {
	    mkdir($`, $_[1] || 0777) || do {
		&Log("cannot mkdir $`: $!"); 
		return 0;
	    };
	}
    }

    1;
}


1;
