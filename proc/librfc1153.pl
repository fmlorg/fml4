# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)
# $rcsid   = q$Id$;


sub Rfc1153ReadFileHook
{
    # Skipped field for each mail header
    local($READ_FILE_HOOK) = q#
	next if /^Return-Path:/oi;
	next if /^X-ML-Name:/oi;
	next if /^X-MLServer:/oi;
	next if /^lines:/oi;
	next if /^Reply-To:/oi;
	next if /^Errors-To:/oi;
	next if /^Precedence:/oi;
    #;

    $READ_FILE_HOOK;
}


# THIS ROUTINE CAN BE CALLED MULTIPLY.
sub Rfc1153Custom
{
    local(@filelist) = @_;
    local($i, $f, $s);
    local($issue)     = 1;
    local($listname)  = "UJA";
    local($vol)       = $year;
    local($ISSUE_SEQ) = "$DIR/issue_seq"; # file to remember count;

    &GetTime;
    require 'libMIME.pl' if $USE_LIBMIME;

    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153phGetSeq($ISSUE_SEQ);

    ##### PREAMBLE #####

    # MAIL SUBJECT 
    # example "Subject: Info-IBMPC Digest V95 #22"
    $_cf{'subject', 'msend'} = "$listname Digest V$vol #$issue";

    # FIRST LINE
    $PREAMBLE .= "$listname DIGEST\t";
    $PREAMBLE .= sprintf("%3s, %2d %3s %2d", $WDay[$wday], $mday, $Month[$mon], $year);
    $PREAMBLE .= sprintf("\tVolume %2d: Issue %d\n",$vol, $issue);

    # SECOND LINE
    $PREAMBLE .= "\n";

    # 3rd LINE and Subjects
    $PREAMBLE .= "Today's Topics:\n";
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
	    $s =~ s/\[$BRACKET:\d+\]\s*//g if $STRIP_BRACKETS; # Cut [Elena:101] form
	    $s = &DecodeMimeStrings($s) if $USE_LIBMIME;       # MIME DECODING 
	    ($s =~ /\nSubject:(.*)\n/) && ($PREAMBLE .= "\t$1\n");
	}
    }# end of foreach;

    # end of preamble
    # Separater between the main part and preamble
    $PREAMBLE .= "\n".('-' x 70)."\n\n";



    ##### TRAILER #####
    $TRAILER  .= "------------------------------\n\n";
    $TRAILER  .= ($s = "End of $listname Digest V$vol Issue \#$issue\n");
    $i = length($s) - 1;
    while($i-- > 0) { $TRAILER  .= "*";}
    $TRAILER  .= "\n";


    return ($PREAMBLE, $TRAILER);
}


sub Rfc1153phGetSeq
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


sub Rfc1153phDestructer
{
    local($listname)  = "UJA";
    local($vol)       = $year;
    local($ISSUE_SEQ) = "$DIR/issue_seq"; # file to remember count;

    # ONCE ONLY
    return if $_cf{'rfc1153', 'in-destr'};
    $_cf{'rfc1153', 'in-destr'} = 1;

    &eval($RFC1153_CUSTOM_HOOK, 'RFC1153 custom:');
    $issue = &Rfc1153phGetSeq($ISSUE_SEQ);

    open(F, "> $ISSUE_SEQ") || &Log("Cannot open $ISSUE_SEQ");
    $issue++;
    print F "$issue\n";
    close(F);
}

1;
