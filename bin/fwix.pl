#!/usr/local/bin/perl
#
# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

unshift(@ARGV, split(/\s+/, $ENV{'FWIX_OPTS'}));

require 'getopts.pl';
&Getopts("f:i:hd:b:m:M:t:vT:D:I:A:C:R:N:n:L:S:Z:Fo:");

$debug=1;

##### Config VARIABLES #####
$Chapter = $Section = 0;
$COMMENT = '^\.comment|^\.\#';
$KEYWORD = 'C|ST|S|C\.S|P|http|label|l|key|k|seealso|xref|A|ptr|url|filename|n';
$IGNKEY  = 'toc';
$FORMAT  = 'q|~q|appendix';
$HTML_KEYWORD = 'HTML_PRE|~HTML_PRE';

# output in both Japanese and English mode.
$ALWAYS_OUTPUT_KEYWORD = 'C|C\.S|\.S|url|ptr|xref|seealso';

$BGColor   = "E6E6FA";# lavender ("E0FFFF" == lightcyan);

%Part = (1, 'I',
	 2, 'II',
	 3, 'III',
	 4, 'IV',
	 5, 'V',
	 6, 'VI',
	 7, 'VII',
	 8, 'VIII',
	 9, 'IX',
	 10, 'X',
	 );


# Alphabetical Order Table
for('A'..'Z') { push(@AlpTable, $_);}

$|           = 1;
$no_index    = 1 if $opt_n eq 'i';
$not_include = 1 if $opt_n eq 'I';
$debug       = $opt_v; 
$Author      = $opt_I;
$Copyright   = $opt_C;
$DIR         = $opt_d || $opt_I;
$HtmlDir     = $opt_D;
$RoffDir     = $opt_R;
$Title       = $opt_T || "NONE TITLE";
$TmpDir      = (-d $ENV{'TMPDIR'} && $ENV{'TMPDIR'}) || './var/tmp'; 

# index list
$IndexFile   = $opt_f || $NULL; # list of lidex
$MakeIndex   = $opt_i || $NULL; # make index table (only table)

$OUTPUT_FILE = $opt_o;

$OnFml       = 1 if $opt_F;

$Lang        = $opt_L || 'JAPANESE';
$Lang        =~ tr/a-z/A-Z/;

$Manifest    = ""; # log of label;

$TmpFile     = $opt_t || "$TmpDir/$$.fml";
$TmpFile_Eng = "$TmpDir/$$.fml-e";

$ManifestFile = $opt_M || "$TmpDir/MANIFEST";

# <LINK > element
$LINK_MAILTO     = $opt_Z;
$LINK_STYLESHEET = $opt_S;

# this order is correct.
-d $TmpDir || mkdir($TmpDir, 0700);

$SIG{'TERM'} = 'CleanUp';
$SIG{'HUP'}  = 'CleanUp';
$SIG{'INT'}  = 'CleanUp';
$SIG{'QUIT'} = 'CleanUp';
$SIG{'HUP'}  = 'CleanUp';
##### VARIABLES ENDS #####


