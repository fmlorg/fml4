# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

&use('fop');


######################################################################
#
# INTERFACE FUNCTION FOR %mget_list;
#
# matomete get articles from the spool, then return them
# mget is an old version. 
# new version should be used as mget ver.2(mget[ver.2])
# matomete get articles from the spool, then return them
sub MgetCompileEntry
{
    local(*e) = @_;
    local($key, $value, $status, $fld, @fld, $value, @value);
    local($proc) = 'mget';

    # Do nothing if no entry.
    return unless %mget_list;

    $0 = "${FML}: Command Mode loading mget library: $MyProcessInfo>";

    while (($key, $value) = each %mget_list) {
	print STDERR "TRY MGET ENTRY [$key]\t=>\t[$value]\n" if $debug;

	# SPECIAL EFFECTS
	next if $key =~ /^\#/o;
	
	@fld = split(/:/, $fld = $key); 
	$fld =~ s/:/ /;		# for $0;

	# targets, may be multiple
	@value = split(/\s+/, $value); 

	# Process Table
	$0 = "${FML}: Command Mode mget[$key $fld]: $MyProcessInfo>";

	# mget3 is a new interface to generate requests of "mget"
	$fld = $key;		# to make each "sending entry"
	$status = &mget3(*value, *fld, *e);

	$0 = "${FML}: Command Mode mget[$key $fld] status=$status: $MyProcessInfo>";

	# regardless of RETURN VALUE;
	return if $_PCB{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

	if ($status) {
	    ;
	}
	else {
	    $status = "Fail";
	    # &Mesg(*e, "\n>>> $proc $value $fld\n\tfailed.");
	    local($fld) = $Fld;

	    # XXX: "# command" is internal represention
	    # XXX: remove '# command' part if exist since not essential
	    $fld =~ s/^\#\s*//;
	    &Mesg(*e, "\n>>> $fld");
	    &Mesg(*e, "\tfailed.", 'fail');
	};

	&Log("$proc:[$$] $key $fld: $status");
    }
}


######################################################################
#
# VARIABLES
#
# sp (set by ExistCheck)
# @sp matched plain flies
# %sp key=archive, value=files_in_it(may be multiple)..
# @ar archive files (must be binary)
#
# Sending Entry ; private
#local(@SendingEntry, @SendingArchiveEntry, %SendingEntry, %SendingArchiveEntry);


# NEW MGET Interface e.g. 
# THIE ROUTINE MUST BE GIVEN 
#            @f filelist to send
#                 and
#            options, so mode and timeout is FIXED!
#         NOT CONFUSE!
#   In addition, ALREADY UNLOCKED!
#
# mget3 is just an interface for mget2 mechanism
#
#      mget2 *, ? and 1?, in addition like a
#      mget2 1-100,101,110-1000
#
#      mget * or mget 1?
#
# ATTENTION: "mget3 is called in MgetCompileEntry", NOT DO ACTIONS;
#
sub mget3 
{
    # $opt is used to identify %Sending.*Entry
    local(*value, *opt, *e) = @_;

    local(%cf);			# SCOPE is restricted hereafter
    local($r, @r, %r);		# Result
    local($sp, @sp, %sp, $ar, @ar, %ar); # sp, ar
    local($fn, $dir, $tmpf, $prev, $m, $total, $s, @filelist);
    local($log_s) = "mget[$$]:";
    
    $0 = "${FML}: mget3 initialize $MyProcessInfo>";

    &mget3_Init(*cf, *e);	# default values and ADDR_CHECK_MAX?(security)
				# set -> %cf
    &InitDraftGenerate;		# set "function pointers"
				# set -> %_FOPH
    &mget3_Getopt(*cf,*opt,*e); # parsing options 
				# set -> %cf

    $0 = "${FML}: mget3 searching files $MyProcessInfo>";

    $r = &mget3_Search(*cf, *value, *opt, *sp, *ar, *e);
				# Search and if found
				# @sp   spool/\d+ files
				# @ar   archive files in @ARCHIVE_DIR

    return 0 if $r eq 'STOP';	# ERROR! (ATTACK?)


    ##### IF TOO MATCHED
    if (&ExcessMaxFileP(*sp, *cf)) {
	return 0;
    }
    else {
	# NameSort is required here for the escape code in the next "for" loop;
	@sp = sort NameSort @sp;
    }


    ##### SORTING: PLAIN TEXT in @sp
    # whether the requested files exist or not?
    # if with unpack option, select only plain text files. 
    # require 400, "your own and only you"
    # SORT: foreach (sort csort @sp) { # sort as strings since e.g. "spool/\d+"
    &Debug("--mget3 sort session") if $debug;
    SORT: for (@sp) { # sort is done after
	&Debug("   scan $_") if $debug;

        next SORT if $prev eq $_; # uniq emulation
	$prev = $_;		  # uniq emulation

	stat($_);
	(-r _ && -o _ && -T _) && push(@filelist, $_) && $m++;
	(-r _ && -o _ && -B _) && 
	    &Log("Must be Plain but Binary[$_]? NOT SENT");

	last SORT if $m > $cf{'MAXFILE'}; # if @sp > $cf{'MAXFILE'}
    }

    if ($debug) { while(($k, $v) = each %sp) { &Debug("\%sp $k = $v");}}

    ### Extract plain text from archives 
    # %sp is $sp{100.tar.gz} = 99. ...
    # @r is extracted filelists to send
    # SO @r SHOULD BE UNLINKED AFTER COMPRESSED FILES GENERATED
    $0 = "${FML}: mget3 extracting files $MyProcessInfo>";
    &Debug("--mget3 extract session") if $debug;
    if (%sp) {		
	$m += &ExtractFiles(*sp, *r);
	push(@filelist, @r) if @r;
    }
    else {
	&Debug("--mget3 extract session: no %sp") if $debug;
    }


    ##### ADJUST: counting matched archives
    $m +=  scalar(@ar);		# in archives


    ###### Check and Log: not matched!
    # Here @filelist has already the list to send back.
    #
    if (0 == $m) {
	$0 = "${FML}: mget3 error, so ends $MyProcessInfo>";
	&Log("$log_s: NO MATCHED FILE[\$m == 0]");
	return 0;
    }
    # non zero files match
    else {
	undef %sp; undef @sp;
	if (&ExcessMaxFileP(*sp, *cf, $m)) { return 0;}
    }

    ###### for Headers and a few variables
    $0 = "${FML}: mget3 try send-back-processes $MyProcessInfo>";
    &Debug("--mget3 try send back session") if $debug;

    local($mode_doc);
    $which     = join(" ", @value);# file1 file2 ... (MAY BE NOISY?)
    $mode      = $cf{'mode'};	# set $mode !
    $to        = $cf{'reply-to'} = $e{'Addr2Reply:'};
    $mode_doc  = $cf{'mode-doc'} ? "[$which $cf{'mode-doc'}]" : "[$which]";
    $sleeptime = $cf{'SLEEP'};

    local(%template_cf) = ("_DOC_MODE_", $mode_doc,
			   "_PREAMBLE_", $e{'r:Subject'},
			   );

    $subject = &SubstituteTemplate($MGET_SUBJECT_TEMPLATE, *template_cf);

    # default 1000lines == 50k
    $MAIL_LENGTH_LIMIT = ($MAIL_LENGTH_LIMIT || 1000); 
    
    ### TMP 
    # SETTINGS affected by config.ph
    # ATTENTION: in SendingBackOrderly $DIR/$returnfile
    # relative path for all modes availability
    local($returnfile);

    if ($COMPAT_ARCH) {
	$returnfile = "${TMP_DIR}/m_${opt}_${$}return";	
    }
    else {
	$returnfile = "${TMP_DIR}/m:${opt}:${$}return";
    }


    ##### mget interface 
    # filename may be a complicated filename but it is O.K.?
    if ($mode eq 'lhaish') {
	$s = "msend.lzh";
    }
    elsif ($mode eq 'tgz') {
	$s = "msend.tar.gz";
    }
    elsif ($mode eq 'uu') {
	$s = "msend.uu";
    }
    else {
	$s = "msend.gz";
    }

    if (@filelist) {
	# sort files with extracted files
	local($xa, $xb);
	@filelist = sort NameSort @filelist;

	# define %SE_MIB; # mget3; SendingEntry MIME Information Base;

	$total  = &DraftGenerate($returnfile, $mode, $s, @filelist);
	
	# ENTRY IN
	push(@SendingEntry, $opt);
	$SendingEntry{$opt, 'file'}    = "$DIR/$returnfile";#multi ml
	$SendingEntry{$opt, 'total'}   = $total;
	$SendingEntry{$opt, 'subject'} = $subject;
	$SendingEntry{$opt, 'sleep'}   = $sleeptime;
	$SendingEntry{$opt, 'to:'}     = $to;
	$SendingEntry{$opt, 'unlink'}  = " @r ";

	# MIME Header Info;
	$SE_MIB{$opt, 'h:mime-version:'} = $e{'GH:Mime-Version:'};;
	$SE_MIB{$opt, 'h:content-type:'} = $e{'GH:Content-Type:'};
	$SE_MIB{$opt, 'h:content-transfer-encoding:'} = 
	    $e{'GH:Content-Transfer-Encoding:'};
	undef $e{'GH:Mime-Version:'};
	undef $e{'GH:Content-Type:'};
	undef $e{'GH:Content-Transfer-Encoding:'};
    }
    elsif (@ar) {
	# ENTRY IN
	for $opt (@ar) {
	    next unless -f $opt;

	    if ($cf{'mode-default'}) { # IF MODE IS NOT GIVEN,
		# PLAIN->MIME/Multipart
		$mode = -T $opt ? 
		    ($MGET_TEXT_MODE_DEFAULT || 'mp'): 
			($MGET_BIN_MODE_DEFAULT || 'uu'); 
		$cf{'mode'}     = $mode;
		$cf{'mode-doc'} = &DocModeLookup("#3$mode");

		if ($e{'r:Subject'}) {
		    $subject = $e{'r:Subject'};
		}
		else {
		    $subject = "$DEFAULT_MGET_SUBJECT " .
			($cf{'mode-doc'}? 
			 "[$which $cf{'mode-doc'}]": "[$which]");
		}
	    }

	    push(@SendingArchiveEntry, $opt);
	    $SendingArchiveEntry{$opt, 'file'}    = $opt;
	    $SendingArchiveEntry{$opt, 'mode'}    = $mode;
	    $SendingArchiveEntry{$opt, 'subject'} = $subject;
	    $SendingArchiveEntry{$opt, 'to:'}     = $cf{'reply-to'};

	    # FYI: MIME;
	    # SendFileBySplit do both &DraftGenerate and disables Mime Headers;
	    # Arayuru OK:-)
	}
    }
    else {
	&Mesg(*e, "no matched file in mget3 processing", 'fop.not_found');
	# &Mesg(*e, "\tprocessing ends.");
	return 0;
    }

    1;
}


sub NameSort
{
    $xa = $a;
    $xb = $b;
    $xa =~ s/^(\D+)(\d+)/$xa = $2/e;
    $xb =~ s/^(\D+)(\d+)/$xb = $2/e;
    $xa <=> $xb;
}


# ACTUAL WORKS OF SENDING AFTER UNLOCKED
sub mget3_SendingEntry
{
    local($file, $mode, $subject, $to, $t, $r, $sleep);

    # Reply-To:
    local($mget_reply_to) = $Envelope{'GH:Reply-To:'};
    $Envelope{'GH:Reply-To:'} = $MAIL_LIST;

    if ((!$Envelope{'mode:fmlserv'}) && ($mget3_SendingEntry_counter++ > 0)) {
	&Log("mget3_SendingEntry is SHOULD NOT be called more then once");
	return;
    }

    foreach $opt (@SendingEntry) {
	&Debug("\@SendingEntry\t@SendingEntry") if $debug;

	$file     = $SendingEntry{$opt, 'file'};
	$t        = $SendingEntry{$opt, 'total'};
	$subject  = $SendingEntry{$opt, 'subject'};
	$sleep    = $SendingEntry{$opt, 'sleep'};
	$to       = $SendingEntry{$opt, 'to:'};
	$r        = $SendingEntry{$opt, 'unlink'};

	# MIME Info;
	$Envelope{'GH:Mime-Version:'} = $SE_MIB{$opt, 'h:mime-version:'};
	$Envelope{'GH:Content-Type:'} = $SE_MIB{$opt, 'h:content-type:'};
	$Envelope{'GH:Content-Transfer-Encoding:'} = 
	    $SE_MIB{$opt, 'h:content-transfer-encoding:'};

	&Debug("&SendingBackInOrder($file, $t, $subject, $sleep, $to);") 
	    if $debug;

	&SendingBackInOrder($file, $t, $subject, $sleep, $to);
	&mget3_Unlink($r)    if $r;    # remove extracted files
	&mget3_Unlink($file) if $file;

	# MIME Info Desctructor;
	undef $Envelope{'GH:Mime-Version:'};
	undef $Envelope{'GH:Content-Type:'};
	undef $Envelope{'GH:Content-Transfer-Encoding:'};
    }

    foreach $opt (@SendingArchiveEntry) {
	&Debug("\@SendingArchiveEntry\t@SendingArchiveEntry") if $debug;

	$file    = $SendingArchiveEntry{$opt, 'file'};
	$mode    = $SendingArchiveEntry{$opt, 'mode'};
	$subject = $SendingArchiveEntry{$opt, 'subject'};
	$to      = $SendingArchiveEntry{$opt, 'to:'};

	&Debug("&SendFilebySplit($file, $mode, $subject, $to);") if $debug;
	&SendFilebySplit($file, $mode, $subject, $to);
    }

    # restore Reply-To:
    $Envelope{'GH:Reply-To:'} = $mget_reply_to;
}


sub mget3_Unlink
{
    local($_) = @_;

    for (split(/\s+/, $_)) {
	next if /^\./;
	next unless -f $_;

	&Debug("mget3_Unlink $_") if $debug;
	unlink $_;
    }
}


sub ExcessMaxFileP
{
    local(*sp, *cf, $c) = @_;
    local($x, @xa);

    print STDERR "00 \$c += $c\n" if $debug;

    $x = scalar(@sp); $c += $x;
    print STDERR "01 \$c += $x\n" if $debug; 
    
    for (keys %sp) { 
	@xa = split(/\s+/, $sp{$_}); 
	$x  = $#xa + 1; # == scalar(@x);
	$c += $x;
	print STDERR "02 \$c += $x ($_ +$x)\n" if $debug; 
    }

    print STDERR "03 \$c  = $c (sum)\n" if $debug; 
    if ($c > $cf{'MAXFILE'}) {
	&Log("mget[$$]: files to request > $cf{'MAXFILE'}");
	&Mesg(*e, "your request exceeds $cf{'MAXFILE'}", 
	      'fop.mget.too_many', $cf{'MAXFILE'});
	1;
    }

    0;
}



######################################################################
###                       MGET3 LIBRARY
######################################################################
sub mget3_Init
{ 
    local(*cf, *e) = @_;
    local($mode)   = $MGET_MODE_DEFAULT || 'tgz'; # default

    &Debug("--mget3_Init") if $debug;

    $MGET_SUBJECT_TEMPLATE = $MGET_SUBJECT_TEMPLATE || 
	"result for mget _DOC_MODE_ _PART_ _ML_FN_";

    # global variable
    $ArchiveBoundary = &GetArchiveBoundary;

    # default
    $cf{'PACK'}     = 1;
    $cf{'SLEEP'}    = $MGET_SEND_BACK_SLEEPTIME || $SLEEPTIME || 300;
    $cf{'MAXFILE'}  = $MGET_SEND_BACK_FILES_LIMIT || 1000;
    $cf{'mode'}     = $mode;
    $cf{'mode-doc'} = &DocModeLookup("#3$mode");
    $cf{'reply-to'} = $e{'Addr2Reply:'};

    # global
    $MGetSentBackFilesLimit = $cf{'MAXFILE'};

    # for the later EVARLUATOR(NO EVAL NOW! 95/09)
    # &MetaP($cf{'reply-to'})     && return 0;
    # &InSecureP($cf{'reply-to'}) && return 0;
}


# This function is required to operate local scope variables.
# required when listserv-style multi-ML's handling
sub mget3_Reset
{
    &Debug("--mget3_Reset") if $debug;

    undef @SendingEntry;
    undef @SendingArchiveEntry;
    undef %SendingEntry;
    undef %SendingArchiveEntry;
}


sub mget3_Getopt
{
    local(*cf, *opt, *e) = @_;

    $cf{'mode-default'} = 1;	# default flag on

    foreach(@opt) {
	next if /^(\s*|default)$/;

	/^(\d+)$/o && ($cf{'SLEEP'}  = $1, next);
	local($dummy, $mode) = &ModeLookup("3$_");

	if ($mode) {
	    $cf{'mode'}     = $mode;
	    $cf{'mode-doc'} = &DocModeLookup("#3$mode");
	    undef $cf{'mode-default'}; # MODE IS GIVEN !
	}
	else {
	    &Mesg(*e, $NULL, 'fop.mget.no_such_mode', $_, 'gzip');
	}
    }
}


# foreach entry in @value
# try 
#     MH
#     V2
#     exact 
#     V1
#
#    Please see FAQ too
#
sub mget3_Search
{
    local(*cf, *value, *opt, *sp, *ar, *e) = @_;
    local($dir, $target, $fn, $tmpf, *r, $m);

    &Debug("--mget3_Search") if $debug;

  TARGET: foreach $target (@value) {
      undef $fn;		# reset

      print STDERR "TARGET: $target\n" if $debug;
      $m .= "   Searching $target\n";

      ### MH
      $r = &mget3_MHExpand($target, *sp);

      ### V2
      # set the result to @sp, %sp
      print STDERR "MGET V2 Request [$r]\n" if $debug;
      &mget3_V2search($r, *sp) && ($m .= "\tFOUND.\n") && (next TARGET);

      if ($_PCB{'INSECURE'}) { # EMERGENCY STOP FOR SECURITY
	  &Log('mget3_Search: insecure, stop');
	  return 'STOP';
      }

      ### search in archive
      # set the result to @ar
      print STDERR "\tARCHIVE\t$r\n" if $debug;
      &mget3_SearchInArchive($r, *ar, *e) 
	  && ($m .= "\tFOUND.\n") && (next TARGET);

      return 'STOP' if $_PCB{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

      ### V1
      if (0) { ### REMOVED; $SECURITY_LEVEL < 2) { # permit mget(v1)
	  &mget3_V1search($r, *sp, *ar) 
	      && ($m .= "\tFOUND.\n") && (next TARGET);
      }
      elsif ($target =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	  &Log("NOT PERMIT mget v1 since Security level < 2, stop");
	  $m .= "\n* Sorry, our Server ";
	  $m .= "NOT permit shell-matching when mget\n\n";
	  print STDERR "MGET V[12] NO MATCH [$r]\n" if $debug;
	  return 0;
      }
      # NOTHING IS MATCHED
      else {
	  &Log("$target not found");
	  &Mesg(*e, 'not found', 'not_found', $m);
      }

      # EMERGENCY STOP FOR SECURITY
      return 'STOP' if $_PCB{'INSECURE'}; 
  }# foreach;
}


# Search files in Archives 
#
# e.g. 
#    100 in spool i.e. spool/100
#    100.tar.gz          SEARCH -> $dir/100.tar.gz 
#    archive/100.tar.gz 
#    uja                 SEARCH -> $dir/uja
#    archive/uja
#
# VARIABLES:
# tmpf: the real file path
#   fn: file name to use in subject
#
sub mget3_SearchInArchive
{
    local($target, *ar, *e) = @_;
    local($dir, $fn, $tmpf, *r);
    local($ok) = 0;

    print STDERR "\tSearch [$target] in ARCHIVE\n" if $debug;

  AR: foreach $dir (@ARCHIVE_DIR) {
      print STDERR "\tDIR\t$dir\n" if $debug;

      ### save the original for each $dir
      $fn = $target;
      
      ### SECURITY ROUTINES, STOP!
      if (! &SecureP($fn)) {
	  &Log("SECURITY_LEVEL: $SECURITY_LEVEL");
	  $_PCB{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  &Mesg(*e, 
		"trap special charactors, so process stops for security reason",
		'filter.insecure_p.stop');
	  &Log("STOP for insecure [$fn]");
	  return 0;
      }

      if ($Permit{'ShellMatchSearch'} && (! &SecureP($fn))) {
	  $_PCB{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  &Mesg(*e, 
		"trap special charactors, so process stops for security reason",
		'filter.insecure_p.stop');
	  &Log("STOP for insecure [$fn]");
	  return 0;
      }

      # CHECK If include $dir syntax
      # e.g. archive($dir)/summary-old-ml
      # "GET $fn"
      # 
      ### $dir/"PATTERN CHECK"
      if ($fn =~ /^$dir\/(.*)/) {
	  $fn = $1;

	  # $dir/100.gz
	  if ($fn =~ /^\d+\.gz$/) {
	      $tmpf = "$dir/$fn";
	  }
	  # $dir/100.tar.gz;
	  elsif ($fn =~ /^\/\d+\.tar\.gz$/) {
	      $tmpf = "$dir/$fn";
	  }
	  # $dir/100.lzh;
	  elsif ($fn =~ /^\/\d+\.lzh$/) {
	      $tmpf = "$dir/$fn";
	  }
	  # $dir/uja
	  else {
	      if ($fn =~ /^$dir\/(.*)/) {
		  $fn = $1;
		  $tmpf = "$dir/$fn";
	      }
	      else {
		  $tmpf = $fn;
	      }
	  }
      }
      ##### "PATTERN CHECK" INCLUDE NO $dir
      else {
	  $tmpf = "$dir/$fn";
      }

      print STDERR "\tTRY\t$tmpf\n" if $debug;

      # IF Found, ..
      if (-f $tmpf) {
	  print STDERR "\tFound\t$tmpf\n" if $debug;
	  push(@ar, $tmpf);
	  $ok++;
      }
      elsif (-f "$dir/$tmpf") {
	  $tmpf = "$dir/$tmpf";
	  print STDERR "\tFound\t$tmpf\n" if $debug;
	  push(@ar, $tmpf);
	  $ok++;
      }
      else {
	  print STDERR "\tNot found\t$tmpf\n" if $debug;
      }
  }# AR: loop;

    print STDERR "\tSearch ENDS in ARCHIVE\n\n" if $debug;
    $ok;
}


#### MH Expand
# Syntax Extensions similar to MH
# PHASE 1
# 1,10-cur,last:3 -> 1,10-100,98,99,100
# 
#
sub mget3_MHExpand
{
    local($f, *sp) = @_;
    local($r);

    foreach(split(/,/, $f)) {
	s/^(last:\d+)$/&MHwiseExpand($1)/e;
	s/^(\S+)\-(\S+)$/&MHwiseExpand($1).'-'.&MHwiseExpand($2)/e;
	$r .= $r ? ','.$_ : $_;
    }

    print STDERR "Expand [$f] -> [$r]\n" if $debug;

    $r;
}


sub mget3_V2search
{
    local($r, *sp) = @_;
    local($L, $R);
    local($ok, $error);

    &Debug("--mget3_V2search") if $debug;

    ##### MGET V2 #####
    # check of regular expressions type, which of mget or mget2? 
    if ($r =~ /^[\d\-\,]+$/) {	# MGET2!
	print STDERR "MGET V2 Request [$r]\n" if $debug;

	foreach (split(/\,/, $r, 9999)) {
	    undef $ok;

	    /^(\d+)\-(\d+)$/ && ($L = $1, $R = $2) && $ok++;
	    /^(\d+)$/        && ($L = $R = $1)     && $ok++;
	    $ok || $error++;
	    
	    &ExistCheck($L, $R, *sp) ||	&Log("$log_s: scan $L ->$R fails");
	}
    }
    # NOT V2 FORMAT
    else {
	$error++;
    }

    $error ? 0 : 1;# if not match any, ERROR
}


# Old format pattern search
# 
sub mget3_V1search
{
    local($f, *sp, *ar) = @_;
    &Log("2.1REL: V1Search is removed for security.");
}


######################################################################
###                       MGET3 LIBRARY ENDS
######################################################################


# first、prev、cur、next、last ?
# expand MH-wise syntax
# return expanded expression
sub MHwiseExpand
{
    local($s) = @_;

    print STDERR "MH Expanding [$s]\n" if $debug;

    ($s =~ /^\d+$/) && (return $s);
    ($s eq 'last')  && (return &GetID);

    if ($s =~ /^last:\d+$/) {
	local($L, $R) = &GetLastID($s);
	return "$L-$R";
    }

    ($s eq 'cur')   && (return &GetID);
    ($s eq 'first') && (return 1);
    return $s;
}


# Determine which is the boundary between spool and archive
# return Boundary (MAXIMUM) 
sub GetArchiveBoundary
{
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
    local($i, $id);
    local($bound)   = 0; # obsolete in config.ph

    # Reset $bound
    # if exists archive-directory/1000.tar.gz, must be bound=1000;
    # since e.g. Archive.pl gobble 901-1000 in 1000.tar.gz.
    # Archiver ignores 1001-1099 until the article 1100 appears.
    if ($id = &GetID){
	for ($i = $ar_unit; $i < $id; $i += $ar_unit) {
	    for $dir ($SPOOL_DIR, @ARCHIVE_DIR) {
		$bound = $i if -f "$DIR/$dir/$i.gz"; # very early possibility?;
		$bound = $i if -f "$DIR/$dir/$i.tar.gz";
	    }
	}
    }

    $bound;
}


# Set
#    @flist is "spool/number" lists
#    %flist is "archive/100.tar.gz" like lists by &ArchiveFileList
#
# return 1(success) or 0;
#
sub ExistCheck
{
    local($left, $right, *flist) = @_;
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
    local($ep) = 'ExistCheck';

    print STDERR "$ep: $left <-> $right\n" if $debug;

    # illegal
    if ($left > $right) {
	&Log("$log_s: illegal condition: $left > $right");
	return 0;
    }

    # meaningless?
    if ($left == $right) {
	# if an article in spool
	if ($left > $ArchiveBoundary && (-f "$FP_SPOOL_DIR/$left")) { 
	    push(@flist, "$SPOOL_DIR/$left");
	}
	else {			       # if stored as an archive 
	    &Debug("$ep:\$left <= ArchiveBoundary=$ArchiveBoundary") if $debug;
	    &ArchiveFileList($left, $right, *flist);
	}
	return 1;
    }

    # O.K. Here we go!
    # for too large request e.g. 1-100000
    # This code may be not good but useful enough.
    # 
    # FAILS if the spool continuity has holes.
    #   e.g. 100 101 102   105 106 107 ...
    #   If the search pivot is on 104. the right is set to 104.
    #   Hence we cannot "mget" 102-105, which fails for the pivot search.
    # 
    if ($left < $right) {
	local($try)  = $right;

	# 1 one hole
	#    If already $try exists, we should not pivot search.
	# 2 several holes. the rule 1 above fails.
	#    Hence we should do the full scan for $right < $ID (seq file).
	if ($try > &GetID) {
	    do {
		$right = $try;
		$try  = int($try - ($try - $left)/2);
		&Debug("ExistCheck: pivot $left <-> $try") if $debug;
	    } while( (!&ExistP($try)) && ($left < $try));
	}

	if ($left > $right) { return 0;}	# meaningless

	&Debug("ExistCheck: try to scan $left <-> $right") if $debug;

	# store the candidates
	for ($i = $left; $i < $right + 1; $i++) { 
	    &Debug("   ExistCheck::scan $i") if $debug;

	    # check the archive against dup of @flist and %flist
	    # if dup, we use %flist since expiration occurs in pararell.
	    if (-f "$FP_SPOOL_DIR/$i" && &NotExistArchiveP($i)) {
		&Debug("   push \@flist $i") if $debug;
		push(@flist, "$SPOOL_DIR/$i");
		$flist_count++; 
	    }
	    elsif ($debug) {
		&Debug("   $i is not found")   if !-f "$FP_SPOOL_DIR/$i";
		&Debug("   $i not in archive") if &NotExistArchiveP($i);
		&Debug("   $i in archive")     if !&NotExistArchiveP($i);
	    }

	    # ends if the number of matched files exceeds 1010
	    if ($file_count > $MGetSentBackFilesLimit + 10) {
		&Log("ExistCheck: stop for \@flist > $MGetSentBackFilesLimit");
		return 0;
	    }
	}

	&Debug("$ep:left=$left <= AB:$ArchiveBoundary") if $debug;

	if (@ARCHIVE_DIR && $left < ($ArchiveBoundary + 1)) { 
	    &ArchiveFileList($left, $right, *flist);
	}

	return 1;
    }# left < right;

    0;
}


# Search files in ARCHIVE_DIR directories
# find to store in %filelist
# return NONE.
sub ArchiveFileList
{
    local($left, $right, *flist) = @_;
    local($i, $f);
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;

    for ($i = $left; $i < ($right + 1); $i++) {
	local($sp) = (int(($i - 1)/$ar_unit) + 1) * $ar_unit;

	for $dir ($SPOOL_DIR, @ARCHIVE_DIR) {
	    $f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";

	    stat($f);
	    if (-B _ && -r _ && -o _) { 
		# ensure the uniqueness
		$flist{$f} .= "$SPOOL_DIR/$i " 
		    if $i && $flist{$f} !~ "$SPOOL_DIR/$i";
	    }
	}#FOREACH;
    }# FOR:
}


sub ArticleInWhichArchive
{
    local($i) = @_;
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
    (int(($i - 1)/$ar_unit) + 1) * $ar_unit;
}


sub NotExistArchiveP
{
    local($i) = @_;
    local($f, $sp, $dir);
    local($ar_unit) = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;

    # $sp = &ArticleInWhichArchive($i);
    $sp = (int(($i - 1)/$ar_unit) + 1) * $ar_unit;

    for $dir ($SPOOL_DIR, @ARCHIVE_DIR) {
	next unless $dir;

	$f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";
	stat($f);

	# if archive exist, false
	if (-B _ && -r _ && -o _) { return 0;} 
    }

    1;
}


# &ExtractFiles(*candidate, *return_filelist_to_send);
# extract values %candidate from keys %candidate
# extract files and set @return_filelist_to_send;
# return the number of matched files
sub ExtractFiles
{
    local(*c, *r) = @_;
    local($cmd, $m, $s, $f);
    
    &DiagPrograms('TAR', 'ZCAT');

    $cmd = $TAR;
    $cmd =~ s/^(\S+)\s.*$/$1/;
    $cmd = "$cmd xf - ";

    # (cd tmp; tar zxvf ../old/300.tar.gz $SPOOL_DIR/201 ...)
    foreach $f (keys %c) {
	next if $f eq 'Binary';	# special for e.g. archive/summary-old-ml

	$s = "cd $FP_TMP_DIR; $ZCAT $DIR/$f|$cmd ". $c{$f};
	print STDERR "Extractfiles::system($s)\n" if $debug;
	&system($s);

	foreach (split(/\s+/, $c{$f})) {
	    push(@r, "$TMP_DIR/$_");
	    push(@c, "$TMP_DIR/$_");
	    $m++;
	}	
    }

    $m;
}


1;
