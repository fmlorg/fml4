# Library of fml.pl 
# Copyright (C) 1996      kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

sub MLAddr
{
    local($addr) = @_;

    local($name, $domain) = split(/\@/, $addr);

    $DOMAINNAME                    = $domain;
    $MAIL_LIST                     = "${name}\@$domain";
    $ML_FN                         = "($name ML)";
    $XMLNAME                       = "X-ML-Name: $name";
    $XMLCOUNT                      = "X-Mail-Count";
    $MAINTAINER                    = "${name}-request\@$domain";
    $CONTROL_ADDRESS               = "${name}-ctl\@$domain";

    if ($debug) {
	print STDERR "\nSeveral Variables are set as follows:\n\n";

	for (DOMAINNAME, FQDN, MAIL_LIST, ML_FN, XMLNAME,
	     XMLCOUNT, MAINTAINER, CONTROL_ADDRESS) {
	    eval "printf STDERR \"%-20s\t%s\n\", $_, \$$_;";
	}

	print STDERR "\n";
    }
}

1;