##### MAIN #####
{
    my ($dirname) = $0;
    $dirname =~ s@bin/[^/]+$@@;
    $dirname =~ s@/*$@@;
    $dirname = '.' unless $dirname;
    push(@INC, $dirname);
    push(@INC, "$dirname/module/Japanese");

    require 'jcode.pl';

    local($mode) = $opt_b || $opt_m || 'text';

    &Init;

    if ($MakeIndex) {
	print STDERR "\t-- make index list mode\n" if $debug_make_index;
    }
    else {
	print STDERR "fwix generation mode:\t$mode (Language=$Lang)\n";
    }

    &Formatter($mode);		# main;
}

&CleanUp;
exit 0;
##### MAIN ENDS #####


############################################################

##### Section: Main
sub CopyRight
{
q%
<PRE>
Copyright (C) 1993-2000 Ken'ichi Fukamachi
All rights of this page is reserved.

# This Document(html format) is automatically geneareted by fwix.pl. 
# fwix (Formatter of WIX Language) is fml document formatter system
# designed to generate plaintext, html, texinfo and nroff from one file.
</PRE>    
%;
}

sub Init
{
    if ($opt_m eq 'htmlconv') {
	if (! $OUTPUT_FILE) { 
	    print STDERR "Usage: fwix.pl -m htmlconv -o output.html source\n";
	    exit 1;
	}
	$mode = 'html';
    }
    elsif ($mode eq 'html') {
	$HtmlDir    || 
	    die("Required! \$HtmlDir for the output of html files\n");
	-d $HtmlDir || mkdir($HtmlDir, 0755);
    }

    %Prog = ( 
	     'phase1:text',  'ReadFile',
	     'phase1:html',  'ReadFile',
	     'phase1:roff',  'ReadFile',
	     'phase1:latex', 'ReadFile',

	     'phase2:text',  'OutputFile',
	     'phase2:html',  'OutputFile',
	     'phase2:roff',  'OutputFile',
	     'phase2:latex', 'OutputFile',

	     # tricky filter
	     'phase1:htmlconv',  'ReadFile',
	     'phase2:htmlconv',  'OutputFile',
	     );

    # jcode.pl
    &jcode'init();#';
}


sub Formatter
{
    local($mode) = @_;
    local($dir, $Prog);

    ### PHASE 01: once read, fix, calculate chap.sec.. :include, ..
    $Prog = $Prog{"phase1:$mode"};
    &Open4Write($mode);

    if (@ARGV) {
	foreach (@ARGV) {
	    s/(\S+)\/(\S+)/$dir = $1, $_ = $2/e;
	    &$Prog($_, ($DIR || $dir || '.'), $mode);
	}
    }
    else { # STDIN;
	&$Prog($opt_N, ($DIR || '.'), $mode);
    }

    close(TMPF);
    close(ENG);

    if ($MakeIndex) {
	&FlushMakeIndex;
	print STDERR "\t-- \$MakeIndex mode ends\n" if $debug_make_index;
	return;
    }

    # load index list to overwrite %index by %indexlist
    # (e.g. {text,html}_index.ph)
    if ($IndexFile && -f $IndexFile) {
	require $IndexFile;
	while (($k, $v) = each %index) { $indexlist{$k} = $v;}
	%index = %indexlist;
    }

    ### PHASE 02:
    $Prog = $Prog{"phase2:$mode"};
    &Open4Read;
    &$Prog($_, ($DIR || $dir || '.'), $mode);

    close(TMPF);
    close(ENG);

    ### PHASE 03:
    if ($mode eq 'text') {
	&LogManifest;
	&ShowIndex unless $no_index;
    }

}


sub FlushMakeIndex
{
    while (($k, $v) = each %MakeIndex) {
	print "\$indexlist{'$k'} = '$v';\n\n";
    }
}


##### Section: Signal
# SIGNAL HANDER
# 1st argument is signal name
sub CleanUp 
{  
    local($sig) = @_;

    print STDERR "Caught a SIG$sig--shutting down\n" if $sig;
    print STDERR "debug mode: not unlink temporary files\n" if $debug;

    if ($debug) {
	print STDERR "tmp file is $TmpFile $TmpFile_Eng\n";
    }
    else {
	unlink $TmpFile;
	unlink $TmpFile_Eng;
    }

    exit(0);
}


##### Section: IO
sub ShowIndex
{
    print "\n\t\tINDEX\n\n";
    foreach $x (sort __CISort keys %key) {
	printf "%-40s   ...   %s\n", $x, $keylist{$x};
    }
}


# case insensitive
sub __CISort
{
    local($ta, $tb) = ($a, $b);

    $ta =~ tr/A-Z/a-z/;
    $tb =~ tr/A-Z/a-z/;
    $ta =~ s/[\$\%\@\#\&\'\"\-\s]//g;
    $tb =~ s/[\$\%\@\#\&\'\"\-\s]//g;

    $ta cmp $tb;
}


sub LogManifest
{
    open(MANIFEST, "> $ManifestFile") || die("CANNOT OPEN $ManifestFile:$!");
    print MANIFEST $Manifest;
    close(MANIFEST);
}


# ALIASES
sub Log { print STDERR @_, "\n"; }


sub Open4Write
{
    local($mode) = @_;

    open(TMPF, "> $TmpFile") || die($!);
    select(TMPF); $| = 1; select(STDOUT);

    open(ENG, "> $TmpFile_Eng") || die($!);
    select(ENG); $| = 1; select(STDOUT);

    if ($opt_m eq 'htmlconv') {
	print TMPF "\n\#.CUT:$OUTPUT_FILE\n";
	print ENG  "\n\#.CUT:$OUTPUT_FILE\n";
    }
    elsif ($mode eq 'html') {
	print TMPF "\n\#.CUT:${HtmlDir}/index.html\n";
	print ENG  "\n\#.CUT:${HtmlDir}/index.html\n";
    }

    print STDERR "---Open::($TmpFile $TmpFile_Eng)\n" if $verbose || $debug;
}


sub Print
{
    if ($debug && /CUT:/) { @c = caller; &Debug("CUT TRAP $c[2]");}

    # Save the body
    if ($mode eq 'text') {
	print "$Tag$_\n";
    }
    elsif ($mode eq 'latex') {
	print "$Tag$_\n";
    }
    elsif ($mode eq 'html') {
	print "$_\n";
    }
    elsif ($mode eq 'roff') {
	print "$_\n";
    }
}


sub Open4Read
{
    print STDERR "Open4Read::($TmpFile)\n" if $debug;
    open(TMPF, $TmpFile)   || die $!;
    open(ENG, $TmpFile_Eng) || die $!;
}


##### Section: Read Handlers


sub ReadFile
{
    local($file, $dir, $mode) = @_;
    local($InIf, $TrueInIf, $HaveDotReturn);
    local($d, $f);
    local($fname) = $file;

    # XXX 2000/04/11 by fukachan@cvs.fml.org
    # XXX This existence check is too strict ?
    # XXX 
    # if ($file && (! -f "$dir/$file")) {
    # print STDERR "no such file $dir/$file\n";
    # return;
    # }

    $ReadFileRecursiveLevel++;

    print STDERR "ReadFile[$ReadFileRecursiveLevel] $file\n" if $debug;

    $mode = $mode || 'text';

    # $file =~ s#(\S+)\/(\S+)#$d = $1, $f = $2#e;
    # $dir  = "$dir"    if -d $dir;
    # $dir  = "$dir/$d" if -d "$dir/$d";
    # $dir  = $d        if -d $d;
    #print STDERR "Try Including $dir/$file\n";

    if ($file && -f $file) {
	open($file, $file) || &Log("cannot open $file");
    }
    elsif ("$dir/$file" && -f "$dir/$file") {
	$file = "$dir/$file";
	open($file, $file) || &Log("cannot open $file");
    }
    else {
	$file = 'STDIN';
    }

    # info
    {	
	local($c) = $Chapter + 1;
	printf STDERR "\tinclude[$ReadFileRecursiveLevel] %-40s  %s\n", $file,
	"(".($Appendix ? "App.$Appendix " : ""). "Chap.$c)";
    }
    
    ### split after the tmpfile is generated;
    if ($mode eq 'html') {
	;#; print TMPF "\n#.CUT:$HtmlDir/$fname\n";
    }
    elsif ($mode eq 'roff') {
	$fname =~ s/\.wix/.1/;
	print TMPF "#.CUT:$RoffDir/$fname\n";
	print ENG  "#.CUT:$RoffDir/$fname\n";
    }


    while (<$file>) {
	chop;

	undef $Both;
	undef $NotFormatReset;
	undef $NotIncrement;
	undef $TrapEC;

	# if find space only line, cut off spaces
	s/^\s+$//;

	# debug, comment
	/$COMMENT/i && next;                    # Comments
	/^\.DEBUG/o && ($debug = 1, next); 	# DEBUG MODE

	# IF, ENDIF
	if (/^\.if\s+LANG\s*==\s*(\S+)|^<Lang\s+(\S+)/i) {
	    $InIf = 1;
	    # print STDERR " \$TrueInIf = $Lang eq $1 ? 1 : 0;  \n";
	    $TrueInIf = $Lang eq $1 ? 1 : 0; 
	    next;
	}
	if (/^\.endif/i || /^\.~if/ || /^\.fi/ || /^<\//) { 
	    undef $InIf; 
	    next;
	}

	# here (before here, cannot eval .endif
	# skip if IN IF BLOCK BUT CONDISION IS FALSE.
	$HaveDotReturn = 1 if /^\.return/;
	next if $InIf && !$TrueInIf;

	# long jump
	if (/^\.return/) { 
	    # print STDERR "*** return; last here ($. $_)\n";
	    last;
	}

	# html mode
	if ($mode eq 'html' && /[\&\<\>]/) {
	    &Debug($_) if $debug_html;
	    &Debug("\t=>") if $debug_html;
	    &ConvSpecialChars(*_);
	    &Debug($_) if $debug_html;
	}

	# language declared
	# reset Language if it encounters null line; 
	if (/^\s*$/ || /^\.($KEYWORD)/) {
	    undef $LANG;
	}

	# BLOCK WITHIN OR NOT INFOMATION
	# null line reset the block info
	if (/^\s*$/) {
	    undef $WithinBlock;
	}

	# keywords
	$WithinBlock = $DetectKeyword = $. if /\.($KEYWORD)/;# EUC or English;

	# Case 1: EUC(Japanese);
	if (/[\241-\376][\241-\376]/) {	
	    undef $LANG;
	    $DetectEUC = $.;	# save the current line;
	}
	# Case 2: to avoid duplicate title;
	elsif (!$LANG && !/^\.($KEYWORD)/) { 
	    $Both = 1;
	}
	# Case 3: but print out English chapter or section name
	elsif (!$LANG && /^\.($ALWAYS_OUTPUT_KEYWORD)/) { 
	    $Both = 1;
	}

	
	# Pair Relation Check  .S <=> =E.S 
	# Japanese .C .S .P requires the next line =E.[CSP]
	if ($OnFml) {
	    if (! $HaveDotReturn) {
		if (/^\.[CSP]/) {
		    $PrevCSPrequireECSP = $_ if /[\241-\376][\241-\376]/;
		}
		elsif ($PrevCSPrequireECSP) {
		    if (! /^=E\.[CSP]/) {
			print STDERR "--ERROR: missing =E.[CSP]?\n";
			print STDERR "         prev: $PrevCSPrequireECSP\n";
			print STDERR "          now: $_\n";
		    }

		    undef $PrevCSPrequireECSP;
		}
	    }
	}

	if (/^=E/) {
	    s/^=E//; 
	    $LANG = 'ENGLISH';
	    $TrapEC = 1;
	    $NotFormatReset = 1;
	    $NotIncrement = 1;
	}

	if (/^==/) { 
	    undef $LANG;
	    $CurLang = $LANG || "JAPANESE";
	    next;
	}


	##########
	if (/^\.($KEYWORD)/) {
	    $CurLang = $LANG || "JAPANESE";
	}


	### PATTERN MATCH
	###
	if (/^\.($HTML_KEYWORD)/) {
	    print STDERR "\tCATCH HTML($&)\n" if $verbose;
	    if ($mode eq 'html')  {
		s/^\.($HTML_KEYWORD)/($_ = &HtmlExpand($1, $2, $file, $mode)) || next/e;
	    }
	    else {
		next;		# skip .HTML.*
	    }
	}

	# seealso{guide}
	if (/^\.($KEYWORD)\{(\S+)\}/) {
	    print STDERR "\t--catch{}syntax $1"."{$2}\n"; # against perl 5
	    s/\.($KEYWORD)\{(\S+)\}/&Expand($1, $2, $file, $mode)/e;
	}

	s/^\.($KEYWORD)\s+(.*)/$_ = &Expand($1, $2, $file, $mode)/e;
	s/^\.($FORMAT)\s*(.*)/$_  = &Format($1, $2, $file, $mode)/e;

	### Command Exceptions in the middle of a line
	### ESCAPE SEQUENCE
	if (/\\\.(ptr|fig|ps)/) {
	    s/\\\./\./g;
	}
	### expand
	else {
	    s/\.(ptr|fig|ps)\s*\{(\S+)\}/&Expand($1, $2, $file, $mode)/ge;
	}


	# NEXT
	next if /^\#.next/o;
	
	# INCLUDE; anyway including. we add ".CUT" commands to Temporary Files
	if (! $not_include) {
	    s/^\.include\s+(\S+)/&ReadFile($1, $dir || '.', $mode)/e;
	}

	# Handling Multiple Languages
	# TMPF == Japanese;
	undef $select_channel; # passed to the next if ($Both) {}
	if ($LANG eq 'ENGLISH') {
	    select(ENG); $| = 1;
	    $select_channel = $LANG;
	    &Print;
	}
	else {
	    select(TMPF); $| = 1;
	    $select_channel = $LANG;
	    &Print;
	}

	### BOTH LANGUAGES
	# OK. Print in both languages
	# BUT if a null line is output between Japanese sentences.
	# a lot of null lines are printed.
	# "(! $LANG && !/\.($KEYWORD)/)" ALREADY satisfied 
	if ($Both || $ForcePrint) {
	    select(ENG); $| = 1;

	    # force printout (.S english)
	    if ($ForcePrint && !$TrapEC) {
		print STDERR "\$ForcePrint($_) is set\n" if $debug;
		&Print;
		undef $ForcePrint;
	    }

	    # e.g. form '.url English' line IS IGNORED!
	    next if $DetectKeyword == $.;

	    # print "--Cur[$CurLang]   ";

	    # the previous line is not Japanese, output a null line;
	    if (/^\s*$/ && (($DetectEUC - 1) != $.)) {
		&Print;
	    }
	    else {
		# print "--Detect[$DetectKeyword != $.]\n";
		&Print;
	    }
	}

	# ignore .toc
	if (/^\.($IGNKEY)/) { next;}

	# Try to detect ERROR
	if ($mode ne 'roff') { /^\.(\S+)/ && &Log("Error?(${file} $.) ^.$1");}
    }# WHILE;

    close($file);

    select(STDOUT);

    $ReadFileRecursiveLevel--;

    $NULL;
}


sub GobbleUntil
{
    local($last_key, $s) = @_;
    local($flag);

    $s =~ /$last_key/ && ($flag = 0);
    ($s, $flag);
}

##### Section: Output Handlers
sub OutputHtml
{
    local($input) = @_;
    local($cur_n);

    print STDERR "$input -> ", select,"\n";

    while (<$input>) {
	undef $Error;

	# if ($prev_line eq $_) {
	#    $prev_line = $_;
	#    next;
	# }
	{
	    $prev_line = $_;

	    if (m@\<\/PRE\>\<A.*\<PRE\>\s*$@) {
		s@^\<\/PRE\>@@;
		s@\<PRE\>\s*$@\n\n@ if $__withinPRE;
	    }
	    
	    $__withinPRE = 0 if m@\</PRE\>@;
	    $__withinPRE = 1 if m@\<PRE\>@;
	}

	if (/^\#\.CUT_SKIP:(\S+)/) {
	    $name = $outfile = $1;
	    $name =~ s#.*/##;
	    if ($name =~ /^(\d+)\.html/) {
		$PrevUrlPointer = $1 - 1;
		$PrevUrlPointer = $PrevUrlPointer > 0 ? $PrevUrlPointer : 1;
	    }

	    print STDERR "---Skipping\t$outfile";
	    print STDERR "(prev->$PrevUrlPointer)" if $verbose;
	    print STDERR "\n";

	    next;
	}

	if (/^\#\.CUT:(\S+)/) {
	    $name = $outfile = $1;
	    $name =~ s#.*/##;

	    $prev_url_pointer =  $CurUrlPointer;

	    # here the cur_n is the next number (attention) 
	    # since here is close() phase for the next chapter;
	    if ($name =~ /^(\d+)\.html/) {
		my $n = $1;
		&POH(($CurUrlPointer = &ShowPointer($n)));
		&POH(&CopyRight) if $OnFml;
	    }

	    &POH("</BODY>\n");
	    &POH("</HTML>\n");

	    &POH_CLOSE;
	    open(OUTHTML, "> $outfile") || die "$!\n";
	    select(OUTHTML); $| = 1;
	    &POH_Init;

	    &POH("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n");
	    if ($Lang eq 'ENGLISH') {
		&POH("<HTML lang=\"en\">\n");
	    }
	    elsif ($Lang eq 'JAPANESE') {
		&POH("<HTML lang=\"ja\">\n");
	    }
	    &POH("<HEAD>\n");
	    &POH("<TITLE>$Title $name</TITLE>\n");
	    &POH("<META http-equiv=\"Content-Type\"\n");
	    if ($Lang eq 'ENGLISH') {
		&POH("   content=\"text/html; charset=us-ascii\">\n");
	    }
	    elsif ($Lang eq 'JAPANESE') {
		&POH("   content=\"text/html; charset=ISO-2022-JP\">\n");
	    }
	    else {
		print STDERR "ERROR: http-equiv lang=$Lang";
	    }

	    # META keywords
	    {
		my ($keyword) = $Title;
		$keyword     .= ",". $ENV{'FWIX_META_KEYWORD'};
		if ($Lang eq 'ENGLISH') {
		    &POH("<META name=\"keywords\"");
		    &POH("   lang=\"en\"\n");
		    &POH("   content=\"$keyword\">\n");
		}
		elsif ($Lang eq 'JAPANESE') {
		    &POH("<META name=\"keywords\"");
		    &POH("   lang=\"ja\"\n");
		    &POH("   content=\"$keyword\">\n");
		}
	    }

	    # <LINK ... > element
	    if ($LINK_ELEMENT || $LINK_MAILTO || $LINK_STYLESHEET) {
		if ($LINK_MAILTO) {
		    &POH("<LINK rev=\"made\" href=\"mailto:$LINK_MAILTO\">\n");
		}

		if ($LINK_STYLE_SHEET) {
		    &POH("<LINK rel=\"stylesheet\" type=\"text/css\" ");
		    &POH("href=$LINK_STYLE_SHEET>\n");
		}		
	    }

	    &POH("</HEAD>\n");
	    &POH("\n<BODY BGCOLOR=$BGColor>\n") if $BGColor;
	    &POH("___SHOW_POINTER___");
	    # &POH($prev_url_pointer) if $prev_url_pointer;

	    if ($CurUrlPointerTop =~ /NEXT/ &&
		$CurUrlPointerTop =~ /PREV/) {
		&POH($CurUrlPointerTop);
	    }

	    next;		# cut the line "^#.CUT";
	}

	s%\#\.fn(\d+)%<A HREF=footnote.html#footnote$1>* $1</A>%g;

	s%\#\.ps\{(\S+)\}%<A HREF=$1>$1</A>%i;
	s/\#\.fig\{(\S+)\}/&FigExpand($1)/gei;

	s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	s/^\#\.url\s+(\S+)/&IndexExpand($1,1)/gei; # .url URL ignored
	s/^(\#\.index|\.toc)/$Index{$Lang}/; 
	s/^=S//;

	print STDERR "   $prev   $_\n" if $Error; 
	$prev = $_;

	&POH($_);
    }

    &POH_CLOSE('LAST'); # 'LAST' is required exceptionally.

    if (%FootNote) {
	print STDERR "   generating\t$HtmlDir/footnote.html\n";
	open(OUTHTML, "> ${HtmlDir}/footnote.html") || die "$!\n";
	&POH_Init;
    
	&POH("<TITLE>FootNote</TITLE>\n");

	for (sort {$a <=> $b} keys %FootNote) {
	    &POH("<P>\n");
	    &POH("<A NAME=\"footnote$_\">* $_ </A>\n");
	    &POH("$FootNote{$_}\n\n");
	}

	&POH("\n\n");

	&POH_CLOSE;
    }

}


