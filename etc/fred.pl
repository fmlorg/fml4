# [SPR 64k NTT TS5] =~ /.*/ ? &NOC : &;
sub NOC
{
    local(*_, *pat, *fred, *opt) = @_;

    if (/[A-Z][A-Z][A-Z]\s+(\S+)\s+(\S+)\s+TS(\S+)/) {
	$bw = $1;
	$cv = $2;
	$ts = $3;
    }

    if (! &bwchk($bw, $ts)) {
	&Mesg("Conflict between $bw and $ts");
    }

}

sub bwchk
{
    local($bw, $ts) = @_;

    if ($bw =~ /(\d+)k/) {
	$bw = $1;
    }
    elsif ($bw =~ /(\d+)M/) {
	$bw = $1;
	if ($bw == 1)   { $bw = 1152;}
	if ($bw == 1.5) { $bw = 1536;}
    }

    if ($bw == 64) {
	($ts =~ /^\d$/) && (return 1);
    }
    else {
	for ($ts) {
	    $bwts += 64;
	}
	($bw == $bwts) && (return 1);
    }

    0;
}

1;
