#-*- perl -*-
#
# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

sub SecureP
{
    my ($ok) = 0;

    &P("ERROR: ML is empty.")   unless $ML;
    &P("ERROR: PROC is empty.") unless $PROC;

    my ($secure_pat) = '[A-Za-z0-9\-_]+';
    my ($mail_addr)  = '[A-Za-z0-9\.\-_]+\@[A-Za-z0-9\.\-]+';
    my ($account)    = '[A-Za-z0-9\-_]+';

    if ($ML !~ /^($secure_pat)$/i) {
	&P("ERROR: ML is insecure.");
	0;
    }
    elsif ($PROC !~ /^($secure_pat)$/i) {
	&P("ERROR: PROC is insecure.");
	0;
    }
    elsif ($LANGUAGE && ($LANGUAGE !~ /^[A-Za-z]+$/)) {
	&P("ERROR: LANGUAGE is insecure.");
	0;
    }
    elsif ($MAIL_ADDR && ($MAIL_ADDR !~ /^($mail_addr)$/)) {
	&P("ERROR: MAIL_ADDR is insecure.");
	0;
    }
    elsif ($CGI_ADMIN_USER && ($CGI_ADMIN_USER !~ /^($mail_addr|$account)$/)) {
	&P("ERROR: CGI_ADMIN_USER is insecure.");
	0;
    }
    elsif ($VARIABLE && ($VARIABLE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VARIABLE $VARIABLE is insecure.");
	0;	
    }
    elsif ($VALUE && ($VALUE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VALUE is insecure.");
	0;	
    }
    elsif ($OPTION && ($OPTION !~ /^($secure_pat)$/i)) {
	&P("ERROR: OPTION is insecure.");
	0;	
    }
    elsif ($ACTION && ($ACTION !~ /^($secure_pat)$/i)) {
	&P("ERROR: ACTION is insecure.");
	0;	
    }
    elsif ($MTA && ($MTA !~ /^([a-z]+)$/i)) {
	&P("ERROR: MTA is insecure.");
	0;	
    }
    elsif ($PTR && ($PTR !~ /^([0-9A-Z_\/]+)$/i)) {
	&P("ERROR: PTR is insecure.");
	0;	
    }
    else {
        # if (@PROC_ARGV) { 1;} # check 'ARGV'

	$ok = 1;
    }

    # checkd in each routine
    {
	$Config{'YYYY'};
	$Config{'MM'};
	$Config{'DD'};
	$Config{'TAIL_SIZE'};
    }

    # ambiguous (cannot restrict it ...)
    {
	$Config{'PASSWORD'};
	$Config{'PASSWORD_VRFY'};
    }

    $ok;
}


1;
