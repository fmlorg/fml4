#!/usr/local/bin/perl
#
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $Id$;
$Rcsid   = 'fmlserv #: Wed, 29 May 96 19:32:37  JST 1996';

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# "free order is available" Now for the exist-check (DIR, LIBDIR) 
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
$0 =~ m#(\S+)/(\S+)# && (unshift(@INC, $1)); #for lower task;
unshift(@INC, $DIR); #IMPORTANT @INC ORDER; $DIR, $1(above), $LIBDIR ...;


### MAIN ###
&InitFmlServ;

umask(007);		# ATTENTION! require group-writable permission;_:

&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..

&Parse;				# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers
&FixHeaderFields(*Envelope);	# Phase 3, fixing fields information
&CheckCurrentProc(*Envelope);	# Phase 4, fixing environment and check loops
				# If an error is found, exit here.

&FmlServ(*Envelope);

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'};# Reply some report if-needed.

exit 0;
### MAIN ENDS ###


##### FmlServ Emulation Codes

# Fmlserv specific here
sub InitFmlServ
{
    require 'libkern.pl';

    # Check-routine before "chdir $DIR";
    # $DIR is up-directory over "fmlserv, several Mailing List $DIR".
    # e.g. $DIR = "/var/spool/ml"; Under it, you can find 
    # /var/spol/ml/fmlserv, /var/spol/ml/elena, /var/spol/ml/mirei, ...

    # Define the Up-Directory over ML's $DIR;
    $DIR =~ s#[/]+$##;
    $DIR =~ s#(/fmlserv)$##;
    $MAIL_LIST_DIR = $DIR;
    $FMLSERV_DIR   = $FMLSERV_DIR || "$DIR/fmlserv";

    # redefine the current $DIR (fmlserv's directory)
    $DIR           = $FMLSERV_DIR;
    $LIBDIR	   = $LIBDIR || $DIR;
    unshift(@INC, $FMLSERV_DIR);

    # Directory check
    $FMLSERV_DIR || die "Please define \$FMLSERV_DIR\n";

    # 0700 is enough for fmlserv, since fmlserv controls other ML's;
    if (! -d $FMLSERV_DIR) { mkdir($FMLSERV_DIR, 0700);}

    # log file of fmlserv
    $LOGFILE       = "$FMLSERV_DIR/log";
    &Touch($LOGFILE) unless -f $LOGFILE;
}


