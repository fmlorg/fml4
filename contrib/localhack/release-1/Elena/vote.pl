#!/usr/local/bin/jperl
eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

# ;$rcsid = q"$Id$";

###### User Custumize Parameters #####

$COMMENT_STRING = 'comment';
$END_COMMENT_STRING = 'endcomment';

@keywords = ('male', 'female', 'vactor', 'vactoress', 'story');
@maxkeywords = ('10', '10', '10', '10', '10');

# files for logging
$RESULTDIR   = 'result';
$COMMENT_LOG = "$RESULTDIR/comment_log";
$LOGFILE     = 'logfile';
$debug       = 0; # global debug option

###### User Custumize Section ends #####

######  parameters ######
$max_keywords = @keywords;

###### MAIN #####
umask (022);
&cleanup if($0 =~ 'init.pl');
&total_summary if($0 =~ 'summary.pl');

###### DEBUG if this file is done with the filename. #####

if( __FILE__ eq $0 && $0 =~ 'vote.pl') {
    &init;
    while(@ARGV) {
        &vote($ARGV[0]);
        shift @ARGV;
    }

    print "======== Debug Mode ========\n" if($debug);
    for($i = 0; $i < $max_keywords; $i++ ) {
	chop $votelog[$i];
	open(FD1,"|/bin/cat");
	print FD1 $keywords[$i], ":\n";close(FD1);
	open(FD1,"|/bin/cat|/bin/sort|/bin/uniq -c|/bin/sort -nr|/bin/cat");
	print FD1 $votelog[$i], "\n" if($votelog[$i]);close(FD1);
    }
    print "Comments:\n";
    print $comment_strings, "\n";
    &info if($debug);
    exit 0;
}

###### Libraries ######

sub osakana
{
    local($FD) = @_;
    &init;
    &vote($FD);
    &info;
}

# if subroutine info is not fitted to your object, please rewrite it;
sub info
{
    local($i) = 0;
    for( $i = 0; $i < $max_keywords; $i++ ) {
	open(FILE, ">> $RESULTDIR/$keywords[$i]") || &log("cannot open $RESULTDIR/$keywords[$i]");
	print FILE $votelog[$i];
    }
    open(FILE, ">> $COMMENT_LOG") || &log("cannot open $COMMENT_LOG");
    print FILE "--------\nFrom: $From_address\n\n";
    print FILE $comment_strings, "\n";
}

# get one file, collect @keywords up to @maxkeywords. 
sub vote {
    local($FD) = @_;
    local($i, $j) = 0 x 2;
    local($in_comment) = '';
    local(@counter_keywords) = 0 x $max_keywords;

    open(FD) || &log("cannot open $FD");
    while(<FD>) {
	print STDERR ">>>", $_ if( __FILE__ eq $0 && $debug);
	/^From: *(.*) *$/ && ($From_address = $1);
	y/A-Z/a-z/ if(! $in_comment);
	s/[¡¡ \t]//g if(! $in_comment);
	print STDERR ">>>", $_ if( __FILE__ eq $0 && $debug);
	if(/^$COMMENT_STRING:(.*)/){ 
	    $in_comment = 'on';
	    $comment_strings .= $1;
	    next;
	}elsif(/$END_COMMENT_STRING/) {
	    $in_comment = '';
	    next;
	}elsif($in_comment) {
	    $comment_strings .= $_;
	    next;
	} 
	if($in_comment) {$comment_strings .= $_; next;}
	for( $i = 0; $i < $max_keywords; $i++ ) {
	    $match = "^$keywords[$i]:(.*)";
	    if(/$match/ && ($counter_keywords[$i])++ < $maxkeywords[$i]) {
		$votelog[$i] .= $1 . "\n";
	    }
	}
    }
}

sub log
{
    local($strings) = @_;
    open(FILE, ">> $LOGFILE");
    print FILE $Date, ":", $strings, "\n";
}

sub init
{

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);$wday++; $mon++;
    $Date = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
		    $mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);

    if(!-d $RESULTDIR){ mkdir("$RESULTDIR", 0755);}
}

sub cleanup
{
    unlink @keywords;
    unlink $COMMENT_LOG;
    unlink $LOGFILE;
    system "rm -fr $ENV{'PWD'}/$RESULTDIR";
    exit 0;
}

sub total_summary
{
    local($i) = 0;
    local($TMPBUFFER);
    open(TMPBUFFER,"|cat");
    for( $i = 0; $i < $max_keywords; $i++ ) {
	print TMPBUFFER "\n$keywords[$i]:\n\n";
	print TMPBUFFER `sort $RESULTDIR/$keywords[$i] | uniq -c | sort -nr`;
    }	
    close(TMPBUFFER);
}

1;
