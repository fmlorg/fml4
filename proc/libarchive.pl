#!/usr/local/bin/perl
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


sub Archive
{
    local($archive_dir, $max_seq, $unit, $limit);

    $archive_dir = $ARCHIVE_DIR || $ARCHIVE_DIR[0] || "var/archive";
    $max_seq     = &GetFirstLineFromFile($SEQUENCE_FILE);
    $unit        = $ARCHIVE_UNIT || $DEFAULT_ARCHIVE_UNIT || 100;

    &use('utils');

    &Archive'Init; #';
    &Archive'Archive($archive_dir, $max_seq, $unit, $limit); #';
}


package Archive;


sub Archive'Log               { &main'Log(@_);}
sub Archive'Debug             { &main'Debug(@_);}
sub Archive'Append2           { &main'Append2(@_);}
sub Archive'MkDir             { &main'MkDir(@_);}


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
    &MkDir($archive_dir, 0700);

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
		&Debug("$TAR $files |$COMPRESS > $archive_dir/$tar.tar.gz")
		    if $debug;

		if ($INSECURE_SYSTEM) {
		    system("$TAR $files |$COMPRESS >$archive_dir/$tar.tar.gz");
		}
		else {
		    &main'system("$TAR $files | $COMPRESS", 
			    "$archive_dir/$tar.tar.gz");
		}

		&Log("Error: Archive::Archive [$@]") if $@;
		&Log("$archive_dir/$tar.tar.gz is created") unless $@;
	    }
	}
    }
}


1;
