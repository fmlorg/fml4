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
# $FML: wrapper.pl,v 1.2 2001/05/09 15:23:00 fukachan Exp $

### INFO
# Win32::Process module
#
# $CurProc
# $CurProc->Suspend();
# $CurProc->Resume();
# $CurProc->Wait(1000); # the unit is "msec"
#
# Wait($Timeout)
#
#    $Timeout
#      The number of milliseconds to wait for process to end, for no timeout
#      value, use INFINITE.
#
# Wait for the process to exit. 
# Wait returns FALSE if it times out. $! Is set to
# WAIT_FAILED in this case.
#
# $CurProc->Kill(1);
#
# *** ATTENTION! ***
# Create() CANNOT READ "/" path syntax;
# Only in this call, we need to user 'c:\perl' .. syntax ;_;
# 

&Run;

exit 0;

sub Run
{
    use Win32::Process;
    use Win32;

    require 'getopts.pl';
    &Getopts("fp:t:");

    $TIMEOUT  = $opt_t || 3600;
    $PerlProg = $opt_p;
    ($exec, @argv) = @ARGV;
    $argv = join(" ", @argv);
    $argv =~ s#\\#/#g;

    &Win32::Process::Create($CurProc, 
			    $PerlProg, 
			    "perl $exec $argv --COMPAT_ARCH=WINDOWS_NT4",
			    1,
			    CREATE_SUSPENDED, ".") || die ErrorReport();


    # $CurProc->SetPriorityClass(NORMAL_PRIORITY_CLASS);
    $CurProc->SetPriorityClass(IDLE_PRIORITY_CLASS);
    $CurProc->Resume();

    $TIMEOUT = $TIMEOUT * 1000;

    $r = $CurProc->Wait($TIMEOUT);

    if (! $r) { 
	&GetTime;
	print STDERR "$MailDate TimeOut $exec $argv\n";
    }

    $CurProc->Kill(1);
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


1;
