# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$


##### $CFVersion < 3 #####
#
# &DEFINE_MODE ensures compatible of
#
#    Distribution mode mode:post=*    -> $PERMIT_POST_*
#    Command Mode      mode:command=* -> $PERMIT_COMMAND_*
#

### Section: Delivery, Commands Mode and reject_handering

if (! $ML_MEMBER_CHECK) {
    $REJECT_POST_HANDLER    = "auto_regist";
    $REJECT_COMMAND_HANDLER = "auto_regist";
    &ConvertArType2CFVersion3;
}

if ($Permit{'command'}) { 
    &Log("\$PERMIT_COMMAND_FROM => anyone") if $debug;
    $PERMIT_COMMAND_FROM = "anyone";
}

# overwrite mode:anyoneok
if ($PROHIBIT_COMMAND_FOR_STRANGER) { 
    &Log("\$PERMIT_COMMAND_FROM => members_only") if $debug;
    $PERMIT_COMMAND_FROM = "members_only";
}

&ConvertMode2CFVersion3;


### Section: Misc
$USE_MIME      = 1 if $USE_LIBMIME; 
$USE_ERRORS_TO = 1 if $AGAINST_NIFTY;
$COMMAND_SYNTAX_EXTENSION = 1 if $RPG_ML_FORM_FLAG;
$SUBJECT_FORM_LONG_ID     = 1 if $HML_FORM_LONG_ID;
$SENDFILE_NO_FILECHECK    = 1 if $SUN_OS_413;
$HTML_EXPIRE_LIMIT = $HTML_EXPIRE unless $HTML_EXPIRE_LIMIT;


### Section: Digest/Matome Okuri

if ($USE_RFC1153_DIGEST || $USE_RFC1153) {
    $MSEND_MODE_DEFAULT = "rfc1153";
}
elsif ($USE_RFC934) {
    $MSEND_MODE_DEFAULT = "rfc934";
}

$MSEND_NOT_USE_NEWSYSLOG = $NOT_USE_NEWSYSLOG;

push(@ARCHIVE_DIR, @StoredSpool_DIR); # FIX INCLUDE PATH


if ($NOT_SHOW_DOCMODE) {
    $MGET_SUBJECT_TEMPLATE =~ s/_PART_\s*//g;
}


### Section: Subject
if ($SUBJECT_HML_FORM) { &use("tagdef"); &SubjectTagDef("[:]");}


### Section: Remote Administration
if ($REMOTE_ADMINISTRATION_REQUIRE_PASSWORD) {
    $REMOTE_ADMINISTRATION_AUTH_TYPE = "crypt";
}
else {
    $REMOTE_ADMINISTRATION_AUTH_TYPE = "address";
}

if ($USE_MD5) {
    $REMOTE_ADMINISTRATION_AUTH_TYPE = "md5";
}


### Section: compatible function
sub ConvertMode2CFVersion3
{
    local($m) = @_;
    $m eq 'post=anyone'          && ($PERMIT_POST_FROM = "anyone");
    $m eq 'post=members_only'    && ($PERMIT_POST_FROM = "members_only");
    $m eq 'post=moderated'       && ($PERMIT_POST_FROM = "moderator");
    $m eq 'command=anyone'       && ($PERMIT_COMMAND_FROM = "anyone");
    $m eq 'command=members_only' && ($PERMIT_COMMAND_FROM = "members_only");
    $m eq 'artype=confirm'       && ($AUTO_REGISTRATION_TYPE = "confirmation");

    if (!$Envelope{"mode:ctladdr"} &&
	($Envelope{"mode:post=anyone"} ||
	 $Envelope{"mode:post=members_only"} ||
	 $Envelope{"mode:post=moderated"})) {
	# ML_MEMBER_CHECK determines handler ???
	$REJECT_POST_HANDLER    = "reject"; # for members_only
	$Envelope{"compat:cf2:post_directive"} = 1;
    }
}


sub ConvertArType2CFVersion3
{
    $AUTO_REGISTRATION_KEYWORD = $REQUIRE_SUBSCRIBE;

    if ($Envelope{'mode:artype=confirm'}) {
	$AUTO_REGISTRATION_TYPE = "confirmation";
    }
    elsif ($REQUIRE_SUBSCRIBE) {
	$AUTO_REGISTRATION_TYPE = "subject";
    }
    elsif ($REQUIRE_SUBSCRIBE && $REQUIRE_SUBSCRIBE_IN_BODY) {
	$AUTO_REGISTRATION_TYPE = "body";
    }
    else {
	$AUTO_REGISTRATION_TYPE = "no-keyword";
    }
}


sub CF2CompatFMLv1P
{
    local($ca, $ml) = @_;

    $ca        || return 1;	# not defiend, if < 3
    $ml eq $ca && return 1;

    # if thes are not defined, both ml and ca are command-available
    if (!$Envelope{"mode:ctladdr"} && 
	$Envelope{"compat:cf2:post_directive"}) {
	&Log("Compat::CF2 defined mode:post=* => !compat_hml") if $debug;
	return 0;
    }
    else {
	&Log("Compat::CF2 compat_hml mode") if $debug;
	return 1;
    }
}


###########################################################################
### obsolete functions;
###########################################################################
sub MLMemberNoCheckAndAdd { &MLMemberCheck;}; # backward compatibility
sub MLMemberCheck 
{
    &use("compat_fml20");
    &DoMLMemberCheck;
}  

1;
