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

# local scope in this library
($LibraryArchiveDir, %LibraryMGetList) = ();

&use('sendfile');


# Library access code
# IN THE PRESENT TIME,  Codes to access plain files
# return NONE.
#
sub ProcLibrary4PlainArticle
{
    local($proc, *Fld, *e, *misc) = @_;
    local($lib_dir, $arc_dir, $_, @p, @fld, $seq, $summary);

    ### convert library -> mget call;
    @p   = @Fld[3 .. $#Fld]; 
    @fld = @Fld[2 .. $#Fld]; 
    unshift(@fld, '#');

    &Debug("\nProcLibrary4PlainArticle::\n\tp @p\n\tfld @fld\n") if $debug;

    ### variables
    $lib_dir =  $LIBRARY_DIR || 'library';
    $arc_dir =  "$lib_dir/".($LIBRARY_ARCHIVE_DIR || 'archive');
    $seq     =  $SEQUENCE_FILE;
    $seq     =~ s/$DIR/$lib_dir/g;
    $summary =  $SUMMARY_FILE;
    $summary =~ s/$DIR/$lib_dir/g;

    for ($lib_dir, $arc_dir) { -d $_ || &Mkdir($_);}
    for ($seq, $summary)     { -f $_ || &Touch($_);}

    &Debug("lib_dir\t$lib_dir\narc_dir\n\t$arc_dir\n\t") if $debug;
    &Debug("seq\t$seq\nsummary\t$summary\n")             if $debug;

    ### set the command of the library system;
    $_   = $Fld[2]; 

    ### "# library (get|put) @p"
    if (/^get$/i) {
	&Log("$proc $_");

	# save main space;
	local($dir)    = $SPOOL_DIR;
	local($fp_dir) = $FP_SPOOL_DIR;
	local(%list)   = %mget_list;

	# restore the library space mget_list;
	%mget_list     = %LibraryMGetList;

	# config
	unshift(@ARCHIVE_DIR, $arc_dir);
	$SPOOL_DIR     = $arc_dir;	# tricky though
	$FP_SPOOL_DIR  = "$DIR/$arc_dir";# tricky though;

	# save initialize parameters for LibrarySendingEntry; 
	$LibraryArchiveDir = $arc_dir;

	&ProcMgetMakeList($proc, *fld, *e, *misc);

	&LogWEnv("Library: submitted entry [mget @p]", *e);

	if ($FML_EXIT_HOOK !~ /LibrarySendingEntry/) {
	    $FML_EXIT_HOOK .= '&LibrarySendingEntry(*Envelope);';
	}
	
	# save Library Specific space;
	%LibraryMGetList = %mget_list;
	
	# restore main space;
	$SPOOL_DIR    = $dir;
	$FP_SPOOL_DIR = $fp_dir;
	%mget_list    = %list;
    }
    elsif (/^unlink$|^rm$|^delete$/i) {
	local($target, $n);
	$target = $n = shift @p;
	&Log("$proc $_ $target");

	if ($target =~ /^\d+$/) {
	    $target = "$arc_dir/$target";
	}
	else {
	    &LogWEnv("filename($n) is not numeric, STOP!", *e);
	    return;
	}

	if (! &LibraryUnlinkP($From_address, $target)) {
	    &Mesg(*e, "Error: library unlink: you cannot unlink $n");
	    &Log("Error: library unlink: not author try to unlink $n");
	    &Warn("Warning: illegal request of library unlink $ML_FN",
		  "library unlink:\n\tnot author ($From_address)\n".
		  "\ttry to unlink $n in library spool");
	    return;
	}

	if (unlink($target)) {
	    &LogWEnv("Unlink $target", *e);
	    &LibraryExpireSummary($summary, $n);
	}
	else {
	    &LogWEnv("Fail to unlink $target", *e);
	}
    }
    elsif (/^put$/i) {
	# *IMPORTANT* e != le(Local Envelope)!!!;
	local($id, %le, $s); 

	($id = &LibraryWriteSummary(*e, $seq, $summary)) || (return 0);
	&Log("$proc $_");

	&use('MIME') if $USE_MIME;
	
	### Header
	for (@HdrFieldsOrder) {
	    if ($s = $e{"h:$_:"}) {
		$s = &DecodeMimeStrings($s) if $USE_MIME && ($s =~ /ISO/i);
	    }
	    $le{'Hdr'} .= "$_: $s\n" if $s;
	}
	$le{'Hdr'} .= "$XMLCOUNT: ".sprintf("%05d", $id)."\n"; # 00010 
	
	### Fix Body
	$le{'Body'} =  $e{'Body'};
	$le{'Body'} =~ s/^[\n\s]*//;
	$le{'Body'} =~ s/^[\s\#]*$proc\s+$_\s*\n//;

	### Write
	&Write3(*le, "$arc_dir/$id");
	&Log("Library: ARTICLE $id [saved in $arc_dir/$id]");
	&Mesg(*e, "The article is saved as $id in the archive");

	return 'LAST'; # 95/12/25 tanigawa@tribo.mech.nitech.ac.jp;
    }
    elsif (/^index$|^summary$/i) {
	local($org)     = $SUMMARY_FILE;
	$SUMMARY_FILE   = $summary;
	$e{'r:Subject'} = "Library Index";

	&ProcSummary($proc, *fld, *e, *misc);

	$SUMMARY_FILE   = $org;
	undef $e{'r:Subject'};
    }
}


sub LibrarySendingEntry
{
    local(*e) = @_;

    @ARCHIVE_DIR  = ($LibraryArchiveDir);
    $SPOOL_DIR    = $LibraryArchiveDir;
    $FP_SPOOL_DIR = "$DIR/$LibraryArchiveDir";
    %mget_list    = %LibraryMGetList;

    if (%mget_list) {
	&MgetCompileEntry(*e);
	
	if ($debug) {
	    while (($k, $v) = each %mget_list)   { &Debug("LSE::ml:$k => $v");}
	    while (($k, $v) = each %SendingEntry){ &Debug("LSE::SE:$k => $v");}
	}

	&mget3_SendingEntry;
    }
}


sub LibraryWriteSummary
{
    local(*e, $seq, $summary) = @_;
    local($id);

    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    open(IDINC, $seq) || (&Log($!), return);
    $id = <IDINC>;		# get
    $id++;			# increment, GLOBAL!
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($id, $seq) || return;

    ##### ML Preliminary Session Phase 021: $DIR/summary
    # save summary and put log
    $s = $e{'h:Subject:'};
    $s =~ s/\n(\s+)/$1/g;

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($USE_MIME && $s =~ /ISO\-/i) {
        &use('MIME');
	$s = &DecodeMimeStrings($s);
    }

    &Append2(sprintf("%s [%d:%s] %s", 
		     $Now, $id, substr($From_address, 0, 15), $s),
	     $summary) || return;

    $id;
}


# &LibraryExpireSummary($summary, $n);
sub LibraryExpireSummary
{
    local($file, $seq) = @_;
    local($backf) = "$file.bak";
    local($tmpf)  = "$file.tmp";

    open(IN,  $file)      || (&Log($!), return);
    open(BAK, "> $backf") || (&Log($!), return);
    open(NEW, "> $tmpf")  || (&Log($!), return);
    select(BAK); $| = 1; select(STDOUT);
    select(NEW); $| = 1; select(STDOUT);    

    # FORMAT: 96/04/23 15:16:00 [493:fukachan@beth.s] subject...
    while (<IN>) {
	print BAK $_;

	if (/^\d\d\/\d\d\/\d\d\s+\d\d:\d\d:\d\d\s+\[(\d+):\S+\]/) {
	    next if $1 == $seq;	# cut only $seq ARTICLE;
	}

	print NEW $_;
    }

    close(IN);
    close(BAK);
    close(NEW);

    if (! rename($tmpf, $file)) {
	&Log("fail to rename $tmpf"); 
	return $NULL;
    }
    else {
	&Log("Expiring \$file has succeeded");
    }
}

# Originlly written by kizu@ics.es.osaka-u.ac.jp
# merged by fukachan@sapporo.iij.ad.jp 1998/04/29
# sub CheckFromInFile($addr, $file)
# return 1 if "From: " in $file and $addr matched
sub GetFieldFromFile
{
    local($pat, $file) = @_;
    local($field, $contents, $s);

    open(CHECKFILE, $file) || (&Log($!), return 0);
    while(<CHECKFILE>) {
	chop;
	if (/^\s+\S/) {
	    chop;
	    $field =~ /^$pat$/i && ($s .= "\n$_");
	} else {
	    ($field, $contents) = /^([^: ]*): *(.*)/;
	    $field =~ /^$pat$/i && ($s = $contents);
	}
	last if (/^$/);
    }
    close(CHECKFILE);

    $s;
}

# Originlly written by kizu@ics.es.osaka-u.ac.jp
# merged by fukachan@sapporo.iij.ad.jp 1998/04/29
sub LibraryUnlinkP
{
    local($addr, $file) = @_;
    local($a);

    $a = &GetFieldFromFile("From", $file);
    $a = &Conv2mailbox($a);

    &AddressMatch($addr, $a);
}


1;