sub FmlServ
{
    local(*e) = @_;
    local($eval, $hook);

    ### initialize fmlserv procedures;
    $FmlServProcExitPat	= 'quit|end|exit';
    $FmlServProcPat = 
	'guide|info|help|lists|which|href|http|gopher|ftp|ftpmail';
    &SetFmlServProcedure;

    ### The first reply message;
    &MakePreambleOfReply(*e);

    # Declare 
    $e{'mode:fmlserv'} = 1;

    # ML::constructor() for fmlserv@$DOMAIN
    &NewML($FMLSERV_DIR, 'fmlserv', *e);

    # for logging all log's in fmlserv/log, too
    $FMLSERV_LOGFILE = $LOGFILE;

    # Alloc %MailList {list => directory_of_list} Global Variable
    # checks -d $MAIL_LIST_DIR/* -> %MailList (generated from the data)
    #           except for "^@\w+"
    &NewMLAA($MAIL_LIST_DIR, *MailList);

    # Summary of requested procedures for each ML
    # Envelope{Body} => %ReqInfo (Each ML)
    #                   @ReqInfo (fmlserv commands) 
    &SortRequest(*Envelope, *MailList, *ReqInfo);

    require 'libfml.pl';# if %ReqInfo;

    # Save 'main' NameSpace
    &Save_mainNS;			
    #&Dump_mainNS("$FMLSERV_DIR/tmp/main_name_space") if debug_dump;

    $FMLSERV_DIR = $DIR;	# save $DIR

    ###
    ### Processing For Each ML's
    ###
    foreach $ml (keys %ReqInfo) {
	next if $ml eq 'fmlserv'; # fmlserv is the last (internal functions);
	next if $ml =~ /^majordomo:/; # exceptions

	$DIR  = $MailList{$ml};	# reset $DIR for each ML's $DIR
	$cf   = "$DIR/config.ph";
	$proc = $ReqInfo{$ml};

	$CurrentProcML = $ml;	# for logfile

	if ($debug) {
	    &Debug("---Processing ML $ml");
	    &Debug("DIR\t$DIR\ncf\t$cf\nprocs\t$proc\n");
	}

	# Load 'ml' NS from $list/config.ph
	&NewML($DIR, $ml, *e, *MailList);

	&Lock;			# LOCK

	chdir $DIR || do {
	    &Log("cannot chdir $DIR, ignore given commands for $ml");
	    &Mesg(*e, "Hmm, ... I cannot find $ml. really?");
	    next;
	};

	# &Mesg(*e, "\n===Requested Commands for \"$ml\" Mailing List");
	# $e{'message'} .= $ML_cmds_log{$ml};

	### Processing $proc For $ml ###
	&Debug("FmlServ::DoFmlServProc($ml, $proc, *e);") if $debug;
	&DoFmlServProc($ml, $proc, *e);

	### mget ... for $ml;
	if ($FML_EXIT_HOOK =~ /mget3_SendingEntry/) {
	    undef $eval;
	    foreach $n ('SendingEntry', 'SendingArchiveEntry') {
		$eval .= sprintf("\@%s'$n = \@main'$n;\n", $ml);
		$eval .= sprintf("%%%s'$n = %%main'$n;\n", $ml);
		$hook .= sprintf("\@main'$n = \@%s'$n;\n", $ml);
		$hook .= sprintf("%%main'$n = %%%s'$n;\n", $ml);
	    }

	    # hook
	    $hook .= qq#&mget3_SendingEntry;\n#;

	    # eval
	    eval($eval); &Log($@) if $@;

	    $FML_EXIT_HOOK =~ s/&mget3_SendingEntry;//g;
	    &mget3_Reset;	# only mget3 routine called..
	}	

	&Unlock;		# UNLOCK

	&RunHooks;		# run-hook for each ML

	undef $FML_EXIT_HOOK;	# unlink each ML hook

	# Reload NS from main'NS
	&DestructCompatMajordomo if $e{'mode:majordomo'};
	&ResetNS;

	undef $CurrentProcML;
    }# each MLs

    $FML_EXIT_HOOK = $hook;
    $DIR           = $FMLSERV_DIR; #reset global variable

    ###
    ### FMLSERV INTERNAL (ITSELF) FUNCTIONS; ###
    ###
    if ($debug) { &Debug("---Processing ML fmlserv");}

    chdir $DIR || die $!;

    &NewML($FMLSERV_DIR, 'fmlserv', *e, *MailList);

    if ($ReqInfo{'fmlserv'}) {
	&Debug("FmlServ::DoFmlServItselfFunctions") if $debug;
	&DoFmlServItselfFunctions(*ReqInfo, *e);

	# Report Mail is From and Reply-To MAIL_LIST;
	$e{'GH:From:'}          = $MAIL_LIST;# special case when fmlserv
	$e{'message:h:subject'} = "Fmlserv command status report";
    }

    ### We ALWAYS append the simple help ###
    if (-f "$FMLSERV_DIR/help") {
	$e{'message:append:files'} = "$FMLSERV_DIR/help";
    }
    else {
	&AppendFmlServInfo(*e);
    }
}


######### Standard Utilities ##########
### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}


#########################################################################
##### LIBRARY OF FMLSERV #####
sub MakePreambleOfReply
{
    local(*e) = @_;
    &Mesg(*e, "Fmlserv (Fml Listserv-Like Interface) Results:");
}

