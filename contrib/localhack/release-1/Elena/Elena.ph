# $Id$
#
### User Custumize ###

# the Main Command
$VOTING            = "$DIR/vote.pl";
$MAKESUMMARY       = "$DIR/summary.pl";

# jis -> EUC for mail   -> Elena
$JCONVERTER         = "/usr/sony/bin/jconv -je";

# EUC -> jis for Elena -> mail
$REVERSE_JCONVERTER = "/usr/sony/bin/jconv -ej";

# when send back a mail of the presetnt vote summary
$SUMMARY_SUBJECT        = "$ML_FN\n\tThe Present Summary of Elena Server";

# when cancel request
$CANCEL_NOFILE_SUBJECT  = "$ML_FN\n\tI cannot find the vote, the number ";
$CANCEL_NOFILE_BODY     = "No matched to your request.\nPlease check your number\n";
$CANCEL_SUBJECT         = "$ML_FN\n\tCanceled for your vote, the Number ";
$CANCEL_NO_AUTHENTICATED_SUBJECT = "$ML_FN\n\tYou are not authenticated in canceling ";

# in voting process, return a receipt message to the voter.
$ELENA_SERVER_SUBJECT  = "$ML_FN\n\tI have received your vote. Your number is ";
$RETURN_MAIL_BODY_FIRST = "Elena Voting Server accepts your vote as follows:\n";
$RETURN_MAIL_BODY_1     = "--- Your vote is accepted as below ---\n\n";
$RETURN_MAIL_BODY_2     = "--- Your vote is original as below ---\n\n";
$RETURN_MAIL_BODY_3     = "--- Guide and Usage of this server is ---\n\n";

### Custumize ends ###

1;
