#!/usr/local/bin/perl
#
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
$Rcsid = 'fmlserv 4.0';

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
    -d $_   || push(@LIBDIR, $_);
}
$DIR    = $DIR    || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
$0 =~ m#^(.*)/(.*)# && do { unshift(@INC, $1); unshift(@LIBDIR, $1);};
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
				# FML parsing process ends

if (! &MailLoopP) {		# TEMPFAIL ERROR may cause a virtual loop.
    &FmlServ(*Envelope);	# GO an actual fmlserv process
}

&RunExitHooks;			# run hooks after unlock

if ($Envelope{'mode:fmlserv:disable_notify'}) {
    print STDERR "ignore &Notify\n";
}
elsif ($Envelope{'message'}) { # Reply some report if-needed.
    &Notify;
}

exit 0;
### MAIN ENDS ###


##### FmlServ (Listserv-Emulation) Codes
#####    the fundamental idea is to use virtual "fmlserv" Maling List;
#####    If fmlserv have to handle several owner's ML's, 
#####    group-writable permission is required;_;

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
    if (! -d $FMLSERV_DIR) { &Mkdir($FMLSERV_DIR, 0700);}

    # log file of fmlserv
    $LOGFILE       = "$FMLSERV_DIR/log";
    &Touch($LOGFILE) unless -f $LOGFILE;

    # sitedef.ph
    for (@INC) {
	if (-f "$_/sitedef.ph") { 
	    $SiteDefPH = "$_/sitedef.ph"; 
	    $ml'SiteDefPH = "$_/sitedef.ph";  #';
	    last;
	}
    }

    # ml cache
    $MAP_DB = $MAP_DB || "$FMLSERV_DIR/mlmap";

    # if Berkeley DB is not used, reset always ;-)
    if ((stat($MAIL_LIST_DIR))[9] >  (stat("$MAP_DB.db"))[9]) {
	&CreateMLMap($FMLSERV_DIR, $MAP_DB);
    }
}


