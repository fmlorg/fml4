#!/usr/local/bin/perl
#
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

%config = (
	   'INCOMING_MAIL_SIZE_LIMIT', 512000,
	   'USE_DISTRIBUTE_FILTER',    1,
	   'USE_MTI',                  1,
	   'USE_LOG_MAIL',             1,
	   );


while (<>) {
    chop;

    if (/^LOCAL_CONFIG/) {
	for $key (keys %config) {
	    next unless $config{$key};
	    print "$key\t\t$config{$key}\n";
	}
    };

    for $key (keys %config) {
	s/^$key\s*/$key\t\t$config{$key}/ && (delete $config{$key});
    }

    print $_, "\n";

    if (eof) {
	print "# FOR SECURITY, Disable user to retrieve member list\n";
	print 
	    "\@DenyProcedure = ('member', 'active', 'members', 'actives');\n";
    }
}

exit 0;
