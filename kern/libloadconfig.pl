#-*- perl -*-
#
# Copyright (C) 2000-2001 Ken'ichi Fukamachi
#          All rights reserved. 
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

##
## Example:
##	$EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
##	push(@INC, $EXEC_DIR) if -d $EXEC_DIR;
##	push(@INC, $ENV{'PWD'}) if -d $ENV{'PWD'};
##	require 'libloadconfig.pl'; &__LoadConfiguration('__KERN__');
##            # _OR_
##	require 'libloadconfig.pl'; &__LoadConfiguration;
##

#    argv: __KERN__ or $NULL
# require: $DIR, @LIBDIR
#
sub __LoadConfiguration
{
    local($space) = @_;

    if (! $DIR) {
	print STDERR "ERROR: __LoadConfiguration: \$DIR is not defined\n";
	&Log("ERROR: __LoadConfiguration: \$DIR is not defined");
	exit(1);
    }
    elsif (! -d $DIR) {
	print STDERR "ERROR: __LoadConfiguration: \$DIR not exsts\n";
	&Log("ERROR: __LoadConfiguration: \$DIR not exists");
	exit(1);
    }

    # reset to overload many times
    for (keys %INC) { delete $INC{$_} if /config.ph/;}

    # fix @INC to suppose
    # 1. $DIR
    # 2. $DIR/../etc/fml/ (e.g. /var/spool/ml/etc/fml/ )
    # 3. $EXEC_DIR (e.g. /usr/local/fml/)
    if (-d "$DIR/../etc/fml/") {
	unshift(@LIBDIR, "$DIR/../etc/fml/"); # ../etc for not UNIX OS
	unshift(@INC, "$DIR/../etc/fml/"); # ../etc for not UNIX OS
    }
    if (-d $DIR) {
	unshift(@LIBDIR, $DIR);
	unshift(@INC, $DIR);
    }

    require 'default_config.ph';

    &LoadSystemParams; # NOT USER BUT SYSTEM DEFINED PARAMETERS 

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

    # reset to overload many times to ensure next time loading
    for (keys %INC) {
	delete $INC{$_} if /config.ph/;
	delete $INC{$_} if /loadconfig.pl/;
    }

    $LoadConfigurationDone = 1;
}


# Descriptions: define global system parameters
#               USER SHOULD NOT CHANGE THESE PARAMETERS.
#    Arguments: none
# Side Effects: define global system parameters
# Return Value: none
sub LoadSystemParams
{
    # $debug options
    # XXX avoid the last 3 bit anyway.
    $DEBUG_OPT_VERBOSE_LEVEL_2 = 0x0002;
    $DEBUG_OPT_DELIVERY_ENABLE = 0x1000; # enabele delivery
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
    print STDERR "-- LoadDummyMacros\n" if $debug_30B;

    eval "sub GET_HEADER_FIELD_VALUE { 1;}";
    eval "sub GET_ORIGINAL_HEADER_FIELD_VALUE { 1;}";
    eval "sub SET_HEADER_FIELD_VALUE { 1;}";
    eval "sub GET_ENVELOPE_VALUE { 1;}";
    eval "sub SET_ENVELOPE_VALUE { 1;}";
    eval "sub ENVELOPE_APPEND { 1;}";
    eval "sub ENVELOPE_PREPEND { 1;}";
    eval "sub GET_BUFFER_FROM_FILE { 1;}";

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

    # procedure manipulation
    eval "sub PERMIT_PROCEDURE { 1;}";
    eval "sub DENY_PROCEDURE { 1;}";
    eval "sub DEFINE_PROCEDURE { 1;}";
    eval "sub PERMIT_ADMIN_PROCEDURE { 1;}";
    eval "sub DENY_ADMIN_PROCEDURE { 1;}";
    eval "sub DEFINE_ADMIN_PROCEDURE { 1;}";
    eval "sub DEFINE_MAXNUM_OF_PROCEDURE_IN_ONE_MAIL { 1;}";
    eval "sub DEFINE_MAXNUM_OF_ADMIN_PROCEDURE_IN_ONE_MAIL { 1;}";

    # for convenience
    eval "sub DUMMY { ;}";
    eval "sub TRUE  { 1;}";
    eval "sub FALSE { \$NULL;}";
}

# hash control interface
sub GET_HEADER_FIELD_VALUE
{ 
    my ($hf) = @_;
    $hf = &FieldCapitalize($hf);
    $Envelope{"h:${hf}:"};
}

sub GET_ORIGINAL_HEADER_FIELD_VALUE
{ 
    my ($hf) = @_;
    $hf =~ tr/A-Z/a-z/;
    $Envelope{"h:${hf}:"};
}

sub SET_HEADER_FIELD_VALUE
{ 
    my ($hf, $value) = @_;
    $hf = &FieldCapitalize($hf);
    $Envelope{"h:${hf}:"} = $value;
}

sub GET_ENVELOPE_VALUE
{ 
    my ($key) = @_;
    $Envelope{$key};
}

sub SET_ENVELOPE_VALUE
{ 
    my ($key, $value) = @_;
    $Envelope{$key} = $value;
}

sub ENVELOPE_APPEND
{ 
    my ($key, $value) = @_;

    if (($key eq 'Body') && $Envelope{'h:Lines:'}) {
	my ($lines) = ($value =~ tr/\n/\n/);
	$Envelope{'h:Lines:'} += $lines;
    }

    $Envelope{$key} .= $value;
}

