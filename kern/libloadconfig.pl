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

sub __LoadConfiguration
{
    local($space) = @_;

    require 'default_config.ph';

    # If this routine is used not within libkern.pl, 
    # fml.pl, we enforce to use dummy definitions to avoid errors.
    &LoadDummyMacros if $space ne '__KERN__';

    # site_init
    if ($SiteInitPath = &SearchFileInLIBDIR("site_init.ph")) {
	if (-r $SiteInitPath) { 
	    &Log("require $SiteInitPath") if $debug;
	    require($SiteInitPath);
	}
    }

    # include fundamental configurations and library
    if (-r "$DIR/config.ph")  { 
	require("$DIR/config.ph");
    }
    else {
	print STDERR "I cannot read $DIR/config.ph\n" if !-r "$DIR/config.ph";
	print STDERR "no $DIR/config.ph exist?\n" if !-f "$DIR/config.ph";
	print STDERR "FYI: FML Release 2 Release requires \$DIR/config.ph\n";
	exit 1;
    }

    # site_force
    for ("site_force.ph", "sitedef.ph") {
	($SiteforcePath = &SearchFileInLIBDIR($_)) || next;
	-r $SiteforcePath || next;

	&Log("require $SiteforcePath") if $debug;
	require($SiteforcePath);
	last;
    }
}


sub SearchFileInLIBDIR
{
    for (@LIBDIR) { 
	&Debug("SearchFileInLIBDIR: <$_>/$_[0]") if $debug;
	if (-f "$_/$_[0]") { return "$_/$_[0]";}
    }
    $NULL;
}


### Section: User available macros in config.ph

# tricky
sub LoadDummyMacros
{
    print STDERR "-- LoadDummyMacros\n";

    eval "sub STR2JIS {1;}";
    eval "sub STR2EUC {1;}";
    eval "sub JSTR    {1;}";

    eval "sub DEFINE_SUBJECT_TAG          { 1;}";
    eval "sub DEFINE_MODE                 { 1;}";
    eval "sub DEFINE_FIELD_FORCED         { 1;}";
    eval "sub DEFINE_FIELD_ORIGINAL       { 1;}";
    eval "sub DEFINE_FIELD_OF_REPORT_MAIL { 1;}";
    eval "sub DEFINE_FIELD_PAT_TO_REJECT  { 1;}";
    eval "sub DEFINE_FIELD_LOOP_CHECKED   { 1;}";
    eval "sub UNDEF_FIELD_LOOP_CHECKED    { 1;}";

    eval "sub ADD_FIELD    { 1;}";
    eval "sub DELETE_FIELD { 1;}";
    eval "sub COPY_FIELD   { 1;}";
    eval "sub MOVE_FIELD   { 1;}";

    eval "sub ADD_CONTENT_HANDLER { 1;}";
    eval "sub DEFINE_MAILER       { 1;}";
}


sub STR2JIS { &JSTR($_[0], 'jis');}
sub STR2EUC { &JSTR($_[0], 'euc');}
sub JSTR
{
    local($s, $code) = @_;
    print STDERR "--main->JSTR\n";
    require 'jcode.pl';
    &jcode'convert(*s, $code || 'jis'); #';
    $s;
} 

sub DEFINE_SUBJECT_TAG { &use('tagdef'); &SubjectTagDef($_[0]);}

sub DEFINE_MAILER
{
    local($t) = @_;
    if ($t eq 'ipc' || $t eq 'prog') { 
	$Envelope{'mci:mailer'} = $t;
    }
    else {
	&Log("DEFINE_MAILER: unknown type=$t (shuold be 'ipc' or 'prog')");
    }
}

sub DEFINE_MODE
{ 
    local($m) = @_;
    print STDERR "--DEFINE_MODE($m)\n" if $debug;

    $m =~ tr/A-Z/a-z/;
    $Envelope{"mode:$m"} = 1;

    # config.ph CFVersion == 3
    if ($CFVersion < 3) {
	&use("compat_cf2");
	&ConvertMode2CFVersion3($m);
    }

    if ($m =~ 
	/^(post=|command=|artype=confirm|ctladdr|disablenotify|makefml)/) {
	&Log("ignore $m call ModeDef") if $debug;
    }
    else {
	&Log("call ModeDef($m)") if $debug;
	&use("modedef"); 
	&ModeDef($m);
    }
}

sub DEFINE_FIELD_FORCED 
{ 
    local($_) = $_[0]; tr/A-Z/a-z/; $Envelope{"fh:$_:"} = $_[1];
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_ORIGINAL
{ 
    local($_) = $_[0]; tr/A-Z/a-z/; $Envelope{"oh:$_:"} = 1;
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_OF_REPORT_MAIL 
{ 
    local($_) = $_[0]; $Envelope{"GH:$_:"} = $_[1];
    &ADD_FIELD(&FieldCapitalize($_));
}

sub DEFINE_FIELD_PAT_TO_REJECT
{ 
    $REJECT_HDR_FIELD_REGEXP{$_[0]} = $_[1];
    $REJECT_HDR_FIELD_REGEXP_REASON{$_[0]} = $_[2] if $_[2];
}

sub DEFINE_FIELD_LOOP_CHECKED
{ 
    local($_) = $_[0]; tr/A-Z/a-z/;
    $LOOP_CHECKED_HDR_FIELD{$_} = 1;
}

sub UNDEF_FIELD_LOOP_CHECKED
{ 
    local($_) = $_[0]; tr/A-Z/a-z/;
    $LOOP_CHECKED_HDR_FIELD{$_} = 0;
}

sub ADD_FIELD
{ 
    grep(/^$_[0]$/i, @HdrFieldsOrder) || push(@HdrFieldsOrder, $_[0]);
    &Debug("ADD_FIELD $_[0]") if $debug;
}

sub DELETE_FIELD 
{
    local(@h); 

    # If $SKIP_FIELDS has no this entry.
    # print STDERR "    if ($SKIP_FIELDS !~ /\"\\|$_[0]\\|\"/) { \n";
    if ($SKIP_FIELDS !~ /\|$_[0]$|\|$_[0]\|/) {
	$SKIP_FIELDS .= $SKIP_FIELDS ? "|$_[0]" : $_[0];
    }

    for (@HdrFieldsOrder) { push(@h, $_) if $_ ne $_[0];}
    @HdrFieldsOrder = @h;
}

# the value is not inserted now.
sub COPY_FIELD 
{ 
    $HdrFieldCopy{ $_[0] } = $_[1];
    &ADD_FIELD(&FieldCapitalize($_[1]));
}

# the value is not inserted now.
sub MOVE_FIELD 
{ 
    &COPY_FIELD(@_);
    &DELETE_FIELD($_[0]);
}

# add Content Handler
sub ADD_CONTENT_HANDLER
{
    local($bodytype, $parttype, $action) = @_;
    local($type, $subtype, $xtype, $xsubtype);
   
    if ($bodytype eq '!MIME') {
	$type = '!MIME';
	$subtype = '.*';
    } else {
	($type, $subtype) = split(/\//, $bodytype, 2);
    }
    ($xtype, $xsubtype) = split(/\//, $parttype, 2);
    push (@MailContentHandler,
	  join("\t", $type, $subtype, $xtype, $xsubtype, $action));
}

1;
