# Library of fml.pl 
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# Library access code
# IN THE PRESENT TIME,  Codes to access plain files
# return NONE.
#
sub ProcLibrary4PlainArticle
{
    local($proc, *Fld, *e, *misc) = @_;
    local($lib_dir, $arc_dir);
    local($dummy0, $dummy1, $_, @p) = @Fld;
    @Fld = ($dummy0, $_, @p);	# convert library -> mget call;

    ### variables
    $lib_dir = $LIBRARY_DIR || 'library';
    $arc_dir = "$lib_dir/".($LIBRARY_ARCHIVE_DIR || 'archive');
    $seq     = $SEQUENCE_FILE;
    $seq     =~ s/$DIR/$lib_dir/g;
    $summary = $SUMMARY_FILE;
    $summary =~ s/$DIR/$lib_dir/g;

    for ($lib_dir, $arc_dir) { -d $_ || mkdir($_, 0700);}
    for ($seq, $summary)     { -f $_ || &Touch($_);}

    ### "# library (get|put) @p"
    if (/^get$/i) {
	&Log("$proc $_");
	local($dir)  = $SPOOL_DIR;
	local(%list) = %mget_list;
	unshift(@ARCHIVE_DIR, $arc_dir);
	$SPOOL_DIR  = $arc_dir;	# tricky though

	$e{'r:Subject'} = "Library get [@p] $ML_FN";
	&ProcMgetMakeList($proc, *Fld, *e, *misc);
	&MgetCompileEntry(*e);
	&LogWEnv("Submit Entry -> [mget @p]", *e);
	undef $e{'r:Subject'};

	if ($FML_EXIT_HOOK !~ /mget3_SendingEntry/) {
	    $FML_EXIT_HOOK .= '&mget3_SendingEntry;';
	}

	$SPOOL_DIR  = $dir;
	%mget_list  = %list;
    }
    elsif (/^put$/i) {
	$ID = &LibraryWriteSummary(*e, $seq, $summary) || (return 0);
	&Log("$proc $_");

	&use('MIME') if $USE_LIBMIME;

	### Header
	for ('Date', 'From', 'Subject', 'Sender', 'To') {
	    if ($s = $e{"h:$_:"}) {
		$s = &DecodeMimeStrings($s) if $USE_LIBMIME && ($s =~ /ISO/);
	    }
	    $e{'Hdr'} .= "$_: $s\n" if $s;
	}
	$e{'Hdr'} .= "$XMLCOUNT: ".sprintf("%05d", $ID)."\n"; # 00010 
	
	### Fix Body
	$e{'Body'} =~ s/^[\n\s]*//;
	$e{'Body'} =~ s/^\s*\#\s*$proc\s+$_\s*\n//;

	### Write
	&Write3(*e, "$arc_dir/$ID");
    }
    elsif (/^index$|^summary$/i) {
	local($org)     = $SUMMARY_FILE;
	$SUMMARY_FILE   = $summary;
	$e{'r:Subject'} = "Library Index";

	&ProcSummary($proc, *Fld, *e, *misc);

	$SUMMARY_FILE   = $org;
	undef $e{'r:Subject'};
    }
}


sub LibraryWriteSummary
{
    local(*e, $seq, $summary) = @_;
    local($ID);

    ##### ML Preliminary Session Phase 01: set and save ID
    # Get the present ID
    open(IDINC, $seq) || (&Log($!), return);
    $ID = <IDINC>;		# get
    $ID++;			# increment, GLOBAL!
    close(IDINC);		# more safely

    # ID = ID + 1 (ID is a Count of ML article)
    &Write2($ID, $seq) || return;

    ##### ML Preliminary Session Phase 021: $DIR/summary
    # save summary and put log
    $s = $e{'h:Subject:'};
    $s =~ s/\n(\s+)/$1/g;

    # MIME decoding. 
    # If other fields are required to decode, add them here.
    # c.f. RFC1522	2. Syntax of encoded-words
    if ($USE_LIBMIME && $e{'MIME'}) {
        &use('MIME');
	$s = &DecodeMimeStrings($s);
    }

    &Append2(sprintf("%s [%d:%s] %s", 
		     $Now, $ID, substr($From_address, 0, 15), $s),
	     $summary) || return;

    $ID;
}

1;