sub POH
{
    local($s) = @_;
    local($lc, $buf);
    local($re_jin)    = '\033\$[\@B]';
    local($re_euc_c)  = '[\241-\376][\241-\376]';

    $lc = ($s =~ tr/\n/\n/);

    if ($Lang eq 'ENGLISH' && $s =~ /$re_euc_c|$re_jin/) {
	print STDERR "ignore <$s>\n";
	return;
    }

    if ($s =~ /^\s*$/) {
	$AlignCount++ if $s =~ /^\s*$/;
	if ($AlignCount > 2) { return;}
    }
    else {
	$AlignCount = 0;
    }

    if ($lc > 1) {
	&Debug("POH: input $lc lines") if $debug;
	for $b (split(/\n/, $s)) {
	    &jcode'convert(*b, 'jis'); #';
	    $buf .= "$b\n";
	}

	$s = $buf;
    }
    else {
	&jcode'convert(*s, 'jis'); #';
    }

    # print OUTHTML $s;
    $POH_Buffer .= $s;
}


sub POH_Init
{
    undef $POH_Buffer;
    undef $CurUrlPointer;
}

sub POH_CLOSE
{
    my ($mode) = @_;

    if ($mode eq 'LAST') { 
	$CurUrlPointer = $LastUrlPointer . $CurTOCPointer;
    }

    $POH_Buffer =~ s/___SHOW_POINTER___/$CurUrlPointer/;
    $POH_Buffer =~ s/___SHOW_POINTER___//;

    print OUTHTML $POH_Buffer;
    close(OUTHTML);
    undef $POH_Buffer;
}


