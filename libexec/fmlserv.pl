#!/usr/local/bin/perl
#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
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

umask(007);		# ATTENTION!

&CheckUGID;

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..

&Parse;				# Phase 1(1st pass), pre-parsing here
&GetFieldsFromHeader;		# Phase 2(2nd pass), extract headers
&FixHeaders(*Envelope);		# Phase 3, fixing fields information
&CheckEnv(*Envelope);		# Phase 4, fixing environment and check loops
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

    $DIR           = $DIR;
    $MAIL_LIST_DIR = $DIR;
    $FMLSERV_DIR   = $FMLSERV_DIR || "$DIR/fmlserv";
    $DIR           = $FMLSERV_DIR;
    $LIBDIR	   = $LIBDIR || $DIR;
    unshift(@INC, $FMLSERV_DIR);

    # Directory check
    $FMLSERV_DIR || die "Please define \$FMLSERV_DIR\n";
    if (! -d $FMLSERV_DIR) { mkdir($FMLSERV_DIR, 0700);}

    $LOGFILE       = "$FMLSERV_DIR/log";
    &Touch($LOGFILE);
}


sub FmlServ
{
    local(*e) = @_;
    local($eval, $hook);

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

    foreach $ml (keys %ReqInfo) {
	next if $ml eq 'fmlserv'; # fmlserv is the last;
	next if $ml =~ /^majordomo:/; # fmlserv is the last;

	$DIR  = $MailList{$ml};	# reset $DIR for each ML's $DIR
	$cf   = "$DIR/config.ph";
	$proc = $ReqInfo{$ml};

	$PresentML = $ml;	# for logfile

	&Debug("ML\t$ml\nDIR\t$DIR\ncf\t$cf\nprocs\t$proc\n") if $debug;
	
	# Load 'ml' NS from $list/config.ph
	&NewML($DIR, $ml, *e, *MailList);

	&Lock;			# LOCK

	chdir $DIR || die $!;

	&Mesg(*e, "\n\n--- Requests to ML[$ml]");
	# $e{'message'} .= $ML_cmds_log{$ml};

	&DoFmlServProc($ml, $proc, *e);

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

	undef $PresentML;
    }# each MLs

    $FML_EXIT_HOOK = $hook;
    $DIR           = $FMLSERV_DIR; #reset global variable

    chdir $DIR || die $!;

    &NewML($FMLSERV_DIR, 'fmlserv', *e, *MailList);

    # WHEN no result code commands only e.g. help, 
    # we do not append the simple help;
    if ($ReqInfo{'fmlserv'} =~ /^[\s\n(help|guide|info|exit|end|quit)]*$/i) {
	&DoFmlServItselfFunctions(*ReqInfo, *e);
    }
    else {
	&Mesg(*e, "\n\n--- fmlserv ");
	&DoFmlServItselfFunctions(*ReqInfo, *e) if ($ReqInfo{'fmlserv'});

	$e{'h:From'} = $MAIL_LIST;	# special case when fmlserv
	$e{'message:h:subject'} = "fmlserv command status report";

	# append help;
	if (-f "$FMLSERV_DIR/help") {
	    $e{'message:append:files'} = "$FMLSERV_DIR/help";
	}
	else {
	    &AppendFmlServInfo(*e);
	}
    }

    # Already '_main' ENVIRONMENT
    # DONE;
}


