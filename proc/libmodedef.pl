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


sub ModeDef
{
    local($mode) = @_;
    $mode =~ tr/A-Z/a-z/;

    ### MODE DEFINITIN ALIASES;
    # in fact, converts them to the current configuration in compat_cf2;    
    #    artype={subject,body} codes are called in ModeDef();
    %MODE_ALIASES = ('distribute',                   'post=anyone',
		     'distribute_with_member_check', 'post=members_only',
		     'moderated',                    'post=moderated',

		     # auto registratin type declaration
		     # require ML_MEMBER_CHECK = 0; particularly
		     'confirm',        'artype=confirm',

		     # aliases for convenience (against TYPO)
		     'post=anyone_ok',    'post=anyone',
		     'command=anyone_ok', 'command=anyone',
		     'command=member_only', 'command=members_only', 
		     );

    # rewrite (backword compat)
    $mode = $MODE_ALIASES{$mode} ? $MODE_ALIASES{$mode} : $mode;

    &Debug("ModeDef: scan mode=$mode") if $debug;

    if ($mode =~ /^(post|command)=(anyone|members_only|moderated)/) {
	&use('compat_cf2');
	&ConvertMode2CFVersion3($mode);
    }
    elsif ($mode eq 'html') {
	&HtmlMode;
    }
    elsif ($mode eq 'expire') {
	&ExpireMode;
    }
    elsif ($mode eq 'archive') {
	&ArchiveMode;
    }
    elsif ($mode eq 'mime') { 
	$USE_MIME = 1;
    }
    ### 
    ### AUTO REGISTRATION 
    ### 
    elsif ($mode eq 'artype=confirm') { 
	$AUTO_REGISTRATION_TYPE = "confirmation";
	;# if confirm mode, this declaration is NOT backward;
    }
    elsif ($mode eq 'artype=subject') { 
	$AUTO_REGISTRATION_TYPE = "subject";
    }
    elsif ($mode eq 'artype=body') {
	$AUTO_REGISTRATION_TYPE = "body";
    }
    elsif ($mode eq 'check') { 
	$ML_MEMBER_CHECK = 1;
    }
    elsif ($mode eq 'auto' || $mode eq 'autoregist') { 
	$ML_MEMBER_CHECK = 0;
    }
    elsif ($mode eq 'autosubject') { 
	$AUTO_REGISTRATION_KEYWORD = "subscribe";
	$AUTO_REGISTRATION_TYPE    = "subject";
    }
    elsif ($mode eq 'autobody') {
	$AUTO_REGISTRATION_KEYWORD = "subscribe";
	$AUTO_REGISTRATION_TYPE    = "body";
    }
    ### 
    ### HEADER
    ### 
    elsif ($mode eq 'through') { 
	$SUPERFLUOUS_HEADERS = 1;
    }
    ### 
    ### COMMANDS
    ### 
    elsif ($mode eq 'commandonly' || $mode eq 'ctladdr') { 
	$COMMAND_ONLY_SERVER = 1;
    }
    elsif ($mode eq 'caok') {	# command anyone ok
	$PERMIT_COMMAND_FROM = "anyone";
    }
    ### 
    ### REMOTE ADMINISTRATION
    ### 
    elsif ($mode eq 'remote' || $mode eq 'ra') {
	$REMOTE_ADMINISTRATION = 1;
	$REMOTE_ADMINISTRATION_AUTH_TYPE = "crypt";
    }
    ### 
    ### modeutils; (which requires several functions for them)
    ### so functions are separeted as another library;
    ### 
    else {
	&use('modeutils');
	&SubMode($mode);
    }
}


# --html
sub HtmlMode
{
    if ($CFVersion < 3) {
	$HTML_INDEX_UNIT = $HTML_INDEX_UNIT || 'day'; # since yahoo is day..;
	$HTML_INDEX_REVERSE_ORDER = $USE_MIME = $HTML_THREAD = 1;
    }

    $FmlExitHook{'html'} = q# 
	$USE_MIME = 1;
	require 'libsynchtml.pl';
	&SyncHtml($HTML_DIR || 'htdocs', $ID, *Envelope); 
    #;
}


# check_limit: each time calling is of no use.
sub ExpireMode
{
    $FmlExitHook{'expire'} = q#;
    local($check_limit, $unit, $conflict_p);

    if ($USE_ARCHIVE) {
	$conflict_p = &ArchiveAndExpireConflictP("expire");
    }

    if ($conflict_p) {
	&Log("not try to expire");
    }
    else {
	$check_limit  = $EXPIRE_LIMIT || '7days';
	$check_limit  = $check_limit =~ /(\d+)days/ ? $1*100: $check_limit;
	$check_limit  = int($check_limit/10) || 1;

	&Log("ExpireMode: $ID % $check_limit == 0") if $debug;

	if (($ID % $check_limit) == 0) {
	    &Log("here we go expire ... ") if $debug;
	    require 'libexpire.pl';
	    &CtlExpire($EXPIRE_LIMIT || '7days');
	}
	else {
	    &Log("skip since we check once in $check_limit") if $debug;
	}
    }

    #;
}


# check_limit: each time calling is of no use.
sub ArchiveMode
{
    $FmlExitHook{'archive'} = q#;
    local($check_limit, $unit, $conflict_p);

    if ($USE_EXPIRE) {
	$conflict_p = &ArchiveAndExpireConflictP("archive");
    }

    if ($conflict_p) {
	&Log("not try to archive");
    }
    else {
	$unit        = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
	$check_limit = int($unit/4) || 1;

	&Log("ArchiveMode: $ID % $check_limit == 0") if $debug;

	if (($ID % $check_limit) == 0) {
	    &Log("here we go archive ... ") if $debug;
	    require 'libarchive.pl';
	    &Archive;
	}
	else {
	    &Log("skip since we check once in $check_limit") if $debug;
	}
    }

    #;
}


sub ArchiveAndExpireConflictP
{
    local($action) = @_;
    local($au) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;

    if ($EXPIRE_LIMIT =~ /(\d+)days/) {
	&Log("Warning: \$EXPIRE_LIMIT != \"number\" BUT \$USE_ARCHIVE on");
	&Log("Warning: So We DO NOT $action the spool for safety");
	return 1;
    }

    if ($EXPIRE_LIMIT < 2*$au) {
	&Log("Error: CANNOT $action the spool for safety");
	&Log("Error: since \$EXPIRE_LIMIT < 2*\$ARCHIVE_UNIT");
	return 1;
    }

    0;
}


1;
