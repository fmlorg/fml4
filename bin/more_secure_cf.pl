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
	   'INCOMING_MAIL_SIZE_LIMIT',   512000,
	   'USE_DISTRIBUTE_FILTER',      1,
	   'FILTER_ATTR_REJECT_COMMAND', 1,
	   'FILTER_ATTR_REJECT_MS_GUID', 1,
	   'USE_MTI',                    1,
	   'USE_LOG_MAIL',               1,
	   );


while (<>) {
    chop;

    if (/^LOCAL_CONFIG/) {
	for $key (keys %config) {
	    next unless $config{$key};
	    &Write($key, $config{$key});
	    &P($key, $config{$key});
	}

	print "\n\n";
    };

    for $key (keys %config) {
	# remove entry
	if (/^$key\s+(\S+)/) { 
	    $x = $1;

	    if (! $x) {
		&P($key, $config{$key});
		&Write($key, $config{$key});
	    }

	    # remove entry which appended in the last
	    delete $config{$key};

	    next;
	}
    }

    print $_, "\n";

    if (eof) {
	print STDERR "  --append the following perl statements\n";
	print STDERR "\t# Append \@DenyProcedure PPEND FOR SECURITY\n";
	print STDERR "\t# to disable user to retrieve member list\n";
	print STDERR "\t\@DenyProcedure = ('member', 'active', 'members', 'actives', 'status');\n";
	print STDERR "\n";

	print "# FOR SECURITY, Disable user to retrieve member list\n";
	print 
	    "\@DenyProcedure = ('member', 'active', 'members', 'actives', 'status');\n";
    }
}

exit 0;

sub P
{
    printf STDERR "\t\$%-30s  =>  %s\n", @_;
}

sub Write
{
    printf "%-30s  %s\n", @_;
}
