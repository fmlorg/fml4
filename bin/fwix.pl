#!/usr/local/bin/perl

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

require 'getopts.pl';
&Getopts("hd:b:m:M:t:vT:D:I:A:C:R:N:n:");


##### VARIABLES #####
$Chapter = $Section = 0;
$COMMENT = '^\.comment|^\.\#';
$KEYWORD = 'C|ST|S|C\.S|P|http|label|l|key|k|seealso|xref|A';
$FORMAT  = 'q|~q';

$HTML_KEYWORD = 'HTML_PRE|HTML_ENDPRE';

# Alphabetical Order Table
for('A'..'Z') { push(@AlpTable, $_);}


$|        = 1;
$no_index = 1 if $opt_n eq 'i';
$debug    = $opt_v; 
$Author   = $opt_I;
$Copyright = $opt_C;
$DIR      = $opt_d || $opt_I;
$HTML_DIR = $opt_D;
$ROFF_DIR = $opt_R;
$Title    = $opt_T || "NONE TITLE";
$TMPDIR   = (-d $ENV{'TMPDIR'} && $ENV{'TMPDIR'}) || './tmp'; # this order is correct.
-d $TMPDIR || mkdir($TMPDIR, 0700);


$TMPF          = $opt_t || "$TMPDIR/$$.fml";
$TMP_ENG       = "$TMPDIR/$$.fml-e";
$MANIFEST_FILE = $opt_M || "$TMPDIR/MANIFEST";


$SIG{'HUP'}  = 'handler';
$SIG{'INT'}  = 'handler';
$SIG{'QUIT'} = 'handler';
$SIG{'HUP'}  = 'handler';
##### VARIABLES ENDS #####


##### MAIN #####
{
    local($mode) = $opt_b || $opt_m || 'text';

    if ($mode eq 'html') {
	$HTML_DIR    || die "Required! \$HTML_DIR Direcotry for the output of html files\n";	
	-d $HTML_DIR || mkdir($HTML_DIR, 0700);
    }

    print STDERR "MODE:\t$mode\n";
    &Init;
    &Formatter($mode);		# main;
}

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


    ### PHASE 02:
    $Prog = $Prog{"phase2:$mode"};
    &Open4Read;
    &$Prog($_, ($DIR || $dir || '.'), $mode);
    close(TMPF);

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
	printf "%-50s   ...   %s\n", $x, $key{$x};
    }
}


sub LogManifest
{
    open(MANIFEST, "> $MANIFEST_FILE") || die $!;
    print MANIFEST $MANIFEST;
    close(MANIFEST);
}



# SIGNAL HANDER
# 1st argument is signal name
sub handler 
{  
    local($sig) = @_;

    print STDERR "Caught a SIG$sig--shutting down\n";

    unlink $TMPF;
    unlink $TMP_ENG;

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

    open(TMPF, "> $TMPF") || die($!);
    select(TMPF); $| = 1; select(STDOUT);

    open(ENG, "> $TMP_ENG") || die($!);
    select(ENG); $| = 1; select(STDOUT);

    print TMPF "\#.CUT:${HTML_DIR}/index.html\n" if $mode eq 'html'; 
    print ENG  "\#.CUT:${HTML_DIR}/index.html\n" if $mode eq 'html'; 
}


sub Open4Read
{
    open(TMPF, $TMPF)   || die $!;
    open(ENG, $TMP_ENG) || die $!;
}


