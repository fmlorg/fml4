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

umask(007);			# ATTENTION! require group-writable perm;_:

&CheckUGID;

chdir $DIR || die("Can't chdir to DIR[$DIR]\n");

				### fml parsing process (the same as fml.pl)

&InitConfig;			# initialize date etc..

&Parse;				# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers
&FixHeaderFields(*Envelope);	# Phase 3, fixing fields information
&CheckCurrentProc(*Envelope);	# Phase 4, fixing environment and check loops
				# If an error is found, exit here.

				### fml parsing process ends

&FmlServ(*Envelope);		### GO actual fmlserv process

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'};# Reply some report if-needed.

exit 0;
### MAIN ENDS ###


##### FmlServ (Listserv-Emulation) Codes
#####    the fundamental idea is to use virtual "fmlserv" Maling List;
#####    of course, group-writable permission is required;_;

# Fmlserv specific here
sub InitFmlServ
{
    # fml main (kernel) library (libkern.pl from fml.pl)
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
    -d $FMLSERV_DIR || die("Cannot find FMLSERV_DIR[$FMLSERV_DIR]\n");

    # 0700 is enough for fmlserv, since fmlserv controls other ML's;
    # 0770 requires other ML's;_; (So, I dislike listserv type ...)
    if (! -d $FMLSERV_DIR) { mkdir($FMLSERV_DIR, 0700);}

    # log file of fmlserv
    $LOGFILE       = "$FMLSERV_DIR/log";
    &Touch($LOGFILE) unless -f $LOGFILE;
}


