# Library of fml.pl 
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

#
# CmpPasswdInFile($file, $from, $passwd);
#
sub ModeratedDelivery
{
    local(*e) = @_;
    local($passwd); 

    if ($passwd = $e{'h:approval:'}) {
	&use('crypt');
	if (&CmpPasswdInFile($PASSWD_FILE, $From_address, $passwd)) {
	    &Log("Moderated: Approval OK");
	    $Rcsid =~ s/\#:/(Moderated mode)#:/;
	    undef $e{'h:approval:'}; # delete the passwd entry;
	    undef $e{'h:Approval:'}; # delete the passwd entry;
	    &Distribute(*e);
	}
	else {
	    &Log("Moderated: Approval FAILED");
	    &Warn("Moderated: Approval FAILED", &WholeMail);
	}
    }
    else {
	$e{'h:Reply-To:'} = $MAIL_LIST;
	&Warn("Forwarded Message: [MODERATED MODE]",
	      "Please check the following mail\n".&WholeMail);
    }
}

1;
