#!/usr/local/bin/jperl
eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

$voteid = q$Id$;

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

###### MAIN #####
umask (022);
require 'vote.ph';

# define the number of keywords to saerch
$max_keywords = @keywords;

&VoteCleanup if($0 =~ 'init.pl');
&VoteSummary if($0 =~ 'summary.pl');

###### MAIN ENDS #####

if( __FILE__ eq $0 && $0 =~ 'vote.pl') {
    &VoteInitConfig;

    # use STDIN
    @ARGV || (@BODY  = <STDIN>);
    if(@BODY) {
	print STDERR "BODY>\n@BODY<BODY ENDS\n" if($debug);
	&Vote(@BODY);
    }

    # get vote from a file
    foreach (@ARGV) { &Vote(&GetBufferFromFile($_));}

    $return = "$DIR/return_body_$$";
    unlink $return if -f $return;

    foreach $key (@keywords) {
	$GET_FIELD .= "open(POUT, \"|cat \");\n";
	$GET_FIELD .= "print POUT \"$key\\n\";";
	$GET_FIELD .= "close POUT;\n";
	$GET_FIELD .= "open(OUT, \"|sort |uniq -c |sort -nr\");";
	$GET_FIELD .= "print OUT join(\"\\n\", \@KEY$key), \"\\n\";\n";
	$GET_FIELD .= "print STDOUT join(\"\\n\", \@KEY$key);\n" if $debug;
	$GET_FIELD .= "close OUT;\n";
    }

    print STDERR $GET_FIELD if $debug;

    eval $GET_FIELD;
    print STDERR $@ if $@;

    unlink $return;

    # Show Comments Summary's
    print "\nComments Summary:\n$comment_strings\n";
    exit 0;
}

###### Libraries ######

sub Osakana
{
    local($FD) = @_;
    &VoteInitConfig;
    &Vote(&GetBufferFromFile($FD));
    &VoteStoreInfo;
}

# if subroutine info is not fitted to your object, please rewrite it;
sub VoteStoreInfo
{
    local($i) = 0;
    for( $i = 0; $i < $max_keywords; $i++ ) {
	open(FILE, ">> $RESULTDIR/$keywords[$i]") || 
	    &VoteLog("cannot open $RESULTDIR/$keywords[$i]");
	print FILE $votelog[$i];
	close(FILE);
    }
    open(FILE, ">> $COMMENT_LOG") || &VoteLog("cannot open $COMMENT_LOG");
    print FILE $comment_strings, "\n";
    close(FILE);
}


# front end of Vote
sub GetBufferFromFile
{
    local($FD) = @_;
    local($BUFFER) = "";
    open(FD) || (&VoteLog("cannot open $FD"), return);
    $BUFFER = join("", <FD>);
    close(FD);
    return $BUFFER;
}


# get one file, collect @keywords up to @maxkeywords. 
sub Vote {
    local(@votebody) = @_;
    local($i) = local($j) = 0;
    local($in_comment) = '';
    local(@counter_keywords);
    local($COMMAND);

    # generate regexp for given fields
    foreach $key (@keywords) {
	$GET_FIELD .= "if(/^$key:(.*)/o) { push(\@KEY$key, \$1);}\n";
    }

    $EXEC_COMMAND = "foreach (\@votebody) {
	# for comment
	if(/^$COMMENT_STRING/o)     { \$in_comment = 'on'; next;}
	if(/^$END_COMMENT_STRING/o) { \$in_comment =   ''; next;}

	if(\$in_comment) {
	    \$comment_strings .= \$_ . \"\"; 
	    next;
	}

 	# Email address for comment log
 	if(/^From:\\s\*\(\\S\+\)\\s\*\.\*\$/) {
 	    \$From_address = \$1;
 	    \$comment_strings .= \"\\nFrom\: \$From\_address\\n\\n\";
         }

 	# get voting fields, initilize
 	y/A-Z/a-z/;
 	s/[¡¡\\s]//g;
        s/^ºÇ¶á/new/g;
 
        $GET_FIELD;
        }\n";

    eval $EXEC_COMMAND;
    print STDERR $@ if $@;
}

sub VoteLog
{
    local($strings) = @_;
    open(FILE, ">> $LOGFILE");
    print FILE $Date, ":", $strings, "\n";
    close(FILE);
}

sub VoteInitConfig
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Date = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
		    $mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);

    if(!-d "$RESULTDIR"){ mkdir("$RESULTDIR", 0755);}
}

sub VoteCleanup
{
    unlink @keywords;
    unlink $COMMENT_LOG;
    unlink $LOGFILE;
    system "rm -fr $RESULTDIR";
    exit 0;
}

sub VoteSummary
{
    local($i) = 0;

    open(OUTBUF,"|cat");
    for( $i = 0; $i < $max_keywords; $i++ ) {
	print OUTBUF "\n$keywords[$i]:\n\n";
	open(GETOUTBUF, "sort $RESULTDIR/$keywords[$i] |uniq -c |sort -nr |");
	while(<GETOUTBUF>) {print OUTBUF $_;}
	close(GETOUTBUF);
    }	
    close(OUTBUF);
}

1;