######### Standard Utilities ##########
# Log is special for fmlserv.
sub Log 
{ 
    local($str, $s) = @_;
    local($package, $filename, $line) = caller; # called from where?
    local($status);

    &GetTime;
    $str =~ s/\015\012$//;	# FIX for SMTP
    if ($debug_sendmail_error && ($str =~ /^5\d\d\s/)) {
	$Envelope{'error'} .= "Sendmail Error:\n";
	$Envelope{'error'} .= "\t$Now $str $_\n\t($package, $filename, $line)\n\n";
    }
    
    $str = "$filename:$line% $str" if $debug_caller;

    &Append2("$Now $str ($From_address)", $LOGFILE, 0, 1);
    &Append2("$Now    $filename:$line% $s", $LOGFILE, 0, 1) if $s;

    local($ml);
    if ($ml = $PresentML) {
	&Append2("$Now $ml\# $str ($From_address)", $FMLSERV_LOGFILE, 0, 1);
	&Append2("$Now $ml\# $filename:$line% $s", $FMLSERV_LOGFILE, 0, 1) 
	    if $s;
    }

    if ($Envelope{'mode:caller'}) {
	&Append2("$Now ($package, $filename, $line)", $LOGFILE, 0, 1);
	&Debug("$Now ($package, $filename, $line) $LOGFILE, 0, 1");
    }
}

### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}


#########################################################################
##### LIBRARY OF FMLSERV #####
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
       send "help" to $MAIL_LIST for the details;
    ;
    Fmlserv command syntax is a Fml command with a ML Name;
    ;
    ;   Command <listname> [the Command Options if available];
    ;
    Examples of Commands for <listname> mailing list(ML):;
    ;
    help    <listname>;
    ;       get help file of <listname> ML;
    ;
    members <listname>;
    ;       get the member list of <listname> ML;
    ;
    actives <listname>;
    ;       get the list of members who read <listname> ML now;
    ;
    get     <listname> 1;
    ;       get the article 1 of <listname> ML;
    ;
    mget    <listname> 1-10 mp;
    ;       get the latest 10 articles of <listname> ML in a set;
    ;       PAY ATTENTION! the options is after the ML's name;
    ;
    e.g. "members elena" is to get the member list for the "elena" ML;
#;
		    
    $m =~ s/;//g;
    $e{'message'} .= $m;
}


sub DoFmlServItselfFunctions
{
    local(*proc, *e) = @_;
    local($procs2fml);

    &SetFmlServProcedure;

    if ($proc{'fmlserv'}) {
	local(@proc) = split(/\n/, $proc{'fmlserv'});
	&use('fml');

	foreach (@proc) {
	    # ATTENTION! already "cut the first #.. syntax"
	    # in sub SortRequest
	    $org_str = $_;
	    ($_, @Fld) = split;
	    @Fld = ('#', $_, @Fld);

	    ### Procedures
	    tr/A-Z/a-z/;

	    # FIRST fmlserv:command form here
	    if ($proc = $Procedure{"fmlserv:$_"}) {
		$0 = "--Command calling $proc: $FML $LOCKFILE>";
		&Debug("Call $proc for [$org_str]") if $debug;

		# REPORT
		if ($Procedure{"r#fmlserv:$_"}) {
		    &Mesg(*e, "\n>>> $org_str");
		}

		# PROCEDURE
		$status = &$proc("fmlserv:$_", *Fld, *e, *misc);
	    }
	    # WHEN NOT FMLSERV:Commands, call usual command(libfml.pl)
	    # not call multiple times, for only one calling
	    else {
		&Debug("Call \$proc for [$org_str]") if $debug;
		$procs2fml .= "$org_str\n";
	    }
	}# foreach;

	### CALL when NOT MATCHED TO FMLSERV:Commnads
	&Command($procs2fml) if $procs2fml;
    }
}


