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

sub MD5_cksum
{
    local(*e, $prog) = @_;
    local($cksum, @path);

    @path = ('/usr/bin', '/sbin', '/usr/local/bin', '/usr/gnu/bin', 
	     '/usr/pkg/bin');

    $prog = $prog || $MD5 || 
	&SearchPath('md5', @path) || 
	    &SearchPath('md5sum', @path);

    if ($prog && -x $prog) {
	require 'open2.pl';
	if (&open2(R_CKSUM, W_CKSUM, $prog)) { 
	    &Log("open2(RS, S, $prog)") if $debug;
	    print W_CKSUM $e{'Body'};
	    close(W_CKSUM);
	    sysread(R_CKSUM, $cksum, 1024);
	    $cksum =~ s/[\s\n]*$//;
	    close(R_CKSUM);
	}
	else {
	    &Log("Error: cannot open2(RS, S, $prog)") if $debug;
	}

	$cksum;
    }
}


sub MailBodyCksum
{
    local(*e) = @_;
    local(@path, $prog);

    if ($MD5 && -x $MD5) {
	$prog = $MD5;
    }
    else {
	@path = ('/usr/bin', '/sbin', '/usr/local/bin', '/usr/gnu/bin', 
		 '/usr/pkg/bin');
	$prog = &SearchPath('md5', @path) || &SearchPath('md5sum', @path);
    }

    # perl 5
    if ($] =~ /^5/ && &PerlModuleExistP('MD5')) {
	&Log("MD5.pm") if $debug_cksum;
	&use('md5');
	$mid = &MailBodyMD5Cksum(*e);
    }
    elsif ($prog && -x $prog) {
	&Log("run prog=$prog") if $debug_cksum;
	&use('cksum');
	$mid = &MD5_cksum(*e, $prog);
    }
    else {
	&Log("Error: neither MD5.pm nor program 'md5' found");
	$NULL;
    }
}


sub CheckMailBodyCKSUM
{
    local(*e) = @_;
    local($status, $mid);

    $CHECK_MAILBODY_CKSUM || return 0;

    $mid = &MailBodyCksum(*e);

    if ($mid) {
	$status = &SearchDupKey($mid, $LOG_MAILBODY_CKSUM);
    }
    else {
	&Log("Error: cannot get cksum value");
	return 0;
    }

    if ($status) {
	local($s) = "Duplicated mail body CKSUM";
	&Log("Loop Alert: $s");
	&Warn("Loop Alert: $s $ML_FN", 
	      "$s in <$MAIL_LIST>.\n\n".&WholeMail);
	1;
    }
    else {
	&Log("md5cksum: not looped") if $debug_cksum;
	0;
    }
}


sub CacheMailBodyCksum
{
    local(*e, $id) = @_;
    local($id);
    
    $CHECK_MAILBODY_CKSUM || return 0;

    $id = $msgid || &MailBodyCksum(*e);

    if ($CachedMailBodyCksum{$id}) {
	&Log("CacheMailBodyCksum: warning: duplicated input") if $debug_loop;
	return 0;
    }

    # Turn Over log file (against too big);
    # The default value is evaluated as "once per about 100 mails".
    &CacheTurnOver($LOG_MAILBODY_CKSUM,
		   $MESSAGE_ID_CACHE_BUFSIZE || 60*100);

    $CachedMailBodyCksum{$id} = 1;
    &Append2($id." \# $PCurrentTime", $LOG_MAILBODY_CKSUM);
}


1;
