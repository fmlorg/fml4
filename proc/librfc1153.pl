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

# local scope -> Global for customize
# local($IssueSeq);

&use('MIME') if $USE_MIME;

# Skipped field for each mail header
# FYI:
#
# 1. This example below is <left only required fields> strategy such
# that we preserve From:, Subject:, Date:, X-Mail-Count: and Message-ID:
# and discard other header fields.
#
# 2. If you pass all fields but cut off special fields, like this
# q#;
#    if (1 .. /^$/) {
#        /^(\S+):/ && ($curhf = $1);
#        next if $curhf =~ /^X-ML-Info/i;
#        next if $curhf =~ /^X-Faces/i;
#        next if $curhf =~ /^X-Anime/i;
#        next if $curhf =~ /^X-Spam/i;
#    }
# #;
#
# where $curhf trick is needed for unfolded cases. For example,
# From: Hayakawa aoi
#      <aoi@chan.panic>
#
sub Rfc1153ReadFileHook
{
    $_ = q#;
    if (1 .. /^$/) {
	if (/^(From|Subject|Date|X-Mail-Count|Message-ID):/io) {
	    $curhf = $1;
	}
	elsif (/^\s+/ && $curhf) {
	    ;
	}
	elsif (! /^$/) {
	    undef $curhf;
	    next;
	}
    }
    #;
}


# THIS ROUTINE CAN BE CALLED MULTIPLY.
sub Rfc1153Custom
{
    local($mode, *filelist) = @_;
    local($i, $f, $s);
    local($issue, $listname, $vol);
    local($preamble, $trailer, $trick);

    ########## CUSTOMIZE BELOW ##########
    $issue     = $RFC1153_ISSUE    || 1;
    $listname  = $RFC1153_LISTNAME || "UJA";
    $vol       = $RFC1153_VOL      || $year;
    $IssueSeq  = $RFC1153_SEQUENCE_FILE  || 
	"$FP_VARLOG_DIR/IssueSeq"; # file to remember count;

    &GetTime;
    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153GetSeq($IssueSeq);

    ##### preamble #####

    # MAIL SUBJECT 
    # example "Subject: Info-IBMPC Digest V95 #22"
    $_cf{'subject', $mode} = "$listname Digest V$vol \#$issue";

    print STDERR "\$_cf{'subject', $mode} = $_cf{'subject', $mode}\n"
	if $debug;

    # FIRST LINE
    $preamble .= "$listname DIGEST\t";
    $preamble .= 
	sprintf("%3s, %2d %3s %2d", $WDay[$wday], $mday, $Month[$mon], $year);
    $preamble .= sprintf("\tVolume %2d: Issue %d\n",$vol, $issue);

    # SECOND LINE
    $preamble .= "\n";

    # 3rd LINE and Subjects
    $preamble .= "Today's Topics:\n";

    ########## CUSTOMIZE ENDS ##########

    # Make Subjects;
    foreach $f (@filelist) {
	stat($f);
	undef $s;
	if(-T _) {
	    open(F, $f) || next;
	    while(<F>) {
		if(1 .. /^$/) { $s .= $_;}
		last if /^$/o;
	    }
	    close(F);

	    # PLEASE CUSTOMIZE!
	    $s =~ s/\n(\s+)/$1/g;
	    $s =~ s/\[$BRACKET:\d+\]\s*//g if $STRIP_BRACKETS; # Cut [Elena:..]
	    $s = &DecodeMimeStrings($s) if $USE_MIME;       # MIME DECODING 
	    ($s =~ /\nSubject:(.*)\n/) && ($preamble .= "\t$1\n");
	}
    }# end of foreach;

    # end of preamble
    # Separater between the main part and preamble
    $preamble .= "\n".('-' x 70)."\n\n";
    
    $trick .= "Date: $MailDate\n";
    $trick .= "From: $MAINTAINER\n";	
    $trick .= q#
	This is a RFC1153 digest format.
#;

	    $preamble .= $trick; 	    

    ########## CUSTOMIZE BELOW ##########

    ##### trailer #####
    $trailer  .= ('-' x 30)."\n\n";
    $trailer  .= ($s = "End of $listname Digest V$vol Issue \#$issue\n");
    $i = length($s) - 1;
    $trailer  .= '*' x $i;
    $trailer  .= "\n";

    ########## CUSTOMIZE ENDS ##########

    return ($preamble, $trailer);
}


sub Rfc1153GetSeq
{
    local($seqfile) = @_;
    local($issue);

    ### ISSUE COUNT UPDATE ###
    # TOUCH
    (-f $seqfile) || do {
	open(F, ">> $seqfile"); close(F);
    };

    # GET SEQ
    open(F, "< $seqfile") || &Log("Cannot open $seqfile");
    $issue = <F>;
    chop $issue;
    close(F);

    # COUNT CHECK OR RESET
    ($issue >= 1) || ($issue = 1);

    # reset when happy new year;
    # fml-support:01917 (soshi@maekawa.is.uec.ac.jp)
    $PrevYear = (localtime((stat($seqfile))[9]))[5];# the last modify time
    if ($PrevYear != $year) {# not ">" when 2000 vs 1999 
	$issue = 1;		
    }

    $issue;
}


sub Rfc1153Destructer
{
    local($listname)  = "UJA";
    local($vol)       = $year;

    # ONCE ONLY
    return if $_cf{'rfc1153', 'in-destr'};
    $_cf{'rfc1153', 'in-destr'} = 1;

    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153GetSeq($IssueSeq);

    open(F, "> $IssueSeq") || &Log("Cannot open $IssueSeq");
    $issue++;
    print F "$issue\n";
    close(F);
}

1;