sub OutputFile
{
    local($file, $dir, $mode) = @_;
    local($outfile);

    if ($mode eq 'html') {
	$INDEX = "<UL>\n$INDEX\n</UL>";

	while (<TMPF>) {
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

	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^(\#\.index)/$INDEX/; 

	    print OUTHTML $_;
	}

	close(OUTHTML);
    }
    elsif ($mode eq 'roff') {
	print ".SH\n$Copyright\n" if $Copyright;
	while (<TMPF>) {
	    if (/^\#\.CUT:(\S+)/) {
		$name = $outfile = $1;
		$name =~ s#.*/##;
		print STDERR "> $outfile\n";

		close(OUTROFF);
		open(OUTROFF, "> $outfile") || die "$!\n";
		print OUTROFF ".SH $Title\n.SH $name\n";

		next;		# cut the line "^#.CUT";
	    }

	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^(\#\.index)/$INDEX/; 

	    print OUTROFF $_;
	}

	close(OUTROFF);
    }
    elsif ($mode eq 'text') {
	while (<TMPF>) {
	    s/^\#\.xref\s+(.*)/&IndexExpand($1)/gei;
	    s/^(\#\.index)/$INDEX/; 
	    print $_;
	}
    }
}


################################################################################
### 


sub Format
{
    local($c, $s, $file, $mode) = @_;
    local($r) = '#.next';

    if ($s =~ /{(.*)}/) { $s = $1;}

    if ($c eq 'q') {
	$TAG = "    ";
	$r = "<PRE>"  if $mode eq 'html';
    }
    elsif ($c eq '~q') {	# destructor:-)
	undef $TAG;
	$r = "</PRE>" if $mode eq 'html';
    }

    $r;
}


sub FormatReset
{
    undef $TAG;
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

	$Part++;
	$s = "$Part{$Part}\t$s";

	if ($mt) {
	    $INDEX .= "\n$s\n";
	}
	elsif ($mh) {
	    $INDEX .= "<HR><LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>\n";

	    # split after the tmpfile is generated;
	    $s     = "\#.CUT:${HTML_DIR}/$Chapter.html\n<HR>\n$s"; 

	    $InPre++;
	}
	elsif ($mr) {
	    $s = ".SH\n$s\n";
	}


    }
    ###  Chapter
    elsif ($c eq 'C') {
	&FormatReset;
	$CurrentSubject = $s;

	$Chapter++;
	$Section    = 0;
	$InAppendix = 0;

	$s = "$Chapter\t$s";

	if ($mt) {
	    $INDEX .= "\n$s\n";
	}
	elsif ($mh) {
	    $INDEX .= "<HR><LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<HR>\n<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>\n";

	    # split after the tmpfile is generated;
	    $s     = "\#.CUT:${HTML_DIR}/$Chapter.html\n<HR>\n$s"; 

	    $InPre++;
	}
	elsif ($mr) {
	    $s = ".SH\n$s\n";
	}

    }
    elsif ($c eq 'S' || $c eq 'C.S') {
	&FormatReset;
	$CurrentSubject = $s;

	$Section++;
	$s = &GetCurPosition."\t$s";

	if ($mt) {
	    $INDEX .= "$s\n";
	}
	elsif ($mh) {
	    $INDEX .= "<LI><A HREF=\"$Chapter.html#C${Chapter}S${Section}\">$s</A>\n";
	    $s      = "<A NAME=\"C${Chapter}S${Section}\">$s</A>\n";
	    $s     .= "<PRE>\n";
	    $InPre++;
	}
	elsif ($mr) {
	    $s = ".SH\t$s\n";
	}

    }
    elsif ($c eq 'ST') {
	$CurrentSubject .= $s;

	$s = "\t$s";
	$INDEX .= "$s\n";
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
	    $INDEX .= "\n$s\n";
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
	$MANIFEST .= "key=$s\n$CurPosition";
	$MANIFEST .= "   $CurrentSubject\n";
	return '#.next';
    }
    elsif ($c eq 'seealso' || $c eq 'xref') {
	$s = "\#.xref $s";
    }
    elsif ($c eq 'label' || $c eq 'l') {
	&Log("$s already exists\tin \%index[$.]\n  ALREADY $_index{$s}") 
	    if $index{$s};
	$_index{$s} = "$c $s($.)";

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
	print STDERR "Including $file\n";
	open($file, $file) || &Log("cannot open $file");
    }
    elsif ("$dir/$file" && -f "$dir/$file") {
	$file = "$dir/$file";
	print STDERR "Including $file\n";
	open($file, $file) || &Log("cannot open $file");
    }
    else {
	$file = 'STDIN';
	print STDERR "Including $file\n";
    }


    ### split after the tmpfile is generated;
    if ($mode eq 'html') {
	;#; print TMPF "#.CUT:$HTML_DIR/$fname\n";
    }
    elsif ($mode eq 'roff') {
	$fname =~ s/\.wix/.1/;
	print TMPF "#.CUT:$ROFF_DIR/$fname\n";
	print ENG  "#.CUT:$ROFF_DIR/$fname\n";
    }


    while (<$file>) {
	chop;

	/$COMMENT/i && next;                    # Comments
	/^\.DEBUG/o && ($debug = 1, next); 	# DEBUG MODE

	# PATTERN
	
	if (/^\.($HTML_KEYWORD)/) {
	    if ($mode eq 'html')  {
		s/^\.($HTML_KEYWORD)/($_  = &HtmlExpand($1, $2, $file, $mode)) || next/e;
	    }
	    else {
		next;		# skip .HTML.*
	    }
	}

	s/^\.($KEYWORD)\s+(.*)/$_ = &Expand($1, $2, $file, $mode)/e;
	s/^\.($FORMAT)\s*(.*)/$_  = &Format($1, $2, $file, $mode)/e;



	# NEXT
	next if /^\#.next/o;

	# INCLUDE; anyway including. we add ".CUT" commands to Temporary Files
	s/^\.include\s+(\S+)/&ReadFile($1, $dir || '.', $mode)/e;

	select(TMPF);

	# Save the body
	if ($mode eq 'text') {
	    print $TAG;
	    print "$_\n";
	}
	elsif ($mode eq 'html') {
	    print "$_\n";
	}
	elsif ($mode eq 'roff') {
	    print "$_\n";
	}


	# Try to detect ERROR
	if ($mode ne 'roff') { /^\.(\S+)/ && &Log("Error? ^.$1");}
    }# WHILE;

    close($file);

    select(STDOUT);

    "";
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
	    &Log("[$. lines] MISS HIT? when try s/$org/$r/\n");
	}
    }

    print STDERR "]\n" if $debug;

    "See also: $result";
#    "Xref: $result";
}


sub HtmlExpand
{
    local($_, $s, $file, $mode) = @_;

    /HTML_PRE/     && ($s = "<PRE>");
    /HTML_ENDPRE/  && ($s = "</PRE>");

    $s;
}


1;
