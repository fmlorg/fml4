# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#


no strict qw(subs);
use vars qw($debug $debug_cksum);
use vars qw($PCurrentTime);
use vars qw(%CachedMailBodyCksum);


sub MD5_cksum
{
    use vars qw(%e $prog);
    local(*e, $prog) = @_;
    my ($cksum, @path);

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
	    &Log("ERROR: cannot open2(RS, S, $prog)") if $debug;
	}

	$cksum;
    }
}


sub MailBodyCksum
{
    local(*e) = @_;
    my (@path, $prog);
    my $mid = 0;

    if ($MD5 && -x $MD5) {
	$prog = $MD5;
    }
    else {
	@path = ('/usr/bin', '/sbin', '/usr/local/bin', '/usr/gnu/bin', 
		 '/usr/pkg/bin');
	$prog = &SearchPath('md5', @path) || &SearchPath('md5sum', @path);
    }

    # perl 5
    if ($] =~ /^5/ && &SearchFileInINC('MD5.pm')) {
	&Log("MD5.pm") if $debug_cksum;
	&use('md5');
	$mid = &MailBodyMD5Cksum(*e);
    }
    elsif ($prog && -x $prog) {
	&Log("run prog=$prog") if $debug_cksum;
	$mid = &MD5_cksum(*e, $prog);
    }
    else {
	&Log("ERROR: neither MD5.pm nor program 'md5' found");
	$mid = '';
    }

    return $mid;
}


sub CheckMailBodyCKSUM
{
    local(*e) = @_;
    my ($status, $mid);

    $CHECK_MAILBODY_CKSUM || return 0;

    $mid = &MailBodyCksum(*e);

    if ($mid) {
	$status = &SearchDupKey($mid, $LOG_MAILBODY_CKSUM);
    }
    else {
	&Log("ERROR: cannot get cksum value");
	return 0;
    }

    if ($status) {
	my ($s) = "Duplicated mail body CKSUM";
	&Log("Loop Alert: $s");
	&WarnE("Loop Alert: $s $ML_FN", "$s in <$MAIL_LIST>.\n\n");
	1;
    }
    else {
	&Log("md5cksum: not looped") if $debug_cksum;
	0;
    }
}


sub CacheMailBodyCksum
{
    use vars qw(%e $id);
    local(*e, $id) = @_;
    
    $CHECK_MAILBODY_CKSUM || return 0;

    $id = $id || &MailBodyCksum(*e);

    if ($CachedMailBodyCksum{$id}) {
	&Log("CacheMailBodyCksum: warning: duplicated input") if $debug;
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
