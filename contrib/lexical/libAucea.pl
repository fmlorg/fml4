# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");

package Aucea; 

sub Init
{
    %LexRegexpType = ("^field-if\$", 'LEX_FIELD_IF',
		      "^switch\$",   'LEX_SWITCH',
		      "^\&",         'LEX_FUNCTION',
		      "^\$",         'LEX_VARIABLE',
		      '^\{',         'LEX_LEFT_BRACE',
		      '^\}',         'LEX_RIGHT_BRACE',
		      '^else$',      'LEX_ELSE',
		      '^and$',       'LEX_AND',
		      '^\s*$',       'LEX_NULL',
		      '^\#',         'LEX_COMMENT',
		      ';\s*$',       'LEX_END_STATEMENT',
		      );

    $WarnString = $ErrorString = $TraceString = '';
}

# analize $Buf{$_} following $CF{${_}, "proc"};
# &Aucea'Aucea(*Envelope, *Buf, *CF, *result);#';
sub Aucea
{
    local(*e, *Buf, *CF, *result) = @_;
    local($type, $entry);

    &Init;

    # system call initialize;
    eval "&Syscall'Init;"; #';

    # config of the current Aucea process mode;
    # directly stored in $Aucea'AuceaConfig in libAuceaCF.pl; #';
    {
	print "\$AuceaConfig\n$AuceaConfig\n---\n" if $debug;
	eval $AuceaConfig;
	&Error("Aucea Config Error:$@") if $@;
    }

    # set %Field;
    &PrintSep('=') if $debug;

    # already %Buf set for each DataType(if required DataType#\d);
    # set %Field;
    &AllocAllFields(*Buf, *CF, *result, *Field);

    &PrintSep('1=') if $debug;
    &CheckUnknownField(*CF, *Field);
    &PrintSep('2=') if $debug;

    ########### MAIN ###########
    # @CF == $type list 
    # 
    for $entry (@CF) {
	&Trace("\n\n*** Checking [$entry] ...\n");
	print "\n\n*** Checking [$entry] ...\n" if $debug;

	# fix type;
	$type = $entry;
	if ($entry =~ /^(\S+)\#\d+/) { $type = $1;}

	# analize the datatype following given rules for each type
	&Analize($type, $entry, *proc, *Buf, *CF, *result, *Field);
    }

    # setting Trace buffers;
    $result{'Warn'}   = $Warn;
    $result{'Error'}  = $Error;
    $result{'Trace'}  = $Trace;
}

sub CheckUnknownField
{
    local(*CF, *Field) = @_;
    local($type, $entry);
    local(%copy) = %Field;

    for $entry (@CF) {
	$type = $entry;
	if ($entry =~ /^(\S+)\#\d+/) { $type = $1;}

	for (split(/\n/, $CF{$type, "proc"}."\n\n")) {
	    next if /^\s*$/;
	    next if /^\#/;

	    if (/field\-if\s+\"(.+)\"/) {
		undef $copy{"$entry:$1"};
	    }
	}

	# dummy entry;
	undef $copy{"$entry:#"};
    }

    # if %copy has anything, it is not defined entry;
    for (keys %copy) {
	&ErrLog('not-defined',$_) if $copy{$_};
    }

}

# Lexical Analizer;
# analize the datatype following given rules for each type
# and apply rules;
#
# SWITCH FOLLWING ASSIGNED STATEMENTS;
#
# DO IF STATEMENTS if () { ;}
# SO @words can be shifted in $fp();
# 
# HERE "$_ = shift @rules";
#
sub Analize
{
    local($type, $entry, *proc, *Buf, *CF, *result, *Field) = @_;
    local($rules, @rules, $args, @args, %args);

    # alloc rules for the given "type"
    # @rules are used within routines

    @rules = split(/\n/, $CF{$type, "proc"}."\n\#\n");

    for ($_ = $rules = shift @rules; @rules; ) {
	print "===Analize:main ($rules)\n" if $debug;
	&LexicalDo($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field);
    }
}


#
# %args is passed 
#
sub LexicalDo
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local($status, @words, $s, $fp);

    ######################################################################
    ### Get Token, the next "rules";
    $rules = $_ = shift @rules;

    ### @words in a rule
    @words = split(/\s+/, $rules);
    $s     = shift @words;

    ### CHECK LEX TYPE 
    for $pat (keys %LexRegexpType) {
	if ($s =~ /$pat/) { 
	    $fp = $LexRegexpType{$pat}; 
	    # print "Lex($StackLevel) <$pat> -> <$fp> ($rules)\n";
	    last;
	}
    }

    if (! $fp) {
	&Error("Lexical Error: [$s] is unknown assigend words.");
	&Trace("Lexical Error: [$s] is unknown assigend words.");
	&Trace("Error {\n$rules\n$rules[0]\n$rules[1]\n");
	return ;
    }

    ######################################################################
    ### NOW LEXICAL ANALIZED ALREADY HERE; 
    ### DO CHECK NO-ACTION BIFURCATION-Precicate?
    ###

    # status monitor;
    if ($CurStatus eq 'unmatch' && $fp eq 'LEX_ELSE') {
	print "__changed unmatch -> match \n" if $debug;
	$CurStatus = 'match'; 
    }
    if ($CurStatus eq 'match' && $fp eq 'LEX_ELSE') {
	print "__changed match -> unmatch \n" if $debug;
	$CurStatus = 'unmatch'; 
    }

    # skip if not /^\s*$/
    if ($CurStatus eq 'skip' || $CurStatus eq 'unmatch') {
	# &UndefLogString;

	printf "__skip    <stat=%-8s> { <%s> }\n", $CurStatus, $_ if $debug_a;

	# skip ends if /^$/;
	if ($rules =~ /^\s*$/) { 
	    undef $CurStatus;
	    printf "__reset    <stat=%-8s> { <%s> }\n", $CurStatus, $_  if $debug_a;;
	}
	# skip 
	else {
	    #printf "__return  <stat=%-8s> { <%s> }\n", $CurStatus, $rules;
	    return;
	}
    }

    # skip
    if ($rules =~ /^\#|^\s*$/) {
	%args = ();
	&SyncLogString;
	print "__reset %args\n" if $debug_a;
	return 0;
    }

    # #if () { } else { } form support?
    #  if ($CurStatus eq 'skip' || $CurStatus eq 'unmatch') { return;}

    ######################################################################
    ### DO Parser ###
    # 
    # &$fp(); -> &LEX_FIELD_IF();
    #            &LEX_* (); FORM;
    # 
    if ($fp) {
	print "\n" if $StackLevel == 0 && $debug;
	&$fp($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field);
    }
    else {
	&Warn("STATEMENT TO SKIP\t[$_]");
    }

    ### %args; ###
    if ($debug) {
	while (($k,$v) = each %args) {print "$type::$fp:args{$k}\t=>\t$v\n";}
    }

    ### Recursive Calls of snalizer;
    # GLOBAL $StackLevel;
    if ($StackLevel > 100) { &Error("TOO MANY STACK");}

    $StackLevel++;
    &LexicalDo($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field);
    $StackLevel--;
}


################## LEX TOP LEVEL FUNCTIONS ##################
# LEX 
#   "FIELD-IF" statemenets TOP LEVEL ROUTINE;
#    @rules can be shifted ...
#
sub LEX_FIELD_IF
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local(@words, $s);

    @words = split(/\s+/, $rules);
    $s     = shift @words;

    &PrintStack("IF<$StackLevel, stat=$CurStatus> (@words)") if $debug;

    # 
    # Parse_  analize the "field-if" line
    # Do_    if syntax OK, DO "field-if" statement;
    # 
    if (&Parse_Field_If(*rules, *words, *args)) {
	if ($debug) {
	    for (sort keys %args) { print "\t*** $_\t$args{$_}\n";}
	    print "\t*** opts\t@args \n";
	}

	&Do_Field_If($type, $entry, *rules, *args, *Buf, *Field, *result);
    }
    # 
    # SYNTAX ERROR
    # 
    else {
	&Warn("field-if: syntax error [$rules]");
	return 0;
    }

    # result code checked;
    # current status;
    if ($CurStatus eq 'unmatch') { 
	return 0;
    }
    else {
	$CurStatus = 'match';
	return 1;
    }
}

