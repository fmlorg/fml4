# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

sub DoSmtpFeed
{
    ;
}


sub SetupSmtpFeed
{
    local($smtpfeed);
    $smtpfeed = &SearchPath("smtpfeed", "/usr/libexec") || 
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
    local($in, $out) = @_;
    open(IN,  $in)      || (&Log("CopyIN: $!"), return);
    open(OUT, "> $out") || (&Log("CopyOUT: $!"), return);
    select(OUT); $| = 1; select(STDOUT); 
    while (<IN>) { print OUT $_;}
    close(OUT);
    close(IN); 
}


1;
