#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$;


sub Archive
{
    local($archive_dir, $max_seq, $unit, $limit);

    $archive_dir = $ARCHIVE_DIR[0] || $ARCHIVE_DIR || "var/archive";
    $max_seq     = &GetFirstLineFromFile($SEQUENCE_FILE);
    $unit        = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
    
    &Archive'Init; #';
    &Archive'Archive($archive_dir, $max_seq, $unit, $limit); #';
}


package Archive;


sub Archive'Log               { &main'Log(@_);}
sub Archive'Debug             { &main'Debug(@_);}
sub Archive'Append2           { &main'Append2(@_);}


sub Init
{
    @Import = ("debug", 
	       ARCHIVE_DIR, DEFAULT_ARCHIVE_UNIT, SPOOL_DIR,
	       TAR, COMPRESS);

    for (@Import) { eval("\$Archive'$_ = \$main'$_;");}
}	   


sub Archive
{
    local($archive_dir, $max_seq, $unit, $limit) = @_;
    local($i) = 1;
    local($dir) = ".";

print STDERR "
    local($archive_dir, $max_seq, $unit, $limit);
";

    # Adjust following config.ph; moved here;
    # fml-support: 02590 <fujita@soum.co.jp>
    $unit  = $unit  || $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;
    $limit = $limit || ($unit * int ($max_seq / $unit )) || 1000;

    # useless when seq(103) < unit(1000)
    if ($max_seq < $unit) { 
	&Log("Do nothing when max_seq=$max_seq < unit=$unit");
	return 0;
    }

    # create archive dir when it does not exist
    for (split(/\//, $archive_dir)) {
	next if /^\s*$/;
	$dir .= "/$_";
	-d $dir || do { 
	    &Debug("create $dir") if $debug;
	    mkdir($dir, 0700);
	}
    }


    $tar_prog  = $TAR;
    $tar_prog  =~ s/\sxf\s/ cf /;
    $gzip      = $COMPRESS;
    

    ### HERE WE GO!
    while ($i * $unit <= $limit) {
	$counter = 0;
	undef $files;

	$lower = $unit * ($i - 1) + 1;
	$upper = $unit * ($i);
	$tar  =  $unit * ($i);
	$i++;
    
	foreach ($lower .. $upper) {
	    if( -f "$SPOOL_DIR/$_") {
		$files .= "$SPOOL_DIR/$_ "; 
		$counter++;
	    }
	}

	&Debug("Checking\t$lower\t->\t$upper\t($counter hits)") if $debug;

	if ($counter > 0) {
	    if (-f "$archive_dir/$tar.tar.gz") {
		&Debug("-f $archive_dir/$tar.tar.gz && skip") if $debug;
		next;
	    }
	    else {
		&Debug("$tar_prog $files |$gzip > $archive_dir/$tar.tar.gz")
		    if $debug;

		system("$tar_prog $files |$gzip > $archive_dir/$tar.tar.gz");
		&Log("Error: Archive::Archive [$@]") if $@;
		&Log("$archive_dir/$tar.tar.gz is created") unless $@;
	    }
	}
    }
}


1;