sub FmlServ
{
    local(*e) = @_;
    local($eval, $hook);
    local($message, $error, $apfiles); # save the %Envelope return values; 

    ### 00: Load Command Library 
    require 'libfml.pl'; # if %ReqInfo;

    ### 01: Configuration ...;
    &InitFmlServProcedure; # initialize fmlserv procedures;

    $e{'mode:fmlserv'} = 1; # Declare (for e.g. mkdir permission change)

    ### 02: alloc virtual "fmlserv" ML 
    # ML::constructor() for fmlserv@$DOMAIN
    #   fmlserv = new ML(Fmlserv);
    # 
    # ATTENTION!: $Enveoope{'mode:*'} is also set. so require the reset
    &MLContextSwitch($FMLSERV_DIR, 'fmlserv', *e);

    # save current envelope
    %OrgEnvelope = %e;

    # for logging all log's in fmlserv/log, SET AGAIN
    # &InitFmlServ: LOGFILE = $FMLSERV_DIR/log 
    # 
    $FMLSERV_LOGFILE = $LOGFILE;

    ### 03: GENERATE "AVAILABLE MAILING LISTS TABLE";
    # Alloc Association Array %MailList {list => directory_of_list} (global)
    # checks -d $MAIL_LIST_DIR/* -> %MailList (generated from the data)
    #           except for "^@\w+"
    # 
    # not use &MLContextSwitchAA($MAIL_LIST_DIR, *MailList);
    # since it will require a large memory if a lot of mail lists exist.
    # Now we use %MLMap (stored in "fmlsrev/mlmap.db" as Berkeley db)

    ### 04: SORT REQUEST: Sorting requests for each ML
    # Envelope{Body} => %ReqInfo (Each ML)
    #                   @ReqInfo (fmlserv commands) 
    # 
    &SortRequest(*Envelope, *MailList, *ReqInfo, *TraceInfo);

    ### 05: REFUGING THE CURRENT NAME SPACE, GO EACH ML NAME SPACE; 
    ### 
    &Save_mainNS; # Save 'main' NameSpace (save the current name space)

    if ($debug_dump) { &Dump_mainNS("$FMLSERV_DIR/tmp/main_name_space");}

    # $FMLSERV_DIR = $DIR; # save the $DIR (must be == $FMLSERV_DIR)

    if ($debug) { &DebugEnvelopeDump("pre e");}

    ### 05.01: GO Processing For Each ML's ...;
    # 
    # Requests to $ml are available if %MailList has the entry;
    # Do aggregated requests (plural lines) $ReqInfo{$ml} for each $ml;
    # 
    for $ml (keys %ReqInfo) {
	# Exceptions: fmlserv is later processed (internal functions);
	next if $ml eq 'fmlserv'; 
	next if $ml eq 'etc'; 

	# reset the current procs for each ML
	$DIR  = "$MAIL_LIST_DIR/$ml";	  # ML's $DIR
	$cf   = "$DIR/config.ph"; # config.ph

	if ($proc) { $proc_count++;}

	$proc = $ReqInfo{$ml};	  # requests

	&Mesg(*e, "\n<<<< Process requests for '$ml' ML". 
	      'fmlserv.process.info', $ml);
	&Mesg(*e, $TraceInfo{$ml});

	# Load $ml NAME SPACE from $list/config.ph
	next if ! -f $cf;
	&MLContextSwitch($DIR, $ml, *e);

	if ($debug) {
	    &Mesg(*e, "\ndebug> requests for \"$ml\" Mailing List");
	    &Debug("---Processing ML $ml");
	    &Debug("DIR\t$DIR\ncf\t$cf\nprocs\t$proc\n");
	    &DebugEnvelopeDump("$ml e") if $debug_ns;
	}

	# test chdir $DIR, next if it fails;
	# if it succeeds, lock and do the processing;
	chdir $DIR || do {
	    &Log("cannot chdir DIR[$DIR], ignore given commands for $ml");
	    &Mesg(*e, "Hmm, ... I cannot find $ml. $ml really exists?",
		  'fmlserv.ml.not_found', $ml);
	    next;
	};

	### PROCESS BEGIN;
	&Lock;			# LOCK each ML (lock $FP_SPOOL_DIR)
	&ReloadMySelf;

	### Processing $proc For $ml ###
	# ProcessEachMLReq is an emulation for each ML;
	&ProcessEachMLReq($ml, $proc, *e);

	### alloc $ml NAME SPACE for mget;
	# attention here; we do not set $FML_EXIT_HOOK
	# aggregate the mget requests, after this routine,
	# we set $FML_EXIT_HOOK;
	if ($FmlExitHook{'mget3'} =~ /mget3_SendingEntry/) {
	    local($n);

	    undef $eval;

	    # "-" of Name Space Name is forbidden.
	    # so save $ml and modify it only in this hook.
	    # (mainly for perl 4 since hash table cannot have arrays;-)
	    # 
	    # e.g. 90210 -> _90210
	    #      a-b   -> _a_b
	    #      a_b   -> _a__b
	    # 
	    $save_ml = $ml;
	    $ml =~ s/_/__/g;	# _   => --
	    $ml =~ s/\-/_/g;	# -   => _
	    $ml =~ s/^/fml_/g;	# ^   => fml_ (fml_ by ando@iij-mc.c.jp)

	    for $n ('SendingEntry', 'SendingArchiveEntry') {
		eval(sprintf("\@%s'$n = \@main'$n;\n", $ml));
		&Log($@) if $@;
		eval(sprintf("%%%s'$n = %%main'$n;\n", $ml));
		&Log($@) if $@;

		$hook .= sprintf("\@main'$n = \@%s'$n;\n", $ml);
		$hook .= sprintf("%%main'$n = %%%s'$n;\n", $ml);
	    }

	    # hook is the real action
	    # passed to "$FML_EXIT_HOOK = $hook;" after here.
	    # and runs it at the last.
	    $hook .= qq#&mget3_SendingEntry;\n#;

	    $FmlExitHook{'mget3'} =~ s/&mget3_SendingEntry;//g;
	    &mget3_Reset;	# only mget3 routine called..

	    # restore;
	    $ml = $save_ml;
	}	

	&Unlock;		# UNLOCK
	### PROCESS ENDS;

	&RunExitHooks;		# run-hook for each ML

	undef $FML_EXIT_HOOK;	# unlink each ML hook

	# Reload NS from main'NS
	&ResetNS;

	# reset %Envelope;
	if ($debug) {
	    &Debug("$ml::message: ---\n$Envelope{'message'}\n---\n");
	    &Debug("$ml::ERROR:   ---\n$Envelope{'error'}\n---\n");
	}

	$apfiles .= "$;$Envelope{'message:append:files'}"
	    if $Envelope{'message:append:files'};
	$message .= $Envelope{'message'};
	$error   .= $Envelope{'error'};
	%Envelope = %OrgEnvelope;
    } # each ML ends;

    ### 06: FMLSERV INTERNAL (ITSELF) FUNCTIONS;
    # reset global variable
    $FML_EXIT_HOOK = $hook;
    $DIR           = $FMLSERV_DIR; 

    $Envelope{'message:append:files'} .= $apfiles;
    $Envelope{'message'} .= $message;
    $Envelope{'error'}   .= $error;

    if ($debug) {
	&Debug("fmlserv::message: ---\n$Envelope{'message'}\n---\n");
	&Debug("fmlserv::ERROR:   ---\n$Envelope{'error'}\n---\n");
	&DebugEnvelopeDump("fmlserv e");
	&Debug("---Processing ML fmlserv");
    }

    # chdir $FMLSERV_DIR; 
    chdir $FMLSERV_DIR || die("$!:cannot chdir FMLSERV_DIR[$DIR]\n");

    # alloc virtual "fmlserv";
    &MLContextSwitch($FMLSERV_DIR, 'fmlserv', *e);

    # request using internal functions or e.g. to get fmlserv/help;
    if ($ReqInfo{'fmlserv'}) {
	&Debug("FmlServ::DoFmlServItselfFunctions") if $debug;
	&DoFmlServItselfFunctions(*ReqInfo, *e);

	# Report Mail is From and Reply-To MAIL_LIST;
	$e{'GH:From:'}          = $MAIL_LIST;# special case when fmlserv
	$e{'message:h:subject'} = "Fmlserv command status report";

	if ($ReqInfo{'fmlserv'} =~ /^[\s\n]*help[\s\n]*$/i) {
	    $help_only = 1;
	}
    }

    ### We ALWAYS append the simple help ###
    if (-f "$FMLSERV_DIR/help") {
	$e{'message:append:files'} .= "$;$FMLSERV_DIR/help";
    }

    &Mesg(*e, "\n*** Processing Done.", 'fmlserv.done');

    # IF HELP ONLY, DO NOT &Notify
    if ($help_only && (! $proc_count)) {
	$e{'mode:fmlserv:disable_notify'} = 1;
    }

    # The first reply message;
    # preparation for &Notify;
    $e{'message'} = 
	"FMLSERV (FML Listserv Style Interface) Results:\n$e{'message'}";
}