sub LEX_CASE
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local(@words, $s, $field, $data);

    $field = $args{'switch:field'};
    $data  = $Field{"$entry:$field"};

    @words = split(/\s+/, $rules);
    $s     = shift @words;

    &PrintStack("CASE<$StackLevel, stat=$CurStatus> (@words)") if $debug;

    # Get KEY (IF KEY MATCH PAT);
    undef $args{'key'};
    for ($_ = shift @words; @words; $_ = shift @words) {
	last if $_ eq ':';
	$pat .= $pat ? " $_" : $_;
    }

    $pat =~ s/"(.*)"/$1/; 

    if (! $args{'key'}) {
	&Error("case: syntax error: no keyword");
	return 0; 
    }
    
    # program type-predicate 
    # pattern check;
    if ($pat !~ /^prog:/) {
	if ($pat !~ m/^\^/) { $pat = "^$pat";}
	if ($pat !~ m/\$$/) { $pat = "$pat\$";}
    }

    # data check;
    if ($data =~ m/$case_pat/) {
	$args{'pat'} = $1;
    }
    elsif (/^&(\S+)/) {
	$args{'pat'} = "prog:$1";
    }
    else {
	&Error("field-if syntax error: illegal matching pettern($_)");
	return 0;
    }

    # opt
    $args{'opt'} = " ".join(" ", @words);

    

    
}

