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

    open(FD, "$JCONVERTER $FD|") || (&VoteLog("cannot open $FD"), return);
    eval "while(<FD>) {
	    $READ_FILE_Hook
		\$WHOLE_MAIL .= \$_;
	}";
    print STDERR $@ if $@;
    close(FD);
    
    &GetFrom($WHOLE_MAIL);
    $Original_From_address = &DecodeMimeStrings($Original_From_address);
    return split(/\n/, $WHOLE_MAIL, 9999);
}

sub GetFrom
{
    # Tricky for folding and unfolding.
    local($WHOLE_MAIL) = @_;
    local($MailBodyIndex) = index($WHOLE_MAIL, "\n\n");
    $StoredMailHeaders = $MailHeaders = 
	substr($WHOLE_MAIL, 0, $MailBodyIndex);
    
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
	$RESET .= "undef %Var;\n";
	$JNAMECONV .= "\ts/^$Jkeywords[$i]/$key/;\n" if $Jkeywords[$i];

	$GET_FIELD .= "if((/^$key:(.*)\\(/o || /^$key:(.*)/o )";
#	$GET_FIELD .= "&& \$Count{$key}++ < $maxkeywords[$i])\n";
#	$GET_FIELD .= "\t{ \$KEY{$key} .=  \"\$1\\n\";}\n\t";

	$GET_FIELD .= "&& \$Count{$key}++ < $maxkeywords[$i])\n\t";
	$GET_FIELD .= "{ \$Var{\$1} += 1;}";
	$GET_FIELD .= "\n\t";

	$AsA2A     .= "\n\t";
	$AsA2A     .= "foreach(keys %Var) { \$KEY{$key} .= \"\$_\\n\";}";
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
	$GET_FIELD .= "open(POUT, \"|cat \");\n";
	if( $Jkeywords[$i] ) {
	    $GET_FIELD .= 
		sprintf("printf POUT \"\\n%-20s \";", $Jkeywords[$i]); 
	}else {
	    $GET_FIELD .= "print POUT \"\\n$key:\\t\";";
	}
	$GET_FIELD .= "print POUT \"\\n\";" if( $maxkeywords[$i] > 1);
	$GET_FIELD .= "print POUT \"\\n\";" if $SUMMARY_MODE;
	$GET_FIELD .= "close POUT;\n";

	if($SUMMARY_MODE) {
	    $GET_FIELD .= "open(OUT, \"|sort |uniq -c |sort -nr\");";
	    $GET_FIELD .= "print STDERR \">>>\",\$KEY{$key},\"<<<\\n\";\n";
	} else {
	    $GET_FIELD .= "open(OUT, \"|cat\");";
	}
	if( $maxkeywords[$i] > 1) {
	    $GET_FIELD .= "\$KEY{$key} =~ s/\\n/\\n                     /g;\n";
	    $GET_FIELD .= 
		"\$KEY{$key} = \"                     \" . \$KEY{$key};\n";
	}

	$GET_FIELD .= "print OUT \$KEY{$key};\n";
	$GET_FIELD .= "close OUT;\n";

	$i++;
    }

    print STDERR ">",$GET_FIELD . $HookOut,"<\n" if $debug;
    eval $GET_FIELD . $HookOut;
    print STDERR $@ if $@;
}

1;
