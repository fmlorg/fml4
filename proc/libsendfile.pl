# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (.*).pl,v\s+(\S+)\s+/ && "$1[$2]");
($sfid) = ($id =~ /Id: (.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

&use('utils');

# VARIABLES
#
# sp (set by ExistCheck)
# @sp matched plain flies
# %sp key=archive, value=files_in_it(may be multiple)..
# @ar archive files (must be binary)
#

# Sending Entry ; private
local(*SendingEntry, *SendingArchiveEntry);


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
sub mget3 
{
    local(*value, *opt) = @_;	# $opt is used to identify %Sending.*Entry
    local(*CF);			# SCOPE is restricted hereafter
    local($log_s) = "mget:[$$]";
    local($fn, $dir, $tmpf);
    local(*r);			# Result
    local(*sp, *ar);
    local($prev, $m, $TOTAL, $s, @filelist);
    
    &mget3_Init(*CF);		# default values and ADDR_CHECK_MAX?(security)
				# set -> %CF
    &InitDraftGenerate;		# set "function pointers"
				# set -> %_fp
    &mget3_Getopt(*CF, *opt);	# parsing options 
				# set -> %CF

    $r = &mget3_Search(*CF, *value, *opt, *sp, *ar);
				# Search and if found
				# @sp   spool/\d+ files
				# @ar   archive files in @ARCHIVE_DIR

    return 0 if $r eq 'STOP';	# ERROR! (ATTACK?)



    ##### IF TOO MATCHED
    if(scalar(@sp) > $CF{'MAXFILE'}) {
	local($s);
	&Log("$log_s: Requested files are exceeded!");
	$s .= "Sorry. your request exceeds $CF{'MAXFILE'}\n";
	$s .= "Anyway, try to send the first $CF{'MAXFILE'} files\n";
	$Envelope{'message'} .= $s;
    }


    ##### SORTING: PLAIN TEXT in @sp
    # whether the requested files exist or not?
    # if with unpack option, select only plain text files. 
    # require 400, "your own and only you"
    SORT: foreach (sort @sp) {	# sort as strings since e.g. "spool/\d+"
	next SORT if $prev eq $_; # uniq emulation
	$prev = $_;		  # uniq emulation

	print STDERR "Sorting stat($_)\n" if $debug;

	stat($_);
	(-r _ && -o _ && -T _) && push(@filelist, $_) && $m++;
	(-r _ && -o _ && -B _) && 
	    &Log("Must be Plain but Binary[$_]? NOT SEND");

	last SORT if $m > $CF{'MAXFILE'}; # if @sp > $CF{'MAXFILE'}
    }

    &Debug("After Sorting, filelist = @filelist\nar = @ar") if $debug;

    ##### Extract plain text from archives #####
    if ($debug) {
	while(($k,$v)=each %sp) {
	    print STDERR "\%SP $k = $v\n"; 
	}
    }
    # 
    # %sp is $sp{100.tar.gz} = 99. ...
    # @r is extracted filelists to send
    if (%sp) {		
	# &ExtractFiles(*candidate, *return_filelist_to_send);
	$m += &ExtractFiles(*sp, *r);
	push(@filelist, @r) if @r;
    }


    ##### ADJUST: counting matched archives
    $m +=  scalar(@ar);		# in archives


    ###### Check and Log: not matched!
    if (0 == $m) {
	print STDERR "$log_s: NO MATCH [\$m == 0]\n" if $debug;
	&Log("$log_s: NO MATCHED files."); 
	return 0;
    }


    ###### for Headers and a few variables
    $0 = "--mget3 try send back process $FML $LOCKFILE>";

    $which = join(" ", @value);
    $mode      = $CF{'mode'};	# set $mode !

    $SUBJECT    = "Matomete Send [$which $CF{'mode-doc'}]";
    $to         = $CF{'reply-to'} = $Envelope{'Addr2Reply:'};
    $SLEEPTIME  = $CF{'SLEEP'};

    # default 1000lines == 50k
    $MAIL_LENGTH_LIMIT = ($MAIL_LENGTH_LIMIT || 1000); 
    
    # RCSID
    local($fid);
    ($fid) = ($rcsid =~ /^(fml\S+)/);
    $rcsid = "$sfid:[$fid]";

    ### TMP 
    # SETTINGS affected by config.ph
    # ATTENTION: in SendingBackOrderly $DIR/$returnfile
    local($returnfile)	 = "$TMP_DIR/m:$opt:$$reteurn";

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
	$TOTAL  = &DraftGenerate($returnfile, $mode, $s, @filelist);
	
	# ENTRY IN
	push(@SendingEntry, $opt);
	$SendingEntry{$opt, 'file'}    = $returnfile;
	$SendingEntry{$opt, 'total'}   = $TOTAL;
	$SendingEntry{$opt, 'subject'} = $SUBJECT;
	$SendingEntry{$opt, 'sleep'}   = $SLEEPTIME;
	$SendingEntry{$opt, 'to:'}     = $to;
	$SendingEntry{$opt, 'unlink'}  = join(" ", @r);
    }
    elsif (@ar) {
	# ENTRY IN
	foreach $opt (@ar) {
	    next unless -f $opt;

	    if ($CF{'mode-default'}) { # IF MODE IS NOT GIVEN,
		$mode = -T $opt ? 'mp': 'uu'; # PLAIN->MIME/Multipart
		$CF{'mode'}     = $mode;
		$CF{'mode-doc'} = &DocModeLookup("#3$mode");
		$SUBJECT        = "Matomete Send [$which $CF{'mode-doc'}]";
	    }

	    push(@SendingArchiveEntry, $opt);
	    $SendingArchiveEntry{$opt, 'file'}    = $opt;
	    $SendingArchiveEntry{$opt, 'mode'}    = $mode;
	    $SendingArchiveEntry{$opt, 'subject'} = $SUBJECT;
	    $SendingArchiveEntry{$opt, 'to:'}     = $CF{'reply-to'};
	}
    }
    else {
	$Envelope{'message'} .= "Hmm.. no match file in mget3 processing\n";
	$Envelope{'message'} .= "\tprocessing ends.\n";
	return $NULL;
    }

    1;
}


# after unlock
sub mget3_SendingEntry
{
    local(*file, *mode, *subject, *to, *t, *r, *sleep);

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
    local(*CF) = @_;
    local($mode) = 'tgz';	# default

    # global variable
    $STORED_BOUNDARY = &GetStoredBoundary;

    # default
    $CF{'PACK'}     = 1;
    $CF{'SLEEP'}    =  300;
    $CF{'MAXFILE'}  = 1000;
    $CF{'mode'}     = $mode;
    $CF{'mode-doc'} = &DocModeLookup("#3$mode");
    $CF{'reply-to'} = $Envelope{'Addr2Reply:'};

    # for the later EVARLUATOR(NO EVAL NOW! 95/09)
    # &MetaP($CF{'reply-to'})     && return 0;
    # &InSecureP($CF{'reply-to'}) && return 0;
}


sub mget3_Getopt
{
    local(*CF, *opt) = @_;
    local($dummy);		# dummy variable for ModeLookup

    $CF{'mode-default'} = 1;	# default flag on

    foreach(@opt) {
	next if /^$/o;#tricky?
	    next if /^default$/o;#tricky?	

		/^(\d+)$/o   && ($CF{'SLEEP'}  = $1, next);
	($dummy, $mode) = &ModeLookup("3$_");

	if ($mode) {
	    $CF{'mode'}     = $mode;
	    $CF{'mode-doc'} = &DocModeLookup("#3$mode");
	    undef $CF{'mode-default'}; # MODE IS GIVEN !
	}
	else {
	    $Envelope{'message'} .= "mget:\n";
	    $Envelope{'message'} .= "\tgiven mode[$_] is unknown.\n";
	    $Envelope{'message'} .= "\tanyway try [gzip] mode\n";
	    $ERROR_FLAG++;	# global
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
    local(*CF, *value, *opt, *sp, *ar) = @_;
    local($dir, $target, $fn, $tmpf, *r);

  TARGET: foreach $target (@value) {
      undef $fn;		# reset

      print STDERR "TARGET: $target\n" if $debug;

      ### MH
      $r = &mget3_MHExpand($target, *sp);

      ### V2
      # set the result to @sp, %sp
      print STDERR "\tV2\t$r\n" if $debug;
      &mget3_V2search($r, *sp) && (next TARGET);

      return 'STOP' if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

      ### search in archive
      # set the result to @ar
      print STDERR "\tARCHIVE\t$r\n" if $debug;
      &mget3_SearchInArchive($r, *ar) && (next TARGET);

      return 'STOP' if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY

      ### V1
      if ($SECURITY_LEVEL < 2) { # permit mget(v1)
	  print STDERR "\tV1\t$r\n" if $debug;
	  &mget3_V1search($r, *sp,*ar) && (next TARGET);
      }
      else {
	  &Log("NOT PERMIT mget v1 search since Security level < 2, stop");
	  $Envelope{'message'} .= 
	      "\n* Sorry, our Server NOT permit shell-matching when mget\n\n";
	  print STDERR "MGET V[12] NO MATCH [$r]\n" if $debug;
	  return 0;
      }

      return 'STOP' if $_cf{'INSECURE'}; # EMERGENCY STOP FOR SECURITY
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
    local($target, *ar) = @_;
    local($dir, $fn, $tmpf, *r);
    local($ok) = 0;

    print STDERR "\tSearch [$target] in ARCHIVE\n" if $debug;

  AR: foreach $dir (@ARCHIVE_DIR) {
      print STDERR "\tDIR\t$dir\n" if $debug;

      ### save the original for each $dir
      $fn = $target;

      ### SECURITY ROUTINES, STOP!
      if (&MetaP($fn) || &InSecureP($fn)) {
	  $_cf{'INSECURE'} = 1; # EMERGENCY STOP FOR SECURITY
	  $Envelope{'message'}  .= "Execuse me. Please check your request.\n";
	  $Envelope{'message'}  .= "  PROCESS STOPS FOR SECURITY REASON\n\n";
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

    if ($s =~ /^\d+$/) {
	return $s;
    }
 
    if ($s eq 'last') {
	return &GetID;
    }

    if ($s =~ /^last:\d+$/) {
	local($L, $R) = &GetLastID($s);
	return "$L-$R";
    }

    if ($s eq 'cur') {
	return &GetID;
    }

    if ($s eq 'first') {
	return 1;
    }

    return $s;
}


# Determine which is the boundary between spool and archive
# return Boundary 
sub GetStoredBoundary
{
    local($i, $ID);
    local($ar_unit) = ($DEFAULT_ARCHIVE_UNIT || 100);
    local($STORED_BOUNDARY) = 0; # obsolete in config.ph

    # Reset $STORED_BOUNDARY
    if($ID = &GetID){
	for($i = $ar_unit; $i < $ID; $i += $ar_unit) {
	    foreach $dir ("spool", @ARCHIVE_DIR) {
		$STORED_BOUNDARY += $ar_unit 
		    if(-f "$dir/$i.tar.gz" || -f "$dir/$i.gz");
	    }
	}
    }

    $STORED_BOUNDARY;
}


# Set
#    @flist is "spool/number" lists
#    %flist is "archive/100.tar.gz" like lists by &Storedfilelist
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
    if($left > $right) {
	&Log("$log_s: illegal condition: $left > $right");
	return 0;
    }

    # meaningless?
    if($left == $right) {
	# if an article in spool
	if($left > $STORED_BOUNDARY && (-f "$SPOOL_DIR/$left")) { 
	    push(@flist, "$SPOOL_DIR/$left");
	}else {			       # if stored as an archive 
	    print STDERR "$EC:\$left <= $STORED_BOUNDARY\n" if $debug;
	    &Storedfilelist($left, $right, *flist);
	}
	return 1;
    }

    # O.K. Here we go!
    # for too large request e.g. 1-100000
    # This code may be not good but useful enough.
    if($left < $right) {
	local($try)  = $right;
	do {
	    $right = $try;
	    $try  = int($try - ($try - $left)/2);
	    print STDERR "ExistCheck: $left <-> $try\n" if($debug);
	}while( (!&ExistP($try)) && ($left < $try));

	if($left > $right) { return 0;}	# meaningless

	# store the candidates
	for($i = $left; $i < $right + 1; $i++) { 
	    push(@flist, "$SPOOL_DIR/$i") if -f "$SPOOL_DIR/$i";
	}

	print STDERR "$EC:\$left <= $STORED_BOUNDARY\n" if $debug;

	if(defined(@ARCHIVE_DIR) && $left < ($STORED_BOUNDARY + 1)) { 
	    &Storedfilelist($left, $right, *flist);
	}

	return 1;
    }# left < right;

    return 0;
}


# Search files in ARCHIVE_DIR directories
# find to store in %filelist
# return NONE.
sub Storedfilelist
{
    local($left, $right, *flist) = @_;
    local($i, $f);
    local($ar_unit) = $DEFAULT_ARCHIVE_UNIT ? $DEFAULT_ARCHIVE_UNIT : 100;

    for($i = $left; $i < ($right + 1); $i++) {
	local($sp) = (int(($i - 1)/$ar_unit) + 1) * $ar_unit;

	foreach $dir ("spool", @ARCHIVE_DIR) {
	    $f = (-f "$dir/$sp.tar.gz") ? "$dir/$sp.tar.gz" : "$dir/$sp.gz";

	    stat($f);
	    if(-B _ && -r _ && -o _) { 
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
    local($cmd, $m, $s, $c);
    
    $cmd = $TAR;
    $cmd =~ s/^(\S+)\s.*$/$1/;
    $cmd = "$cmd xf - ";

    # (cd tmp; tar zxvf ../old/300.tar.gz $SPOOL_DIR/201 ...)
    foreach $c (keys %c) {
	next if $c eq 'Binary';	# special for e.g. archive/summary-old-ml

	$s = "cd $TMP_DIR; $ZCAT $DIR/$c|$cmd ". $c{$c};
	print STDERR "Extract: sh -c $s\n" if $debug;
	&system($s);

	foreach (split(/\s+/, $c{$c})) {
	    push(@r, "$TMP_DIR/$_");
	    push(@c, "$TMP_DIR/$_");
	    $m++;
	}	
    }

    $m;
}


1;
