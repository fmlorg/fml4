#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

require 'getopts.pl';
&Getopts("hd:b:m:M:t:vT:D:I:A:C:R:N:n:L:");


##### Config VARIABLES #####
$Chapter = $Section = 0;
$COMMENT = '^\.comment|^\.\#';
$KEYWORD = 'C|ST|S|C\.S|P|http|label|l|key|k|seealso|xref|A|ptr';
$FORMAT  = 'q|~q';
$HTML_KEYWORD = 'HTML_PRE|~HTML_PRE';


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

$SIG{'HUP'}  = 'CleanUp';
$SIG{'INT'}  = 'CleanUp';
$SIG{'QUIT'} = 'CleanUp';
$SIG{'HUP'}  = 'CleanUp';
##### VARIABLES ENDS #####


##### MAIN #####
{
    local($mode) = $opt_b || $opt_m || 'text';

    if ($mode eq 'html') {
	$HtmlDir    || die "Required! \$HtmlDir Direcotry for the output of html files\n";	
	-d $HtmlDir || mkdir($HtmlDir, 0700);
    }

    print STDERR "MODE:\t$mode\n";
    &Init;
    &Formatter($mode);		# main;
}

&CleanUp;
exit 0;
##### MAIN ENDS #####


############################################################
##### Libraries #####
sub Init
{
    %Prog = ( 
	     'phase1:text', 'ReadFile',
	     'phase1:html', 'ReadFile',
	     'phase1:roff', 'ReadFile',

	     'phase2:text', 'OutputFile',
	     'phase2:html', 'OutputFile',
	     'phase2:roff', 'OutputFile',
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


sub ShowIndex
{
    print "\n\t\tINDEX\n\n";
    foreach $x (sort keys %key) {
	printf "%-40s   ...   %s\n", $x, $keylist{$x};
    }
}


sub LogManifest
{
    open(MANIFEST, "> $ManifestFile") || die $!;
    print MANIFEST $Manifest;
    close(MANIFEST);
}



# SIGNAL HANDER
# 1st argument is signal name
sub CleanUp 
{  
    local($sig) = @_;

    print STDERR "Caught a SIG$sig--shutting down\n" if $sig;

#    unlink $TmpFile;
#    unlink $TmpFile_Eng;

    exit(0);
}


# ALIASES
sub Log { print STDERR @_, "\n"; }


################################################################################
######### Libraries
################################################################################


################################################################################
### IO


sub Open4Write
{
    local($mode) = @_;

    open(TMPF, "> $TmpFile") || die($!);
    select(TMPF); $| = 1; select(STDOUT);

    open(ENG, "> $TmpFile_Eng") || die($!);
    select(ENG); $| = 1; select(STDOUT);

    print TMPF "\#.CUT:${HtmlDir}/index.html\n" if $mode eq 'html'; 
    print ENG  "\#.CUT:${HtmlDir}/index.html\n" if $mode eq 'html'; 
}


sub Open4Read
{
    print STDERR "Open4Read::($TmpFile)\n" if $debug;
    open(TMPF, $TmpFile)   || die $!;
    open(ENG, $TmpFile_Eng) || die $!;
}


sub OutputHtml
{
    local($IN) = @_;

    while (<$IN>) {
	undef $Error;

	if (/^\#\.CUT:(\S+)/) {
	    print STDERR ">>>$_\n";
	    $name = $outfile = $1;
	    $name =~ s#.*/##;
	    print STDERR "> $outfile\n";

	    close(OUTHTML);
	    open(OUTHTML, "> $outfile") || die "$!\n";
	    print OUTHTML "<TITLE>$Title $name</TITLE>";

	    next;		# cut the line "^#.CUT";
	}

	s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;

	s/^(\#\.index)/$Index{$Lang}/; 

	print STDERR "   $prev   $_\n" if $Error; $prev = $_;
	print OUTHTML $_;
    }

    close(OUTHTML);
}

sub OutputFile
{
    local($file, $dir, $mode) = @_;
    local($outfile, $prev);

    if ($mode eq 'html') {
	$Index = "<UL>\n$Index\n</UL>";

	&OutputHtml('TMPF');
	&OutputHtml('ENG');
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
		print OUTROFF ".SH $Title\n.SH $name\n";

		next;		# cut the line "^#.CUT";
	    }
	    s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^(\#\.index)/$Index{$Lang}/; 

	    print STDERR "   $prev   $_\n" if $Error; $prev = $_;
	    print OUTROFF $_;
	}

	close(OUTROFF);
    }
    elsif ($mode eq 'text') {
	$IN = $Lang eq 'ENGLISH' ? 'ENG' : 'TMPF';

	while (<$IN>) {
	    undef $Error;

	    s/\#\.ptr\{(\S+)\}/&PtrExpand($1)/gei;
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^(\#\.index)/$Index{$Lang}/; 

	    print STDERR "   $prev   $_\n" if $Error; $prev = $_;
	    print $_;
	}
    }
}


############################################################################


sub Format
{
    local($c, $s, $file, $mode) = @_;
    local($r) = '#.next';

    if ($s =~ /{(.*)}/) { $s = $1;}

    if ($c eq 'q') {
	$Tag = "    ";
	$r = "<PRE>"  if $mode eq 'html';
    }
    elsif ($c eq '~q') {	# destructor:-)
	undef $Tag;
	$r = "</PRE>" if $mode eq 'html';
    }

    $r;
}


sub FormatReset
{
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

########################
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

    ###  Part
    if ($c eq 'P') {
	&FormatReset;
	$CurrentSubject = $s;

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

	$Part++ unless $LANG;
	$s = "$Part{$Part}\t$s";

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    $Index{$CurLang} .= "<HR><LI><H3><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A></H3>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>\n";

	    # split after the tmpfile is generated;
	    # $s     = "\#.CUT:${HtmlDir}/$Chapter.html\n<HR>\n$s"; 

	    $InPre++ unless $LANG;
	}
	elsif ($mr) {
	    $s = ".SH\n$s\n";
	}


    }
    ###  Chapter
    elsif ($c eq 'C') {
	&FormatReset;
	$CurrentSubject = $s;

	$Chapter++ unless $LANG;
	$Section    = 0;
	$InAppendix = 0;

	$s = "$Chapter\t$s";

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    $Index{$CurLang} .= "<HR><LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>\n";

	    # split after the tmpfile is generated;
	    $s     = "\#.CUT:${HtmlDir}/$Chapter.html\n<HR>\n$s"; 

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
	    $s     .= "<PRE>\n";
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
	$InAppendix = 1;

	$Appendix = shift @AlpTable;
	$Section = 0;
	$s = "Appendix $Appendix\t$s";

	if ($mt) {
	    $Index{$CurLang} .= "\n$s\n";
	}
	elsif ($mh) {
	    ;
	}
	elsif ($mr) {
	    ;
	}

    }
    elsif ($c eq 'http') {
	;
    }
    elsif ($c eq 'key' || $c eq 'k') {
	$key{$s} = $CurPosition;
	$keylist{$s} .= "$CurPosition ";

	$Manifest .= "key=$s\n$CurPosition";
	$Manifest .= "   $CurrentSubject\n";
	return '#.next';
    }
    elsif ($c eq 'seealso' || $c eq 'xref') {
	$s = "\#.xref $s";
    }
    elsif ($c eq 'ptr') {
	$s = "\#.ptr{$s}";
    }
    elsif ($c eq 'label' || $c eq 'l') {
	if ($index{$s}) {
	    &Log("   $s already exists\tin \%index[$file::line=$.]");
	    &Log("      xref: $_index{$s}") ;
	}

	$_index{$s} = "$c $s($file::line=$.)";

	if ($mode eq 'text') {
	    $index{$s}  = $CurPosition;
	}
	elsif ($mode eq 'html') {
	    $index{$s} = 
		"</PRE><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$Chapter.$Section</A><PRE>";
	}
	elsif ($mode eq 'roff') {
	    $index{$s}  = "$Chapter.$Section"; 
	}

	return '#.next';
    }

    $s;
}


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
	printf STDERR "Including %-40s  %s\n", $file,
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

	# language declared
	# reset Language if it encounters null line; 
	if (/^\s*$/ || /\.($KEYWORD)/) {
	    undef $LANG;
	}

	if (/[\241-\376][\241-\376]/) {	# EUC(Japanese);
	    undef $LANG;
	}
	elsif (! $LANG && !/\.($KEYWORD)/) {# to avoid duplicate title;
	    $Both = 1;
	}
	
	if (/^=E/) { 
	    s/^=E//; 
	    $LANG = 'ENGLISH';
	}

	##########
	if (/\.($KEYWORD)/) {
	    $CurLang = $LANG || "JAPANESE";
	}


	/$COMMENT/i && next;                    # Comments
	/^\.DEBUG/o && ($debug = 1, next); 	# DEBUG MODE

	# PATTERN
	
	if (/^\.($HTML_KEYWORD)/) {
	    print STDERR "\tCATCH HTML($&)\n";
	    if ($mode eq 'html')  {
		s/^\.($HTML_KEYWORD)/($_  = &HtmlExpand($1, $2, $file, $mode)) || next/e;
	    }
	    else {
		next;		# skip .HTML.*
	    }
	}

	# seealso{guide}
	if (/\.($KEYWORD)\{(\S+)\}/) {
	    print STDERR "\tCATCH $1{$2}\n";
	    s/\.($KEYWORD)\{(\S+)\}/&Expand($1, $2, $file, $mode)/e;
	}

	s/^\.($KEYWORD)\s+(.*)/$_ = &Expand($1, $2, $file, $mode)/e;
	s/^\.($FORMAT)\s*(.*)/$_  = &Format($1, $2, $file, $mode)/e;



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
	if ($Both) {
	    select(ENG); $| = 1;
	    &Print;
	}

	# Try to detect ERROR
	if ($mode ne 'roff') { /^\.(\S+)/ && &Log("Error? ^.$1");}
    }# WHILE;

    close($file);

    select(STDOUT);

    "";
}