sub LEX_LEFT_BRACE
{
    $LeftBrace++;
}

sub LEX_RIGHT_BRACE
{ 
    $LeftBrace--;
}

sub LEX_SWITCH
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local(@words, $s, @resbuf);

    @words = split(/\s+/, $rules);
    $s     = shift @words;

    $args{'switch:field'} = $s;

    &PrintStack("SWITCH<$StackLevel> (@words)") if $debug;

    if ($LexRegexpType{$rules[0]} eq LEX_LEFT_BRACE) {

	$SwitchLevel++;
    }
    else {
	&Error("switch syntax error");
    }
}

sub GabbleBraces
{
    local(*rules, *resbuf) = @_;

    for ($_ = shift @rules; @rules; ) {
	next if $LexRegexpType{$rules[0]} eq LEX_LEFT_BRACE;
	last if $LexRegexpType{$rules[0]} eq LEX_RIGHT_BRACE;
	push(@buffer, $_);
    }    

}


###### FUNCTIONS #####
sub LEX_FUNCTION
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local($fp, $s);
    local($argv);

    # cut the last ";";
    $rules =~ s/;\s*$//;

    @words = split(/\s+/, $rules);
    &PrintStack("FUNCTION<$StackLevel> (@words)") if $debug;

    # possible function pointer form;
    # $fp = &uja("ujauja")
    if ($rules =~ /\(/) {
	$rules =~ s/(\S+)\s*\((.*)\)/$fp = $1, $args{'argv'} = $2/e;
    }
    # $fp = &uja
    else {
	$fp =  $words[0];
    }

    &Trace("\n---Call $fp() { $args{'argv'};}\n");

    # MAPPING TABLE: 
    # Error -> Err();
    # 
    if (%FUNCTION_ALIASES) {
	local($fpp, $repl);
	for $fpp (keys %FUNCTION_ALIASES) {
	    $fp =~ s/$fpp/$FUNCTION_ALIASES{$fpp}/;
	}
    }

    # calling function pionter;
    $fp =~ s/^&(\S+)/Syscall'$1/;#';
    $s = q#&$fp($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field);#;

    eval $s;
    &Error("Error Statemnet[$fp()]\n$@") if $@;
}


