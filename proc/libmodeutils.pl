# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

sub SubMode
{
    local($mode) = @_;

    &Log("SubMode::mode=$mode") if $debug;

    if ($mode eq 'fmlserv') {
	&FmlServMode;
    }
    elsif ($mode eq 'fml') {
	&FmlMode;
    }
    elsif ($mode eq 'hml') {
	&HmlMode;
    }
    elsif ($mode eq 'emudistribute') {
	&EmulateDistributeMode;
    }
    elsif ($mode eq 'stdinlog') {
	&StdinLogMode;
    }
    elsif ($mode eq 'distorctl') {
	&SpeculateContorolOrDistriuteMode;
    }
    elsif ($mode eq 'mimedecodedsubject') {
	&AppendMimeDecodedSubjectMode;
    }
    elsif ($mode eq "simulation") { 
	push(@INC, $INCLUDE_SIM_PATH); 
	require 'libsimulation.pl';
    }
    else {
	&Log("ERROR: mode [$mode] is unknown");
    }
}


# THIS IS NOT 100% OK, ONLY SPECULATEION.
sub SpeculateContorolOrDistriuteMode
{
    $START_HOOK .= q#;
    local($ca) = &CutFQDN($CONTROL_ADDRESS);
    if (($ca && ($Envelope{'trap:rcpt_fields'} =~ /$ca/i))) {
	$LOAD_LIBRARY || ($LOAD_LIBRARY = 'libfml.pl'); 
        $COMMAND_ONLY_SERVER = 1; 
    }
    else {
        $PERMIT_POST_FROM = "anyone";
    }
    #;
}


sub StdinLogMode
{
    $FmlStartHook{'stdinlog'} = q#;
    &use('debug');
    &StdinLog;
    #;
}


sub AppendMimeDecodedSubjectMode
{
    $FmlStartHook{'AppendMimeDecodedSubjectMode'} = 
	q# &AppendMimeDecodedSubject(*Envelope);#;
}


sub AppendMimeDecodedSubject
{
    local(*e) = @_;
    local($append, $s, $jin);

    $s   = $e{"h:Subject:"};
    $jin = '\033\$[\@B]';

    # if MIME and Japanese mixed?
    if ($s =~ /$jin/i) {
	$e{'h:X-Subject:'} = $s;
	$e{'h:Subject:'} = &mimedecode($s);
	$append++;
    }

    # IF Subject: MIME, Append  X-Subject: MIME-Decoded
    if ($s =~ /=\?ISO\-2022\-JP\?/i) {
	&use('MIME');
	$e{'h:X-Subject:'} = &mimedecode($s);
	$append++;
    }

    if ($append) {
	local(@h, %dup);
	for (@HdrFieldsOrder) {
	    next if $dup{$_}; $dup{$_} = 1; # duplicate check;
	    push(@h, $_);
	    if ('Subject' eq $_) { push(@h, 'X-Subject');}
	}
	@HdrFieldsOrder = @h;
    }
}


sub EmulateDistributeMode
{
    local($name, $domain) = split(/\@/, $MAIL_LIST);

    $SUBJECT_FREE_FORM = 1;
    $BEGIN_BRACKET     = '[';
    $BRACKET           = $name;
    $BRACKET_SEPARATOR = ' ';
    $END_BRACKET       = ']';
    $SUBJECT_FREE_FORM_REGEXP = "\\[$BRACKET\\s+\\d+\\]";
}


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


1;