sub DoFmlServItselfFunctions
{
    local(*proc, *e) = @_;
    local($procs2fml);

    if ($proc{'fmlserv'}) {
	&use('fml');

	foreach (split(/\n/, $proc{'fmlserv'})) {
	    &Debug("DoFmlServItselfFunctions($_)") if $debug;

	    # ATTENTION! already "cut the first #.. syntax"
	    # in sub SortRequest
	    $org_str = $_;
	    ($_, @Fld) = split;
	    @Fld = ('#', $_, @Fld);

	    # REPORT IF REPLY IS DEFINED?
	    #if($Procedure{"r#fmlserv:$_"}){&Mesg(*e,"\n${ml}> $org_str");}
	    # Anyway We REPORT ALWAYS Anything!
	    &Mesg(*e, "\nfmlserv> $org_str");

	    ### Procedures is lower-case;
	    tr/A-Z/a-z/;

	    # FIRST fmlserv:command form here
	    if ($proc = $Procedure{"fmlserv:$_"}) {
		$0 = "--Command calling $proc: $FML $LOCKFILE>";
		&Debug("Call $proc for [$org_str]") if $debug;
		
		# PROCEDURE
		# $status = &$proc("fmlserv:$_", *Fld, *e, *misc);
		$status = &$proc($_, *Fld, *e, *misc);
		# &Mesg(*e, "*** $status") if $status;
	    }
	    # WHEN NOT FMLSERV:Commands, call usual command(libfml.pl)
	    # not call multiple times, for only one calling
	    else {
		&Debug("Call \$proc for [$org_str]") if $debug;
		$procs2fml .= "$org_str\n";
	    }
	}# foreach;

	### CALL when NOT MATCHED TO FMLSERV:Commnads
	# foreach (split(/\n/, $proc2fml)) { &Mesg(*e, "fmlserv> $_");}
	&Command($procs2fml) if $procs2fml;
    }
}


sub DoFmlServProc
{
    local($ml, $proc, *e) = @_;
    local($sp, $guide_p, $auth, $badproc);

    $ACTIVE_LIST = $MEMBER_LIST unless $ML_MEMBER_CHECK; # tricky

    # check member-lists (2.1 extentions)
    @MEMBER_LIST || do { @MEMBER_LIST = ($MEMBER_LIST);};

    foreach $file (@MEMBER_LIST) {
	&Debug("---MLMemberCheck($From_address in $file);") if $debug;
	-f $file && &CheckMember($From_address, $file) && ($auth++, last);
    }

    if ($auth) {
	foreach (split(/\n/, $proc)) { &Mesg(*e, "${ml}> $_");}
	&Command($proc);
    }
    else {
	local($mesg);
	$mesg  = "\n   Your subscribe request is forwarded to the maintainer.";
	$mesg .= "\n   Please wait a little.";

	&Debug("ERROR: CheckMember($From_address, @MEMBER_LIST)") if $debug;
	foreach (split(/\n/, $proc)) {
	    &Debug("DoFmlServProc($_)") if $debug;
	    s/\s+$//;		# cut the \s+

	    &Mesg(*e, "\n${ml}> $_");
	    &Debug("DoFmlServProc::$_()") if $debug;
	    
	    if (/^(guide|info)/i)    { 
		&GuideRequest; 
		&Mesg(*e, "   guide is sent to $From_address");
		next;
	    }

	    if (/^subscribe\s*(.*)/i){ 
		$addr = $1; 

		if ($ML_MEMBER_CHECK) {
		    &Mesg(*e, $mesg);
		    &Warn("Subscribe Request $ML_FN", &WholeMail);
		}
		else {
		    &use('amctl');
		    $addr = $addr || $From_address;
		    &Mesg(*e, "   Auto-Register-Routine called for [$addr]");
		    &AutoRegist(*e, $addr);
		}

		next;
	    }

	    &Debug("DoFmlServProc::$_(){YOU ARE NOT MEMBER($ml)") if $debug;

	    &Mesg(*e, "\n   *** [$_] FORBIDDEN FOR NOT MEMBER OF ML[$ml]");
	}
    }
}