sub ShowPointer
{
    # CAUTION: $cur_n == 2 if fwix process 1.html now.
    my ($cur_n) = @_;
    my ($s, $n);

    # $s .= "</PRE><HR>\n";
    $s .= "</PRE>\n";

    if ($cur_n != 2) { # except 1.html
	$n = $cur_n - 2;
	$n = $PrevUrlPointer < $n ? $PrevUrlPointer : $n;

	# ignore -1
	if ($n > 0) {
	    $s .= "<A HREF=${n}.html>[PREVIOUS CHAPTER]</A>\n";
	}
	else {
	    my $n = 'index';
	    $s   .= "<A HREF=${n}.html>[______TOC_______]</A>\n";
	}
    }
    else { # 1.html
	my $n = 'index';
	$s   .= "<A HREF=${n}.html>[______TOC_______]</A>\n";
	$CurTOCPointer = "<A HREF=${n}.html>[______TOC_______]</A>\n";
    }
    
    print STDERR "   generating\t$outfile (prev-> $n, ";

    $n = $cur_n - 1;
    if ($n > 0) {
	$LastUrlPointer = "<A HREF=${n}.html>[PREVIOUS CHAPTER]</A>\n";
    }
    else {
	$LastUrlPointer = "<A HREF=index.html>[PREVIOUS CHAPTER]</A>\n";
    }

    $n = $cur_n;
    $s .= "<A HREF=${n}.html> [NEXT CHAPTER]</A>\n";

    print STDERR "next -> $n)\n";

    $PrevUrlPointer = 10000;

    $s;
}


