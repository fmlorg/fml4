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

&use('modedef');

sub MLAddr
{
    local($addr) = @_;

    # Loading the Default Entries
    require 'libcompat_cf1.pl';

    local($name, $domain) = split(/\@/, $addr);
    local($host);
    chop($host = `hostname`);

    # if has . , already FQDN form.
    $FQDN = ($host !~ /\./) ? "$host.$domain" : $host;

    $DOMAINNAME      = $domain;
    $MAIL_LIST       = "${name}\@$domain";
    $ML_FN           = "($name ML)";
    $XMLNAME         = "X-ML-Name: $name";
    $XMLCOUNT        = "X-Mail-Count";
    $MAINTAINER      = "${name}-request\@$domain";
    $CONTROL_ADDRESS = "${name}-ctl\@$domain";

    if ($debug) { # command line -d is not effective here
	print STDERR "\nSeveral Variables are set as follows:\n\n";

	for (DOMAINNAME, FQDN, MAIL_LIST, ML_FN, XMLNAME,
	     XMLCOUNT, MAINTAINER, CONTROL_ADDRESS) {
	    eval "printf STDERR \"%-20s\t%s\n\", $_, \$$_;";
	}

	print STDERR "\n";
    }
}

1;