#
# --majorodmo mode is the compatibility with majordomo
# but the conflict fml's ml is a directory <-> majordomo's ml == members of fml
# Hmm...
sub NewML
{
    local($DIR, $ml, *e, *MailList) = @_;
    local($cf)  = "$DIR/config.ph";

    # reset
    undef $e{'mode:majordomo:chmemlist'};

    print STDERR "NewML::Check($cf)\n" if $debug;

    # Define Defaults against "no $MAIL_LIST_DIR/$ml/config.ph"
    print STDERR "NewML::SetMLDefaults($DIR, $ml)\n" if $debug;

    &SetMLDefaults($DIR, $ml);
    if ($e{'mode:majordomo'} && $MailList{"majordomo:$ml"}) { 
	&CompatMajordomo($DIR, $ml);
    }
    &FixMLMode($DIR, $ml);	# check $DIR/$ml.auto ...

    if (-f $cf) {
	print STDERR "NewML::Load($cf)\n" if $debug;
	&LoadMLNS($cf);		# eval("$DIR/config.ph")
    }

    if ($debug) {
	for (FQDN, DOMAINNAME, MAIL_LIST, CONTROL_ADDRESS, 
	     ML_FN, XMLNAME, XMLCOUNT, MAINTAINER) {
	    eval "printf STDERR \"%-20s %s\\n\", '$_', \$$_;";
	}
    }

    ### do actions for each $list ###
    # RESET IMPORTANT VARIABLES
    # direct reply e.g. get, ... 
    $e{'h:Reply-To:'}             = $e{'Addr2Reply:'};
    $From_address = $e{'h:From:'} = &Conv2mailbox($e{'from:'});

    &GetTime;

    # required settings
    $COMMAND_ONLY_SERVER      = 1;
    $COMMAND_SYNTAX_EXTENSION = 1;

    for ('SPOOL_DIR', 'TMP_DIR', 'VAR_DIR', 'VARLOG_DIR', 'VARRUN_DIR') {
	$s .= "-d \$$_ || mkdir(\$$_, 0700); \$$_ =~ s#$DIR/##g;\n";
	$s .= "\$FP_$_ = \"$DIR/\$$_\";\n"; # FullPath-ed (FP)
    }

    eval($s); 
    &Log("FAIL EVAL \$SPOOL_DIR ...") if $@;

    # Foce Reply-To: be fmlserv@fqdn in &Notify;
    $e{'GH:Reply-To:'}  = "fmlserv\@$DOMAINNAME";
}


sub FixMLMode
{
    local($dir, $ml) = @_;
    local($mdir) = "$MAIL_LIST_DIR/$ml";

    $ML_MEMBER_CHECK = 1 if -f "${mdir}.closed";
    $ML_MEMBER_CHECK = 0 if -f "${mdir}.auto";
}


sub SetMLDefaults
{
    local($dir, $ml) = @_;
    local($domain);

    # $DOMAINNAME, $FQDN should be used of _main NS
    $domain          = $DOMAINNAME || $FQDN; # preserv original DOMAINNAME
    $MAIL_LIST       = "$ml\@$domain";
    $ML_FN           = "($ml ML)";
    $XMLNAME         = "X-ML-Name: $ml";
    $XMLCOUNT        = "X-Mail-Count";
    $CONTROL_ADDRESS = "fmlserv\@$domain";
    $MAINTAINER      = "fmlserv-admin\@$domain";

    # Directory
    $SPOOL_DIR                     = "spool";
    $TMP_DIR                       = "tmp"; # tmp, after chdir, under DIR
    $VAR_DIR                       = "var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR                    = "var/log";
    $VARRUN_DIR                    = "var/run";

    # files
    $MEMBER_LIST                   = "$DIR/members"; # member list
    $ACTIVE_LIST                   = "$DIR/actives"; # active member list
    $OBJECTIVE_FILE                = "$DIR/objective"; # objective file
    $GUIDE_FILE                    = "$DIR/guide";
    $HELP_FILE                     = "$DIR/help";
    $DENY_FILE                     = "$DIR/deny"; # attention to illegal access
    $WELCOME_FILE                  = "$DIR/guide"; # could be $DIR/welcome
    $LOGFILE                       = "$DIR/log"; # activity log file
    $MGET_LOGFILE                  = "$DIR/log"; # log file for mget routine
    $SMTP_LOG                      = "$VARLOG_DIR/_smtplog";
    $SUMMARY_FILE                  = "$DIR/summary"; # article summary file
    $SEQUENCE_FILE                 = "$DIR/seq"; # sequence number file
    $MSEND_RC                      = "$VARLOG_DIR/msendrc";
    $LOCK_FILE                     = "$VARRUN_DIR/lockfile.v7"; # liblock.pl


    # IF NOT EXIST;
    -f $GUIDE_FILE   || ($GUIDE_FILE   = "$FMLSERV_DIR/help");
    -f $HELP_FILE    || ($HELP_FILE    = "$FMLSERV_DIR/help");
    -f $DENY_FILE    || ($DENY_FILE    = "$FMLSERV_DIR/help");
    -f $WELCOME_FILE || ($WELCOME_FILE = "$FMLSERV_DIR/help");
}