sub Print
{
    # Save the body
    if ($mode eq 'text') {
	print "$Tag$_\n";
    }
    elsif ($mode eq 'html') {
	print "$_\n";
    }
    elsif ($mode eq 'roff') {
	print "$_\n";
    }
}

sub PtrExpand
{
    local($k) = @_;
    print STDERR "PtrExpand::($k)   $k -> $key{$k}\n" if $debug;
    $key{$k};
}

sub IndexExpand
{
    local($org, $r, $result);
    local($X) = @_;
    local(@index) = split(/\s*[,\s+]\s*/, $X);

    print STDERR "[$X] -> [" if $debug;

    foreach (@index) {
	$org = $_;
	$r = $index{$_} || $_;
	print STDERR "$r " if $debug;	    
	$result .= "$r ";

	if (index($r, $org) == 0) {
	    &Log("[$. lines] error or not defined? $org => $r\n");
	    $Error = 1;
	}
    }

    print STDERR "]\n" if $debug;

    "See also: $result";
#    "Xref: $result";
}


sub HtmlExpand
{
    local($_, $s, $file, $mode) = @_;

    print STDERR "HtmlExpand::($_, $s, $file, $mode);\n";

    /~HTML_PRE/ && ($s = "</PRE>");
    /HTML_PRE/  && ($s = "<PRE>");

    $s;
}


1;
