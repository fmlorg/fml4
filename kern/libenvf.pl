# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

# Called under $USE_DISTRIBUTE_FILTER is not null.
# IF *HOOK is not defined, we apply default checkes.
# The function name looks strange but this is derived from
# that "filtering for %Envelope hash, not only mail message/body".
sub __EnvelopeFilter
{
    local(*e, $mode) = @_;
    local($c, $p, $r, $org_mlp, $bodylen);

    # basic parameter
    $bodylen = length($e{'Body'});

    # force plural line match
    $org_mlp = $*;
    $* = 0;

    # compatible 
    # appending twice must be no problem since statments is "return".
    $DISTRIBUTE_FILTER_HOOK .= $REJECT_DISTRIBUTE_FILTER_HOOK;
    $COMMAND_FILTER_HOOK    .= $REJECT_COMMAND_FILTER_HOOK;

    if ($mode eq 'distribute' && $DISTRIBUTE_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *DISTRIBUTE_FILTER_HOOK);
    }
    elsif ($mode eq 'command' && $COMMAND_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *COMMAND_FILTER_HOOK);
    }

    ### Part I. Check Invalid Header ###
    if ($r) {
	; # O.K.
    }
    # reject for some header field patterns.
    elsif (%REJECT_HDR_FIELD_REGEXP) {
	local($hf, $pat, $match);

	for $hf (keys %REJECT_HDR_FIELD_REGEXP) {
	    next unless ($hf && $REJECT_HDR_FIELD_REGEXP{$hf});

	    $pat = $REJECT_HDR_FIELD_REGEXP{$hf};

	    if ($pat =~ m@/i$@) { # case insensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		$e{"h:$hf:"} =~ /$pat/i && $match++;
	    }
	    else {		# case sensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		$e{"h:$hf:"} =~ /$pat/ && $match++;
	    }

	    if ($match) {
		&Log("EnvelopeFilter: \$REJECT_HDR_FIELD_REGEXP{\"$hf\"} HIT");
		$r = "reject for invalid $hf field.";
		last;
	    }
	}
    }


    ### Part II. Check Body Content ####
    # XXX malloc() too much?
    # If multipart, check the first block only.
    # If plaintext, check the first two paragraph or 1024 bytes.
    local($xbuf);

    if ($e{'MIME:boundary'}) {
	$xbuf = &GetFirstMultipartBlock(*e);
    }
    else {
	$p = 0;
	while (substr($e{'Body'}, $p, 1) eq "\n") { $p++;} # skip null lines.

	# 1. skip plural null lines like as one line
	# 2. extract the first 3+1 paragraphs or the first 1024 bytes 
	# 3. last 1 paragraph to be cut off (remove the last part as a signature)
	$p = index($e{'Body'}, "\n\n", $p);
	while (substr($e{'Body'}, $p, 1) eq "\n") { $p++;} # skip null lines.
	$p = index($e{'Body'}, "\n\n", $p + 1);
	while (substr($e{'Body'}, $p, 1) eq "\n") { $p++;} # skip null lines.
	$p = index($e{'Body'}, "\n\n", $p + 1);
	while (substr($e{'Body'}, $p, 1) eq "\n") { $p++;} # skip null lines.
	$p = index($e{'Body'}, "\n\n", $p + 1);

	if ($p > 0) {
	    $xbuf = substr($e{'Body'}, 0, $p < 1024 ? $p : 1024);
	}
	else { # may be null or continuous character buffer?
	    $xbuf = substr($e{'Body'}, 0, 1024);
	}

	&Debug("--EnvelopeFilter::InitialBuffer($xbuf\n)\n") if $debug;
    }

    # remove superflous spaces
    $xbuf =~ s/^[\n\s]*//;		# remove the first spaces
    $xbuf =~ s/[\n\s]*$//;		# remove the last spaces

    # XXX: remove the signature (we suppose) part
    if (index($xbuf, "\n\n") > 0) {  # we must have at least one paragraph.
	$p = rindex($xbuf, "\n\n", $bodylen); # backward from the buffer last point ...
	&Debug("--EnvelopeFilter::bodylen=$bodylen substr(\$xbuf, 0, $p)\n") if $debug;
	$xbuf = substr($xbuf, 0, $p + 1) if $p > 0;
    }

    ### count up the number of paragraphs
    # count up "\n\n" lines;
    # If one paraghaph (+ signature), must be $c == 0. 
    &Debug("--EnvelopeFilter::CountUpBuffer($xbuf\n)\n") if $debug;
    $c = $p = 0;
    $pe = rindex($xbuf, "\n\n"); # ignore the last signature
    while (($p = index($xbuf, "\n\n", $p + 1)) > 0) {
	last if $p > $pe; # change '>=' to '>' at 2000/04/16 (fukachan)
	$c++;
    }
    ### "count up the number of paragraphs" ends

    # FILTERING INITIALIZE() routine
    # 1. cut off Email addresses (exceptional).
    $xbuf =~ s/\S+@[-\.0-9A-Za-z]+/account\@domain/g;

    # 2. remove invalid syntax seen in help file with the bug? ;D
    $xbuf =~ s/^_CTK_//g; $xbuf =~ s/\n_CTK_//g;

    # XXX 3. Hmm,convert 2 byte Japanese charactor to 1 byte (required)?
    # XXX    How we deal buffer with both 1 and 2 bytes strings ??

    # 4. reject not ISO-2022-JP
    if ($FILTER_ATTR_REJECT_INVALID_JAPANESE && &NonJISP($xbuf)) {
	$r = 'neigher ASCII nor ISO-2022-JP';
    }


    &Debug("--EnvelopeFilter::Buffer($xbuf\n);\ncount=$c\n") if $debug;

    if ($r) { # must be matched in a hook.
	;
    }
    elsif ($xbuf =~ /^[\s\n]*$/ && $FILTER_ATTR_REJECT_NULL_BODY) {
	$r = "null body";
    }
    # e.g. "unsubscribe", "help", ("subscribe" in some case)
    # DO NOT INCLUDE ".", "?" (I think so ...)! 
    # XXX but we need "." for mail address syntax e.g. "chaddr a@d1 b@d2".
    # If we include them, we cannot identify a command or an English phrase ;D
    # If $c == 0, the mail must be one paragraph (+ signature).
    elsif (!$c && $xbuf =~ /^[\s\n]*[\s\w\d:,\@\-]+[\n\s]*$/ &&
	   $FILTER_ATTR_REJECT_ONE_LINE_BODY) {
	$r = "one line body";
    }
    # elsif ($xbuf =~ /^[\s\n]*\%\s*echo.*[\n\s]*$/i) {
    elsif ($xbuf =~ /^[\s\n]*\%\s*echo.*/i && 
	   $FILTER_ATTR_REJECT_INVALID_COMMAND) {
	$r = "invalid command line body";
    }

    # JIS: 2 byte A-Z => \043[\101-\132]
    # JIS: 2 byte a-z => \043[\141-\172]
    # EUC 2-bytes "A-Z" (243[301-332])+
    # EUC 2-bytes "a-z" (243[341-372])+
    # e.g. reject "SUBSCRIBE" : octal code follows:
    # 243 323 243 325 243 302 243 323 243 303 243 322 243 311 243 302
    # 243 305
    if ($FILTER_ATTR_REJECT_2BYTES_COMMAND && 
	$xbuf =~ /\033\044\102(\043[\101-\132\141-\172])/) {
	# /JIS"2byte"[A-Za-z]+/
	
	$s = &STR2EUC($xbuf);

	local($n_pat, $sp_pat);
	$n_pat  = '\243[\301-\332\341-\372]';
	$sp_pat = '\241\241'; # 2-byte space

	$s = (split(/\n/, $s))[0]; # check the first line only
	if ($s =~ /^\s*(($n_pat){2,})\s+.*$|^\s*(($n_pat){2,})($sp_pat)+.*$|^\s*(($n_pat){2,})$/) {
	    &Log("2 byte <". &STR2JIS($s) . ">");
	    $r = '2 byte command';
	}
    }

    # some attributes
    # XXX: "# command" is internal represention
    # XXX: but to reject the old compatible syntaxes.
    if ($mode eq 'distribute' && $FILTER_ATTR_REJECT_COMMAND &&
	$xbuf =~ /^[\s\n]*(\#\s*[\w\d\:\-\s]+)[\n\s]*$/) {
	$r = $1; $r =~ s/\n//g;
	$r = "avoid to distribute commands [$r]";
    }

    # Spammer?  Message-Id should be <addr-spec>
    if ($e{'h:message-id:'} !~ /\@/) { $r = "invalid Message-Id";}

    # [VIRUS CHECK against a class of M$ products]
    # Even if Multipart, evaluate all blocks agasint virus checks.
    if ($FILTER_ATTR_REJECT_MS_GUID && $e{'MIME:boundary'}) {
	&use('viruschk');
	local($xr);
	$xr = &VirusCheck(*e);
	$r = $xr if $xr;
    }

    if ($r) { 
	$DO_NOTHING = 1;
	&Log("EnvelopeFilter::reject for '$r'");
	&WarnE("Rejected mail by FML EnvelopeFilter $ML_FN", 
	       "Mail from $From_address\nis rejected for '$r'.\n\n");
	if ($FILTER_NOTIFY_REJECTION) {
	    &Mesg(*e, 
		  "Your mail is rejected for '$r'.\n", 
		  'filter.rejected', $r);
	    &MesgMailBodyCopyOn;
	}
    }

    $* = $org_mlp;
}

# return 0 if reject;
sub EvalRejectFilterHook
{
    local(*e, *filter) = @_;
    return $NULL unless $filter;
    local($r) = sprintf("sub DoEvalRejectFilterHook { %s;}", $filter);
    eval($r); &Log($@) if $@;
    $r = &DoEvalRejectFilterHook;
    $r || $NULL;
}


# based on fml-support: 07020, 07029
#   Koji Sudo <koji@cherry.or.jp>
#   Takahiro Kambe <taca@sky.yamashina.kyoto.jp>
# check the given buffer has unusual Japanese (not ISO-2022-JP)
sub NonJISP
{
    local($buf) = @_;

    # check 8 bit on
    if ($buf =~ /[\x80-\xFF]/ ){
	return 1;
    }

    # check SI/SO
    if ($buf =~ /[\016\017]/) {
	return 1;
    }

    # HANKAKU KANA
    if ($buf =~ /\033\(I/) {
	return 1;
    }

    # MSB flag or other control sequences
    if ($buf =~ /[\001-\007\013\015\020-\032\034-\037\177-\377]/) {
	return 1;
    }

    0; # O.K.
}


1;