sub OutputFile
{
    local($file, $dir, $mode) = @_;
    local($outfile, $prev);

    &Debug("---OutputFile: Lang=$Lang");

    if ($mode eq 'html' || $mode eq 'htmlconv') {
	$Index = "<UL>\n$Index\n</UL>";

	if ($Lang eq 'ENGLISH'){
	    &OutputHtml('ENG');
	}
	else {
	    &OutputHtml('TMPF');
	}
    }
    elsif ($mode eq 'roff') {
	print ".SH\n$Copyright\n" if $Copyright;
	while (<TMPF>) {
	    undef $Error;

	    if (/^\#\.CUT:(\S+)/) {
		$name = $outfile = $1;
		$name =~ s#.*/##;
		print STDERR "> $outfile\n";

		close(OUTROFF);
		open(OUTROFF, "> $outfile") || die "$!\n";
		select(OUTROFF); $| = 1;

		print OUTROFF ".SH $Title\n.SH $name\n";

		next;		# cut the line "^#.CUT";
	    }

	    s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^\#\.url\s+(.*)/&IndexExpand($1,1)/gei;
	    s/^(\#\.index|\.toc)/$Index{$Lang}/; 

	    print STDERR "   $prev   $_\n" if $Error; $prev = $_;
	    print OUTROFF $_;
	}

	close(OUTROFF);
    }
    elsif ($mode eq 'text') {
	$input = $Lang eq 'ENGLISH' ? 'ENG' : 'TMPF';

	if ($Index{$Lang}) {
	    local($sep) = ("-" x 60);
	    $Index{$Lang} = $sep. $Index{$Lang}. $sep."\n";
	}

	while (<$input>) {
	    undef $Error;

	    ### NULL LINE SKIP
	    if (/^\s*$/) {
		$null_line++;
	    }
	    else {
		$null_line = 0;
	    }

	    # aggregate null lines if 3 continuous lines are null;
	    next if $null_line > 1;
	    ##### NULL LINE FORMATS END

	    s/\#\.fn(\d+)/*$1/g;
	    s/\#\.ps\{(\S+)\}/Figure $PostScript{$1}/i;
	    s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	    s/\#\.fig\{(\S+)\}/&FigExpand($1)/gei;
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^\#\.url\s+(.*)/&IndexExpand($1,1)/gei;
	    s/^(\#\.index|\.toc)/$Index{$Lang}/; 
	    s/^=S//;

	    print STDERR "==ERROR:\n- $prev\n+ $_\n" if $Error; 
	    $prev = $_;

	    print $_;
	}

	if (%FootNote) {
	    print "___________\nFootnote\n\n";
	    for (sort {$a <=> $b} keys %FootNote) {
		print "$_: $FootNote{$_}\n\n";
	    }
	    print "\n\n";
	}
    }
    elsif ($mode eq 'latex') {
	# &OutputLaTex('ENG');
	&OutputLatex('TMPF');
    }

}


sub OutputLatex
{
    local($input) = @_;

    while (<$input>) {
	undef $Error;

	s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	s/^\#\.url\s+(.*)/&IndexExpand($1,1)/gei;
	s/^(\#\.index|\.toc)/$Index{$Lang}/; 
	s/^=S//;

	print STDERR "==ERROR:\n- $prev\n+ $_\n" if $Error; 
	$prev = $_;

	print $_;
    }
}



##### Section: Format 


sub Format
{
    local($c, $s, $file, $mode) = @_;
    local($r) = '#.next';

    if ($s =~ /{(.*)}/) { $s = $1;}

    if ($c eq 'q') {
	$Tag = "    ";
	if ($mode eq 'html') {
	    if ($In_PRE) {
		$QuoteInPRE = 1;
	    }
	    else {
		# $r = "<PRE>";
		$In_PRE = 1;
	    }
	}
    }
    elsif ($c eq '~q') {	# destructor:-)
	undef $Tag;
	if ($mode eq 'html') {
	    if ($QuoteInPRE) {
		$QuoteInPRE = 0;
	    }
	    elsif ($In_PRE) {
		# $r = "</PRE>";
	    }
	    else {
		;
	    }
	}
	undef $In_PRE;
    }
    elsif ($c eq 'appendix') {	# set flag, return without effect;
	$InAppendix = 1;
	$r = "";
    }

    $r;
}


sub FormatReset
{
    return if $NotFormatReset;	# e.g. =E.\w ;

    undef $Tag;

    if ($InPre) {
	print TMPF "</PRE>";
	print ENG  "</PRE>";
    }
    undef $InPre;
}


sub GetCurPosition
{
    if ($InAppendix) {
	$CurPosition = $Section ? 
	    "Appendix $Appendix.$Section" : "Appendix $Appendix";
    }
    else {
	$CurPosition = $Section ? "$Chapter.$Section" : $Chapter;
    }
}


##### Section: Macro Expantion

# ROFF
# .TH 
# .SH 
# .B 
# .br
#
sub Expand
{
    local($c, $s, $file, $mode) = @_;
    local($mh, $mn, $mr);

    &GetCurPosition;
    print STDERR "Current: $CurPosition\n" if $debug;
    
    $htmlname = $file;
    $htmlname =~ s#.*/##;
    $htmlname =~ s#\.wix$#.html#;

    ### Mode of Xxxx (-> MX)
    $mh = 1 if $mode eq 'html';
    $mr = 1 if $mode eq 'roff';
    $mt = 1 if $mode eq 'text';

    ### Fix {.*} Syntax
    if ($s =~ /{(.*)}/) { 
	$s = $1; # if $mt; 
    }


    if ($InAppendix) {
	$c = 'A' if $c eq 'C';
    }

    ###  Part
    if ($c eq 'P') {
	&FormatReset;
	$CurrentSubject = $s;
	
	$Part++ if !$LANG && !$NotIncrement;
	$s = "$Part{$Part}\t$s";

	# FORCE PRINT
	if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
	    $ForcePrint = 1;
	}

	if ($mt) {
	    # always set ENGLISH MODE Title:)
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= "$s\n"; 
		$ForcePrint = 1;
	    }

	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    local($ch) = $Chapter + 1;
	    local($se) = 0;
	    $Index{$CurLang} .= 
		"<HR>\n<LI><H3><A HREF=\"$ch.html#C${ch}S${se}\">$s</A></H3>\n";
	    $s      = "<HR>\n<A NAME=\"C${ch}S${se}\">$s</A>\n";
	    $s     .= "<PRE>"; 	$In_PRE = 1;

	    $InPre++ unless $LANG;

	    $s = &HtmlSplitHere($s, 1);
	}
	elsif ($mr) {
	    $s = ".SH\n$s\n";
	}


    }
    ###  Chapter
    elsif ($c eq 'C') {
	&FormatReset;
	$CurrentSubject = $s;

	$Chapter++ if !$LANG && !$NotIncrement;
	$Section    = 0;
	$InAppendix = 0;
	$Figure     = 0;

	if ($ENV{'debug_fwix'}) {
	    print STDERR "C($Chapter): <$c><$s> LANG=$LANG/$CurLang\n";
	}

	$s = "$Chapter\t$s";

	# FORCE PRINT
	if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
	    $ForcePrint = 1;
	}

	if ($mt) {
	    # always set ENGLISH MODE Title:)
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= "\n$s\n"; 
		$ForcePrint = 1;
	    }

	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= 
		    "<HR>\n<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    }

	    $Index{$CurLang} .= "<HR>\n<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>";	    $In_PRE = 1;

	    $s = &HtmlSplitHere($s, 0);

	    $InPre++ unless $LANG;
	}
	elsif ($mr) {
	    $s = ".SH\n$s\n";
	}

    }
    elsif ($c eq 'S' || $c eq 'C.S') {
	&FormatReset;
	$CurrentSubject = $s;

	$Section++ unless $LANG;
	$s = &GetCurPosition."\t$s";

	# FORCE PRINT
	if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
	    $ForcePrint = 1;
	}

	if ($mt) {
	    # always set ENGLISH MODE Title:)
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= "$s\n"; 
		$ForcePrint = 1;
	    }

	    $Index{$CurLang}  .= "$s\n";
	}
	elsif ($mh) {
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= "<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    }

	    $Index{$CurLang} .= "<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<A NAME=\"C${Chapter}S${Section}\">$s</A>";
	    $s     .= "<PRE>";  	$In_PRE = 1;
	    $InPre++ unless $LANG;
	}
	elsif ($mr) {
	    $s = ".SH\t$s\n";
	}

    }
    elsif ($c eq 'ST') {
	$CurrentSubject .= $s;

	$s = "\t$s";
	$Index{$CurLang} .= "$s\n";
    }
    ###  Chapter
    elsif ($c eq 'A') {
	&FormatReset;
	$CurrentSubject = $s;

	$Chapter++ if !$LANG && !$NotIncrement;
	$InAppendix = 1;
	$Section = 0;

	$Appendix = shift @AlpTable if !$NotIncrement;
	$s = "Appendix $Appendix\t$s";

	# FORCE PRINT
	if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
	    $ForcePrint = 1;
	}

	if ($mt) {
	    # always set ENGLISH MODE Title:)
	    if ($s !~ /[\241-\376][\241-\376]/ && $CurLang ne 'ENGLISH') {
		$Index{'ENGLISH'} .= "$s\n"; 
		$ForcePrint = 1;
	    }

	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    $Index{$CurLang} .= "<HR>\n<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>";  	$In_PRE = 1;

	    $s = &HtmlSplitHere($s, 0);
	}
	elsif ($mr) {
	    ;
	}

    }
    elsif ($c eq 'http') {
	;
    }
    elsif ($c eq 'url') {
	$ForcePrint = 1;

	if ($mode eq 'html') {
	    print STDERR "url::html {\$s = <$s>}\n" if $debug;

	    # XXX 3.0D 2000/05/02 true (actually ignore In_PRE) ?
	    $index{"url=$s"} = "<A HREF=$s>$s</A>";
	    $index{"url=$s"} = "</PRE>".$index{"url=$s"}."<PRE>" if $In_PRE;
	    $index{"url=$s"} = "<A HREF=$s>$s</A>" if $In_PRE;
	    $s = "\#.url url=$s";
	}
	else {
	    $s = "\t$s"; 
	}
    }
    elsif ($c eq 'ptr') {
	&Log("ptr:: -> \#.ptr{$s}") if $debug;
	$s = "\#.ptr{$s}";
    }
    elsif ($c eq 'fig') {
	&Log(".fig{$s} -> \#.fig{$s}") if $debug;
	$s = "\#.fig{$s}";
    }
    elsif ($c eq 'ps') {
	$Figure++;

	&Log(".ps{$s} -> $Chapter.$Figure") if $debug;

	if ($figure_index{$s}) {
	    &Log("ERROR: $s is already assinged as $figure_index{$s}");
	}
	else {
	    $figure_index{$s} = "$Chapter.$Figure";
	}

	$PostScript{$s} = "$Chapter.$Figure";
	$s = "#.ps{$s}";
    }
    elsif ($c eq 'seealso' || $c eq 'xref') {
	$s = "\#.xref $s";
    }
    elsif ($c eq 'key' || $c eq 'k') {
	# English
	if ($Lang eq 'ENGLISH') {
	    $key{$s} = $CurPosition if $s !~ /[\241-\376][\241-\376]/;
	}
	# Japanese
	else {
	    $key{$s} = $CurPosition;
	}

	if ($keylist{$s} !~ /$CurPosition/) {
	    $keylist{$s} .= "$CurPosition ";
	}

	$Manifest .= "key=$s\n$CurPosition";
	$Manifest .= "   $CurrentSubject\n";

	return '#.next';
    }
    elsif ($c eq 'label' || $c eq 'l') {
	# label is internal use, so we should split .l and .k ;-)

	if ($index{$s}) {
	    &Log("   $s already exists\tin \%index[$file::line=$.]");
	    &Log("      xref: $diag_index{$s}") ;
	}

	$diag_index{$s} = "$c $s($file::line=$.)";

	if ($mode eq 'text') {
	    $index{$s}  = $CurPosition;

	    if ($MakeIndex) {
		print STDERR "\$MakeIndex{$s} = $MakeIndex $CurPosition\n"
		    if $debug_make_index;
		$MakeIndex{$s} = "$MakeIndex $CurPosition";
	    }
	}
	elsif ($mode eq 'html') {
	    $index{$s}  = "</PRE>";
	    $index{$s} .= "<A HREF=\"$Chapter.html#C${Chapter}S${Section}\">";
	    $index{$s} .= "$Chapter.$Section</A>";
	    $index{$s} .= "<PRE>";
	    $In_PRE = 1;

	    if ($MakeIndex) {
		print STDERR "\$MakeIndex{$s} = $MakeIndex $CurPosition\n"
		    if $debug_make_index;
		$MakeIndex{$s} = "</PRE>".
		    "<A HREF=\"../$MakeIndex/$Chapter.html#C${Chapter}S${Section}\">".
			"../$MakeIndex $Chapter.$Section</A>".
			    "<PRE>";
	    }
	}
	elsif ($mode eq 'roff') {
	    $index{$s}  = "$Chapter.$Section"; 
	}

	return '#.next';
    }
    elsif ($c eq 'n') {
	if ($mode eq 'html') {
	    $s =~ s/\s//g;
	    $Index{'JAPANESE'} .= "<A NAME=\"$s\">\n";
	    $Index{'ENGLISH'}  .= "<A NAME=\"$s\">\n";
	}
	return; # ignore
    }


    $s;
}