# The point to mention is "skip if /^\./"!!!
# We may use this feature for the compatibility with majordomo
sub NewMLAA
{
    local($dir, *entry) = @_;

    opendir(DIRD, $dir) || die $!;
    foreach (readdir(DIRD)) {
	next if /^\./;	# this skip is important for the further trick (^^)

	# etc is the special directory
	next if $_ eq "etc";

	# $_.archive is the default archive dir of $_
	if (/^(\S+)\.archive$/ && -d "$dir/$_") {
	    local($mf) = $1;	# member file
	    next if $Envelope{'mode:majordomo'} && -f "$dir/$mf";
	}
	# 
	# e.g. $_.info, $_.auto is the file of the ml $_ (majordomo)
	# skip
	if ($Envelope{'mode:majordomo'} && -f "$dir/$_" && /^(\S+)\.(\S+)$/) {
	    next if -f "$dir/$1";
	}

	# FML Case
	# IF -d elena && -f elena.auto
	if ($Envelope{'mode:majordomo'} && -f "$dir/$_" && /^(\S+)\.(\S+)$/) {
	    next if -d "$dir/$1";
	}

	# A Candidate
	$entry{$_} = "$dir/$_"  if -d "$dir/$_" && (! /^\@/);

	# Compat:Majordomo
	if ($Envelope{'mode:majordomo'} && -f "$dir/$_") {
	    -d "$dir/\@$_" || mkdir("$dir/\@$_", 0755);

	    if (-d "$dir/${_}.archive") {
		-d "$dir/\@$_/var" || mkdir("$dir/\@$_/var", 0755);
		eval("symlink(\"$dir/${_}.archive\", \"$dir/\@$_/var/archive\")");
	    }

	    $entry{$_} = "$dir/\@$_";
	    $entry{"majordomo:$_"} = "$dir/\@$_";
	    print STDERR "Declare \$entry{majordomo:$_}\n";
	} 
    }
    closedir(DIRD);

    if ($debug) {
	while (($key, $value) = each %entry) {
	    print STDERR "ML AssocArray [$key]\t=>\t[$value]\n";
	}
    }
}


# ATTENTION! "cut the first #.. syntax"
sub SortRequest
{
    local(*e, *MailList, *ML_cmds) = @_;
    local($cmd, $ml, @p, $s, $k, $v);

    foreach (split(/\n/, $e{'Body'})) {
	next if /^\s*$/;	# skip null line
	s/^\#\s*//;		# cut the first #.. syntax
	next if /^\S+=\S+/;	# variable settings, skip

	($cmd, $ml, @p) = split(/\s+/, $_);
	$ml =~ tr/A-Z/a-z/;

	# EXPILICIT ML DETECTED. 
	# $ml is non-nil and the ML exists
	if ($ml && $MailList{$ml}) {	
	    $ML_cmds{$ml}         .= "$cmd @p\n";
	    $ML_cmds_log{$ml}     .= "${ml}> $cmd $ml @p\n";	    
	}
	# LISTSERV COMPATIBLE: COMMANDS SINCE NO EXPILICIT ML.
	else {
	    last if /^\s*($FmlServProcExitPat)/i;
	    
	    if (/^\s*($FmlServProcPat)/i) { # default >> virtual fmlserv ML
		$ML_cmds{'fmlserv'} .= "$_\n";
		next;
	    }

	    &Mesg(*e, "\nfmlserv> $_");

	    if ($ml) {
		&Mesg(*e, "   ML[$ml] NOT EXISTS; Your request is ignored\n");
	    }
	    else {
		&Mesg(*e, "   Unknown fmlserv commands");
	    }
	}
    }    

    if ($debug) { while (($k,$v) = each %ML_cmds) { &Debug("[$k]=>\n$v");}}
}


