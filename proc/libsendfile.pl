# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

&use('fop');

# VARIABLES
#
# sp (set by ExistCheck)
# @sp matched plain flies
# %sp key=archive, value=files_in_it(may be multiple)..
# @ar archive files (must be binary)
#
# Sending Entry ; private
local(@SendingEntry, @SendingArchiveEntry, %SendingEntry, %SendingArchiveEntry);


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
    local($log_s) = "mget:[$$]";
    
    $0 = "--mget3 initialize $FML $LOCKFILE>";

    &mget3_Init(*cf, *e);	# default values and ADDR_CHECK_MAX?(security)
				# set -> %cf
    &InitDraftGenerate;		# set "function pointers"
				# set -> %_fp
    &mget3_Getopt(*cf,*opt,*e); # parsing options 
				# set -> %cf

    $0 = "--mget3 searching files $FML $LOCKFILE>";

    $r = &mget3_Search(*cf, *value, *opt, *sp, *ar, *e);
				# Search and if found
				# @sp   spool/\d+ files
				# @ar   archive files in @ARCHIVE_DIR

    return 0 if $r eq 'STOP';	# ERROR! (ATTACK?)



    ##### IF TOO MATCHED
    if (scalar(@sp) > $cf{'MAXFILE'}) {
	&Log("$log_s: Requested files are exceeded! > $cf{'MAXFILE'}");
	$e{'message'} .= "Sorry. your request exceeds $cf{'MAXFILE'}\n";
	$e{'message'} .= "Anyway, try to send the first $cf{'MAXFILE'} files\n";
    }


    ##### SORTING: PLAIN TEXT in @sp
    # whether the requested files exist or not?
    # if with unpack option, select only plain text files. 
    # require 400, "your own and only you"
    SORT: foreach (sort csort @sp) {	# sort as strings since e.g. "spool/\d+"
	next SORT if $prev eq $_; # uniq emulation
	$prev = $_;		  # uniq emulation

	stat($_);
	(-r _ && -o _ && -T _) && push(@filelist, $_) && $m++;
	(-r _ && -o _ && -B _) && 
	    &Log("Must be Plain but Binary[$_]? NOT SENT");

	last SORT if $m > $cf{'MAXFILE'}; # if @sp > $cf{'MAXFILE'}
    }

    if ($debug) {
	while(($k,$v) = each %sp) { print STDERR "\%SP $k = $v\n";}
    }

    ### Extract plain text from archives 
    # %sp is $sp{100.tar.gz} = 99. ...
    # @r is extracted filelists to send
    $0 = "--mget3 extracting files $FML $LOCKFILE>";
    if (%sp) {		
	$m += &ExtractFiles(*sp, *r);
	push(@filelist, @r) if @r;
    }


    ##### ADJUST: counting matched archives
    $m +=  scalar(@ar);		# in archives


    ###### Check and Log: not matched!
    if (0 == $m) {
	$0 = "--mget3 error, so ends $FML $LOCKFILE>";
	print STDERR "$log_s: NO MATCHED FILE[\$m == 0]\n" if $debug;
	&Log("$log_s: NO MATCHED FILE"); 
	return 0;
    }


    ###### for Headers and a few variables
    $0 = "--mget3 try send-back-processes $FML $LOCKFILE>";

    $which     = " @value ";	# file1 file2 ... (MAY BE NOISY?)
    $mode      = $cf{'mode'};	# set $mode !
    $subject   = $e{'r:Subject'} || "Matomete Send [$which $cf{'mode-doc'}]";
    $to        = $cf{'reply-to'} = $e{'Addr2Reply:'};
    $sleeptime = $cf{'SLEEP'};

    # default 1000lines == 50k
    $MAIL_LENGTH_LIMIT = ($MAIL_LENGTH_LIMIT || 1000); 
    
    ### TMP 
    # SETTINGS affected by config.ph
    # ATTENTION: in SendingBackOrderly $DIR/$returnfile
    local($returnfile)	 = "$TMP_DIR/m:$opt:$$return";

    ##### mget interface 
    # filename may be a complicated filename but it is O.K.?
    if ($mode eq 'lhaish') {
	$s = "msend.lzh";
    }
    elsif ($mode eq 'tgz') {
	$s = "msend.tar.gz";
    }
    else {
	$s = "msend.gz";
    }

    if (@filelist) {
	$total  = &DraftGenerate($returnfile, $mode, $s, @filelist);
	
	# ENTRY IN
	push(@SendingEntry, $opt);
	$SendingEntry{$opt, 'file'}    = $returnfile;
	$SendingEntry{$opt, 'total'}   = $total;
	$SendingEntry{$opt, 'subject'} = $subject;
	$SendingEntry{$opt, 'sleep'}   = $sleeptime;
	$SendingEntry{$opt, 'to:'}     = $to;
	$SendingEntry{$opt, 'unlink'}  = " @r ";
    }
    elsif (@ar) {
	# ENTRY IN
	foreach $opt (@ar) {
	    next unless -f $opt;

	    if ($cf{'mode-default'}) { # IF MODE IS NOT GIVEN,
		$mode = -T $opt ? 'mp': 'uu'; # PLAIN->MIME/Multipart
		$cf{'mode'}     = $mode;
		$cf{'mode-doc'} = &DocModeLookup("#3$mode");
		$subject        = $e{'r:Subject'} || 
		    "Matomete Send [$which $cf{'mode-doc'}]";
	    }

	    push(@SendingArchiveEntry, $opt);
	    $SendingArchiveEntry{$opt, 'file'}    = $opt;
	    $SendingArchiveEntry{$opt, 'mode'}    = $mode;
	    $SendingArchiveEntry{$opt, 'subject'} = $subject;
	    $SendingArchiveEntry{$opt, 'to:'}     = $cf{'reply-to'};
	}
    }
    else {
	$e{'message'} .= "Hmm.. no matched file in mget3 processing\n";
	$e{'message'} .= "\tprocessing ends.\n";
	return 0;
    }

    1;
}


