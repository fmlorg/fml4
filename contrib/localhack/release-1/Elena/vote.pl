#!/usr/local/bin/jperl
eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

$voteid = q$Id$;

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

###### MAIN #####
require 'getopts.pl';
&Getopts('D:hd');
$DIR = $opt_D ? $opt_D : $ENV{'PWD'};

umask (022);
require 'vote.ph';
$debug = 1 if $opt_d;

&VoteInitConfig;

if($0 =~ 'summary.pl') { 
    $SUMMARY_MODE = 1;
    foreach (<$DIR/spool/[0-9]>, <$DIR/spool/[0-9][0-9]>, 
	     <$DIR/spool/[0-9][0-9][0-9]>) { # built-in is a special?
	&Vote(&GetBufferFromFile($_)) if(/spool\/\d+$/);
    }
    &VoteOutput;
    exit 0;
}

if(@ARGV) {
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
    local($WHOLE_MAIL);
    local($MailHeaders) = "";

    open(FD, "$JCONVERTER $FD|") || (&VoteLog("cannot open $FD"), return);
    eval "while(<FD>) {
	    if(1 .. /^\$/) {
	        \$MailHeaders .= \$_;
	    };

	    $READ_FILE_Hook;
	    \$WHOLE_MAIL .= \$_;
	}";
    print STDERR $@ if $@;
    close(FD);

    &GetFrom($MailHeaders);
    $Original_From_address = &DecodeMimeStrings($Original_From_address);

    return split(/\n/, $WHOLE_MAIL, 9999);
}

sub GetFrom
{
    # Tricky for folding and unfolding.
    local($MailHeaders) = @_;

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
	/^Sender:$/io         && ($Sender   = $contents, next);
	/^X-Mail-Count:$/io   && ($ID       = $contents, next);

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
    local($COMMAND, $GET_FIELD, $JNAMECONV, $RESET, $AsA2A);

    # generate regexp for given fields(One Line Matching)
    foreach $key (@keywords) {
	$RESET .= "\$Count{$key} = 0;\n";
	$RESET .= "undef %Var$key;\n";
	$JNAMECONV .= "\ts/^$Jname{$key}/$key/;\n" if $Jname{$key};

	$GET_FIELD .= "if((/^$key:(.*)\\(/o || /^$key:(.*)/o )";
	$GET_FIELD .= "&& \$Count{$key}++ < $maxkeywords[$i])\n\t";
	$GET_FIELD .= "{ \$Var$key{\$1} += 1;}";
	$GET_FIELD .= "\n\t";

	$AsA2A     .= "\n\t";
	$AsA2A     .= "foreach(keys %Var$key) { \$$key{\$_} += 1;}\n";
	$i++;
    }

    # Execution Command Generation
    $EXEC_COMMAND = "$RESET
    foreach (\@votebody) {
        $Hook

 	# get voting fields, initilize
 	#y/A-Z/a-z/;  # to lower case
        y/£Á-£Ú/A-Z/;
        y/£á-£ú/a-z/;
        y/£°-£¹/0-9/;
        y/¡Ê¡§/\(:/;
 	s/[¡¡\\s]//g;# Spaces
        $JNAMECONV\n\t# Jname and Name conversion
        $GET_FIELD\n
    }
    $AsA2A;\n";
    $I++;
    
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
    local($i) = 0;

    # generate evaled strings
    foreach $key (@keywords) {
	$title = $Jname{$key} ? $Jname{$key} : $key;
	$GET_FIELD .= 
	    "foreach(keys \%$key) { 
                 push(\@$key, \"\$$key{\$_} \$_\");
            }
            print \"$title\\n\\n\t\", 
                  join(\"\\n\\t\", sort {\$b <=> \$a;} \@$key), \"\\n\\n\";
            ";
    }

    print STDERR ">",$GET_FIELD . $HookOut,"<\n" if $debug;
    eval $GET_FIELD . $HookOut;
    print STDERR $@ if $@;
}

1;
