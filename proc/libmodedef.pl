# Library of fml.pl 
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

sub FmlServMode
{
    $MAINTAINER      = "fmlserv-admin\@$DOMAINNAME";
    $CONTROL_ADDRESS = "fmlserv\@$DOMAINNAME";
}


sub FmlMode
{
    local($name, $domain) = split(/\@/, $MAIL_LIST);
    $MAINTAINER      = "${name}-admin\@$domain";
    $CONTROL_ADDRESS = "${name}-ctl\@$domain";
}


sub HmlMode
{
    local($name, $domain) = split(/\@/, $MAIL_LIST);

    $SUBJECT_HML_FORM              = 1;
    $BRACKET                       = $name;
    $SUPERFLUOUS_HEADERS           = 1;
    $STRIP_BRACKETS                = 1;
    $AGAINST_NIFTY                 = 1;
}


sub DistributeMode
{
    local($name, $domain) = split(/\@/, $MAIL_LIST);

    $SUBJECT_FREE_FORM = 1;
    $BEGIN_BRACKET     = '[';
    $BRACKET           = $name;
    $BRACKET_SEPARATOR = ' ';
    $END_BRACKET       = ']';
    $SUBJECT_FREE_FORM_REGEXP = "\\[$BRACKET \\d+\\]";
}

1;