########## Name Space Operations ##########

sub Save_mainNS
{
    local($ns) = @_;
    local($key, $val, $eval);

    if ($] =~ /5.\d\d\d/) {
	*stab = *{"main::"};
    }
    else {
	(*stab) = eval("*_main");
    }

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) {
	    next if $key eq '0'; # $0;
	    $eval .= "\$org'$key = \$main'$key;\n";
	    $NameSpaceS{$key} = 1;
	}
	if (defined @entry) { 
	    $eval .= "\@org'$key = \@main'$key;\n";
	    $NameSpaceA{$key} = 1;
	}
	if ($key ne "_$package" && defined %entry) { 
	    $eval .= "\%org'$key = \%main'$key;\n";
	    $NameSpaceAA{$key} = 1;
	}
    }

    print $eval if $debug_ns;
    eval($eval); &Log($@) if $@;
}


sub Dump_mainNS
{
    local($outfile) = @_;
    local($key, $val);

    if ($] =~ /5.\d\d\d/) {
	*stab = *{"main::"};
    }
    else {
	(*stab) = eval("*_main");
    }

    open(OUT, "> $outfile") || die $!;

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) { print OUT "$key\t$entry\n";}
	if (defined @entry) { print OUT "$key\t@entry\n";}
	if ($key ne "_$package" && defined %entry) { 
	    print OUT "$key\t",join(" ", %entry),"\n";
	}
    }

    close(OUT);
}


sub ResetNS
{
    local($eval);

    # undef main NS
    foreach (keys %ML_NameSpaceS)  { $eval .= "undef \$main'$_;\n";}
    foreach (keys %ML_NameSpaceA)  { $eval .= "undef \@main'$_;\n";}
    foreach (keys %ML_NameSpaceAA) { $eval .= "undef \%main'$_;\n";}

    # load main NS from org(saved main) NS
    foreach (keys %NameSpaceS)  { $eval .= "\$main'$_ = \$org'$_;\n";}
    foreach (keys %NameSpaceA)  { $eval .= "\@main'$_ = \@org'$_;\n";}
    foreach (keys %NameSpaceAA) { $eval .= "\%main'$_ = \%org'$_;\n";}

    &Debug($eval) if $debug_ns;
    eval $eval || &Log($@);
}


# SYNTAX
# $s = $_;(present line of the given mail body)
# $ProcFileSendBack($proc, *s);
sub SetFmlServProcedure
{
    %Procedure = (
		  'fmlserv:lists',	'ProcLists',
		  'fmlserv:which',	'ProcWhich',

		  # WWW Interface
		  # WWW Interface
		  'fmlserv:href',	'ProcHRef',
		  'r#fmlserv:href',	1,

		  'fmlserv:http',	'ProcHRef',
		  'r#fmlserv:http',	1,

		  'fmlserv:gopher',	'ProcHRef',
		  'r#fmlserv:gopher',	1,

		  'fmlserv:ftp',	'ProcHRef',
		  'r#fmlserv:ftp',	1,

		  # ftpmail == ftp ( anyway.. 95/10)
		  'fmlserv:ftpmail',	'ProcHRef',
		  'r#fmlserv:ftpmail',	1,
		  );
}



###### PROC PROCEDURES #####

