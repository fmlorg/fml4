# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# if $SUBJECT_HML_FORM = 1;
#   [Elena:100]
# 
# other candidates as follows:
sub SubjectTagDef
{
    local($mode) = @_;

    $mode =~ s/\"//g;
    $mode =~ s/\'//g;

    # (Elena 100) 
    if ($mode eq '( )') {
	$SUBJECT_FREE_FORM = 1;
	$BEGIN_BRACKET     = '(';
	$BRACKET           = $BRACKET || 'Elena';
	$BRACKET_SEPARATOR = ' ';
	$END_BRACKET       = ')';
	$SUBJECT_FREE_FORM_REGEXP = "\\($BRACKET \\d+\\)";
    }
    # [Elena 100];
    elsif ($mode eq '[ ]') {
	$SUBJECT_FREE_FORM = 1;
	$BEGIN_BRACKET     = '[';
	$BRACKET           = $BRACKET || 'Elena';
	$BRACKET_SEPARATOR = ' ';
	$END_BRACKET       = ']';
	$SUBJECT_FREE_FORM_REGEXP = "\\[$BRACKET \\d+\\]";
    }
    # (Elena:100) 
    elsif ($mode eq '(:)') {
	$SUBJECT_FREE_FORM = 1;
	$BEGIN_BRACKET     = '(';
	$BRACKET           = $BRACKET || 'Elena';
	$BRACKET_SEPARATOR = ':';
	$END_BRACKET       = ')';
	$SUBJECT_FREE_FORM_REGEXP = "\\($BRACKET:\\d+\\)";
    }
    # [Elena:100];
    elsif ($mode eq '[:]') {
	$SUBJECT_FREE_FORM = 1;
	$BEGIN_BRACKET     = '[';
	$BRACKET           = $BRACKET || 'Elena';
	$BRACKET_SEPARATOR = ':';
	$END_BRACKET       = ']';
	$SUBJECT_FREE_FORM_REGEXP = "\\[$BRACKET:\\d+\\]";
    }
}

1;
