# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;

sub SubMode
{
    local($mode) = @_;

    &StdinLogMode                     if $mode eq 'stdinlog';
    &SpeculateContorolOrDistriuteMode if $mode eq 'distorctl';
    &AppendMimeDecodedSubjectMode     if $mode eq 'mimedecodedsubject';
}


# THIS IS NOT 100% OK, ONLY SPECULATEION.
sub SpeculateContorolOrDistriuteMode
{
    $START_HOOK .= q#;
    local($ca) = &CutFQDN($CONTROL_ADDRESS);
    if (($ca && ($Envelope{'mode:chk'} =~ /$ca/i))) {
	$LOAD_LIBRARY || ($LOAD_LIBRARY = 'libfml.pl'); 
        $COMMAND_ONLY_MODE = 1; 
    }
    else {
        &DEFINE_MODE('distribute');
    }
    #;
}

sub StdinLogMode
{
    $START_HOOK .= q#;
    &use('debug');
    &StdinLog;
    #;
}


sub AppendMimeDecodedSubjectMode
{
    $START_HOOK .= q# &AppendMimeDecodedSubject(*Envelope);#;

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
    if ($s =~ /ISO\-2022\-JP/i) {
	&use('MIME');
	$e{'h:X-Subject:'} = &mimedecode($s);
	$append++;
    }

    if ($append) {
	local(@h);
	for (@HdrFieldsOrder) {
	    push(@h, $_);
	    if ('Subject' eq $_) { push(@h, 'X-Subject');}
	}
	@HdrFieldsOrder = @h;
    }
}

1;