sub DoFmlServProc
{
    local($ml, $proc, *e) = @_;
    local($sp, $guide_p, $auth, $badproc);

    # check member-lists (2.1 extentions)
    @MEMBER_LIST || do { @MEMBER_LIST = ($MEMBER_LIST);};

    foreach $file (@MEMBER_LIST) {
	&Debug("---MLMemberCheck($From_address in $file);") if $debug;
	-f $file && &CheckMember($From_address, $file) && ($auth++, last);
    }

    if ($auth) {
	&Command($proc);
    }
    else {
	local($mesg);
	$mesg  = "\n   Your subscribe request is forwarded to the maintainer.";
	$mesg .= "\n   Please wait a little.";

	&Debug("ERROR: CheckMember($From_address, @MEMBER_LIST)") if $debug;
	foreach (split(/\n/, $proc)) {
	    s/\s+$//;		# cut the \s+

	    &Mesg(*e, "\n>>>> $_");
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
		    &use('lm');
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

    eval($s); &Log("FAIL EVAL \$SPOOL_DIR ...") if $@;

    # FORCE Reply-TO
    $e{'h:Reply-To:'}  = "fmlserv\@$DOMAINNAME";
}


sub FixMLMode
{
    local($dir, $ml) = @_;
    local($mdir) = "$MAIL_LIST_DIR/$ml";

    &Debug("\n\tFound $mdir.closed;\n") if -f "$mdir.closed" && $debug;
    &Debug("\n\tFound $mdir.auto;\n")   if -f "$mdir.auto"   && $debug;

    $ML_MEMBER_CHECK = 1 if -f "$mdir.closed";
    $ML_MEMBER_CHECK = 0 if -f "$mdir.auto";
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

    foreach ( split(/\n/, $e{'Body'}) ) {
	next if /^\s*$/;	# skip null line
	s/^\#\s*//;		# cut the first #.. syntax
	next if /^\S+=\S+/;	# variable settings, skip

	($cmd, $ml, @p) = split(/\s+/, $_);
	$ml =~ tr/A-Z/a-z/;

	# EXPILICIT ML DETECTED. 
	# $ml is non-nil and the ML exists
	if ($ml && $MailList{$ml}) {	
	    # &Log("Request::${ml}::$cmd", (@p ? "(@p)" : ""));
	    $ML_cmds{$ml}         .= "$cmd @p\n";
	    $ML_cmds_log{$ml}     .= ">>>> $cmd $ml @p\n";	    
	    &Debug("\$ML_cmds{$ml} = $ML_cmds{$ml}") if $debug;
	}
	# LISTSERV COMPATIBLE: COMMANDS SINCE NO EXPILICIT ML.
	else {
	    last if /^\s*(quit|end|exit)/i;

	    local($pat);
	    $pat = "guide|info|help|lists|which|href|http|gopher|ftp|ftpmail";

	    if (/^\s*($pat)/i) {
		# push(@ML_cmds, $_);
		# default >> virtual fmlserv ML
		$ML_cmds{'fmlserv'}         .= "$_\n";
		&Debug("FMLSERV COMMAND [$_]") if $debug;
		next;
	    }

	    &Mesg(*e, "\n>>>> $_");

	    if ($ml) {
		&Mesg(*e, "   ML[$ml] NOT EXISTS; Your request is ignored\n");
	    }
	    else {
		&Mesg(*e, "   Unknown commands");		
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
    # (guide|info|help|lists|which|href|http|gopher|ftp|ftpmail)/) {

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

    &Mesg(*e, "\n>>> $proc\n");
    &Mesg(*e, "  $MAIL_LIST serves the following lists\n");
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
    local($r, $s, $DIR, $hitc);
    local($addr) = $Fld[2] || $From_address;

    &Log($proc);

    &Mesg(*e, "\n>>> $proc $addr\n");
    &Mesg(*e, "   You are registered in the following lists:");
    $e{'message'} .= sprintf("   %-15s\t%s\n", 'List', 'Address');
    $e{'message'} .= "   ".('-' x 50)."\n";

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
	    &Mesg(*e, "ML Configuration Error");
	}

	# if eval is succeed, get entry for $addr
	if ($r && ($s = &CheckMember($addr, $MEMBER_LIST))) {
	    $e{'message'} .= sprintf("%-15s\t%s\n", $ml, $addr);
	    $hitc++;
	}
    }#FOREACH;

    if (! $hitc) { &Mesg(*e, "\tnothing");}
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
