sub NotifyMailSizeOverFlow
{
    local(*e) = @_;
    local($subj, $body);

    &Log("Error: in-coming mail body size > $INCOMING_MAIL_SIZE_LIMIT");
    &Log("Forward to \$MAINTAINER");

    $subj = 
	"Error: In-coming mail body size > $INCOMING_MAIL_SIZE_LIMIT $ML_FN";
	
    $body = "--- Error ---\n";
    $body .= 
	"In-coming mail size exceeds $INCOMING_MAIL_SIZE_LIMIT bytes\n\n";

    $e{'ctl:smtp:stdin2socket'} = 1;
    &Warn($subj, $body.$e{'Body'});
    undef $e{'ctl:smtp:stdin2socket'};
}

1;
