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
$TmpDir      = (-d $ENV{'TMPDIR'} && $ENV{'TMPDIR'}) || './tmp'; 

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
Copyright (C) 1993-1999 Ken'ichi Fukamachi
All rights of this page is reserved.

# This Document(html format) is automatically geneareted by fwix.pl. 
# fwix (Formatter of WIX Language) is fml document formatter system
# designed to generate plaintext, html, texinfo and nroff from one file.
#
# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
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
    foreach $x (sort ci_sort keys %key) {
	printf "%-40s   ...   %s\n", $x, $keylist{$x};
    }
}


# case insensitive
sub ci_sort
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
	print TMPF "\#.CUT:$OUTPUT_FILE\n";
	print ENG  "\#.CUT:$OUTPUT_FILE\n";
    }
    elsif ($mode eq 'html') {
	print TMPF "\#.CUT:${HtmlDir}/index.html\n";
	print ENG  "\#.CUT:${HtmlDir}/index.html\n";
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
	;#; print TMPF "#.CUT:$HtmlDir/$fname\n";
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
	if (/^\.if\s+LANG\s*==\s*(\S+)/i) { 
	    $InIf = 1;
	    # print STDERR " \$TrueInIf = $Lang eq $1 ? 1 : 0;  \n";
	    $TrueInIf = $Lang eq $1 ? 1 : 0; 
	    next;
	}
	if (/^\.endif/i || /^\.~if/ || /^\.fi/) { 
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
			print STDERR "--Error: missing =E.[CSP]?\n";
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


sub GabbleUntil
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
		&POH(($CurUrlPointer = &ShowPointer($1)));
		&POH(&CopyRight) if $OnFml;
	    }

	    &POH("</BODY>\n");
	    &POH("</HTML>\n");
	    close(OUTHTML);
	    open(OUTHTML, "> $outfile") || die "$!\n";
	    select(OUTHTML); $| = 1;

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
		print STDERR "error: http-equiv lang=$Lang";
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
	    # &POH($prev_url_pointer) if $prev_url_pointer;

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

    close(OUTHTML);

    if (%FootNote) {
	print STDERR "   generating\t$HtmlDir/footnote.html\n";
	open(OUTHTML, "> ${HtmlDir}/footnote.html") || die "$!\n";
    
	&POH("<TITLE>FootNote</TITLE>\n");

	for (sort {$a <=> $b} keys %FootNote) {
	    &POH("<P>\n");
	    &POH("<A NAME=\"footnote$_\">* $_ </A>\n");
	    &POH("$FootNote{$_}\n\n");
	}

	&POH("\n\n");

	close(OUTHTML);
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

    print OUTHTML $s;
}


sub ShowPointer
{
    local($cur_n) = @_;
    local($s);

    $s .= "</PRE><HR>\n";


    if ($cur_n != 2) {
	$n = $cur_n - 2;
	$n = $PrevUrlPointer < $n ? $PrevUrlPointer : $n;

	# ignore -1
	if ($n > 0) {
	    $s .= "<A HREF=${n}.html>[PREVIOUS CHAPTER]</A>\n";
	}
    }

    print STDERR "   generating\t$outfile (prev-> $n, ";
    
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

	    print STDERR "==Error:\n- $prev\n+ $_\n" if $Error; 
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

	print STDERR "==Error:\n- $prev\n+ $_\n" if $Error; 
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
		$r = "<PRE>";
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
		$r = "</PRE>";
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
	print TMPF "</PRE>\n";
	print ENG  "</PRE>\n";
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
	    $Index{$CurLang} .= "<HR>\n<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>";  	$In_PRE = 1;

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
	    $Index{$CurLang} .= "<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
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
	    &Log("Error: $s is already assinged as $figure_index{$s}");
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
	    &Log("      xref: $_index{$s}") ;
	}

	$_index{$s} = "$c $s($file::line=$.)";

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
	"\#.CUT_SKIP:${HtmlDir}/$Chapter.html\n\n$s"; 
    } 
    else {
	# split after the tmpfile is generated;
	# $s     = "\#.CUT:${HtmlDir}/$Chapter.html\n<HR>\n$s";
	"\#.CUT:${HtmlDir}/$Chapter.html\n\n$s"; 
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
	$result =~ s#</PRE>#</PRE>$fyi#;
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

###
#:import: jcode.pl 2.6, see ftp.iij.ad.jp

package jcode;
;######################################################################
;#
;# jcode.pl: Perl library for Japanese character code conversion
;#
;# Copyright (c) 1995,1996,1997 Kazumasa Utashiro <utashiro@iij.ad.jp>
;# Internet Initiative Japan Inc.
;# 3-13 Kanda Nishiki-cho, Chiyoda-ku, Tokyo 101, Japan
;#
;# Copyright (c) 1992,1993,1994 Kazumasa Utashiro
;# Software Research Associates, Inc.
;#
;# Original version was developed under the name of srekcah@sra.co.jp
;# February 1992 and it was called kconv.pl at the beginning.  This
;# address was a pen name for group of individuals and it is no longer
;# valid.
;#
;# Use and redistribution for ANY PURPOSE, without significant
;# modification, is granted as long as all copyright notices are
;# retained.  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND
;# ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.
;#
;; $rcsid = q$Id$;
;#
;######################################################################
;#
;# INTERFACE:
;#
;#	&jcode'getcode(*line)
;#		Return 'jis', 'sjis', 'euc' or undef according to
;#		Japanese character code in $line.  Return 'binary' if
;#		the data has non-character code.
;#
;#		When evaluated in array context, it returns a list
;#		contains two items.  First value is the number of
;#		characters which matched to the expected code, and
;#		second value is the code name.  It is useful if and
;#		only if the number is not 0 and the code is undef, and
;#		the case means it couldn't tell 'euc' or 'sjis'
;#		because the evaluation score was exactly same.  This
;#		interface should be too tricky, though.
;#
;#		Code detection between euc and sjis is very difficult
;#		or sometimes impossible or even lead to wrong result
;#		when it's include JIS X0201 KANA characters.  So JIS
;#		X0201 KANA is ignored for automatic code detection.
;#
;#	&jcode'convert(*line, $ocode [, $icode [, $option]])
;#		Convert the line in any Japanese code to the specified
;#		code in the second argument $ocode.  $ocode can be any
;#		of "jis", "sjis" or "euc", or use "noconv" when you
;#		don't want the code conversion.  Input code is
;#		recognized automatically from the line itself when
;#		$icode is not supplied (JIS X0201 KANA is ignored.
;#		See above).  $icode also can be specified, but xxx2yyy
;#		routine is more efficient when both codes are known.
;#
;#		It returns a list of pointer of convert subroutine and
;#		input code.  It means that this routine returns the
;#		input code of the line in scalar context.
;#
;#		See next paragraph for $option parameter.
;#
;#	&jcode'xxx2yyy(*line [, $option])
;#		Convert the Japanese code from xxx to yyy.  String xxx
;#		and yyy are any convination from "jis", "euc" or
;#		"sjis".  They return *approximate* number of converted
;#		bytes.  So return value 0 means the line was not
;#		converted at all.
;#
;#		Optional parameter $option is used to specify optional
;#		conversion method.  String "z" is for JIS X0201 KANA
;#		to X0208 KANA, and "h" is for reverse.
;#
;#	$jcode'convf{'xxx', 'yyy'}
;#		The value of this associative array is pointer to the
;#		subroutine jcode'xxx2yyy().
;#
;#	&jcode'to($ocode, $line [, $icode [, $option]])
;#	&jcode'jis($line [, $icode [, $option]])
;#	&jcode'euc($line [, $icode [, $option]])
;#	&jcode'sjis($line [, $icode [, $option]])
;#		These functions are prepared for easy use of
;#		call/return-by-value interface.  You can use these
;#		funcitons in s///e operation or any other place for
;#		convenience.
;#
;#	&jcode'jis_inout($in, $out)
;#		Set or inquire JIS start and end sequences.  Default
;#		is "ESC-$-B" and "ESC-(-B".  If you supplied only one
;#		character, "ESC-$" or "ESC-(" is added as a prefix
;#		for each character respectively.  Acutually "ESC-(-B"
;#		is not a sequence to end JIS code but a sequence to
;#		start ASCII code set.  So `in' and `out' are somewhat
;#		misleading.
;#
;#	&jcode'get_inout($string)
;#		Get JIS start and end sequences from $string.
;#
;#	&jcode'cache()
;#	&jcode'nocache()
;#	&jcode'flush()
;#		Usually, converted character is cached in memory to
;#		avoid same calculations have to be done many times.
;#		To disable this caching, call &jcode'nocache().  It
;#		can be revived by &jcode'cache() and cache is flushed
;#		by calling &jcode'flush().  &cache() and &nocache()
;#		functions return previous caching state.
;#
;#	---------------------------------------------------------------
;#
;#	&jcode'h2z_xxx(*line);
;#		JIS X0201 KANA (so-called Hankaku-KANA) to X0208 KANA
;#		(Zenkaku-KANA) code conversion routine.  String xxx is
;#		any of "jis", "sjis" and "euc".  From the difficulty
;#		of recognizing code set from 1-byte KATAKANA string,
;#		automatic code recognition is not supported.
;#
;#	&jcode'z2h_xxx(*line);
;#		X0208 to X0201 KANA code conversion routine.  String
;#		xxx is any of "jis", "sjis" and "euc".
;#
;#	$jcode'z2hf{'xxx'}
;#	$jcode'h2zf{'xxx'}
;#		These are pointer to the corresponding function just
;#		as $jcode'convf.
;#
;#	---------------------------------------------------------------
;#
;#	&jcode'tr(*line, $from, $to [, $option]);
;#		&jcode'tr emulates tr operator for 2 byte code.  Only 'd'
;#		is interpreted as option.
;#
;#		Range operator like `A-Z' for 2 byte code is partially
;#		supported.  Code must be JIS or EUC, and first byte
;#		should be same on first and last character.
;#
;#		CAUTION: Handling range operator is a kind of trick
;#		and it is not perfect.  So if you need to transfer `-' 
;#		character, please be sure to put it at the beginning
;#		or the end of $from and $to strings.
;#
;#	&jcode'trans($line, $from, $to [, $option);
;#		Same as &jcode'tr but accept string and return string
;#		after translation.
;#
;#	---------------------------------------------------------------
;#
;#	&jcode'init()
;#		Initialize the variables used in other functions.  You
;#		don't have to call this when using jocde.pl by do or
;#		require.  Call it first if you embedded the jcode.pl
;#		in your script.
;#
;######################################################################
;#
;# SAMPLES
;#
;# Convert any Kanji code to JIS and print each line with code name.
;#
;#	while (<>) {
;#	    $code = &jcode'convert(*_, 'jis');
;#	    print $code, "\t", $_;
;#	}
;#	
;# Convert all lines to JIS according to the first recognized line.
;#
;#	while (<>) {
;#	    print, next unless /[\033\200-\377]/;
;#	    (*f, $icode) = &jcode'convert(*_, 'jis');
;#	    print;
;#	    defined(&f) || next;
;#	    while (<>) { &f(*_); print; }
;#	    last;
;#	}
;#
;# The safest way of JIS conversion.
;#
;#	while (<>) {
;#	    ($matched, $code) = &jcode'getcode(*_);
;#	    print, next unless (@buf || $matched);
;#	    push(@readahead, $_);
;#	    next unless $code;
;#	    eval "&jcode'${code}2jis(*_), print while (\$_ = shift(\@buf));";
;#	    eval "&jcode'${code}2jis(*_), print while (\$_ = <>);";
;#	    last;
;#	}
;#		
;######################################################################

;#
;# Call initialize function if it is not called yet.  This may sound
;# strange but it makes easy to embed the jcode.pl at the end of
;# script.  Call &jcode'init at the beginning of the script in that
;# case.
;#
&init unless defined $version;

;#
;# Initialize variables.
;#
sub init {
    $version = $rcsid =~ /,v ([\d.]+)/ ? $1 : 'unkown';

    $re_bin  = '[\000-\006\177\377]';

    $re_jis1978 = '\e\$\@';
    $re_jis1983 = '\e\$B';
    $re_jis1990 = '\e&\@\e\$B';
    $re_jp = "$re_jis1978|$re_jis1983|$re_jis1990";

    $re_asc = '\e\([BJ]';
    $re_kana = '\e\(I';
    ($esc_jp, $esc_asc, $esc_kana) = ("\e\$B", "\e(B", "\e(I");

    $re_sjis_c = '[\201-\237\340-\374][\100-\176\200-\374]';
    $re_sjis_kana = '[\241-\337]';

    $re_euc_c = '[\241-\376][\241-\376]';
    $re_euc_kana = '\216[\241-\337]';

    # These variables are retained only for backward compatibility.
    $re_euc_s = "($re_euc_c)+";
    $re_sjis_s = "($re_sjis_c)+";

    $cache = 1;

    # X0201 -> X0208 KANA conversion table.  Looks weird?  Not that
    # much.  This is simply JIS text without escape sequences.
    ($h2z_high = $h2z = <<'__TABLE_END__') =~ tr/\021-\176/\221-\376/;
!	!#	$	!"	%	!&	"	!V	#	!W
^	!+	_	!,	0	!<
'	%!	(	%#	)	%%	*	%'	+	%)
,	%c	-	%e	.	%g	/	%C
1	%"	2	%$	3	%&	4	%(	5	%*
6	%+	7	%-	8	%/	9	%1	:	%3
6^	%,	7^	%.	8^	%0	9^	%2	:^	%4
;	%5	<	%7	=	%9	>	%;	?	%=
;^	%6	<^	%8	=^	%:	>^	%<	?^	%>
@	%?	A	%A	B	%D	C	%F	D	%H
@^	%@	A^	%B	B^	%E	C^	%G	D^	%I
E	%J	F	%K	G	%L	H	%M	I	%N
J	%O	K	%R	L	%U	M	%X	N	%[
J^	%P	K^	%S	L^	%V	M^	%Y	N^	%\
J_	%Q	K_	%T	L_	%W	M_	%Z	N_	%]
O	%^	P	%_	Q	%`	R	%a	S	%b
T	%d			U	%f			V	%h
W	%i	X	%j	Y	%k	Z	%l	[	%m
\	%o	]	%s	&	%r	3^	%t
__TABLE_END__
    %h2z = split(/\s+/, $h2z . $h2z_high);
    %z2h = reverse %h2z;

    $_ = '';
    for $f ('jis', 'sjis', 'euc') {
	for $t ('jis', 'sjis', 'euc') {
	    $_ .= "\$convf{'$f', '$t'} = *${f}2${t};\n";
	}
	$_ .= "\$h2zf{'$f'} = *h2z_${f};\n\$z2hf{'$f'} = *z2h_${f};\n";
    }
    eval $_;
}

;#
;# Set escape sequences which should be put before and after Japanese
;# (JIS X0208) string.
;#
sub jis_inout {
    $esc_jp = shift || $esc_jp;
    $esc_jp = "\e\$$esc_jp" if length($esc_jp) == 1;
    $esc_asc = shift || $esc_asc;
    $esc_asc = "\e\($esc_asc" if length($esc_asc) == 1;
    ($esc_jp, $esc_asc);
}

;#
;# Get JIS in and out sequences from the string.
;#
sub get_inout {
    local($esc_jp, $esc_asc);
    $_[$[] =~ /$re_jp/o && ($esc_jp = $&);
    $_[$[] =~ /$re_asc/o && ($esc_asc = $&);
    ($esc_jp, $esc_asc);
}

;#
;# Recognize character code.
;#
sub getcode {
    local(*_) = @_;
    local($matched, $code);

    if (!/[\e\200-\377]/) {	# not Japanese
	$matched = 0;
	$code = undef;
    }				# 'jis'
    elsif (/$re_jp|$re_asc|$re_kana/o) {
	$matched = 1;
	$code = 'jis';
    }
    elsif (/$re_bin/o) {	# 'binary'
	$matched = 0;
	$code = 'binary';
    }
    else {			# should be 'euc' or 'sjis'
	local($sjis, $euc);

	$sjis += length($&) while /($re_sjis_c)+/go;
	$euc  += length($&) while /($re_euc_c)+/go;

	$matched = &max($sjis, $euc);
	$code = ('euc', undef, 'sjis')[($sjis<=>$euc) + $[ + 1];
    }
    wantarray ? ($matched, $code) : $code;
}
sub max { $_[ $[ + ($_[$[] < $_[$[+1]) ]; }

;#
;# Convert any code to specified code.
;#
sub convert {
    local(*_, $ocode, $icode, $opt) = @_;
    return (undef, undef) unless $icode = $icode || &getcode(*_);
    return (undef, $icode) if $icode eq 'binary';
    $ocode = 'jis' unless $ocode;
    $ocode = $icode if $ocode eq 'noconv';
    local(*convf) = $convf{$icode, $ocode};
    do convf(*_, $opt);
    (*convf, $icode);
}

;#
;# Easy return-by-value interfaces.
;#
sub jis  { &to('jis',  @_); }
sub euc  { &to('euc',  @_); }
sub sjis { &to('sjis', @_); }
sub to {
    local($ocode, $_, $icode, $opt) = @_;
    &convert(*_, $ocode, $icode, $opt);
    $_;
}
sub what {
    local($_) = @_;
    &getcode(*_);
}
sub trans {
    local($_) = shift;
    &tr(*_, @_);
    $_;
}

;#
;# SJIS to JIS
;#
sub sjis2jis {
    local(*_, $opt, $n) = @_;
    &sjis2sjis(*_, $opt) if $opt;
    s/($re_sjis_kana)+|($re_sjis_c)+/&_sjis2jis($&, $')/geo;
    $n;
}
sub _sjis2jis {
    local($_) = shift;
    local($post) = $_[$[] =~ /^($re_sjis_kana|$re_sjis_c)/o ? "" : $esc_asc;
    if (/^$re_sjis_kana/o) {
	$n += tr/\241-\337/\041-\137/;
	$esc_kana . $_ . $post;
    } else {
	$n += s/$re_sjis_c/$s2e{$&}||&s2e($&)/geo;
	tr/\241-\376/\041-\176/;
	$esc_jp . $_ . $post;
    }
}

;#
;# EUC to JIS
;#
sub euc2jis {
    local(*_, $opt, $n) = @_;
    &euc2euc(*_, $opt) if $opt;
    s/($re_euc_kana)+|($re_euc_c)+/&_euc2jis($&, $')/geo;
    $n;
}
sub _euc2jis {
    local($_) = shift;
    local($pre) = tr/\216//d ? $esc_kana : $esc_jp;
    local($post) = $_[$[] =~ /^($re_euc_kana|$re_euc_c)/o ? "" : $esc_asc;
    $n += tr/\241-\376/\041-\176/;
    $pre . $_ . $post;
}

;#
;# JIS to EUC
;#
sub jis2euc {
    local(*_, $opt, $n) = @_;
    s/($re_jp|$re_asc|$re_kana)([^\e]*)/&_jis2euc($1,$2)/geo;
    &euc2euc(*_, $opt) if $opt;
    $n;
}
sub _jis2euc {
    local($esc, $_) = @_;
    if ($esc !~ /$re_asc/o) {
	$n += tr/\041-\176/\241-\376/;
	s/[\241-\337]/\216$&/g if $esc =~ /$re_kana/o;
    }
    $_;
}

;#
;# JIS to SJIS
;#
sub jis2sjis {
    local(*_, $opt, $n) = @_;
    &jis2jis(*_, $opt) if $opt;
    s/($re_jp|$re_asc|$re_kana)([^\e]*)/&_jis2sjis($1,$2)/geo;
    $n;
}
sub _jis2sjis {
    local($esc, $_) = @_;
    if ($esc !~ /$re_asc/o) {
	$n += tr/\041-\176/\241-\376/;
	s/$re_euc_c/$e2s{$&}||&e2s($&)/geo if $esc =~ /$re_jp/o;
    }
    $_;
}

;#
;# SJIS to EUC
;#
sub sjis2euc {
    local(*_, $opt,$n) = @_;
    $n = s/$re_sjis_kana|$re_sjis_c/$s2e{$&}||&s2e($&)/geo;
    &euc2euc(*_, $opt) if $opt;
    $n;
}
sub s2e {
    local($c1, $c2, $code);
    ($c1, $c2) = unpack('CC', $code = shift);

    if (0xa1 <= $c1 && $c1 <= 0xdf) {
	$c2 = $c1;
	$c1 = 0x8e;
    } elsif (0x9f <= $c2) {
	$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
	$c2 += 2;
    } else {
	$c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
	$c2 += 0x60 + ($c2 < 0x7f);
    }
    if ($cache) {
	$s2e{$code} = pack('CC', $c1, $c2);
    } else {
	pack('CC', $c1, $c2);
    }
}

;#
;# EUC to SJIS
;#
sub euc2sjis {
    local(*_, $opt,$n) = @_;
    &euc2euc(*_, $opt) if $opt;
    $n = s/$re_euc_c|$re_euc_kana/$e2s{$&}||&e2s($&)/geo;
}
sub e2s {
    local($c1, $c2, $code);
    ($c1, $c2) = unpack('CC', $code = shift);

    if ($c1 == 0x8e) {
	return substr($code, 1, 1);
    } elsif ($c1 % 2) {
	$c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
	$c2 -= 0x60 + ($c2 < 0xe0);
    } else {
	$c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
	$c2 -= 2;
    }
    if ($cache) {
	$e2s{$code} = pack('CC', $c1, $c2);
    } else {
	pack('CC', $c1, $c2);
    }
}

;#
;# JIS to JIS, SJIS to SJIS, EUC to EUC
;#
sub jis2jis {
    local(*_, $opt) = @_;
    s/$re_jp/$esc_jp/go;
    s/$re_asc/$esc_asc/go;
    &h2z_jis(*_) if $opt =~ /z/;
    &z2h_jis(*_) if $opt =~ /h/;
}
sub sjis2sjis {
    local(*_, $opt) = @_;
    &h2z_sjis(*_) if $opt =~ /z/;
    &z2h_sjis(*_) if $opt =~ /h/;
}
sub euc2euc {
    local(*_, $opt) = @_;
    &h2z_euc(*_) if $opt =~ /z/;
    &z2h_euc(*_) if $opt =~ /h/;
}

;#
;# Cache control functions
;#
sub cache {
    ($cache, $cache = 1)[$[];
}
sub nocache {
    ($cache, $cache = 0)[$[];
}
sub flushcache {
    undef %e2s;
    undef %s2e;
}

;#
;# X0201 -> X0208 KANA conversion routine
;#
sub h2z_jis {
    local(*_, $n) = @_;
    if (s/$re_kana([^\e]*)/$esc_jp . &_h2z_jis($1)/geo) {
	1 while s/(($re_jp)[^\e]*)($re_jp)/$1/o;
    }
    $n;
}
sub _h2z_jis {
    local($_) = @_;
    $n += s/[\41-\137]([\136\137])?/$h2z{$&}/g;
    $_;
}

sub h2z_euc {
    local(*_) = @_;
    s/\216([\241-\337])(\216([\336\337]))?/$h2z{"$1$3"}/g;
}

sub h2z_sjis {
    local(*_, $n) = @_;
    s/(($re_sjis_c)+)|(([\241-\337])([\336\337])?)/
	$1 || ($n++, $e2s{$h2z{$3}} || &e2s($h2z{$3}))/geo;
    $n;
}

;#
;# X0208 -> X0201 KANA conversion routine
;#
sub z2h_jis {
    local(*_, $n) = @_;
    s/($re_jp)([^\e]+)/&_z2h_jis($2)/geo;
    $n;
}
sub _z2h_jis {
    local($_) = @_;
    s/(\%[!-~]|![\#\"&VW+,<])+|([^!%][!-~]|![^\#\"&VW+,<])+/&__z2h_jis($&)/ge;
    $_;
}
sub __z2h_jis {
    local($_) = @_;
    return $esc_jp . $_ unless /^%/ || /^![\#\"&VW+,<]/;
    $n += length($_) / 2;
    s/../$z2h{$&}/g;
    $esc_kana . $_;
}

sub z2h_euc {
    local(*_, $n) = @_;
    &init_z2h_euc unless defined %z2h_euc;
    s/$re_euc_c|$re_euc_kana/$z2h_euc{$&} ? ($n++, $z2h_euc{$&}) : $&/geo;
    $n;
}

sub z2h_sjis {
    local(*_, $n) = @_;
    &init_z2h_sjis unless defined %z2h_sjis;
    s/$re_sjis_c/$z2h_sjis{$&} ? ($n++, $z2h_sjis{$&}) : $&/geo;
    $n;
}

;#
;# Initializing JIS X0208 to X0201 KANA table for EUC and SJIS.  This
;# can be done in &init but it's not worth doing.  Similarly,
;# precalculated table is not worth to occupy the file space and
;# reduce the readability.  The author personnaly discourages to use
;# X0201 Kana character in the any situation.
;#
sub init_z2h_euc {
    local($k, $_);
    s/[\241-\337]/\216$&/g && ($z2h_euc{$k} = $_) while ($k, $_) = each %z2h;
}
sub init_z2h_sjis {
    local($_, $v);
    /[\200-\377]/ && ($z2h_sjis{&e2s($_)} = $v) while ($_, $v) = each %z2h;
}

;#
;# TR function for 2-byte code
;#
sub tr {
    # $prev_from, $prev_to, %table are persistent variables
    local(*_, $from, $to, $opt) = @_;
    local(@from, @to);
    local($jis, $n) = (0, 0);
    
    $jis++, &jis2euc(*_) if /$re_jp|$re_asc|$re_kana/o;
    $jis++ if $to =~ /$re_jp|$re_asc|$re_kana/o;

    if ($from ne $prev_from || $to ne $prev_to) {
	($prev_from, $prev_to) = ($from, $to);
	undef %table;
	&_maketable;
    }

    s/[\200-\377][\000-\377]|[\000-\377]/
	defined($table{$&}) && ++$n ? $table{$&} : $&/ge;

    &euc2jis(*_) if $jis;

    $n;
}

sub _maketable {
    local($ascii) = '(\\\\[\\-\\\\]|[\0-\133\135-\177])';

    &jis2euc(*to) if $to =~ /$re_jp|$re_asc|$re_kana/o;
    &jis2euc(*from) if $from =~ /$re_jp|$re_asc|$re_kana/o;

    grep(s/([\200-\377])[\200-\377]-\1[\200-\377]/&_expnd2($&)/ge, $from, $to);
    grep(s/$ascii-$ascii/&_expnd1($&)/geo, $from, $to);

    @to   = $to   =~ /[\200-\377][\000-\377]|[\000-\377]/g;
    @from = $from =~ /[\200-\377][\000-\377]|[\000-\377]/g;
    push(@to, ($opt =~ /d/ ? '' : $to[$#to]) x (@from - @to)) if @to < @from;
    @table{@from} = @to;
}

sub _expnd1 {
    local($_) = @_;
    s/\\(.)/$1/g;
    local($c1, $c2) = unpack('CxC', $_);
    if ($c1 <= $c2) {
	for ($_ = ''; $c1 <= $c2; $c1++) {
	    $_ .= pack('C', $c1);
	}
    }
    $_;
}

sub _expnd2 {
    local($_) = @_;
    local($c1, $c2, $c3, $c4) = unpack('CCxCC', $_);
    if ($c1 == $c3 && $c2 <= $c4) {
	for ($_ = ''; $c2 <= $c4; $c2++) {
	    $_ .= pack('CC', $c1, $c2);
	}
    }
    $_;
}


1;
