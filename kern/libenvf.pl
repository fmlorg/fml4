# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libenvf.pl,v 2.16 2001/08/25 12:42:30 fukachan Exp $
#

use vars qw($debug $debug_filter $debug_envf_rule);
use vars qw($COMMAND_FILTER_HOOK); # used for compatibility

# Called under $USE_DISTRIBUTE_FILTER is not null.
# IF *HOOK is not defined, we apply default checkes.
# The function name looks strange but this is derived from
# that "filtering for %Envelope hash, not only mail message/body".
sub __EnvelopeFilter
{
    use vars qw(%e $mode @pmap);
    local(*e, $mode) = @_;
    local(@pmap); # paragraph map: the array of the first ptr in paragraph
    my ($xbuf);
    my ($c, $p, $r, $org_mlp, $bodylen);
    my ($lparbuf, $fparbuf, $n_paragraph);
    my ($one_line_check_p);


    ### 0. preparation
    $bodylen = length($e{'Body'}); # body length

    # force plural line match
    $org_mlp = $*;
    $* = 0;

    ### 1. run-hooks
    # compatible 
    # appending twice must be no problem since statments is "return".
    $DISTRIBUTE_FILTER_HOOK .= $REJECT_DISTRIBUTE_FILTER_HOOK;
    $COMMAND_FILTER_HOOK    .= $REJECT_COMMAND_FILTER_HOOK;

    &Log("ENVF: run-hooks \$DISTRIBUTE_FILTER_HOOK") if $debug_envf_rule;
    if ($mode eq 'distribute' && $DISTRIBUTE_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *DISTRIBUTE_FILTER_HOOK);
    }
    elsif ($mode eq 'command' && $COMMAND_FILTER_HOOK) {
	$r = &EvalRejectFilterHook(*e, *COMMAND_FILTER_HOOK);
    }


    ### 2. evaluate %REJECT_HDR_FIELD_REGEXP
    &Log("ENVF: eval \%REJECT_HDR_FIELD_REGEXP") if $debug_envf_rule;
    if ($r) {
	; # O.K.
    }
    # reject for some header field patterns.
    elsif (%REJECT_HDR_FIELD_REGEXP) {
	my ($hf, $pat, $match);
	my ($buf);

	for $hf (keys %REJECT_HDR_FIELD_REGEXP) {
	    next unless ($hf && $REJECT_HDR_FIELD_REGEXP{$hf});

	    $pat = $REJECT_HDR_FIELD_REGEXP{$hf};
	    $pat = &STR2EUC($pat);

	    $buf = $e{"h:$hf:"};
	    if ($buf =~ /ISO-2022-JP/i) { 
		&use('MIME');
		$buf = &DecodeMimeStrings($buf);
	    }
	    $buf = &STR2EUC($buf);

	    if ($pat =~ m@/i$@) { # case insensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		print STDERR "<$buf> =~ /$pat/i && $match++; \n" if $debug;
		$buf =~ /$pat/i && &EUCCompare($buf, $&) && $match++;
	    }
	    else {		# case sensitive
		$pat =~ s@(/i|/)$@@g; 
		$pat =~ s@^/@@g;
		print STDERR "<$buf> =~ /$pat/ && $match++; \n" if $debug;
		$buf =~ /$pat/ && &EUCCompare($buf, $&) && $match++;
	    }

	    if ($match) {
		&Log("EnvelopeFilter: \$REJECT_HDR_FIELD_REGEXP{\"$hf\"} HIT");
		$r = "${hf}: contains an invalid pattern.";
		last;
	    }
	}
    }


    ### 3. extract contents to check
    # XXX malloc() too much?
    # If multipart, check the first block only.
    # If plaintext, check the first two paragraph or 1024 bytes.

    &Log("ENVF: create target buffer (pmap,multipart)") if $debug_envf_rule;
    &use('envfsubr');
    if ($e{'MIME:boundary'}) {
	$xbuf = &GetFirstMultipartBlock(*e);
	$p = &EnvelopeFilter::MakeParagraphMap(*e, *pmap, $xbuf);
    }
    else { # check whole $Envelope{'Body'}
	$p = &EnvelopeFilter::MakeParagraphMap(*e, *pmap);
    }

    # extract the buffer to check
    if ($p >= 0 && $p < 1024) {
	$xbuf    = substr($e{'Body'}, $pmap[0], $pmap[$#pmap]);
	$fparbuf = substr($e{'Body'}, $pmap[0], $pmap[1]); # first par(agraph)
	$lparbuf = substr($e{'Body'}, $pmap[ $#pmap - 1 ], $pmap[$#pmap]); # last
    }
    else { # may be null or continuous character buffer?
	my ($i);
	for ($i = 0; $i < $#pmap && $pmap[$i] < 1024; $i++) {;}
	&Log("EnvelopeFilter: check from $pmap[0] to $pmap[$i] since too big");
	$xbuf = substr($e{'Body'}, $pmap[0], $pmap[$i]);
    }
    $n_paragraph = $#pmap;

    &Debug("--EnvelopeFilter::InitialBuffer($xbuf)\n") if $debug;


    ### 4. check the only last paragraph
    # If it has @ or ://, it must be a paragraph 
    $one_line_check_p = &EnvelopeFilter::OneLineCheckP(*e, *pmap, $lparbuf);
    &Debug("--EnvelopeFilter::BufferToCheck($xbuf)\n") if $debug;
    &Log("EnvelopeFilter: one line check? $one_line_check_p") if $debug;
    &Log("ENVF: one-line-check-p") if $debug_envf_rule;

    ### 5. arrange
    $xbuf = &EnvelopeFilter::CleanUpBuffer($xbuf);
    &Log("ENVF: clean up buffer") if $debug_envf_rule;
    
    ### 6. reject if the mail body has non ISO-2022-JP Japanese strings.
    &Log("ENVF: jis-p (default = $FILTER_ATTR_REJECT_INVALID_JAPANESE)")
	if $debug_envf_rule;
    if ($FILTER_ATTR_REJECT_INVALID_JAPANESE && &NonJISP($xbuf)) {
	$r = 'neigher ASCII nor ISO-2022-JP';
    }


    ### 7. body check whether invalid or not
    if ($debug_envf_rule) {
	&Log("ENVF: null-body-p (default = $FILTER_ATTR_REJECT_NULL_BODY)");
	&Log("ENVF: one-line-p (default = $FILTER_ATTR_REJECT_ONE_LINE_BODY)");
    }

    if ($r) { # must be matched in a hook already.
	;
    }
    # null ?
    elsif ($xbuf =~ /^[\s\n]*$/ && $FILTER_ATTR_REJECT_NULL_BODY) {
	$r = "null mail body";
    }
    # one line mail ?
    elsif ($one_line_check_p) {
	&Log("EnvelopeFilter: one line body check") if $debug;

	# e.g. "unsubscribe", "help", ("subscribe" in some case)
	# XXX DO NOT INCLUDE ".", "?" (I think so ...)! 
	# XXX but we need "." for mail address syntax e.g. "chaddr a@d1 b@d2".
	# If we include them, we cannot identify a command or an English phrase ;D
	if ($FILTER_ATTR_REJECT_ONE_LINE_BODY && 
	    ($fparbuf =~ /^[\s\n]*[\s\w\d:,\@\-]+[\n\s]*$/)) {
	    $r = "one line mail body";
	}
    }

    ## 7.1
    if ($debug_envf_rule) {
	&Log("ENVF: invalid-command-p (default = $FILTER_ATTR_REJECT_INVALID_COMMAND)");
	&Log("ENVF: check-2-bytes (default = $FILTER_ATTR_REJECT_2BYTES_COMMAND)");
    }

    if ($r) {
	;
    }
    # check only the first paragraph
    elsif ($fparbuf =~ /^[\s\n]*\%\s*echo.*/i && 
	   $FILTER_ATTR_REJECT_INVALID_COMMAND) {
	$r = "invalid command in the mail body";
    }
    # Japanese command
    # JIS: 2 byte A-Z => \043[\101-\132]
    # JIS: 2 byte a-z => \043[\141-\172]
    # EUC 2-bytes "A-Z" (243[301-332])+
    # EUC 2-bytes "a-z" (243[341-372])+
    # e.g. reject "SUBSCRIBE" : octal code follows:
    # 243 323 243 325 243 302 243 323 243 303 243 322 243 311 243 302
    # 243 305
    elsif ($FILTER_ATTR_REJECT_2BYTES_COMMAND && 
	   $fparbuf =~ /\033\044\102(\043[\101-\132\141-\172])/) {
	# /JIS"2byte"[A-Za-z]+/
	
	my $s = &STR2EUC($fparbuf);

	my ($n_pat, $sp_pat);
	$n_pat  = '\243[\301-\332\341-\372]';
	$sp_pat = '\241\241'; # 2-byte space

	$s = (split(/\n/, $s))[0]; # check the first line only
	if ($s =~ /^\s*(($n_pat){2,})\s+.*$|^\s*(($n_pat){2,})($sp_pat)+.*$|^\s*(($n_pat){2,})$/) {
	    &Log("2 byte <". &STR2JIS($s) . ">");
	    $r = '2 byte command';
	}
    }


    # 7.2
    # XXX: "# command" is internal represention
    # XXX: but to reject the old compatible syntaxes.
    if ($debug_envf_rule) {
	&Log("ENVF: reject-#proc-p (default = $FILTER_ATTR_REJECT_COMMAND)");
    }
    if ($mode eq 'distribute' && $FILTER_ATTR_REJECT_COMMAND &&
	$fparbuf =~ /^[\s\n]*(\#\s*[\w\d\:\-\s]+)[\n\s]*$/) {
	$r = $1; $r =~ s/\n//g;
	$r = "avoid to distribute commands [$r]";
    }


    ### 8. simple SPAM check
    # Spammer?  Message-Id should be <addr-spec>
    if ($e{'h:message-id:'} !~ /\@/) { $r = "invalid Message-Id";}
    &Log("ENVF: message-id check") if $debug_envf_rule;


    ### 9. virus checker
    # [VIRUS CHECK against a class of M$ products]
    # Even if Multipart, evaluate all blocks agasint virus checks.
    &Log("ENVF: MS-GUID (default = $FILTER_ATTR_REJECT_MS_GUID)")
	if $debug_envf_rule;
    if ($FILTER_ATTR_REJECT_MS_GUID && $e{'MIME:boundary'}) {
	&use('viruschk');
	my ($xr);
	$xr = &VirusCheck(*e);
	$r = $xr if $xr;
    }


    ### 10. return result
    if ($r) { 
	$DO_NOTHING = 1;
	&Log("EnvelopeFilter::reject for '$r'");

	# notification to admins
	my ($m) = "Mail from $From_address\nis rejected for '$r'.\n\n";
	&use('mesgle');
	$m = &MesgLE(*e, 'filter.rejected.notify_to_admin', 
		     $From_address, $r) || $m;
	&WarnE("Rejected mail by FML EnvelopeFilter $ML_FN", $m);

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
    use vars qw($filter);
    local(*e, *filter) = @_;
    return $NULL unless $filter;
    my ($r) = sprintf("sub DoEvalRejectFilterHook { %s;}", $filter);
    eval($r); 
    &Log($@) if $@;
    $r = &DoEvalRejectFilterHook;
    $r || $NULL;
}


# based on fml-support: 07020, 07029
#   Koji Sudo <koji@cherry.or.jp>
#   Takahiro Kambe <taca@sky.yamashina.kyoto.jp>
# check the given buffer has unusual Japanese (not ISO-2022-JP)
sub NonJISP
{
    my ($buf) = @_;

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


# EUCCompare($buf, $pat) where $pat should be $& (matched pattern)
sub EUCCompare
{
    my ($a, $pat) = @_;

    # (Refeence: jcode 2.12)
    # $re_euc_c    = '[\241-\376][\241-\376]';
    # $re_euc_kana = '\216[\241-\337]';
    # $re_euc_0212 = '\217[\241-\376][\241-\376]';
    my ($re_euc_c, $re_euc_kana, $re_euc_0212);
    $re_euc_c    = '[\241-\376][\241-\376]';
    $re_euc_kana = '\216[\241-\337]';
    $re_euc_0212 = '\217[\241-\376][\241-\376]';

    # always true if given buffer is not EUC.
    if ($a !~ /($re_euc_c|$re_euc_kana|$re_euc_0212)/) {
	&Log("EUCCompare: do nothing for non EUC strings") if $debug;
	return 1;
    }

    # extract EUC code (e.g. .*EUC_PATTERN.*)
    # but how to do for "EUC ASCII EUC" case ???
    my ($pa, $loc, $i);
    do {
	if ($a =~ /(($re_euc_c|$re_euc_kana|$re_euc_0212)+)/) {
	    $pa  = $1;
	    $loc = index($pa, $pat);
	}

	print "buf = <$a> pa=<$pa> pat=<$pat> loc=$loc\n";

	return 1 if ($loc % 2) == 0;

	$a = substr($a, index($a, $pa) + length($pa) );
    } while ($i++ < 16);

    0;
}

1;
