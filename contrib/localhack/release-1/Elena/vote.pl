#!/usr/local/bin/jperl
eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

$rcsid = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$STATUS = "vote.pl [$rcsid] ";

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

###### MAIN #####
require 'getopts.pl';
&Getopts('D:hdS:t');
$DIR = $opt_D ? $opt_D : $ENV{'PWD'};
$TODAY = 1 if $opt_t;
die("USAGE: $0 -[DhdSt] files\n") if $opt_h;

umask (022);
require 'vote.ph';
$debug = 1 if $opt_d;

&VoteInitConfig;

if($opt_S) {
    $SUMMARY_MODE = 1;
    local($a, $b) = split(/\-/, $opt_S);
    foreach ($a .. $b) {
	local($file) = "$DIR/spool/$_";
	print STDERR "$file\n";
	&Vote(&GetBufferFromFile($file)) if -f $file;
    }
    &VoteOutput;
    exit 0;
}

if($0 =~ 'summary.pl') { 
    $SUMMARY_MODE = 1;

    if($TODAY) {# today's status report
	$TODAY = sprintf("%2d/%02d/%02d", $year, $mon + 1, $mday);
	print STDERR "TODAY $TODAY\n\n";
	if(open(TMP, "$DIR/summary")) {
	    while(<TMP>) {
		if(/^$TODAY \d\d:\d\d:\d\d \[(\d+)/) {
		    push(@TODAY, "spool/$1");
		}
	    }
	    close(TMP);
	}

	foreach (@TODAY) {
	    print STDERR "TODAY $_\n";
	    &Vote(&GetBufferFromFile($_)) if(/spool\/\d+$/);
	}

    }else {
	foreach (<$DIR/spool/[0-9]>, <$DIR/spool/[0-9][0-9]>, 
		 <$DIR/spool/[0-9][0-9][0-9]>) { # built-in is a special?
	    &Vote(&GetBufferFromFile($_)) if(/spool\/\d+$/);
	}
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
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
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
    local($MailHeaders, $BUFFER, $WHOLE_MAIL);

    open(FD, "$JCONVERTER $FD|") || (&VoteLog("cannot open $FD"), return);
    eval "while(<FD>) {
	    if(1 .. /^\$/) {
	        \$MailHeaders .= \$_;
                next;
	    };

	    $READ_FILE_Hook;
	    \$WHOLE_MAIL .= \$_;
	}";
    print STDERR $@ if $@;
    close(FD);

    &GetFrom($MailHeaders);
    if($USE_LIBMIME) {
	$Original_From_address = &DecodeMimeStrings($Original_From_address);
    }

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

    $Summary{$ID} = "$ID\t$From_address"; # for summary report

    return $Original_From_address;
}

# get one buffer, collect @keyword up to %maxkeywords. 
sub Vote {
    local($i) = local($j) = 0;
    local($COMMAND, $GET_FIELD, $JNAMECONV, $RESET, $AsA2A);

    # generate regexp for given fields(One Line Matching)
    foreach $key (@keyword) {
	# Reset Sequence
	$RESET .= "\$Count{$key} = 0;\n";
	$RESET .= "undef %Var$key;\n";

	# Jname conversion sequence
	$JNAMECONV .= "s/^$Jname{$key}/$key/;\n\t" if $Jname{$key};

	# Get fields sequence, a little tricky
	$GET_FIELD .= "if(/^$key:/o) { \$Sum$key .= \$_.\"\\n\";}\n\t";
	$GET_FIELD .= "if(/^$key:/o) { print STDERR \$Sum$key.\"<\\n\";}\n\t"
	    if $debug;
#	$GET_FIELD .= "if((/^$key:(.*)\\(/o || /^$key:(.*)/o )";
	$GET_FIELD .= "if(/^$key:(.*)\\(/o) { \$NonEffective$key += 1; next;};\n\t";
	$GET_FIELD .= "if(/^$key:(.*)/o ";
	$GET_FIELD .= "&& \$Count{$key}++ < $maxkeyword{$key}) {\n\t";
	$GET_FIELD .= "\t\$Var$key{\$1} += 1;\n\t";
	$GET_FIELD .= "\t\$Effective$key += 1;";
	$GET_FIELD .= "\n\t}";
	$GET_FIELD .= "\n\n\t";

	# Asossiation Array -> just array
	$AsA2A     .= "\n\t";
	$AsA2A     .= "foreach(keys %Var$key) { \$$key{\$_} += 1;}\n";
	$i++;
    }

    # Execution Command Generation
    $EXEC_COMMAND = "$RESET
    foreach (\@_) {
        $Hook

 	# get voting fields, initilize
 	#y/A-Z/a-z/;  # to lower case
        y/£Á-£Ú/A-Z/;
        y/£á-£ú/a-z/;
        y/£°-£¹/0-9/;
        y/¡Ê¡§/\(:/;
 	s/[¡¡\\s]//g;# Spaces

        $JNAMECONV\n\t# Jname and Name conversion

        s/\\\(.\*\\\)//g;
        $GET_FIELD\n
    }

    $AsA2A;
    ";

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

    print "$STATUS Status Report\n---\n";

    if($SUMMARY_MODE) {
	print "[Summary] person list who voted\nID\tvoter\n\n";

	foreach (keys %Summary) { # summary Report
	    print $Summary{$_}, "\n";
	}

	print "\n---\n\n";
    }

    foreach $key (@keyword) {
	$title = $Jname{$key} ? $Jname{$key} : $key;
	    $GET_FIELD .= 
		"\$Effctive$key = 0;\n";

		if(!$SUMMARY_MODE) {
	    $GET_FIELD .= 
		"\tforeach(keys \%$key) {
                 \tpush(\@$key, \"\$_\");
	          \$Effctive$key += \$$key{\$_};
            \t};\n\t
           # \$Effective$key = scalar(\@$key);
               \$Effective$key = 0 unless \$Effective$key;
            ";
	}else {
	    $GET_FIELD .= 
		"\tforeach(keys \%$key) {
                 \tpush(\@$key, \"\$$key{\$_}\t\$_\");
            \t};\n\t
            ";
	}

	$GET_FIELD .= "print \"$title Í­¸úÉ¼:\t\$Effective$key\\n\";\n\t";
	$GET_FIELD .= "\$NonEffective$key = 0 unless \$NonEffective$key;\n\t";
	$GET_FIELD .= "print \"$title Ìµ¸úÉ¼:\t\$NonEffective$key\\n\";\n\t";
    }

    $GET_FIELD .= "print \"\\n\";\n\t";

    # generate evaled strings
    foreach $key (@keyword) {
	$title = $Jname{$key} ? $Jname{$key} : $key;

	$GET_FIELD .= 
	    "print \"$title\\n\\n\t\", 
                  join(\"\\n\\t\", sort {\$b <=> \$a;} \@$key), \"\\n\\n\";
            ";
    }

    if($SUMMARY_MODE) {
	$S_GET_FIELD .= "print \"---\nÅêÉ¼¥Ç¡¼¥¿°ìÍ÷\\n\\n\";\n";
	foreach $key (@keyword) {
	    $S_GET_FIELD .= "print \$Sum$key;\n";
	}
    }

    print STDERR "-----\n",$GET_FIELD . $HookOut,"\n-----\n" if $debug;
    eval $GET_FIELD . $S_GET_FIELD . $HookOut;
    print STDERR $@ if $@;

}

1;