sub ENVELOPE_PREPEND
{ 
    my ($key, $value) = @_;
    
    if (($key eq 'Body') && $Envelope{'h:Lines:'}) {
	my ($lines) = ($value =~ tr/\n/\n/);
	$Envelope{'h:Lines:'} += $lines;
    }

    $Envelope{$key} = $value . $Envelope{$key};
}

sub GET_BUFFER_FROM_FILE
{
    my ($file) = @_;
    my ($buffer);

    if (open($file, $file)) {
	while (<$file>) {
	    $buffer .= $_;
	}
	close($file);
	$buffer;
    }
    else {
	&Log("GET_BUFFER_FROM_FILE: cannot open $file");
	$NULL;
    }
}

sub STR2JIS { &JSTR($_[0], 'jis');}
sub STR2EUC { &JSTR($_[0], 'euc');}
sub JSTR
{
    local($s, $code) = @_;
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
    my ($key, $value) = @_;

    $key = &FieldCapitalize($key);
    $Envelope{"GH:${key}:"} = $value;
    &ADD_FIELD($key);
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
    my ($f) = @_;
    $f = &FieldCapitalize($f);
    grep(/^${f}$/i, @HdrFieldsOrder) || push(@HdrFieldsOrder, $f);
    &Debug("ADD_FIELD $f") if $debug;
}

sub DELETE_FIELD 
{
    my ($f) = @_;
    my (@h); 

    $f = &FieldCapitalize($f);

    # If $SKIP_FIELDS has no this entry.
    # print STDERR "    if ($SKIP_FIELDS !~ /\"\\|$f\\|\"/) { \n";
    if ($SKIP_FIELDS !~ /\|$f$|\|$f\|/) {
	$SKIP_FIELDS .= $SKIP_FIELDS ? "|$f" : $f;
    }

    for (@HdrFieldsOrder) { push(@h, $_) if $_ ne $f;}
    @HdrFieldsOrder = @h;
}

# the value is not inserted now.
sub COPY_FIELD 
{ 
    my ($old, $new) = @_; 

    # already %Envelope is ready to use.
    if ($LoadConfigurationDone || $Envelope{"h:${old}:"}) {
	my ($xold, $xnew);
	$xnew = &FieldCapitalize($new);
	$xold = &FieldCapitalize($old);
	$Envelope{"h:${xnew}:"} = $Envelope{"h:${xold}:"};
    }
    else { # in *.ph files
	# XXX pass real operation to the later function
	# XXX while (($old,$new) = each %HdrFieldCopy) { ... } later
	$HdrFieldCopy{ $old } = $new;
    }

    &ADD_FIELD(&FieldCapitalize($new));
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

# XXX overwritten by %LocaProcedure and @DenyProcedure
sub PERMIT_PROCEDURE
{
    local($proc) = @_;

    push(@PermitProcedure, $proc);

    # may be defined by DENY_PROCEDURE() ?
    if ($LocalProcedure{$proc} eq 'ProcDeny') {
	delete $LocalProcedure{$proc};
    }

    # remove entry in @DenyProcedure
    if (@DenyProcedure) {
	my(@x, $x);
	for $x (@DenyProcedure) {
	    push(@x, $x) if $x ne $proc;
	}
	@DenyProcedure = @x;
    }
}

# XXX overwrite @PermitProcedure
sub DENY_PROCEDURE
{
    local($proc) = @_;
    $LocalProcedure{$proc} = 'ProcDeny';
}

# set up Hash %LocalProcedure
sub DEFINE_PROCEDURE
{
    local($proc, $fp) = @_;
    $LocalProcedure{$proc} = $fp;
}

sub DEFINE_MAXNUM_OF_PROCEDURE_IN_ONE_MAIL
{
    local($proc, $n) = @_;
    $LocalProcedure{"l#${proc}"} = $n;
}


# XXX overwritten by %LocaAdminProcedure and @DenyAdminProcedure
sub PERMIT_ADMIN_PROCEDURE
{
    local($proc) = @_;
    if ($proc !~ /^admin/) { $proc = "admin:proc";}

    push(@PermitAdminProcedure, $proc);

    # may be defined by DENY_ADMIN_PROCEDURE() ?
    if ($LocalAdminProcedure{$proc} eq 'ProcDeny') {
	delete $LocalAdminProcedure{$proc};
    }

    # remove entry in @DenyAdminProcedure
    if (@DenyAdminProcedure) {
	my(@x, $x);
	for $x (@DenyAdminProcedure) {
	    push(@x, $x) if $x ne $proc;
	}
	@DenyAdminProcedure = @x;
    }
}

# XXX overwrite @PermitAdminProcedure
sub DENY_ADMIN_PROCEDURE
{
    local($proc) = @_;
    if ($proc !~ /^admin/) { $proc = "admin:proc";}
    $LocalAdminProcedure{$proc} = 'ProcDeny';
}

# set up Hash %LocalAdminProcedure
sub DEFINE_ADMIN_PROCEDURE
{
    local($proc, $fp) = @_;
    if ($proc !~ /^admin/) { $proc = "admin:proc";}
    $LocalAdminProcedure{$proc} = $fp;
}

sub DEFINE_MAXNUM_OF_ADMIN_PROCEDURE_IN_ONE_MAIL
{
    local($proc, $n) = @_;
    if ($proc !~ /^admin/) { $proc = "admin:proc";}
    $LocalAdminProcedure{"l#${proc}"} = $n;
}

sub Debug { print STDERR "@_\n";}

# for conveinience
sub DUMMY { ;}
sub TRUE  { 1;}
sub FALSE { $NULL;}

1;