###### VARIABLES #####
sub LEX_VARIABLE
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;

    &PrintStack("VARIABLE<$StackLevel> ($rules)") if $debug;
}


sub LEX_ELSE 
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;

    &PrintStack("LEX<$StackLevel> ($rules)") if $debug;
    ;
}


sub LEX_END_STATEMENT { ;}


sub LEX_AND
{
    local($type, $entry, *proc, *args, *Buf, *CF, *rules, *result, *Field) = @_;

    &PrintStack("AND<$StackLevel> ($rules)") if $debug;
    ;
}


sub PrintStack
{
    print "\n";
    print '  ' x ($StackLevel + 1);
    print "--@_\n"
}

########################################################################

### LEX SUB FUNCTIONS

# 
# Smentic analize 
# set key, pat, match
#
sub Parse_Field_If
{
    local(*rules, *words, *args) = @_;

    # Get KEY (IF KEY MATCH PAT);
    undef $args{'key'};
    for ($_ = shift @words; @words; $_ = shift @words) {
	last if $_ eq 'match';
	$args{'key'} .= $args{'key'} ? " $_" : $_;
    }
    $args{'key'} =~ s/"(.*)"/$1/; 

    if (! $args{'key'}) {
	&Error("field-if syntax error: no keyword");
	return 0; 
    }
    
    # skip "match"
    ;

    $_ = shift @words;
    if (m#\/(\S+)\/#) {
	$args{'pat'} = $1;
    }
    elsif (m#\/\/#) {
	$args{'pat'} = '^$';
    }
    elsif (/^&(\S+)/) {
	$args{'pat'} = "prog:$1";
    }
    else {
	&Error("field-if syntax error: illegal matching pettern($_)");
	return 0;
    }

    # opt
    $args{'opt'} = " ".join(" ", @words);

    1;
}

# 
sub Do_Field_If
{
    local($type, $entry, *rules, *args, *Buf, *Field, *result) = @_;
    local($key, $pat, %opt, $opt, $data, $eval, $prog);

    # variables
    $key  = "$entry:". $args{'key'};
    $data = $Field{$key};
    $pat  = $args{'pat'};
    $opt  = " $args{'opt'} ";

    # program type-predicate 
    if ($pat !~ /^prog:/) {
	if ($pat !~ m/^\^/) { $pat = "^$pat";}
	if ($pat !~ m/\$$/) { $pat = "$pat\$";}
    }

    if ($debug) {
	print "\tKEY\t[$key]\n";
	print "\tDATA\t[$data]\n";
	print "\tPAT\t[$pat]\n";
	print "\tOPT\t[$opt]\n";
    }

    ### REQUIRED ENTRY: EMPTY CHECK; 
    if ((! $data) && $opt =~ / required /) {
	$CurStatus = 'unmatch';
	&ErrLog('required', $key);
    }
    # OPTIONAL ENTRY
    elsif (! $data) {
	$CurStatus = '';
	&Trace(sprintf("        %-40s (empty but optional, O.K.)", $key));
	return; # no data, so we can return here;
    }


    # plural entries not folded fields
    # e.g. 
    # [best3] Nishihara Kumiko
    # [best3] Koorogi Satomi
    # [best3] ...
    # 
    local($fc, $lc);
    $fc = split(/$;/, $data);
    if ($fc > 1 && ($opt !~ / plural /)) {
	&ErrLog('not-plural', $key);
	&Error("should be not plural($fc plural) ($data)") if $debug;
    }

    # can-be-folded entries;
    # line count;
    $lc = split(/\n/, $data);
    if ($lc > 1 && ($opt !~ / foldable /)) {
	&ErrLog('not-foldable', $key);
    }
    elsif ($opt =~ / foldable / && $opt =~ / foldlevel=(\d+) /) {
	if ($lc > $1) { &ErrLog('fold-lebel-error', $key, $1);}
    }


    ### HERE DATA HAS ANYTHING; if ($data ne "") {
    local($status);

    # If the data is determined by the given function(-predicate);
    if ($pat =~ /prog:(\S+)/) {
	$prog = "Syscall'$1"; #';
	$status = 
	    &EvalProg($type, $entry, $prog, $data, *proc, *Buf, *Field);

	if ($status) {
	    &Trace(sprintf("match   %-40s %s", $key, $data));
	    $CurStatus = 'match';
	}
	else {
	    $CurStatus = 'unmatch';
	    &ErrLog('unmatch', $key, $data, $1);
	}
    }
    elsif ($data =~ /$pat/) {
	$CurStatus = 'match';

	&Trace(sprintf("match   %-40s %s", $key, $&));
	print "\n\t\$Field{$key} -> $Field{$key}\n\n" if $debug;

	# regexp matching pattern
	if ($pat =~ /\(.*\)/) {
	    for (1..10) {
		$eval .= "\$args{\"_regexp:${_}\"} = \$${_} if \$${_};";
	    }
	    $data =~ /^$pat$/;	# try again;
	    eval $eval;
	}
    }
    # pattern unmatched
    else {
	$CurStatus = 'unmatch';
	&Error("Entry $key=[$data] NOT match /$pat/.");
    }

}

