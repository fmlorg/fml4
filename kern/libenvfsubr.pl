package EnvelopeFilter;

sub Log { &main::Log(@_);}

sub MakeParagraphMap
{
    local(*e, *pmap, $buf) = @_;
    my($p, $rp, $xp, $bodylen);
    my($debug) = $main::debug;

    $p       = 0; 
    $bodylen = length($buf ? $buf : $e{'Body'}); # body length

    # return now
    return $p if $bodylen == 0;

    # skip the first null lines. (not find any paragraph yet)
    if ($buf) {
	while (substr($buf, $p, 1) eq "\n") { $p++;}
    }
    else {
	while (substr($e{'Body'}, $p, 1) eq "\n") { $p++;}
    }
    push(@pmap, $p);

    # XXX not find any paragraph yet
    # make @pmap paragraph map
    for ( $xp = $p; ; ) {
	if ($buf) {
	    $xp = index($buf, "\n\n", $p);
	}
	else {
	    $xp = index($e{'Body'}, "\n\n", $p);
	}
	&Log("xp=$xp, p=$p < bodylen=$bodylen") if $debug;

	if ($xp < $p || $xp >= $bodylen) { # search fail or EOB
	    push(@pmap, $bodylen);
	    $n_paragraph++ if $rp < $bodylen; # the last paragraph (without "\n\n")
	    last;
	}
	else {
	    # skip trailing null lines
	    if ($buf) {
		while (substr($buf, $xp, 1) eq "\n") { $xp++;}
	    }
	    else {
		while (substr($e{'Body'}, $xp, 1) eq "\n") { $xp++;}
	    }


	    # the first pointer of the next paragraph
	    $p = $xp;
	    push(@pmap, $p) if $p > 0;
	    $n_paragraph++;
	}
    }

    &Log("pmap($#pmap): @pmap / n_papagraph=$n_paragraph") if $debug;

    if ($debug) {
	my($i);
	for ($i = 0; $i < $#pmap ; $i++) {
	    print STDERR ($i + 1), "($pmap[$i],$pmap[$i+1]):[";
	    if ($buf) {
		print STDERR 
		    substr($buf, $pmap[$i], $pmap[$i+1] - $pmap[$i]);
	    }
	    else {
		print STDERR 
		    substr($e{'Body'}, $pmap[$i], $pmap[$i+1] - $pmap[$i]);
	    }
	    print STDERR "]\n";
	}
    }

    $pmap[ $#pmap ];
}


sub CleanUpBuffer
{
    local($xbuf) = @_;

    # 1. cut off Email addresses (exceptional).
    $xbuf =~ s/\S+@[-\.0-9A-Za-z]+/account\@domain/g;

    # 2. remove invalid syntax seen in help file with the bug? ;D
    $xbuf =~ s/^_CTK_//g;
    $xbuf =~ s/\n_CTK_//g;

    $xbuf;
}


sub SignatureP
{
    local(*e, *pmap, $lparbuf) = @_;
    my($one_line_check_p) = 0;
    my($n_paragraph) = $#pmap;

    if ($n_paragraph == 1) { $one_line_check_p = 1;}
    if ($n_paragraph == 2) { 
	if ($lparbuf =~ /\@/ || 
	    $lparbuf =~ /TEL:/i ||
	    $lparbuf =~ /FAX:/i ||
	    $lparbuf =~ /:\/\// ) {
	    $one_line_check_p = 1; 
	}
    }

    $one_line_check_p;
}


1;
