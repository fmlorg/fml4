# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)
# $rcsid   = q$Id$;

&use('MIME') if $USE_LIBMIME;

# Skipped field for each mail header
sub Rfc1153ReadFileHook
{
    q#
    next if /^Return-Path:/oi;
    next if /^X-ML-Name:/oi;
    next if /^X-MLServer:/oi;
    next if /^lines:/oi;
    next if /^Reply-To:/oi;
    next if /^Errors-To:/oi;
    next if /^Precedence:/oi;
    next if /^To:/oi;
    next if /^Message-ID:/i;
    next if /^Posted:/io;
    next if /^MIME-Version:/io;
    next if /^Content-Type:/io;
    next if /^Content-Transfer-Encoding:/io;
    #;
}


# THIS ROUTINE CAN BE CALLED MULTIPLY.
sub Rfc1153Custom
{
    local($mode, @filelist) = @_;
    local($i, $f, $s);
    local($issue, $listname, $vol, $ISSUE_SEQ);
    local($PREAMBLE, $TRAILER, $TRICK);

    ########## CUSTOMIZE BELOW ##########
    $issue     = 1;
    $listname  = "UJA";
    $vol       = $year;
    $ISSUE_SEQ = "$DIR/issue_seq"; # file to remember count;

    &GetTime;
    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153GetSeq($ISSUE_SEQ);

    ##### PREAMBLE #####

    # MAIL SUBJECT 
    # example "Subject: Info-IBMPC Digest V95 #22"
    $_cf{'subject', $mode} = "$listname Digest V$vol \#$issue";

    print STDERR "\$_cf{'subject', $mode} = $_cf{'subject', $mode}\n";

    # FIRST LINE
    $PREAMBLE .= "$listname DIGEST\t";
    $PREAMBLE .= 
	sprintf("%3s, %2d %3s %2d", $WDay[$wday], $mday, $Month[$mon], $year);
    $PREAMBLE .= sprintf("\tVolume %2d: Issue %d\n",$vol, $issue);

    # SECOND LINE
    $PREAMBLE .= "\n";

    # 3rd LINE and Subjects
    $PREAMBLE .= "Today's Topics:\n";

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
	    $s = &DecodeMimeStrings($s) if $USE_LIBMIME;       # MIME DECODING 
	    ($s =~ /\nSubject:(.*)\n/) && ($PREAMBLE .= "\t$1\n");
	}
    }# end of foreach;

    # end of preamble
    # Separater between the main part and preamble
    $PREAMBLE .= "\n".('-' x 70)."\n\n";
    
    $TRICK .= "Date: $MailDate\n";
    $TRICK .= "From: $MAINTAINER\n";	
    $TRICK .= q#
	This is a RFC1153 digest format.
#;

	    $PREAMBLE .= $TRICK; 	    

    ########## CUSTOMIZE BELOW ##########

    ##### TRAILER #####
    $TRAILER  .= ('-' x 30)."\n\n";
    $TRAILER  .= ($s = "End of $listname Digest V$vol Issue \#$issue\n");
    $i = length($s) - 1;
    $TRAILER  .= '*' x $i;
    $TRAILER  .= "\n";

    ########## CUSTOMIZE ENDS ##########

    return ($PREAMBLE, $TRAILER);
}


sub Rfc1153GetSeq
{
    local($ISSUE_SEQ) = @_;

    ### ISSUE COUNT UPDATE ###
    # TOUCH
    (-f $ISSUE_SEQ) || do {
	open(F, ">> $ISSUE_SEQ");close(F);
    };

    # GET SEQ
    open(F, "< $ISSUE_SEQ") || &Log("Cannot open $ISSUE_SEQ");
    $issue = <F>;
    chop $issue;
    close(F);

    # COUNT CHECK OR RESET
    ($issue >= 1) || ($issue = 1);

    # reset when happy new year!
    $PREV_YEAR = (localtime((stat($f))[9]))[5];# the last modify time
    if($PREV_YEAR != $year) {# not ">" when 2000 vs 1999 
	$issue = 1;		
    }

    $issue;
}


sub Rfc1153Destructer
{
    local($listname)  = "UJA";
    local($vol)       = $year;
    local($ISSUE_SEQ) = "$DIR/issue_seq"; # file to remember count;

    # ONCE ONLY
    return if $_cf{'rfc1153', 'in-destr'};
    $_cf{'rfc1153', 'in-destr'} = 1;

    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153GetSeq($ISSUE_SEQ);

    open(F, "> $ISSUE_SEQ") || &Log("Cannot open $ISSUE_SEQ");
    $issue++;
    print F "$issue\n";
    close(F);
}

1;