# Input Data -> %Field;
sub AllocAllFields
{
    local(*Buf, *CF, *result, *Field) = @_;
    local(%fred, $type, $entry);

    for $entry (@CF) {
	# print "Allocate \$Buf{$entry}\n";

	# fix type;
	$type = $entry;
	if ($entry =~ /^(\S+)\#\d+/) { $type = $1;}

	&SetFields($type, $entry, $Buf{$entry}, *Field, *CF);
    }

    if ($debug) {
	for (sort keys %Field) { print "* $_:$Field{$_}\n";}
    }
}


sub EvalProg
{
    local($type, $entry, $prog, $data, *proc, *Buf, *Field) = @_;

    %Syscall'proc  = %Aucea'proc;
    %Syscall'Buf   = %Aucea'Buf;
    %Syscall'Field = %Aucea'Field;

    return &$prog($data);
}


sub Setq
{
    local($_) = @_;

    if (/^\-\-(\S+)=(\S+)/) {
	eval("\$$1 = '$2';");
    }
    else {
	eval("\$$1 = 1;");
    }
}


### libfred.pl;
### sub FredGetFields
sub SetFields
{
    local($type, $entry, $s, *Field, *CF) = @_;
    local($field, $contents, @hdr);

    # print "SetFields($type, $s, *Field, *CF)\n" if $debug;

    # HERE ALREADY Each-Typed-Buffer;
    # so, the empty line can be cut
    while ( $s =~ s/\n\n/\n/g) { 1;}

    # field type
    $field_type = $CF{$type, 'field-type'} || '\S+';

    ### Get @Hdr;
    local($s) = "\n$s\n";
    $s =~ s/\n($field_type)/\n\n$1\n\n/g; #  trick for folding and unfolding.

    ### Parsing main routines
    for (@hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @hdr; #"From "
	 @hdr; 
	 $_ = $field = shift @hdr, $contents = shift @hdr) {

	print STDERR "FIELD:          >$field<\n"    if $debug;

	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^\s*$/o;		# if null, skip. must be mistakes.

	# Save Entry anyway. '.=' for multiple 'Received:'
	# $field =~ tr/A-Z/a-z/ if $CASE_INSENSITIVE;

	# CASE SENSITIVE
	# $Field{"$entry:$field"} .= $contents;# if $contents;?

	$Field{"$entry:$field"} .= 
	    $Field{"$entry:$field"} ? "$;$contents" : $contents;;

    }# FOR;
}

sub PrintSep 
{
    local($sep) = @_; 
    $sep = $sep ? $sep : '-';
    print $sep x30, "\n";
}


sub GrepCISPattern { &GrepPattern($_[0], $_[1], 1);}

sub GrepPattern
{
    local($pat, $buf, $case_insensitive) = @_;
    local($r);

    if (! $buf) {
	&Trace("GrepPattern: grep /$pat/ in [\$Buf]") if $debug;
	$buf = $Buf;
    }
    else {
	&Trace("GrepPattern: grep /$pat/ in [$buf]") if $debug;
    }

    if ($buf) {
	for (split(/\n/, $buf)) {
	    if ($case_insensitive) {
		if (/$pat/i) { $r .= $r ? "\n$1": $1;}
	    }
	    else {
		if (/$pat/) { $r .= $r ? "\n$1": $1;}
	    }
	}
	return $r;
    }
    else {
	&Error("GrepPatternInBuffer: Buffer has NO DATA");
    }
}


sub GrepPatternInFile
{
    local($pat, $file) = @_;

    open(FILE, $file) || &Error("CANNOT OPEN $file.");
    while (<FILE>) {
	chop;
	return $_ if /$pat/; 
    }
    close(FILE);
}


sub CheckZenkaku
{
    local(*buf, $end_pat) = @_;
    local($line);

    # $re_euc_c  = '[\241-\376][\241-\376]';	
    for $line (split(/\n/, $buf)) {
	$_ = $line;

	last if /$end_pat/;

	if (/¡¡/) {
	    &Error("°Ê²¼¤Î¹Ô¤Ë¤ÏÁ´³Ñ¥¹¥Ú¡¼¥¹¤¬¤¢¤ê¤Þ¤¹¡£");
	    &Error("$line (match $&)");
	}

	if (/(£±|£²|£³|£´|£µ|£¶|£·|£¸|£¹)/) {
	    &Error("°Ê²¼¤Î¹Ô¤Ë¤ÏÁ´³Ñ¤Î¿ô»ú¤¬¤¢¤ê¤Þ¤¹¡£");
	    &Error("$line (match $&)");
	}

	# cut the 'not \243'[\241-\376]
	s/[\241-\242\244-\376][\241-\376]//g;

	if (/(£Á|£Â|£Ã|£Ä|£Å|£Æ|£Ç|£È|£É|£Ê|£Ë|£Ì|£Í|£Î|£Ï|£Ð|£Ñ|£Ò|£Ó|£Ô|£Õ|£Ö|£×|£Ø|£Ù|£Ú|£á|£â|£ã|£ä|£å|£æ|£ç|£è|£é|£ê|£ë|£ì|£í|£î|£ï|£ð|£ñ|£ò|£ó|£ô|£õ|£ö|£÷|£ø|£ù|£ú)/) {
	    &Error("°Ê²¼¤Î¹Ô¤Ë¤ÏÁ´³Ñ¤Î±Ñ¸ì¤¬¤¢¤ê¤Þ¤¹¡£");
	    &Error("$line (match $&)");
	}
    }
}


### Globa in the Name Space "Aucea" ###
# in the last returne;
#    $Warn  = "";
#    $Error = "";
sub Warn   { $WarnString   .= "@_\n";}
sub Error  { $ErrorString  .= "@_\n";}
sub Trace { $TraceString .= "@_\n";}

# required to hold error buffer when skipping ...;
sub SyncLogString 
{
    #if ($WarnString || $ErrorString || $TraceString) { print "Sync Log\n";}

    $Warn   .= $WarnString;
    $Error  .= $ErrorString;
    $Error  .= "\n" if $ErrorString;
    $Trace .= $TraceString;

    &UndefLogString;
}

sub UndefLogString 
{
    undef $WarnString;
    undef $ErrorString;
    undef $TraceString;
}

sub ErrLog 
{ 
    &Syscall'ErrLog(@_);#';
}


########## Exports;
sub Syscall'Warn   { &Aucea'Warn(@_);}
sub Syscall'Error  { &Aucea'Error(@_);}
sub Syscall'Trace  { &Aucea'Trace(@_);}

sub CF'Warn   { &Aucea'Warn(@_);}
sub CF'Error  { &Aucea'Error(@_);}
sub CF'Trace  { &Aucea'Trace(@_);}


1;