sub csort
{
    local($na, $nb, $wa, $wb);
    $xa = $a;
    $xb = $b;

    $xa =~ s/^(\D+)(\d+)/$wa = $1, $na = $2/e;
    $xb =~ s/^(\D+)(\d+)/$wb = $1, $nb = $2/e;

    if ($na || $nb) {
	# print STDERR "($wa cmp $wb) || ($na <=> $nb);\n";
	($wa cmp $wb) || ($na <=> $nb);
    }
    else {
	$a cmp $b;
    }
}


# ACTUAL WORKS OF SENDING AFTER UNLOCKED
sub mget3_SendingEntry
{
    local($file, $mode, $subject, $to, $t, $r, $sleep);

    if ($mget3_SendingEntry_counter++ > 0) { 
	&Log("mget3_SendingEntry is SHOULD NOT be called more then once");
	return;
    }

    foreach $opt (@SendingEntry) {
	$file     = $SendingEntry{$opt, 'file'};
	$t        = $SendingEntry{$opt, 'total'};
	$subject  = $SendingEntry{$opt, 'subject'};
	$sleep    = $SendingEntry{$opt, 'sleep'};
	$to       = $SendingEntry{$opt, 'to:'};
	$r        = $SendingEntry{$opt, 'unlink'};

	&Debug("&SendingBackInOrder($file, $t, $subject, $sleep, $to);") 
	    if $debug;

	&SendingBackInOrder($file, $t, $subject, $sleep, $to);
	unlink $r    if (!$debug) && $r;    # remove extracted files
	unlink $file if (!$debug) && $file;
    }

    foreach $opt (@SendingArchiveEntry) {
	$file    = $SendingArchiveEntry{$opt, 'file'};
	$mode    = $SendingArchiveEntry{$opt, 'mode'};
	$subject = $SendingArchiveEntry{$opt, 'subject'};
	$to      = $SendingArchiveEntry{$opt, 'to:'};

	&Debug("&SendFilebySplit($file, $mode, $subject, $to);") if $debug;
	&SendFilebySplit($file, $mode, $subject, $to);
    }
}