sub GetEntryByName
{
    local($file, $key) = @_;
    local($s);

    open(F, $file) || do { &Log("Cannot open $file"); return '';};
    while(<F>) { $s .= $_ if /$key/;}
    close(F);

    $s;
}


sub ProcLists
{
    local($proc, *Fld, *e, *misc) = @_;

    #&Mesg(*e, "\nfmlserv> $proc");
    &Mesg(*e, "  $MAIL_LIST serves the following lists:\n");
    #$e{'message'} .= sprintf("   %s\n", 'Lists:');

    while (($key, $value) = each %MailList) {
	next if $key eq 'fmlserv'; # fmlserv is an exception
	next if $key =~ /^majordomo:/;
	$e{'message'} .= sprintf("\t%-15s\t%s\n", $key);
    }

    &Mesg(*e, "\n");
}


sub ProcWhich
{
    local($proc, *Fld, *e, *misc) = @_;
    local($r, $s, $DIR, $hitc, $reply);
    local($addr) = $Fld[2] || $From_address;

    &Log($proc);
    #&Mesg(*e, "\nfmlserv> $proc");
    &Mesg(*e, "\"$proc $addr\" yields that\n");

    foreach $ml (keys %MailList) {
	next if $ml eq 'fmlserv'; # fmlserv is an exception

	$DIR = $MailList{$ml};

	# get MEMBER_LIST
	if ("$DIR/config.ph") {
	    $s = "$DIR/config.ph";
	    $s = &GetEntryByName($s, '^\$MEMBER_LIST');
	    $s =~ s/\$DIR/$DIR/g;	# expand $DIR
	    $s .= ' 1;';
	    
	    # and eval it
	    eval $s;
	    $r = 1 if $@ eq "";	# $r is a result
	}
	elsif (-f "$DIR/members") {
	    # sub NewML:: default is
	    # $MEMBER_LIST = "$DIR/members"; # member list
	    $r = $MEMBER_LIST = "$DIR/members";
	}
	else {
	    &Mesg(*e, "*** $ml Mailing List has a Configuration Error");
	}

	# if eval is succeed, get entry for $addr
	if ($r && ($s = &CheckMember($addr, $MEMBER_LIST))) {
	    $reply .= sprintf("   %-15s\t%s\n", $ml, $addr);
	    $hitc++;
	}
    }#FOREACH;

    if ($hitc) { 
	&Mesg(*e, "   $addr is registered in the following lists:");
	&Mesg(*e, sprintf("   %-15s\t%s", 'List', 'Address'));
	&Mesg(*e, "   ".('-' x 50));
	&Mesg(*e, $reply);
    }
    else {
	&Mesg(*e, "*** $addr is not registered in any lists.");
    }
}


sub ProcHRef
{
    local($proc, *Fld, *e, *misc) = @_;
    local(*r, $s, $DIR, $request);

    &Debug("$proc, @Fld, *e, *misc)");

    ($request = $Fld[2]) || do {
	&Mesg(*e, "\tERROR: NO GIVEN PARAMETER");
	return;
    };

    &Log("$proc $request");

    # Include required library
    require 'libhref.pl';

    &HRef($request, *e);

    1;
}



##################################################################
sub CompatMajordomo
{
    local($dir, $ml) = @_;
    local($mldir) = $MAIL_LIST_DIR;

    print STDERR "MAJORDOMO::($dir, $ml) = @_; mldir=$mldir\n" if $debug;

    $MEMBER_LIST                   = "$mldir/$ml"; # member list
    $ACTIVE_LIST                   = "$mldir/$ml"; # active member list
    $GUIDE_FILE                    = "$mldir/$ml.info";

    push(@ARCHIVE_DIR, "$mldir/$ml.archive");
    $Envelope{'mode:majordomo:chmemlist'} = 1;
}


sub DestructCompatMajordomo
{
    undef $MEMBER_LIST;
    undef $ACTIVE_LIST;
    undef $GUIDE_FILE;
    undef @ARCHIVE_DIR;
}


