# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;
#

use vars qw($debug $debug_smtp $debug_relay);


# Example of CF Definition;
#
# # STATIC BRIDGE
# GW smtp-ignmx: aoi.uja.org
# DOM uja.org
#

# attention! largest match
sub RelayHack
{
    local($gw, $domain, $negative_gw);

    if (! open(CF_DEF, $CF_DEF)) { return 0;}
    while (<CF_DEF>) {
	next if /^\#/o;	  # skip comments
	next if /^\s*$/o; # skip null line

	tr/A-Z/a-z/; # lower case;

	# CF Definitions
	# GW  relay host;
	if (/^(GW|NGW)/i) {
	    undef $negative_gw;
	    s/\S+://;
	    if (/^GW\s+(\S+)/i)  { $gw = $1;}
	    if (/^NGW\s+(\S+)/i) { $negative_gw = 1; $gw = $1;}
	    next;
	}

	# DOM domain (may be multiple lines, multiple domains);
	/^DOM\s+(.*)/i && ($domain = $1);

	# 'domains <=> one mx' available (saito@sol.cs.ritsumei.ac.jp)
	if ($negative_gw) {
	    for (split(/\s+/, $domain)) { 
		$RELAY_NGW{$_} = $gw;
		$RELAY_NGW_DOM{$gw} .= $RELAY_NGW_DOM{$gw} ? " $_" : $_;
	    }
	}
	else {
	    for (split(/\s+/, $domain)) { $RELAY_GW{$_} = $gw;}
	}
    }
    close(CF_DEF);

    if ($debug_relay) {
	while (($k, $v) = each %RELAY_GW)  { print STDERR "GW\t$k\t$v\n";}
	while (($k, $v) = each %RELAY_NGW) { print STDERR "NGW\t$k\t$v\n";}
    }
}

# if $already_relay == 1, rcpt == @relay:user@domain form;
sub SearchNegativeGw
{
    local($rcpt, $already_relay) = @_;
    local($match, $ngw);

    # @relay:user@domain or @relay2,@relay1:user@domain
    if ($already_relay) { ($rcpt) = split(/[,:]/, $rcpt);}

    # not_domains -> negative-gw 
    for $ngw (keys %RELAY_NGW_DOM) {
	$match = 0;
	for (split(/\s+/, $RELAY_NGW_DOM{$ngw})) {
	    $rcpt =~ /$_$/ && $match++;
	}

	# if anything matches, fails;
	if (! $match) { return $ngw;}
    }

    return $NULL;
}

1;