######################################################################
###                       MGET3 LIBRARY
######################################################################
sub mget3_Init { 
    local(*cf, *e) = @_;
    local($mode)   = 'tgz';	# default

    # global variable
    $ArchiveBoundary = &GetArchiveBoundary;

    # default
    $cf{'PACK'}     = 1;
    $cf{'SLEEP'}    = 300;
    $cf{'MAXFILE'}  = 1000;
    $cf{'mode'}     = $mode;
    $cf{'mode-doc'} = &DocModeLookup("#3$mode");
    $cf{'reply-to'} = $e{'Addr2Reply:'};

    # for the later EVARLUATOR(NO EVAL NOW! 95/09)
    # &MetaP($cf{'reply-to'})     && return 0;
    # &InSecureP($cf{'reply-to'}) && return 0;
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
	    $e{'message'} .= "mget:\n";
	    $e{'message'} .= "\tgiven mode[$_] is unknown.\n";
	    $e{'message'} .= "\tanyway try [gzip] mode\n";
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

      return 'STOP' if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

      ### search in archive
      # set the result to @ar
      print STDERR "\tARCHIVE\t$r\n" if $debug;
      &mget3_SearchInArchive($r, *ar, *e) 
	  && ($m .= "\tFOUND.\n") && (next TARGET);

      return 'STOP' if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

      ### V1
      if ($SECURITY_LEVEL < 2) { # permit mget(v1)
	  &mget3_V1search($r, *sp,*ar) 
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
	  &Log("$target IS NOT FOUND");
	  $e{'message'} .= "$m\tNOT FOUND.\n\tSkip.\n";
      }

      # EMERGENCY STOP FOR SECURITY
      return 'STOP' if $_cf{'INSECURE'}; 
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
      if (&InSecureP($fn)) {
	  &Log("SECURITY_LEVEL: $SECURITY_LEVEL");
	  $_cf{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  $e{'message'}   .= "Execuse me. Please check your request.\n";
	  $e{'message'}   .= "  PROCESS STOPS FOR SECURITY REASON\n\n";
	  &Log("STOP for insecure [$fn]");
	  return 0;
      }

      if (($SECURITY_LEVEL > 1) && (&MetaP($fn) || &InSecureP($fn))) {
	  $_cf{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  $e{'message'}   .= "Execuse me. Please check your request.\n";
	  $e{'message'}   .= "  PROCESS STOPS FOR SECURITY REASON\n\n";
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
    local($ok, $error);

    print STDERR "MGET V1 Request [$f]\n" if $debug;

    # Check Again and Again;
    &InSecureP($f) && (return 0);

    # old type mget. Not using ARCHIVE_DIR;
    foreach (<./$SPOOL_DIR/$f>) {
	print STDERR "MGET V1 Request [-f $_]\n" if $debug;

	stat($_);
	if (-f _ && -r _ && -T _ && /\d+$/) {# e.g. spool/1000;
	    push(@sp, $_) && $ok++;
	}
	elsif (-f _) {			# arcvhie/uja.tar.gz ?
	    push(@ar, $_) && $ok++;
	}
	else {
	    &Log("NO MATCH $_");
	    &Debug("NO MATCH $_") if $debug;
	}
    }

    $ok;
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

    print STDERR "MH Expanding $s\n" if $debug;

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
# return Boundary 
sub GetArchiveBoundary
{
    local($ar_unit) = ($DEFAULT_ARCHIVE_UNIT || 100);
    local($i, $id);
    local($bound)   = 0; # obsolete in config.ph

    # Reset $bound
    if ($id = &GetID){
	for ($i = $ar_unit; $i < $id; $i += $ar_unit) {
	    foreach $dir ($SPOOL_DIR, @ARCHIVE_DIR) {
		$bound += $ar_unit if -f "$dir/$i.tar.gz" || -f "$dir/$i.gz";
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
    local($ar_unit) = $DEFAULT_ARCHIVE_UNIT ? $DEFAULT_ARCHIVE_UNIT : 100;
    local($EC) = 'ExistCheck';

    print STDERR "$EC: $left <-> $right\n" if $debug;

    # illegal
    if ($left > $right) {
	&Log("$log_s: illegal condition: $left > $right");
	return 0;
    }

    # meaningless?
    if ($left == $right) {
	# if an article in spool
	if ($left > $ArchiveBoundary && (-f "$SPOOL_DIR/$left")) { 
	    push(@flist, "$SPOOL_DIR/$left");
	}
	else {			       # if stored as an archive 
	    print STDERR "$EC:\$left <= $ArchiveBoundary\n" if $debug;
	    &ArchiveFileList($left, $right, *flist);
	}
	return 1;
    }

    # O.K. Here we go!
    # for too large request e.g. 1-100000
    # This code may be not good but useful enough.
    if ($left < $right) {
	local($try)  = $right;
	do {
	    $right = $try;
	    $try  = int($try - ($try - $left)/2);
	    print STDERR "ExistCheck: $left <-> $try\n" if $debug;
	} while( (!&ExistP($try)) && ($left < $try));

	if ($left > $right) { return 0;}	# meaningless

	# store the candidates
	for ($i = $left; $i < $right + 1; $i++) { 
	    push(@flist, "$SPOOL_DIR/$i") if -f "$SPOOL_DIR/$i";
	}

	print STDERR "$EC:\$left <= $ArchiveBoundary\n" if $debug;

	if (defined(@ARCHIVE_DIR) && $left < ($ArchiveBoundary + 1)) { 
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
    local($ar_unit) = $DEFAULT_ARCHIVE_UNIT ? $DEFAULT_ARCHIVE_UNIT : 100;

    for ($i = $left; $i < ($right + 1); $i++) {
	local($sp) = (int(($i - 1)/$ar_unit) + 1) * $ar_unit;

	foreach $dir ("spool", @ARCHIVE_DIR) {
	    $f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";

	    stat($f);
	    if (-B _ && -r _ && -o _) { 
		$flist{$f} .= "$SPOOL_DIR/$i ";
	    }
	}#FOREACH;
    }# FOR:
}


# &ExtractFiles(*candidate, *return_filelist_to_send);
# extract values %candidate from keys %candidate
# extract files and set @return_filelist_to_send;
# return the number of matched files
sub ExtractFiles
{
    local(*c, *r) = @_;
    local($cmd, $m, $s, $f);
    
    $cmd = $TAR;
    $cmd =~ s/^(\S+)\s.*$/$1/;
    $cmd = "$cmd xf - ";

    # (cd tmp; tar zxvf ../old/300.tar.gz $SPOOL_DIR/201 ...)
    foreach $f (keys %c) {
	next if $f eq 'Binary';	# special for e.g. archive/summary-old-ml

	$s = "cd $TMP_DIR; $ZCAT $DIR/$f|$cmd ". $c{$f};
	print STDERR "Extract: sh -c $s\n" if $debug;
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