sub DebugEnvelopeDump
{
    local($log)= @_;
    &Debug("$log: Addr2Reply:\t=>$e{'Addr2Reply:'}") if $e{"Addr2Reply:"};
    for (keys %Envelope) { &Debug("$log: $_\t=>$e{$_}") if $e{$_} && !/^mode/;}
}


######### Standard Utilities ##########
### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}


#####
##### LIBRARY FUNCTIONS OF FMLSERV 
#####

sub DoFmlServItselfFunctions
{
    local(*proc, *e) = @_;
    local($procs2fml, $org_str, @Fld);

    if ($proc{'fmlserv'}) {
	&use('fml');

	for (split(/\n/, $proc{'fmlserv'})) {
	    &Debug("DoFmlServItselfFunctions($_)") if $debug;

	    # ATTENTION! already "cut the first #.. syntax"
	    # in sub SortRequest
	    $org_str = $_;
	    ($_, @Fld) = split;

	    # XXX: "# command" is internal represention
	    @Fld = ('#', $_, @Fld);

	    # REPORT IF REPLY IS DEFINED?
	    # if($Procedure{"r#fmlserv:$_"}){&Mesg(*e,"\n${ml}> $org_str");}
	    # Anyway We REPORT ALWAYS Anything!
	    &Mesg(*e, "<<<< Process fmlserv command", 'fmlserv.command.info');
	    &Mesg(*e, " <<< $org_str");

	    ### Procedures is lower-case;
	    tr/A-Z/a-z/;

	    # FIRST TRY fmlserv:command form here
	    if ($proc = $Procedure{"fmlserv:$_"}) {
		$0 = "${FML}: Fmlserv command $proc: $LOCKFILE>";
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


sub ProcessEachMLReq
{
    local($ml, $proc, *e) = @_;
    local($sp, $guide_p, $auth, $badproc);

    &Debug("FmlServ::ProcessEachMLReq($ml, $proc, *e);") if $debug;

    # reset arrays since fmlserv handles several different ML's;
    undef @MEMBER_LIST;
    undef @ACTIVE_LIST;

    # already $DIR/$ml/file form; 
    # initialize some arrays; if auto-regist is clear here, we reset;
    &AdjustActiveAndMemberLists;

    $auth = &MailListMemberP($From_address);

    if ($auth) {
	local($req);
	$MesgTag = $ml;
	# &Mesg(*e, "*** Processing command(s) for <$ml> ML");

	for $req (split(/\n/, $proc)) { &DoProcedure($req, *e);}
	# &DoProcedure($proc, *e);

	undef $MesgTag;
    }
    else {
	local($mesg, $buf);
	$mesg  = "\n   Your subscribe request is forwarded to the maintainer.";
	$mesg .= "\n   Please wait a little.";

	&Debug("ERROR: MailListMemberP($From_address) fails") if $debug;

	for (split(/\n/, $proc)) {
	    $buf = $_; # preserve;

	    &Debug("ProcessEachMLReq($_)") if $debug;
	    s/\s+$//;		# cut the \s+

	    &Mesg(*e, "\n>>> $_");
	    &Debug("ProcessEachMLReq::$_()") if $debug;
	    
	    if (/^(guide|info)/i)    { 
		&GuideRequest(*e); # bug fix 97/10/24 ando@iij-mc.co.jp
		&Mesg(*e, "   guide is sent to $From_address",
		      'fmlserv.guide.sent', $From_address);
		next;
	    }

	    if (/^(subscribe|confirm)\s*(.*)/i){ 
		if (&NonAutoRegistrableP) {
		    &Mesg(*e, $mesg);
		    &WarnE("Subscribe request $ML_FN", 
			   "subscribe request comes as follows.\n");
		}
		else {
		    &use('amctl');

		    $buf =~ s/$ml//;
		    &Mesg(*e, "");
		    $e{'tmp:ml'} = $ml;	 # for confirmation mode;
		    &AutoRegist(*e, $buf); # using set_buf of AutoRegist
		    undef $e{'tmp:ml'};
		}

		next;
	    }

	    &Debug("ProcessEachMLReq::$_(){YOU ARE NOT MEMBER($ml)") if $debug;
	    &Mesg(*e, "prohibited since you are not member of '$ml' ML", 
		  'not_ml_member', $ml);
	}
    }
}


#
# switch to each ML configuration space
#
sub MLContextSwitch
{
    local($DIR, $ml, *e) = @_;
    local($cf) = "$DIR/config.ph";

    &GetTime;

    if ($debug) {
	print STDERR "MLContextSwitch::Check($cf)\n";

	# Define Defaults against "no $MAIL_LIST_DIR/$ml/config.ph"
	print STDERR "MLContextSwitch::SetMLDefaults($DIR, $ml)\n";
    }

    # default before loading $DIR/config.ph;
    &SetMLDefaults($DIR, $ml);

    # Load config.ph and sitede.ph and record the Name Space 
    # to reset the Name Space in the end (swap, not stack on). 
    # 
    # if the loading fails, default values are used;
    if (-f $cf) {
	print STDERR "MLContextSwitch::Load($cf)\n" if $debug;
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
    $e{'CtlAddr:'}                = "fmlserv\@$DOMAINNAME";
    unshift(@ARCHIVE_DIR, $ARCHIVE_DIR);    

    # special exception
    if ($ml eq 'fmlserv') { $LOGFILE = $FMLSERV_LOGFILE;}

    ### Initialize DIR's and FILE's of the ML server
    # FullPath-ed (FP)
    local($s);
    for (SPOOL_DIR,TMP_DIR,VAR_DIR,VARLOG_DIR,VARRUN_DIR,VARDB_DIR) {
	&eval("\$s = \$$_; \$s =~ s#\$DIR/##g; \$s =~ s#$DIR/##g;");
	&eval("\$FP_$_ = \"$DIR/\$s\";");
	&eval("\$$_ =~ s#\$DIR/##g; \$$_ =~ s#\$DIR/##g;");
	&eval("-d \$$_||&Mkdir(\$$_);");
    }

    for ($LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	 $SEQUENCE_FILE, $SUMMARY_FILE, $LOG_MESSAGE_ID) {
	-f $_ || &Touch($_);	
    }

    ### CF Version 3;
    if (&AutoRegistrableP) {
	$ML_MEMBER_CHECK = 0;
	$touch = "${ACTIVE_LIST}_is_dummy_when_auto_regist";
	if (&NotUseSeparateListP) {
	    &Touch($touch) if ! -f $touch;
	}
	else {
	    unlink $touch if -f $touch;
	}
    }

    ### Here, all variables must be set already. 
    if ($debug) {
	for (FQDN, DOMAINNAME, MAIL_LIST, CONTROL_ADDRESS, 
	     ML_FN, XMLNAME, XMLCOUNT, MAINTAINER,
	     MEMBER_LIST, ACTIVE_LIST,
	     LOGFILE) {
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


sub MLExistP
{
    local($ml) = @_;

    # [0-9A-Za-z_-]+
    if ($ml =~ /^[\w\-]+$/) {
	return 1 if -d "$MAIL_LIST_DIR/$ml";
    }
    else {
	0;
    }
}


# ATTENTION! "cut the first #.. syntax"
sub SortRequest
{
    local(*e, *MailList, *ML_cmds, *TraceInfo) = @_;
    local($cmd, $ml, @p, $s, $k, $v);

    for (split(/\n/, $e{'Body'})) {
	next if /^\s*$/;	# skip null line
	s/^\#\s*//;		# cut the first #.. syntax
	next if /^\S+=\S+/;	# variable settings, skip

	($cmd, $ml, @p) = split(/\s+/, $_);
	$ml  =~ tr/A-Z/a-z/;
	$cmd =~ tr/A-Z/a-z/;

	if ($cmd eq 'lists' && (!$FMLSERV_PERMIT_WHICH_COMMAND)) {
	    &Log("invalid [$cmd] command request");
	    &Mesg(*e, "lists command is prohibited.", 'not_avail', $cmd);
	    &Mesg(*e, "stops for critical error", 'fmlserv.stop');
	    last;
	}
	if ($cmd eq 'which' && (!$FMLSERV_PERMIT_WHICH_COMMAND)) {
	    &Log("invalid [$cmd] command request");
	    &Mesg(*e, "which command is prohibited.", 'not_avail', $cmd);
	    &Mesg(*e, "stops for critical error", 'fmlserv.stop');
	    last;
	}


	# EXPILICIT ML DETECTED. 
	# $ml is non-nil and the ML exists
	if (&MLExistP($ml)) {
	    $ML_cmds{$ml}     .= "$cmd @p\n";
	    $ML_cmds_log{$ml} .= "${ml}> $cmd $ml @p\n";
	    $TraceInfo{$ml}   .= "\n" if $TraceInfo{$ml};
	    $TraceInfo{$ml}   .= " <<< $_";
	}
	# LISTSERV COMPATIBLE: COMMANDS SINCE NO EXPILICIT ML.
	else {
	    # quit end exit
	    last if /^\s*($FmlServProcExitPat)/i;

	    # except for quit end exit
	    # 'guide|info|help|lists|which';
	    # We use "virtual fmlserv ML"
	    # 
	    # In addition, we disable "which addr".
	    # 
	    if (/^\s*($FmlServProcPat)\s*$/i) { 
		$ML_cmds{'fmlserv'} .= "$_\n";
		next;
	    }

	    &Mesg(*e, "<<<< Process fmlserv command");
	    &Mesg(*e, " <<< $_");

	    if ($ml) {
		&Mesg(*e, "ignore request since no such '$ml' ML exists.\n", 
		      'fmlserv.ml.not_found', $ml);
	    }
	    else {
		&Mesg(*e, "unknown fmlserv commands", 'no_such_command', $_);
	    }
	}
    }    

    if ($debug) { 
	&Debug("----- SortRequest ---");
	while (($k,$v) = each %ML_cmds) { &Debug("[$k]=>{\n$v}");}
	&Debug("----- SortRequest ends ---");
    }
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
	    eval "\$org'$key = \$main'$key;";
	    &Log($@) if $@;
	    $NameSpaceS{$key} = 1;
	}
	if (defined @entry) { 
	    eval "\@org'$key = \@main'$key;";
	    &Log($@) if $@;
	    $NameSpaceA{$key} = 1;
	}
	if ($key ne "_$package" && defined %entry) { 
	    eval "\%org'$key = \%main'$key;";
	    &Log($@) if $@;
	    $NameSpaceAA{$key} = 1;
	}
    }

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
    # undef main NS
    for (keys %ml'ML_NameSpaceS)  { eval "undef \$main'$_;"; &Log($@) if $@;}
    for (keys %ml'ML_NameSpaceA)  { eval "undef \@main'$_;"; &Log($@) if $@;}
    for (keys %ml'ML_NameSpaceAA) { eval "undef \%main'$_;"; &Log($@) if $@;}
    
    # load main NS from org(saved main) NS
    for (keys %NameSpaceS)  { eval "\$main'$_ = \$org'$_;"; &Log($@) if $@;}
    for (keys %NameSpaceA)  { eval "\@main'$_ = \@org'$_;"; &Log($@) if $@;}
    for (keys %NameSpaceAA) { eval "\%main'$_ = \%org'$_;"; &Log($@) if $@;}
}


#######################################################
##### PROC PROCEDURES #####

# SYNTAX
# $s = $_;(present line of the given mail body)
# $ProcFileSendBack($proc, *s);
sub InitFmlServProcedure
{
    $FmlServProcExitPat	= 'quit|end|exit';
    $FmlServProcPat     = 'guide|info|help|lists|which';
    # 'guide|info|help|lists|which|href|http|gopher|ftp|ftpmail';

    # ATTENTION: Viatually
    #    fmlserv:help == fmlserv-mailing-list/help
    #    so, fmlserv own function is fmlsrev:which only
    # Today we should disable all functions except for "which";
    %Procedure = (
		  'fmlserv:lists',	'ProcLists',
		  'fmlserv:which',	'ProcWhich',
		  );

    if (! $FMLSERV_PERMIT_WHICH_COMMAND) {
	undef $Procedure{'which'}; 
    }
    if (! $FMLSERV_PERMIT_LISTS_COMMAND) {
	undef $Procedure{'which'}; 
    }
}

# accelerate "lists" command
sub CreateMLMap 
{
    opendir(DIRD, $MAIL_LIST_DIR) || do {
	&Mesg(*Envelope, "\tERROR: cannot opendir ML MAP", 
	      'fmlserv.mlmap.opendir.fail');
	&Log("cannot open $dir");
	return;
    };

    &MLMapopen;

    for (readdir(DIRD)) {
	print STDERR "MAP SCAN $_\n" if $debug;
	next if /^\./;
	next if /^(fmlserv|etc)/;
	$MLMap{$_} = $_;
    }

    &MLMapclose;
    closedir(DIRD);
}

sub MLMapopen  { dbmopen(%MLMap, $MAP_DB, 0644);}
sub MLMapclose { dbmclose(%MLMap);}

sub ProcLists
{
    local($proc, *Fld, *e, *misc) = @_;

    # For security, we should unset "lists" command
    if (! $FMLSERV_PERMIT_LISTS_COMMAND) {
	&Mesg(*e, "prohibit \"$proc\" FOR SECURITY", 'not_avail', $proc);
	&Log("probihit $proc for security.");
	&Log("To enable 'lists', set \$FMLSERV_PERMIT_LISTS_COMMAND = 1");
	return;
    }

    # O.K. here we go
    local($ml, $value);

    &Mesg(*e, "$MAIL_LIST serves the following lists:\n", 
	  'fmlserv.serv', $MAIL_LIST);

    &MLMapopen;

    while (($ml, $value) = each %MLMap) {
	next if $ml eq 'fmlserv'; # fmlserv is an exception
	next if $ml eq 'etc';     # etc is special.
	$e{'message'} .= sprintf("\t%-15s\t%s\n", $ml);
    }

    &MLMapclose;

    &Mesg(*e, "\n");
}


sub ProcWhich
{
    local($proc, *Fld, *e, *misc) = @_;
    local($r, $s, $DIR, $hitc, $reply);
    local($addr) = $Fld[2] || $From_address;

    &Log($proc);

    # For security, we should unset "which" command
    if (! $FMLSERV_PERMIT_WHICH_COMMAND) {
	&Mesg(*e, "prohibit \"$proc\" FOR SECURITY.", 'not_avail', $proc);
	&Log("prohibit $proc for security.");
	&Log("To enable 'which', set \$FMLSERV_PERMIT_WHICH_COMMAND = 1");
	return;
    }

    &MLMapopen;

    while (($ml, $value) = each %MLMap) {
	next if $ml eq 'fmlserv'; # fmlserv is an exception
	next if $ml eq 'etc';     # etc is special.

	$DIR = "$MAIL_LIST_DIR/$ml";	  # ML's $DIR

	# evaluating cost is 9-10 pages. 
	next if ! -f "$DIR/config.ph";
	&MLContextSwitch($DIR, $ml, *e);

	unshift(@MEMBER_LIST, $MEMBER_LIST);

	# if eval is succeed, get entry for $addr
	if (&MailListMemberP($addr)) {
	    $reply .= sprintf("   %-15s\t%s\n", $ml, $addr);
	    $hitc++;
	}

	# reset cost is 1 page.
	&ResetNS;
	undef @MEMBER_LIST;
    } # FOREACH;

    &MLMapclose;

    if ($hitc) { 
	&Mesg(*e, "\"$addr\" is registered in the following lists:\n", 
	      'fmlserv.subscribed_lists', $addr);
	&Mesg(*e, sprintf("   %-15s\t%s", 'List', 'Address'));
	&Mesg(*e, "   ".('-' x 50));
	&Mesg(*e, $reply);
    }
    else {
	&Mesg(*e, "\"$addr\" is not registered in any lists.", 
	      'fmlserv.not_any_member', $addr);
    }
}


##################################################################
##### ml Name Space 

package ml;

# Load config.ph and sitede.ph and record the Name Space 
# to reset the Name Space in the end (swap, not stack on). 
sub main'LoadMLNS 
{
    local($file) = @_;
    # local($key, $val, $eval); # not required ...
    
    # load the presnet directry information (tricky?)
    $ml'DIR = $main'DIR;

    delete $INC{$file};
    $history{$file} = 1;
    require 'libloadconfig.pl'; &__LoadConfiguration;

    if ($] =~ /5.\d\d\d/) {
	*stab = *{"ml::"};
    }
    else {
	(*stab) = eval("*_ml");
    }

    while (($key, $val) = each(%stab)) {
	next if ($key !~ /^[A-Z_0-9]+$/) || $key eq 'ENV' || $key =~ /^_/;
	(*entry) = $val;
		
	if (defined $entry) { 
	    eval "\$main'$key = \$ml'$key;";
	    &main'Log($@) if $@; #';
	    $ML_NameSpaceS{$key} = 1;
	}

	if (defined @key) { 
	    eval "\@main'$key = \@ml'$key;";
	    &main'Log($@) if $@; #';
	    $ML_NameSpaceA{$key} = 1;
	}

	if ($key ne "_$package" && defined %key) { 
	    eval "\%main'$key = \%ml'$key;";
	    &main'Log($@) if $@; #';
	    $ML_NameSpaceAA{$key} = 1;
	}
    }
}

sub ml'Log { &main'Log(@_);}

1;
