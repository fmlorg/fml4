#!/usr/local/bin/perl
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


require 'getopts.pl';
&Getopts("hd:b:m:M:t:vT:D:I:A:C:R:N:n:L:");


##### Config VARIABLES #####
$Chapter = $Section = 0;
$COMMENT = '^\.comment|^\.\#';
$KEYWORD = 'C|ST|S|C\.S|P|http|label|l|key|k|seealso|xref|A|ptr|url';
$FORMAT  = 'q|~q|appendix';
$HTML_KEYWORD = 'HTML_PRE|~HTML_PRE';

$BGColor   = "E6E6FA";# lavender ("E0FFFF" == lightcyan);

%Part = (1, 'I',
	 2, 'II',
	 3, 'III',
	 4, 'IV',
	 5, 'V',
	 6, 'VI',
	 7, 'VII',
	 8, 'X',
	 9, 'XI',
	 10, 'XII',
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

$Lang        = $opt_L || 'JAPANESE';

$Manifest    = ""; # log of label;

$TmpFile     = $opt_t || "$TmpDir/$$.fml";
$TmpFile_Eng = "$TmpDir/$$.fml-e";

$ManifestFile = $opt_M || "$TmpDir/MANIFEST";

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

    print STDERR "fwix generation mode:\t$mode (Language=$Lang)\n";

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
Copyright (C) 1993-1997 Ken'ichi Fukamachi
All rights of this page is reserved.

# This Document(html format) is automatically geneareted by fwix.pl. 
# fwix (Formatter of WIX Language) is fml document formatter system
# designed to generate plaintext, html, texinfo and nroff from one file.
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
</PRE>    
%;
}

sub Init
{
    if ($mode eq 'html') {
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
	     );
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

    print TMPF "\#.CUT:${HtmlDir}/index.html\n" if $mode eq 'html'; 
    print ENG  "\#.CUT:${HtmlDir}/index.html\n" if $mode eq 'html'; 

    print STDERR "---Open::($TmpFile $TmpFile_Eng)\n" if $verbose || $debug;
}


