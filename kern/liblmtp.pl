# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

use vars qw($debug);
no strict qw(subs);

sub DoSmtpFeed
{
    ;
}


sub SetupSmtpFeed
{
    my $smtpfeed = &SearchPath("smtpfeed", "/usr/libexec") || 
	"/usr/libexed/smtpfeed";

    require 'open2.pl';
    if (&open2(RS, S, $smtpfeed)) { 
	&Log("open2(RS, S, $smtpfeed)") if $debug;
    }
    else {
	&Log("SmtpIO: cannot exec $smtpfeed");
	return "SmtpIO: cannot exec $smtpfeed";
    };
}


package lmtp;

sub Copy
{
    my ($in, $out) = @_;
    my ($mode) = (stat($in))[2];

    open(COPYIN,  $in)      || (&Log("ERROR: Copy::In [$!]"), return 0);
    open(COPYOUT, "> $out") || (&Log("ERROR: Copy::Out [$!]"), return 0);
    select(COPYOUT); $| = 1; select(STDOUT);

    chmod $mode, $out;
    while (sysread(COPYIN, $_, 4096)) { print COPYOUT $_;}
    close(COPYOUT);
    close(COPYIN); 

    1;
}


1;
