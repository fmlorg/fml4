# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# Example of CF Definition;
#
# # STATIC BRIDGE
# GW smtp-ignmx: aoi.uja.org
# DOM uja.org
#

# attention! largest match
sub RelayHack
{
    local($mx, $domain);

    &Open(CF_DEF, $CF_DEF) || return 0;
    while (<CF_DEF>) {
	next if /^\#/o;	 # skip comment and off member
	next if /^\s*$/o; # skip null line

	/^GW\s+smtp-ignmx:\s*(\S+)/ && ($mx = $1);
	/^DOM\s+(\S+)/ && ($domain = $1);

	if ($mx && $domain) {
	    $RELAY_SERVER{$domain} = $mx;
	    undef $mx; undef $domain; # reset;
	}
    }
    close(CF);
}

1;
