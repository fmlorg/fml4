# $Id$
###### User Custumize Parameters #####

$COMMENT_STRING     = 'comment';
$END_COMMENT_STRING = 'endcomment';

@keywords           = ('new', 'all'); 
#, 'si', 'ra', 'to', 'new', 'all', 'si', 'ra', 'to');
@maxkeywords        = ('5', '5', '5', '5', '5', '5', '5', '5', '5', '5');

# files for logging
$DIR		    = $DIR ? $DIR : $ENV{'PWD'};
$RESULTDIR          = "$DIR/result";
$COMMENT_LOG        = "$RESULTDIR/comment_log";
$LOGFILE            = "$DIR/logfile";
$debug              = 0; # global debug option

1;