sub Print
{
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
    local($d, $f);
    local($fname) = $file;

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
	printf STDERR " --include %-40s  %s\n", $file,
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

	# language declared
	# reset Language if it encounters null line; 
	if (/^\s*$/ || /^\.($KEYWORD)/) {
	    undef $LANG;
	}

	# keywords
	$DetectKeyword = $. if /\.($KEYWORD)/;# EUC or English;

	if (/[\241-\376][\241-\376]/) {	# EUC(Japanese);
	    undef $LANG;
	    $DetectEUC = $.;	# save the current line;
	}
	elsif (!$LANG && !/^\.($KEYWORD)/) {# to avoid duplicate title;
	    $Both = 1;
	}
	
	if (/^=E/) { 
	    s/^=E//; 
	    $LANG = 'ENGLISH';
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


	/$COMMENT/i && next;                    # Comments
	/^\.DEBUG/o && ($debug = 1, next); 	# DEBUG MODE

	# FOOTNOTE
	# buffer alloc
	if (/\.fn\s*\{/ .. /^\.~fn/)  { 
	    if (/\.fn\s*\{/) {
		$FootNote++;
		s/\.fn\s*\{/\#\.fn${FootNote}/;
	    }
	    else {
		/^\.~fn/ && next;
		$FootNote{$FootNote} .= "$_\n";
		next;
	    }
	}

	# caption
	if (/\.caption/ .. /^\.~caption/)  { 
	    if (/\.caption/) {
		s/\.caption/\[Caption $Chapter.$Figure\] \{/;
	    }
	    else {
		s/^\.~caption/\}/;
	    }
	}


	### PATTERN
	
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

	# Exception ???
	s/\.(ptr|fig|ps)\s*\{(\S+)\}/&Expand($1, $2, $file, $mode)/ge;


	# NEXT
	next if /^\#.next/o;

	# INCLUDE; anyway including. we add ".CUT" commands to Temporary Files
	if (! $not_include) {
	    s/^\.include\s+(\S+)/&ReadFile($1, $dir || '.', $mode)/e;
	}

	# Handling Multiple Languages
	# TMPF == Japanese;
	if ($LANG eq 'ENGLISH') {
	    select(ENG); $| = 1;
	    &Print;
	}
	else {
	    select(TMPF); $| = 1;
	    &Print;
	}

	# OK. Print in both language
	# BUT if a null line is output between Japanese sentences.
	# a lot of null lines are printed.
	# "(! $LANG && !/\.($KEYWORD)/)" ALREADY satisfied 
	if ($Both) {
	    select(ENG); $| = 1;

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

	# Try to detect ERROR
	if ($mode ne 'roff') { /^\.(\S+)/ && &Log("Error?(${file} $.) ^.$1");}
    }# WHILE;

    close($file);

    select(STDOUT);

    "";
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
		print OUTHTML ($CurUrlPointer = &ShowPointer($1));
		print OUTHTML &CopyRight;
	    }

	    close(OUTHTML);
	    open(OUTHTML, "> $outfile") || die "$!\n";
	    select(OUTHTML); $| = 1;

	    print OUTHTML "<TITLE>$Title $name</TITLE>";
	    print OUTHTML "\n<BODY BGCOLOR=$BGColor>\n" if $BGColor;
	    # print OUTHTML $prev_url_pointer if $prev_url_pointer;

	    next;		# cut the line "^#.CUT";
	}

	s%\#\.fn(\d+)%<A HREF=footnote.html#footnote$1>* $1</A>%g;

	s%\#\.ps\{(\S+)\}%<A HREF=$1>$1</A>%i;
	s/\#\.fig\{(\S+)\}/&FigExpand($1)/gei;

	s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	s/^\#\.url\s+(.*)/&IndexExpand($1,1)/gei;
	s/^(\#\.index)/$Index{$Lang}/; 
	s/^=S//;

	print STDERR "   $prev   $_\n" if $Error; 
	$prev = $_;

	print OUTHTML $_;
    }

    close(OUTHTML);

    if (%FootNote) {
	print STDERR "   generating\t$HtmlDir/footnote.html\n";
	open(OUTHTML, "> ${HtmlDir}/footnote.html") || die "$!\n";
    
	print OUTHTML "<TITLE>FootNote</TITLE>\n";

	for (sort {$a <=> $b} keys %FootNote) {
	    print OUTHTML "<P>\n";
	    print OUTHTML "<A NAME=\"footnote$_\">* $_ </A>\n";
	    print OUTHTML "$FootNote{$_}\n\n";
	}

	print OUTHTML "\n\n";

	close(OUTHTML);
    }

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

    if ($mode eq 'html') {
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
	    s/^(\#\.index)/$Index{$Lang}/; 

	    print STDERR "   $prev   $_\n" if $Error; $prev = $_;
	    print OUTROFF $_;
	}

	close(OUTROFF);
    }
    elsif ($mode eq 'text') {
	$input = $Lang eq 'ENGLISH' ? 'ENG' : 'TMPF';

	while (<$input>) {
	    undef $Error;

	    s/\#\.fn(\d+)/*$1/g;
	    s/\#\.ps\{(\S+)\}/Figure $PostScript{$1}/i;
	    s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	    s/\#\.fig\{(\S+)\}/&FigExpand($1)/gei;
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^\#\.url\s+(.*)/&IndexExpand($1,1)/gei;
	    s/^(\#\.index)/$Index{$Lang}/; 
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
	s/^(\#\.index)/$Index{$Lang}/; 
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
	$r = "<PRE>"  if $mode eq 'html';
	$In_PRE = 1;
    }
    elsif ($c eq '~q') {	# destructor:-)
	undef $Tag;
	$r = "</PRE>" if $mode eq 'html';
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

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    local($ch) = $Chapter + 1;
	    local($se) = 0;
	    $Index{$CurLang} .= 
		"<HR><LI><H3><A HREF=\"$ch.html#C${ch}S${se}\">$s</A></H3>\n";
	    $s      = "<HR>\n<A NAME=\"C${ch}S${se}\">$s</A>\n";
	    $s     .= "<PRE>"; 	$In_PRE = 1;

	    $InPre++ unless $LANG;

	    &HtmlSplitHere(1);
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

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    $Index{$CurLang} .= "<HR><LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>";  	$In_PRE = 1;

	    &HtmlSplitHere();

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
# beth
	$s = &GetCurPosition."\t$s";

	if ($mt) {
	    $Index{$CurLang} .= "$s\n";
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

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    $Index{$CurLang} .= "<HR><LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>";  	$In_PRE = 1;

	    &HtmlSplitHere();
	}
	elsif ($mr) {
	    ;
	}

    }
    elsif ($c eq 'http') {
	;
    }
    elsif ($c eq 'url') {
	if ($mode eq 'html') {
	    $index{"url=$s"} = "<A HREF=$s>$s</A>";
	    $index{"url=$s"} = "</PRE>".$index{"url=$s"}."<PRE>" if $In_PRE;
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
	$key{$s} = $CurPosition;
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
	}
	elsif ($mode eq 'html') {
	    $index{$s}  = "</PRE>";
	    $index{$s} .= "<A HREF=\"$Chapter.html#C${Chapter}S${Section}\">";
	    $index{$s} .= "$Chapter.$Section</A>";
	    $index{$s} .= "<PRE>";
	    $In_PRE = 1;
	}
	elsif ($mode eq 'roff') {
	    $index{$s}  = "$Chapter.$Section"; 
	}

	return '#.next';
    }

    $s;
}


sub HtmlSplitHere
{
    local($not_cut) = @_;

    if ($not_cut) {
	$s = "\#.CUT_SKIP:${HtmlDir}/$Chapter.html\n\n$s"; 
    } 
    else {
	# split after the tmpfile is generated;
	# $s     = "\#.CUT:${HtmlDir}/$Chapter.html\n<HR>\n$s";
	$s = "\#.CUT:${HtmlDir}/$Chapter.html\n\n$s"; 
    }
}


sub PtrExpand
{
    local($k) = @_;

    &Log("PtrExpand::($k)   $k -> index[$index{$k}]") if $debug;

    if (! $index{$k}) {
	&Log("PtrExpand::Error($k)  index[$k] -> NULL");
    }

    # $key{$k};
    $index{$k};    
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

    print STDERR "IndexExpand: [$x] -> [" if $debug;

    @index = split(/\s*[,\s+]\s*/, $x);
    foreach (@index) {
	$org = $_;
	$r = $index{$_} || $_;
	print STDERR $r if $debug;	    
	$result .= "$r ";

	if (index($r, $org) == 0) {
	    &Log("[$. lines] error or not defined? $org => $r\n");
	    $Error = 1;
	}
    }

    print STDERR "]\n" if $debug;

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

    /~HTML_PRE/ && ($s = "</PRE>\n") && ($In_PRE = 0);
    /HTML_PRE/  && ($s = "<PRE>")    && ($In_PRE = 1);

    $s;
}


1;
