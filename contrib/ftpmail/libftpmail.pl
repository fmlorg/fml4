# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

&Ftpmail_00 if ($LOAD_LIBRARY eq 'libftpmail.pl') || (!$MASTER_FML);

sub OldFtpmail_00
{
    require 'libutils.pl';
    require 'libftp.pl';
    &Ftp(*Envelope);
}

# may be a DUPLICATED SUBROLUTINE
if (! defined(&InSecureP)) {
    sub InSecureP
    {
	local($ID) = @_;
	if ($ID =~ /..\//o || $ID =~ /\`/o){ 
	    &Logging("Insecure matching: $ID  -> $`($&)$'");
	    &Sendmail($MAINTAINER, "Insecure $ID from $From_address. $ML_FN");
	    return 1;
	}
    }
}

1;
