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

require 'getopts.pl';
&Getopts("df:c:");

$DIR  = $0;
$DIR  =~ s#(.*/).*$#$1#;
$DIR .= "../etc/makefml";

$PARAM_CONFIG = $opt_c || "$DIR/secure_config.ph";
$LOCAL_CONFIG = $opt_f || "$DIR/secure_local_config";

require $PARAM_CONFIG;

while (<>) {
    chop;

    if (/^LOCAL_CONFIG/) {
	for $key (keys %SecureConfig) {
	    next unless $SecureConfig{$key};
	    &Write($key, $SecureConfig{$key});
	    &P($key, $SecureConfig{$key});
	}

	print "\n\n";
    };

    for $key (keys %SecureConfig) {
	# remove entry
	if (/^$key\s+(\S+)/) { 
	    $x = $1;

	    if (! $x) {
		&P($key, $SecureConfig{$key});
		&Write($key, $SecureConfig{$key});
	    }

	    # remove entry which appended in the last
	    delete $SecureConfig{$key};

	    next;
	}
    }

    print $_, "\n";

    if (eof) {
	print STDERR "  --append the following perl statements\n";
	print STDERR "\t# Append \@DenyProcedure PPEND FOR SECURITY\n";
	print STDERR "\t# to disable user to retrieve member list\n";
	print STDERR "\t\@DenyProcedure = ('member', 'active', 'members', 'actives', 'status', 'stat');\n";
	print STDERR "\n";

	&Output($LOCAL_CONFIG);
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

sub Output
{
    local($f) = @_;

    if (open($f, $f)) {
	while (<$f>) {
	    print $_;
	}
	close($f);
    }
    else {
	print STDERR "   cannot open $f\n";
    }
}
