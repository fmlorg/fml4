# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libMIMEId   = q$Id$;
($libMIMEId) = ($libMIMEId =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid .= "/$libMIMEId";

require 'mimer.pl';

sub DecodeMimeStrings
{
    local($StoredMailHeaders) = @_;

    return &mimedecode($StoredMailHeaders);
}

1;
