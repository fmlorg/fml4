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
	@votebody = split(/\n/, join(/\n/,@BODY));
	print STDERR "BODY>\n@votebody<BODY ENDS\n" if($debug);
	&Vote(@votebody);
    }

    # get vote from a file
    while(@ARGV) {
	&Vote(&VoteInitialize($ARGV[0]));
        shift @ARGV;
    }

    # debug mode show infomataion
    print STDERR "======== Debug Mode ========\n" if($debug);
    for($i = 0; $i < $max_keywords; $i++ ) {
	open(OUTBUF,"|cat");
	print OUTBUF $keywords[$i], ":\n";
	close(OUTBUF);	
	open(OUTBUF,"|sort |uniq -c |sort -nr ");
	print OUTBUF $votelog[$i] if($votelog[$i]);
	close(OUTBUF);
    }

    print "Comments:\n", $comment_strings, "\n";
    &VoteStoreInfo  if($debug);
    exit 0;
}

###### Libraries ######

sub Osakana
{
    local($FD) = @_;
    &VoteInitConfig;
    &Vote(&VoteInitialize($FD));
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
sub VoteInitialize
{
    local($FD) = @_;
    local(@votebody) = '';
    open(FD) || (&VoteLog("cannot open $FD"), return);
    while(<FD>) {
	chop;
	push(@votebody, $_);
    }
    close(FD);
    return @votebody;
}


# get one file, collect @keywords up to @maxkeywords. 
sub Vote {
    local(@votebody) = @_;
    local($i, $j) = 0 x 2;
    local($in_comment) = '';
    local(@counter_keywords) = 0 x $max_keywords;
    local($COMMAND);

    # generate regexp for given fields
    for( $i = 0; $i < $max_keywords; $i++ ) {
	$GET_FIELD .= "if\(\/\^$keywords[$i]\:\(\.\*\)\/o\)\{\n";
	$GET_FIELD .= "if\(\(\$counter_keywords\[$i]\)++  \< $maxkeywords[$i]\)\{\n";
	$GET_FIELD .= "\$votelog\[$i\] .= \$1 . \"\\n\";\n";
	$GET_FIELD .= "\}\}\n";
    }

$EXEC_COMMAND =
    "while\(\@votebody\) \{
	\$\_ = \$votebody[0], shift \@votebody;
	print STDERR \"IN\-\> \$\_\\n\" 
              if\( \_\_FILE\_\_ eq \$0 \&\& \$debug\);

	# for comment
	if\(\/\^$COMMENT_STRING\/o\)   \{ \$in_comment \= \'on\'; next;\}
	if\(\/$END_COMMENT_STRING\/o\) \{ \$in_comment \=   \'\'; next;\}

	if\(\$in_comment\) \{
	    \$comment_strings \.\= \$\_ .\"\\n\"; 
	    next;
	\}

 	# Email address for comment log
 	if\(\/\^From\:\\s\*\(\\S\+\)\\s\*\.\*\$\/\)\{
 	    \$From_address = \$1;
 	    \$comment_strings \.\= \"\\nFrom\: \$From\_address\\n\\n\";
         \}

 	# get voting fields, initilize
 	y\/A\-Z\/a\-z\/;
 	s\/\[¡¡ \\t\]\/\/g;
 	print STDERR \"MODIFIED\-\> \$\_\\n\" 
            if\( \_\_FILE\_\_ eq \$0 \&\& \$debug\);
 
        $GET_FIELD;
\}\n";

    eval $EXEC_COMMAND;

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
