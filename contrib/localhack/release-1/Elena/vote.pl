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

&VoteInitConfig;

if($0 =~ 'summary.pl') { 
    foreach (<$DIR/spool/*>) { &Vote(&GetBufferFromFile($_));}
    &VoteOutput;
    exit 0;
}

if(@ARGV) {
# get vote from a file
    foreach (@ARGV) { &Vote(&GetBufferFromFile($_));}
} else {
      &Vote(<STDIN>);
}

&VoteOutput;
exit 0;
###### MAIN ENDS #####

###### Libraries ######

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

    if($USE_LIBMIME) {
	push(@INC, $LIBMIMEDIR) if $LIBMIMEDIR;
	require "libMIME.pl";
    }
}

# front end of Vote
sub GetBufferFromFile
{
    local($FD) = @_;
    local($BUFFER) = "";

    open(FD, "$JCONVERTER $FD|") || (&VoteLog("cannot open $FD"), return);
    local(@tmp) = <FD>;
    close(FD);
    &GetFrom(@tmp);
    $Original_From_address = &DecodeMimeStrings($Original_From_address);
    return @tmp;
}

sub GetFrom
{
    # Tricky for folding and unfolding.
    local($MailHeaders) = join("", @_);

    # No UNIX FROM!(a possibility)
    $MailHeaders =~ s/^(\S+):/$1:\n\n/;
    $MailHeaders =~ s/\n(\S+):/\n\n$1:\n\n/g;
    local(@MailHeaders) = split(/\n\n/, $MailHeaders, 999);

    while(@MailHeaders) {
	$_ = $field = $MailHeaders[0], shift @MailHeaders;
	print STDERR "FIELD:          >$field<\n" if($debug);
	next if(/^from\s/io); # UNIX FROM is a special case.
	$contents = $MailHeaders[0];
	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if($debug);
	shift @MailHeaders;
	next if(/^$/o);		# if null, skip. must be mistakes.

	# filelds to use later.
	/^Reply-to:$/io       && ($Reply_to = $contents, next);
	/^Sender:$/io         && ($Sender = $contents, next);

	if(/^From:$/io) {
	    # Original_From_address is preserved.
	    $_ = $Original_From_address = $contents;
	    s/\n(\s+)/$1/g;
	    if(/^\s*.*\s*<(\S+)>.*$/io) {$From_address = $1; next;}
	    if(/^\s*(\S+)\s*.*$/io)     {$From_address = $1; next;}
	    $From_address = $_; next;
	}
	
    }	# end of while loop

    return $Original_From_address;
}

# get one buffer, collect @keywords up to @maxkeywords. 
sub Vote {
    local(@votebody) = @_;
    local($i) = local($j) = 0;
    local($in_comment) = '';
    local(@counter_keywords);
    local($COMMAND, $GET_FIELD, $JNAMECONV, $RESET);

    # generate regexp for given fields(One Line Matching)
    foreach $key (@keywords) {
	$RESET .= "\$Count$key = 0;\n";
	$GET_FIELD .= "if(/^$key:(.*)/o && (\$Count$key++ < $maxkeywords[$i]))
                       \t{ push(\@KEY$key, \$1);}\n\t" unless $SUMMARY_MODE;
	$GET_FIELD .= "if(/^$key:(.*)/o) { push(\@KEY$key, \$1);}\n\t"
	    if $SUMMARY_MODE;
	$JNAMECONV .= "\ts/^$Jkeywords[$i]/$key/;\n" if $Jkeywords[$i];
	$i++;
    }

    # Execution Command Generation
    $EXEC_COMMAND = "$RESET;\n
    foreach (\@votebody) {
	# for comment
        $Hook

 	# get voting fields, initilize
 	y/A-Z/a-z/;  # to lower case
 	s/[¡¡\\s]//g;# Spaces
        $JNAMECONV\n\t# Jname and Name conversion
        $GET_FIELD\n}\n";

    print STDERR $EXEC_COMMAND if $debug;
    eval $EXEC_COMMAND;
    print STDERR $@ if $@;
}

sub VoteCleanup
{
    unlink $LOGFILE;
    exit 0;
}

sub VoteOutput {
    # Return mail
    local($return) = "$DIR/return_body_$$";
    local($i) = 0;

    # 
    unlink $return if -f $return;

    # generate evaled strings
    foreach $key (@keywords) {
	$GET_FIELD .= "open(POUT, \"|cat \");\n";
	$GET_FIELD .= "print POUT \"$Jkeywords[$i]\\n\";" if $Jkeywords[$i];
	$GET_FIELD .= "print POUT \"$key\\n\";"       unless $Jkeywords[$i];
	$GET_FIELD .= "close POUT;\n";
	$i++;
	$GET_FIELD .= "open(OUT, \"|sort |uniq -c |sort -nr\");";
	$GET_FIELD .= "print OUT join(\"\\n\", \@KEY$key), \"\\n\";\n";
	$GET_FIELD .= "print STDOUT join(\"\\n\", \@KEY$key);\n" if $debug;
	$GET_FIELD .= "close OUT;\n";
    }

    print STDERR ">",$GET_FIELD . $HookOut,"<\n" if $debug;
    eval $GET_FIELD . $HookOut;
    print STDERR $@ if $@;

    # remove the return mail
    unlink $return;
}

1;