sub FmlServ
{
    local(*e) = @_;
    local($eval, $hook);

    ### 00: Load Command Library 
    require 'libfml.pl'; # if %ReqInfo;

    ### 01: Configuration ...;
    &InitFmlServProcedure; # initialize fmlserv procedures;
    &MakePreambleOfReply(*e); # The first reply message;

    $e{'mode:fmlserv'} = 1; # Declare (for e.g. mkdir permission change)

    ### 02: alloc virtual "fmlserv" ML 
    # ML::constructor() for fmlserv@$DOMAIN
    #   fmlserv = new ML(Fmlserv);
    # 
    &NewML($FMLSERV_DIR, 'fmlserv', *e);

    # for logging all log's in fmlserv/log, SET AGAIN
    # &InitFmlServ: LOGFILE = $FMLSERV_DIR/log 
    # 
    $FMLSERV_LOGFILE = $LOGFILE;

    ### 03: GENERATE "AVAILABLE MAILING LISTS TABLE";
    # Alloc Association Array %MailList {list => directory_of_list} (global)
    # checks -d $MAIL_LIST_DIR/* -> %MailList (generated from the data)
    #           except for "^@\w+"
    # 
    &NewMLAA($MAIL_LIST_DIR, *MailList);

    ### 04: SORT REQUEST: Sorting requests for each ML
    # Envelope{Body} => %ReqInfo (Each ML)
    #                   @ReqInfo (fmlserv commands) 
    # 
    &SortRequest(*Envelope, *MailList, *ReqInfo);

    ### 05: REFUGING THE CURRENT NAME SPACE, GO EACH ML NAME SPACE; 
    ### 

    &Save_mainNS; # Save 'main' NameSpace (save the current name space)

    if (debug_dump) { &Dump_mainNS("$FMLSERV_DIR/tmp/main_name_space");}

    $FMLSERV_DIR = $DIR;	# save the $DIR (must be == $FMLSERV_DIR)

    ### 05.01: GO Processing For Each ML's ...;
    # 
    # Requests to $ml are available if %MailList has the entry;
    # Do aggregated requests (plural lines) $ReqInfo{$ml} for each $ml;
    # 
    for $ml (keys %ReqInfo) {
	# Exceptions: fmlserv is later processed (internal functions);
	#             majordomo:$ml is $ml majordomo(<1.91?)-compat flags;
	next if $ml eq 'fmlserv'; 
	next if $ml =~ /^majordomo:/;

	# reset the current procs for each ML
	$DIR  = $MailList{$ml};	  # ML's $DIR
	$cf   = "$DIR/config.ph"; # config.ph
	$proc = $ReqInfo{$ml};	  # requests

	if ($debug) {
	    &Debug("---Processing ML $ml");
	    &Debug("DIR\t$DIR\ncf\t$cf\nprocs\t$proc\n");
	}

	# Load $ml NAME SPACE from $list/config.ph
	&NewML($DIR, $ml, *e, *MailList);

	# test chdir $DIR, next if it fails;
	# if it succeeds, lock and do the processing;
	chdir $DIR || do {
	    &Log("cannot chdir DIR[$DIR], ignore given commands for $ml");
	    &Mesg(*e, "Hmm, ... I cannot find $ml. $ml really exists?");
	    next;
	};

	### PROCESS BEGIN; 
	&Lock;			# LOCK each ML (lock $FP_SPOOL_DIR)

	if ($debug) {
	    &Mesg(*e, "\ndebug> requests for \"$ml\" Mailing List");
	    # &Mesg(*e, $ML_cmds_log{$ml});
	    &Debug("FmlServ::DoFmlServProc($ml, $proc, *e);");
	}

	### Processing $proc For $ml ###
	# DoFmlServProc emulation;
	&DoFmlServProc($ml, $proc, *e);

	### alloc $ml NAME SPACE for mget;
	# attention here; we do not set $FML_EXIT_HOOK
	# aggregate the mget requests, after this routine,
	# we set $FML_EXIT_HOOK;
	if ($FML_EXIT_HOOK =~ /mget3_SendingEntry/) {
	    local($n);

	    undef $eval;

	    for $n ('SendingEntry', 'SendingArchiveEntry') {
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
	### PROCESS ENDS;

	&RunHooks;		# run-hook for each ML

	undef $FML_EXIT_HOOK;	# unlink each ML hook

	# Reload NS from main'NS
	&DestructCompatMajordomo if $e{'mode:majordomo'};
	&ResetNS;
    } # each ML ends;

    ### 06: FMLSERV INTERNAL (ITSELF) FUNCTIONS;
    # reset global variable
    $FML_EXIT_HOOK = $hook;
    $DIR           = $FMLSERV_DIR; 

    if ($debug) { &Debug("---Processing ML fmlserv");}

    # chdir $FMLSERV_DIR; 
    chdir $DIR || die("$!:cannot chdir FMLSERV_DIR[$DIR]\n");

    # alloc virtual "fmlserv";
    &NewML($FMLSERV_DIR, 'fmlserv', *e, *MailList);

    # request using internal functions or e.g. to get fmlserv/help;
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


#####
##### LIBRARY FUNCTIONS OF FMLSERV 
#####

sub MakePreambleOfReply
{
    local(*e) = @_;
    &Mesg(*e, "Fmlserv (Fml Listserv-Like Interface) Results:");
}

sub DoFmlServItselfFunctions
{
    local(*proc, *e) = @_;
    local($procs2fml, $org_str, @Fld);

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

	    # FIRST TRY fmlserv:command form here
	    if ($proc = $Procedure{"fmlserv:$_"}) {
		$0 = "--Fmlserv command $proc: $FML $LOCKFILE>";
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

    # reset arrays since fmlserv handles several different ML's;
    undef @MEMBER_LIST;
    undef @ACTIVE_LIST;

    # already $DIR/$ml/file form; 
    # initialize some arrays; if auto-regist is clear here, we reset;
    if (! $ML_MEMBER_CHECK) { $ACTIVE_LIST = $MEMBER_LIST;}
    push(@MEMBER_LIST, $MEMBER_LIST);
    push(@ACTIVE_LIST, $ACTIVE_LIST);

    if (! $ML_MEMBER_CHECK) {
	$ACTIVE_LIST = $MEMBER_LIST;
	push(@ACTIVE_LIST, @MEMBER_LIST);
    }

    $auth = &MailListMemberP($From_address);

    if ($auth) {
	local($req);
	for $req (split(/\n/, $proc)) {
	    for (split(/\n/, $req)) {
		&Mesg(*e, "${ml}> $_");
	    }
	}
	&Command($proc);
    }
    else {
	local($mesg);
	$mesg  = "\n   Your subscribe request is forwarded to the maintainer.";
	$mesg .= "\n   Please wait a little.";

	&Debug("Error: MailListMemberP($From_address) fails") if $debug;

	for (split(/\n/, $proc)) {
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

    &GetTime;

    # reset
    undef $e{'mode:majordomo:chmemlist'};

    if ($debug) {
	print STDERR "NewML::Check($cf)\n";

	# Define Defaults against "no $MAIL_LIST_DIR/$ml/config.ph"
	print STDERR "NewML::SetMLDefaults($DIR, $ml)\n";
    }

    # default before loading $DIR/config.ph;
    &SetMLDefaults($DIR, $ml);

    # compatible (required?)
    if ($e{'mode:majordomo'} && $MailList{"majordomo:$ml"}) { 
	&CompatMajordomo($DIR, $ml);
    }

    # compatible $DIR/$ml.auto ...?
    # inlined &FixMLMode($DIR, $ml);
    {
	local($mdir) = "$MAIL_LIST_DIR/$ml";
	$ML_MEMBER_CHECK = 1 if -f "${mdir}.closed";
	$ML_MEMBER_CHECK = 0 if -f "${mdir}.auto";
    }

    # Load $DIR/config.ph, if the loading fails, default values are used;
    if (-f $cf) {
	print STDERR "NewML::Load($cf)\n" if $debug;
	&LoadMLNS($cf);		# eval("$DIR/config.ph")
    }

    # RESET IMPORTANT VARIABLES (direct reply e.g. get, ... )
    # IMPORTANT: Foce Reply-To: be fmlserv@fqdn in &Notify;
    # 
    $COMMAND_ONLY_SERVER          = 1;
    $COMMAND_SYNTAX_EXTENSION     = 1;
    $e{'h:Reply-To:'}             = $e{'Addr2Reply:'};
    $From_address = $e{'h:From:'} = &Conv2mailbox($e{'from:'});
    $e{'GH:Reply-To:'}            = "fmlserv\@$DOMAINNAME";

    # Directory *_DIR -> FP_*_DIR (fully pathed)
    for (SPOOL_DIR,TMP_DIR,VAR_DIR,VARLOG_DIR,VARRUN_DIR,VARDB_DIR) {
	$s .= "-d \$$_ || mkdir(\$$_, 0700); \$$_ =~ s#$DIR/##g;\n";
	$s .= "\$FP_$_ = \"$DIR/\$$_\";\n"; # FullPath-ed (FP)
    }
    eval($s); 
    &Log("FAIL EVAL \$SPOOL_DIR ...") if $@;

    ### Here, all variables must be set already. 
    if ($debug) {
	for (FQDN, DOMAINNAME, MAIL_LIST, CONTROL_ADDRESS, 
	     ML_FN, XMLNAME, XMLCOUNT, MAINTAINER,
	     MEMBER_LIST, ACTIVE_LIST) {
	    eval("printf STDERR \"%-20s %s\\n\", '$_', \$$_;");
	}
    }
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
    $SPOOL_DIR       = "spool";
    $TMP_DIR         = "tmp"; # tmp, after chdir, under DIR
    $VAR_DIR         = "var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR      = "var/log";
    $VARRUN_DIR      = "var/run";
    $VARDB_DIR       = "var/db";

    # Files
    $MEMBER_LIST     = "$DIR/members"; # member list
    $ACTIVE_LIST     = "$DIR/actives"; # active member list
    $OBJECTIVE_FILE  = "$DIR/objective"; # objective file
    $GUIDE_FILE      = "$DIR/guide";
    $HELP_FILE       = "$DIR/help";
    $DENY_FILE       = "$DIR/deny"; # attention to illegal access
    $WELCOME_FILE    = "$DIR/guide"; # could be $DIR/welcome
    $LOGFILE         = "$DIR/log"; # activity log file
    $MGET_LOGFILE    = "$DIR/log"; # log file for mget routine
    $SMTP_LOG        = "$VARLOG_DIR/_smtplog";
    $SUMMARY_FILE    = "$DIR/summary"; # article summary file
    $SEQUENCE_FILE   = "$DIR/seq"; # sequence number file
    $MSEND_RC        = "$VARLOG_DIR/msendrc";
    $LOCK_FILE       = "$VARRUN_DIR/lockfile.v7"; # liblock.pl

    # FIXING IF *FILE NOT EXIST;
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
sub InitFmlServProcedure
{
    $FmlServProcExitPat	= 'quit|end|exit';
    $FmlServProcPat = 
	'guide|info|help|lists|which|href|http|gopher|ftp|ftpmail';

    # ATTENTION: Viatually
    #    fmlserv:help == fmlserv-mailing-list/help
    #    so, fmlserv own function is fmlsrev:which only
    # Today we should disable all functions except for "which";
    %Procedure = (
		  'fmlserv:lists',	'ProcLists',
		  'fmlserv:which',	'ProcWhich',

		  # WWW Interface
		  # WWW Interface
		  # 'fmlserv:href',	'ProcHRef',
		  # 'r#fmlserv:href',	1,
		  # 'fmlserv:http',	'ProcHRef',
		  # 'r#fmlserv:http',	1,
		  # 'fmlserv:gopher',	'ProcHRef',
		  # 'r#fmlserv:gopher',	1,
		  # 'fmlserv:ftp',	'ProcHRef',
		  # 'r#fmlserv:ftp',	1,
		  #
		  # ftpmail == ftp ( anyway.. 95/10)
		  # 'fmlserv:ftpmail',	'ProcHRef',
		  # 'r#fmlserv:ftpmail',	1,
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

    # For security, we should unset "lists" command
    if (! $FMLSERV_PERMIT_LISTS_COMMAND) {
	&Mesg(*e, "\nExcuse me, we NOT PERMIT $proc COMMAND FOR SECURITY.");
	&Log("NOT PERMIT $proc COMMAND FOR SECURITY.");
	&Log("To enable 'lists', set \$FMLSERV_PERMIT_LISTS_COMMAND = 1");
	return;
    }

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

    &Mesg(*e, "\"$proc $addr\" yields that\n");

    for $ml (keys %MailList) {
	next if $ml eq 'fmlserv'; # fmlserv is an exception

	$DIR = $MailList{$ml}; # $DIR/Elena/ FORM already;

	&NewML($DIR, $ml, *e, *MailList);

	# if eval is succeed, get entry for $addr
	if (&MailListMemberP($addr)) {
	    $reply .= sprintf("   %-15s\t%s\n", $ml, $addr);
	    $hitc++;
	}

	&ResetNS;
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

    $MEMBER_LIST      = "$mldir/$ml"; # member list
    $ACTIVE_LIST      = "$mldir/$ml"; # active member list
    $GUIDE_FILE       = "$mldir/$ml.info";

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
