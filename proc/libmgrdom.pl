# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

sub MgrdomConsider
{
    local($addr, $type) = @_;
    local($table, $result, $buf);
    local($src, $dst);

    $table = &SearchFileInLIBDIR('etc/mgrdomains');
    return $NULL unless $table;

    local($acct, $domain) = split(/\@/, $addr);

    open(TABLE, $table) || do {
	&Log("cannot open $table");
	return $NULL;
    };

    # XXX: SHOULD NOT "RETURN" WITHOUT DISABLING mode:in_mgrdom
    $Envelope{'mode:in_mgrdom'} = 1;
    while (<TABLE>) {
	next if /^\#/;
	next if /^\s*$/;

	($src, $dst) = split;

	 if ($domain =~ /$src$/i) {
	     $buf = $domain;
	     $buf =~ s/$src$/$dst/;
	     $result = &DoMailListMemberP("$acct\@$buf", $type);
	     last if $result;
	 }

	 if ($domain =~ /$dst$/i) {
	     $buf = $domain;
	     $buf =~ s/$dst$/$src/;
	     $result = &DoMailListMemberP("$acct\@$buf", $type);
	     last if $result;
	 }
    }
    $Envelope{'mode:in_mgrdom'} = 0;

    close(TABLE);

    $result;
}


1;