sub HtmlSplitHere
{
    local($s, $not_cut) = @_;

    if ($not_cut) {
	"\n\#.CUT_SKIP:${HtmlDir}/$Chapter.html\n\n$s"; 
    } 
    else {
	# split after the tmpfile is generated;
	# $s     = "\#.CUT:${HtmlDir}/$Chapter.html\n<HR>\n$s";
	"\n\#.CUT:${HtmlDir}/$Chapter.html\n\n$s"; 
    }
}


sub PtrExpand
{
    local($k) = @_;
    local($x);

    &Log("PtrExpand::($k)   $k -> index[$index{$k}]") if $debug;

    if ((! $index{$k}) && (! $indexlist{$k})) {
	&Log("PtrExpand::Error($k)  {index,indexlist}[$k] -> NULL");
    }

    # $key{$k};
    $x = $index{$k};
    $x =~ s/<PRE>//g;
    $x =~ s/<\/PRE>//g;
    $x;
}


sub FigExpand
{
    local($k) = @_;

    &Log("FigExpand::($k)   $k -> figure_index[$figure_index{$k}]") if $debug;

    if (! $figure_index{$k}) {
	&Log("FigExpand::Error($k)  figure_index[$k] -> NULL");
    }

    # $key{$k};
    #"Fig. $figure_index{$k}";
    $figure_index{$k};
}


