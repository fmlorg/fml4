$CONFIRM_REPLAY_SUBJECT_FUNCTION = 'myGenConfirmReplySubject';

sub myGenConfirmReplySubject
{
    local(*e, *cf, $mode) = @_;
    local($s);

    if ($debug_confirm) {
	local(@c) = caller;
	&Log("GenConfirmReplySubject<$c[2]>: $mode") if $mode ne 'Default';
    }

    # extensions for confirmd
    if ($CONFIRM_REPLAY_SUBJECT_FUNCTION) {
	return &$CONFIRM_REPLAY_SUBJECT_FUNCTION(@_);
    }

    if ($mode eq 'Default') {
	$s = "Subscribe request result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Confirmed') {
	$s = $CONFIRMATION_WELCOME_STATEMENT || $WELCOME_STATEMENT;
	# $s = "Newly added $From_address $ML_FN";
    }
    elsif ($mode eq 'Confirm::Error') {
	$s = "Subscribe with confirmation error $ML_FN";
    }
    elsif ($mode eq 'Confirm::GenPreamble') {
	$s = "$ML_FNÅÐÏ¿¤Î³ÎÇ§";
	$s = &STR2EUC($s);
	# $s = "Subscribe confirmation request $ML_FN";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    elsif ($mode eq 'Confirm::expired') {
	$s = "Subscribe confirmation expired $ML_FN";
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    else {
	&Log("GenConfirmReplySubject: unknown mode [$mode]") if $debug_confirm;
	"Subscribe request result $ML_FN";
    }
}