##################################################################
sub AppendFmlServInfo
{
    local(*e) = @_;
    local($m);

    $m = qq#;
    ;
    ****************************************************************;
    ----- Simple HELP of $MAIL_LIST -----;
    ;
    "Fmlserv" is the Fml Interface for Listserv or Majordomo Styles;
    ;
    ;In the description below items contained in [] are optional.;
    ;do not include the [] around it.;
    ;
    Fmlserv command syntax is a Fml command with a "Mailing-List" Name;
    ;
    ;   Command Mailing-List [Command Arguments or Options];
    ;
    Available typical commands for "Fmlserv":;
    ;
    subscribe Mailing-List [address];
    ;       Subscribe yourself (or "address" if specified) to ;
    ;       the named Mailing-List;
    ;
    unsubscribe Mailing-List [address];
    ;       Unsubscribe yourself (or "address" if specified) ;
    ;       from the named Mailing-List;
    ;
    help;
    ;       Fmlserv help;
    ;
    lists;
    ;       List of maling lists this fmlserv serves;
    ;
    which [address];
    ;       Which lists you (or "address" if specified) are registerd.;
    ;
    exit;
    end;
    quit;
    ;       End of processing (these three commands are the same).;
    ;
    index Mailing-List;
    ;       Return an index of files you can "get" for Mailing-List.;
    ;
    guide Mailing-List;
    info  Mailing-List;
    ;       Retrieve the general "guide" for the Mailing-List.;
    ;
    members Mailing-List;
    ;       get the member list of Mailing-List;
    ;
    actives Mailing-List;
    ;       get the list of members who read Mailing-List now;
    ;
    get     Mailing-List article-number;
    ;       get the "article-number" article count of Mailing-List;
    ;
    mget    Mailing-List 1-10 mp;
    ;       get the latest 10 articles of Mailing-List in a set;
    ;       PAY ATTENTION! the options is after the ML's name;
    ;
#;

    $m =~ s/;//g;
    $e{'message'} .= $m;
}


##################################################################
##### ml Name Space 
##################################################################
package ml;

sub main'LoadMLNS
{
    local($file) = @_;
    local($key, $val, $eval);

    # load Variable list(Association List)
    %ml'NameSpaceS  = %main'NameSpaceS;
    %ml'NameSpaceA  = %main'NameSpaceA;
    %ml'NameSpaceAA = %main'NameSpaceAA;
    
    # load original main NameSpace
    foreach (keys %NameSpaceS)  { $eval .= "\$ml'$_ = \$main'$_;\n";}
    foreach (keys %NameSpaceA)  { $eval .= "\@ml'$_ = \@main'$_;\n";}
    foreach (keys %NameSpaceAA) { $eval .= "\%ml'$_ = \%main'$_;\n";}
    eval($eval); &main'Log($@) if $@; #';
    undef $eval;

    # load the presnet directry information (tricky?)
    $ml'DIR = $main'DIR;

    do $file;

    if ($] =~ /5.\d\d\d/) {
	*stab = *{"ml::"};
    }
    else {
	(*stab) = eval("*_ml");
    }

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	local(*entry) = $val;
		
	if (defined $entry) { 
	    $eval .= "\$main'$key = \$ml'$key;\n";
	    $ML_NameSpaceS{$key} = 1;
	}

	if (defined @key) { 
	    $eval .= "\@main'$key = \@ml'$key;\n";
	    $ML_NameSpaceA{$key} = 1;
	}

	if ($key ne "_$package" && defined %key) { 
	    $eval .= "\%main'$key = \%ml'$key;\n";
	    $ML_NameSpaceAA{$key} = 1;
	}
    }

    $eval .= "\%main'ML_NameSpaceS = \%ml'ML_NameSpaceS;\n";
    $eval .= "\%main'ML_NameSpaceA = \%ml'ML_NameSpaceA;\n";
    $eval .= "\%main'ML_NameSpaceAA = \%ml'ML_NameSpaceAA;\n";
    
    &Debug($eval) if $debug_ns;
    eval($eval); 
    &main'Log($@) if $@; #';
}


1;