sub IndexExpand
{
    local($org, $r, $result, @index, $fyi);
    local($x, $show_only) = @_;

    $fyi = "See also: " unless $show_only;

    print STDERR "IndexExpand($x) => {\n" if $debug;

    # @index = split(/\s*[,\s{1,}]\s*/, $x);
    while ($x =~ s/,\s\s+/, /g) { 1;}
    @index = split(/\s+|\s*,\s+/, $x);
    foreach (@index) {
	$org = $_;
	$r = $index{$_} || $indexlist{$_} || $_;
	print STDERR $r if $debug;	    
	$result .= "$r ";

	if (index($r, $org) == 0) {
	    &Log(sprintf("%20s | %s", 
			 $org, "[$. lines] error? cannot expand"));
	    $Error = 1;
	}
    }

    print STDERR "\n}\n" if $debug;

    if ($mode eq 'html') {
	if ($InPre) {
	    $result =~ s#\<\/PRE\>\s*\<PRE\>\s*##;
	    $result =~ s#\<\PRE\>\s*\<\/PRE\>\s*##;
	    $result =~ s#\<\/PRE\>##;
	    $result =~ s#\<PRE\>\s*$##;
	}
	else {
	    $result =~ s#</PRE>#</PRE>$fyi#;
	}
	$result;
    }
    else {
	"$fyi$result";  # "Xref: $result";
    }

}


sub HtmlExpand
{
    local($_, $s, $file, $mode) = @_;

    print STDERR "HtmlExpand::($_, $s, $file, $mode);\n" if $debug;

    if (/~HTML_PRE/) {
	$s = "</PRE>\n";
	$In_PRE = 0;
    }
    elsif (/HTML_PRE/) {
	$s = "<PRE>";
	$In_PRE = 1;
    }

    $s;
}


# [\&\<\>]
sub ConvSpecialChars
{
    local(*s) = @_;

    if ($opt_v) {
	print STDERR "&ConvSpecialChars(\n$s\nIn_PRE=$In_PRE\n   )\n";
    }

    ### special character convertion
    &jcode'convert(*s, 'euc'); #';
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/\"/&quot;/g;
    &jcode'convert(*s, 'jis'); #';
    ### special character convertion ends
}


### Debug
sub Debug { print STDERR "@_\n";}


1;
