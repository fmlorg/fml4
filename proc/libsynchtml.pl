# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

### Syncronization of spool and html files directory
# Obsolete SyncHtml.ph 
#   $DEFALUT_EXPIRE = 10;
#   $title = "Index of Seminars";
#   @keyword   = 
#   ('non-linear', 'comp', 'material', 'hp', 'misc', 'book', 'info');
# 
#
# &SyncHtml($SPOOL_DIR, $ID, *Envelope)
# 
# if ($HTML_EXPIRE_LIMIT == 0) { NOT do EXPIRE, ONLY APPEND;}
# 
# return NONE
sub SyncHtml
{
    local($dir, $file, *e) = @_;
    local($id, $subdir, $title, $list, $mtime, $probe, $li, $html_dir);
    local($remake_index, $subdir_first_time);

    # import
    $SyncHtml'debug = 1 if $main'debug;

    # save $HTML_DIR information for later use (e.g. expire);
    $html_dir = $dir;

    # $ID is the result of Distribution (&Distribute);
    # WE REQUIRE DEFINED $ID -> $file;
    return unless $file;

    umask (002);# since nobody reads files in the HTML Directories;

    ### Init ###
    # Original SyncHtml is the Converter2Html of the memory image.
    # so $mtime (by stat()) NOT REQUIRED
    # IF YOU CONVERT THE ARTICLE, stat() info REQUIRED
    $mtime = $e{'stat:mtime'} if $e{'stat:mtime'};
    $probe = $e{'html:probe'};

    # INIT THE UNIT;
    $HTML_INDEX_UNIT = $HTML_INDEX_UNIT || 'day';

    # MIME Decoding, suggested by domeki@trd.tmg.nec.co.jp, thanks
    &use('MIME') if $USE_MIME;
    require 'jcode.pl';

    # html root directory
    # here you can only operate html'nized directories
    # but nobody read these
    -d $dir || &Mkdir($dir, 0755);

    # Stylesheet example
    if (! -f "$html_dir/fml.css") {
	local($f) = &SearchFileInLIBDIR("etc/makefml/fml.css");
	if ($f) { 
	    &Copy($f, "$html_dir/fml.css") && 
		&Log("create stylesheet example in $html_dir");
	}
    }

    ### Init ENDS ###

    ### Recursive Html Structure ###
    if ($HTML_INDEX_UNIT) { # HTML_INDEX_UNIT;
	($id, $li) = &SyncHtmlGenDirId($mtime);

	# id generation (probe or not)
	$title  = "ML SPOOL split by the unit '$HTML_INDEX_UNIT' $ML_FN";
	$subdir = "$dir/$id";

	### When htdocs/$subdir OK, but htdocs/index.html is an error case.
	# when $subdir already exists, check possible errors.
	# 
	# for expire 
	if (-d $subdir) {
	    # $id (HREF of $subdir) is included in top_dir index.html ? 
	    # index.html must exist. If not, it must be an error.
	    if (-f "$html_dir/index.html" &&
		(! &Grep($id, "$html_dir/index.html"))) { 
		&Log("Warning: $id is not in $html_dir/index.html") if $debug_html;
		$remake_index = 1; # expire flag (irrespective of first time)
	    }
	    elsif (!-f "$html_dir/index.html") {
		$remake_index = 1;
	    }

	    # Error? or First Time?
	    if (! -f "$subdir/index.html" &&
		!$RequireReGenerateIndex{$id}) {
		&Log("no index.html in $subdir");
		$RequireReGenerateIndex{$id} = $id;
	    }
	}
	# first time
	else {
	    $subdir_first_time = 1;
	    $e{'tmp:subdir_first_time'} = 1;
	}

	########################
	# (not probe) Reconfigure TOP Directory index.html if not exits
	if ((!$probe) || $remake_index) {
	    # here you can only operate html'nized directories
	    # but nobody read these
	    -d $subdir || &Mkdir($subdir, 0755);

	    # make the index.html in $dir (e.g. htdocs/index.html)
	    # that is TOP_DIR Reconfiguration here.
	    # * top directory recreatrion is done as follows:
	    #   RemakeIndex -> ReConfigureIndex -> htdocs/{index,thread}.html
	    # 
	    # <TITLE>$title</TITLE> <UL> <LI><A HREF=..>$li</A>
	    # 
	    # "! -f" implies THE FIRST TIME or ERROR(index.html missing) 

	    if ((! -f "$subdir/index.html") || $remake_index) {
		&SyncHtml'RemakeIndex('index', $dir, "$id/index", $title, $li, *e); #';
	    }

	    if ($HTML_THREAD && 
		((! -f "$subdir/thread.html") || $remake_index)) {
		&SyncHtml'RemakeIndex('thread', $dir, "$id/thread", $title, $li, *e); #'
	    }
	} # not probe;

	###
	### Here after default directory is $subdir (e.g. htdocs/subdir/) ###
	###
	$dir   = $subdir;
	$title = $li;
    }
    else {
	&Log("Error: \$HTML_INDEX_UNIT is not defined");
	return 0;
    }

    ### PROBE ONLY (PROBE ONLY ENDS HERE) ###
    if ($probe) {
	undef $e{'html:probe'}; 
	return (-f "$dir/$file.html" ? 1 : 0);
    }
    ######################################################


    ### Recursive Html Structure ends ###
    ### 
    ### $dir is already "htdocs/19990913"
    ### 

    # cache on
    local($cache)    = $HTML_DATA_CACHE  || ".indexcache";
    local($thread)   = $HTML_DATA_THREAD || ".thread";
    $HtmlDataCache   = "$dir/$cache";
    $HtmlThreadCache = "$dir/$thread";

    # touch
    for ($HtmlDataCache, $HtmlThreadCache) { &Touch($_) unless -f $_;}
	
    # Initialize
    &SyncHtml'Init;#';

    # for subdir
    # return $li of the title of "htdocs/19990913/ID.html"
    # $li is used "<LI><A HREF=ID.html>ID</A>" 
    # for "htdocs/19990913/index.html"
    # 
    &SyncHtml'Write($dir, $file, *li, *e) || return; #';

    # reconfig "htdocs/19990913/index.html"
    &SyncHtml'Configure($dir, $file, $title, $li, *e); #';

    # [Expiration Call]
    # NEW EXPIRATION ALGORITHM:
    #     When the thread is used, to expire one file is difficult.
    #     It is too difficult to adjust the relations of thread regenation.
    #     Hence we remove whole the sub-directories in which 
    #     all the files are expired. WE DO NOT REMOVE EACH FILE.
    #     
    #   1 Check all files in the directory (e.g. htdocs/19970721)
    #   2 If all should be expired, rename directory -> directory.expire
    #   3 htdocs/{index,thread}.html is reconfigured
    #     ignoring *.expire directories.
    #   4 after this, *.expire directories is of no use.
    #     So, we remove them in the future or now:) slowly.
    # 
    # always calling is out of use.
    if ($HTML_EXPIRE_LIMIT > 0 || $HTML_EXPIRE > 0) {
	# "try once 10 articles" is valid?
	# suppose 50 articles /day
 	$HTML_EXPIRE_LIMIT = $HTML_EXPIRE unless $HTML_EXPIRE_LIMIT;
	$unit = $HTML_EXPIRE_SCAN_UNIT || int($HTML_EXPIRE_LIMIT*50/10) || 1;

	&Log("html expire ($ID % $unit) == 0") if $debug;
	if (($ID % $unit) == 0 || $ForceHtmlExpire) {
	    &SyncHtml'Expire($html_dir, $file, *e); #';
	}
    }

    # O.K. remove *.expire in fact;
    &SyncHtml'Remove($html_dir, *e); #';

    # For adjustment for the first time for $id or error, try to
    # reconfig "htdocs/index.html". where $id is for "htdocs/$id/index.html".
    # It is a trick to use probe mode, since probe mode is a probe but 
    # is used to adjust the htdocs/ if required.
    if (! &Grep($id, "$html_dir/index.html")) {
	&Debug("no $id in index.html, reconfig") if $debug;
	$e{'html:probe'} = 1;
	&SyncHtml($html_dir, $file, *e);
	$e{'html:probe'} = 0;
    }
}


sub SyncHtmlProbeOnly
{
    local($dir, $file, *e) = @_;
    $e{'html:probe'} = 1;
    &SyncHtml($dir, $file, *e);
}


sub SyncHtmlReGenerateIndex
{
    local($dir, $file, *e) = @_;
    local($html_dir);

    # save $HTML_DIR information for later use (e.g. expire);
    $html_dir = $dir;

    # cache on
    local($cache)    = $HTML_DATA_CACHE  || ".indexcache";
    local($thread)   = $HTML_DATA_THREAD || ".thread";

    for $id (keys %RequireReGenerateIndex) {
	next unless $RequireReGenerateIndex{$id};
	next if -f "$html_dir/$id/index.html";

	$dir = "$html_dir/$id";

	$HtmlDataCache   = "$dir/$cache";
	$HtmlThreadCache = "$dir/$thread";

	# Initialize
	&SyncHtml'Init;#';

	&Log("RequireReGenerateIndex: $id");
	&SyncHtml'Configure("$html_dir/$id", $file, $title, $li, *e); #';
	undef $RequireReGenerateIndex{$id};
    }
}


sub SyncHtmlExpire
{
    local($dir, $file, *e) = @_;

    # Initialize
    &SyncHtml'Init;#';

    &SyncHtml'Expire(@_); #';

    # O.K. remove *.expire in fact;
    &SyncHtml'Remove($html_dir, *e); #';
}


sub SyncHtmlGenDirId
{
    local($mtime) = @_;
    local($id, $li, $mday, $mon, $year, $wday, $time);
    local($first, $last);

    # "anyway" determine the "present time"
    # (ignoring the boundary between days, weeks, and years).
    $mtime = $mtime ? $mtime : time;
    ($mday, $mon, $year, $wday) = (localtime($mtime))[3..6];
    $mon++;

    if ($HTML_INDEX_UNIT =~ /^\d+$/) { 
	$id     = int($ID/$HTML_INDEX_UNIT) * $HTML_INDEX_UNIT;
	$first  = $id > 0 ? $id : 1;
	$last   = $id + $HTML_INDEX_UNIT - 1;

	# Reconfigure TOP Directory index.html when mkdir ..
	$li     = "Count $first -- $last";
    }
    elsif ($HTML_INDEX_UNIT eq 'day') {
	$id = sprintf("%04d%02d%02d", 1900 + $year, $mon, $mday);
	$li = "in $year/$mon/$mday";
    }
    elsif ($HTML_INDEX_UNIT eq 'week') { # wday == 0 (sunday)
	# search the last Sunday;
	local($f_mday, $f_mon, $f_year, $l_mday, $l_mon, $l_year);
	local($s_time)    = $mtime - 3600*24*$wday;
	local($week_unit) = 24*3600*6;

	($f_mday, $f_mon, $f_year) = (localtime($s_time))[3..5];
	($l_mday, $l_mon, $l_year) = (localtime($s_time + $week_unit))[3..5];
	$f_mon++;
	$l_mon++;

	$id = sprintf("%04d%02d%02d.week", 1900 + $f_year, $f_mon, $f_mday);
	$li = "in the week $f_year/$f_mon/$f_mday -- $l_year/$l_mon/$l_mday";
    }
    elsif ($HTML_INDEX_UNIT eq 'month') {
	$id = sprintf("%04d%02d.month", 1900 + $year, $mon);
	$li = "in the month $year/$mon";
    }
    elsif ($HTML_INDEX_UNIT eq 'infinite') {
	$id = ".";
	$li = $NULL; # "."
    }
    
    ($id, ($HTML_INDEX_TITLE || "ML Articles $li $ML_FN"));
}


sub Grep
{
    local($key, $file) = @_;

    &Log("Grep $key $file") if $verbose;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/i;}
    close(IN);

    $NULL;
}


sub SyncHtmlUnlinkArticle
{
    local(*e, $article) = @_;
    local($dir, $id, $li, %le, $atime, $mtime);

    local($atime, $mtime) = (stat($article))[8,9];

    &Log("remove $article");

    rename($article, "$article.bak") || &Log("cannot rename $article");

    # id -> dir/id
    if ($article =~ m%(.*)/([^/]+)\.html$%) {
	$dir = $1;
	$id  = $2;
    }

    # %le
    $le{'h:From:'} = $MAINTAINER;
    $le{'Body'}    = "This article is removed by ML administrator.";

    $ID = $id;
    $li = "This article is removed by ML administrator.";

    $HTML_TITLE_HOOK = q#
	$HtmlTitle = "This article is removed by ML administrator.";
    #;

    &use('synchtml');
    &SyncHtml'Init; #';
    &SyncHtml'Write($dir, $id, *li, *le); #';

    # reset the original time for expire
    utime $atime, $mtime, $article;
}


##### DEFINITION OF NAME SPACE #####

### import main functions
sub SyncHtml'DecodeMimeStrings  { &main'DecodeMimeStrings(@_);}
sub SyncHtml'SearchFileInLIBDIR { &main'SearchFileInLIBDIR(@_);}
sub SyncHtml'Log                { &main'Log(@_);}
sub SyncHtml'Debug              { &main'Debug(@_);}
sub SyncHtml'Append2            { &main'Append2(@_);}
sub SyncHtml'ProgExecuteP       { &main'ProgExecuteP(@_);}

### DECLARE DIFFERENT NAME SPACE ###
package SyncHtml;

### import main variable
#
# @HTML_FIELD       = (uja, misc); KEYWORD -> EACH FIELD.
# $HTML_EXPIRE_LIMIT      = "EXPIRE DAYS. if < 0, no expiration, append only";
# $HTML_INDEX_TITLE = "THE TITLE of index.html";
#

@Import = ("debug", "debug_html", "debug_expire",
           From_address, Now, HtmlDataCache, HtmlThreadCache,
           COMPAT_ARCH,
           HTML_EXPIRE, HTML_EXPIRE_LIMIT, ID, ML_FN, USE_MIME, USE_LIBMIME, 
           XMLCOUNT,
	   DEFAULT_HTML_FIELD, HTML_INDEX_TITLE, HTML_THREAD, 
           HTML_THREAD_REF_TYPE,
           HTML_OUTPUT_JCODE, HTML_OUTPUT_FILTER, 
           HTML_INDEX_REVERSE_ORDER, HTML_INDEX_UNIT,
           HTML_HEADER_TEMPLATE,
           HTML_FORMAT_PREAMBLE,
           HTML_FORMAT_TRAILER,
           HTML_DOCUMENT_SEPARATOR,
           INDEX_HTML_FORMAT_PREAMBLE,
           INDEX_HTML_FORMAT_TRAILER,
           INDEX_HTML_DOCUMENT_SEPARATOR,
           HTML_STYLESHEET_BASENAME, HTML_INDENT_STYLE,
           HTML_DATA_CACHE, HTML_TITLE_HOOK, BASE64_DECODE);

sub Init
{
    local($preamble, $trailor, $sep);

    # MIME Decoding, suggested by domeki@trd.tmg.nec.co.jp, thanks
    require 'libMIME.pl' if $USE_MIME;
    require 'jcode.pl';

    @SyncHtml'HTML_FIELD = @main'HTML_FIELD;
    for (@Import) { eval("\$SyncHtml'$_ = \$main'$_;");}

    @HtmlHdrFieldsOrder = # rfc822; fields = ...; Resent-* are ignored;
	('Date', 'From', 'Subject', 'Sender', 'To', 'Cc', 
	 'Message-Id', 'In-Reply-To', 
	 'References', 'Keywords', 'Comments', 'Encrypted', 'Posted');

    # Adjust From: field if fh:From exists.
    $From_address = $main'Envelope{'fh:from:'} || $From_address; #';

    # scope is this package
    $HtmlTitle = "Article $ID ($ML_FN)";
    $HtmlTitleForIndex = $HtmlTitle;

    # e.g. for spool2html
    $XMLCOUNT = $XMLCOUNT || 'X-Mail-Count';

    # default preamble, TRAILER, separator
$preamble = 
q#<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN" "http://www.w3.org/TR/REC-html40/strict.dtd">
<HTML>
  <HEAD>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=ISO-2022-JP">
#;

$trailor = 
q#  </BODY>
</HTML>
#;

    $sep = "  </HEAD>\n  <BODY>\n";

    $HTML_FORMAT_PREAMBLE = $HTML_FORMAT_PREAMBLE || $preamble;
    $HTML_FORMAT_TRAILER  = $HTML_FORMAT_TRAILER  || $trailor;
    $HTML_DOCUMENT_SEPARATOR = $HTML_DOCUMENT_SEPARATOR || $sep;
    $INDEX_HTML_FORMAT_PREAMBLE = $INDEX_HTML_FORMAT_PREAMBLE || $preamble;
    $INDEX_HTML_FORMAT_TRAILER  = $INDEX_HTML_FORMAT_TRAILER  || $trailor;
    $INDEX_HTML_DOCUMENT_SEPARATOR = $INDEX_HTML_DOCUMENT_SEPARATOR || $sep;
}

sub Write
{
    local($dir, $file, *title, *e) = @_;
    local($s);
    local($f) = "$dir/$file";
    local($htmlsubject);

    # write permission is required for only you and nobody read these files;
    umask(022);	

    # file existence check
    -f "$f.html" && (&Log("Already $f.html exists"), return $NULL);

    # open
    if ($HTML_OUTPUT_FILTER) {
	open(OUT, "|$HTML_OUTPUT_FILTER > $f.html") || 
	    (&Log("Can't open $f.html"), return $NULL);
    }
    else {	
	open(OUT, "> $f.html") || (&Log("Can't open $f.html"), return $NULL);
    }

    # fflush
    select(OUT); $| = 1; select(STDOUT);
    
    # TITLE
    $htmlsubject = $e{"h:http-subject:"} || $e{"h:Subject:"} || "Article $ID";
    $HtmlTitle = 
	"Article $ID at $Now From: $From_address Subject: $htmlsubject";
    $HtmlTitleForIndex = 
	"<DIV><SPAN CLASS=article>Article <SPAN CLASS=article-value>$ID</SPAN></SPAN> at <SPAN class=Date-value>$Now</SPAN> <SPAN class=Subject>Subject: <SPAN CLASS=Subject-value>$htmlsubject</SPAN></SPAN></DIV><DIV><SPAN CLASS=From>From: <SPAN CLASS=From-value>$From_address</SPAN></SPAN></DIV>";

    # Run Hooks
    # e.g.  $HTML_TITLE_HOOK = 
    # q#$HtmlTitle = sprintf("%s %s", $Now, $HtmlTitle);#;
    $HTML_TITLE_HOOK && eval($HTML_TITLE_HOOK);

    if ($USE_MIME && ($HtmlTitle =~ /ISO/i)) {
	$HtmlTitle = &DecodeMimeStrings($HtmlTitle);
	$HtmlTitleForIndex = &DecodeMimeStrings($HtmlTitleForIndex);
    } 

    # required ?
    $HtmlTitleForIndex =~ s/\n(\s+)/$1/g;

    ### HTML HEADER (REQUIRE SUPERFLUOUS \012 FOR RECONFIGURE OF index
    print OUT $HTML_FORMAT_PREAMBLE;
    if ($HTML_STYLESHEET_BASENAME) {
	local($css) = &StyleSheeRelativePath($dir, $HTML_STYLESHEET_BASENAME);
	print OUT "    <LINK REL=stylesheet TYPE=\"text/css\" HREF=\"$css\">\n";
    }
    print OUT "    <TITLE>$HtmlTitle</TITLE>\n";
    print OUT "$HTML_DOCUMENT_SEPARATOR\n";
    print OUT &ShowPointer;
    print OUT "    <PRE>\n";

    ### Header ###
    print OUT "<SPAN CLASS=mailheaders>";

    if ($HTML_HEADER_TEMPLATE) {
	print OUT $HTML_HEADER_TEMPLATE;
    }
    else {
	local(%dup);
	undef %FieldHash; # reset for spool2html
	&GetHdrField(*e); # -> %FieldHash

	for (@HtmlHdrFieldsOrder) {
	    next if $dup{$_}; $dup{$_} = 1; # duplicate check;
	    # if ($s = $e{"h:$_:"}) {
	    if ($s = $FieldHash{$_}) {
		$s = &DecodeMimeStrings($s) if $USE_MIME && ($s =~ /ISO/i);
		&ConvSpecialChars(*s);
		print OUT "<SPAN CLASS=$_>$_</SPAN>: ";
		print OUT "<SPAN CLASS=$_-value>$s</SPAN>\n";
	    }
	}
    }

    # append time() for convenience 
    # print OUT "X-Unixtime: ".(time)."\n";

    printf OUT ("<SPAN CLASS=xmlcount>$XMLCOUNT</SPAN>: <SPAN CLASS=xmlcount-value>%05d</SPAN>\n", $e{'rewrite:ID'} || $ID)
	if $e{'rewrite:ID'} || $ID;

    print OUT "</SPAN>";

    ### Body ###
    # 96/05/17 If mutipart, goto exceptional routine (for NCF)
    print OUT "\n";

    if ($USE_MIME && $e{"h:Content-Type:"} =~ /Multipart/i) {
	&ParseMultipart($dir, $file, *e);
    }
    else {
	$_ = $e{"Body"};
	&ConvSpecialChars(*_);
	# s#(http://\S+)#<A HREF="$1">$1</A>#g;
	s#(http://\S+)#&Conv2HRef($1)#ge;
	print OUT $_;
    }

    print OUT "    </PRE>\n";
    print OUT $HTML_FORMAT_TRAILER;

    ### fclose
    close(OUT);

    &Log("Create $f.html");

    # return the created .html title;
    $title = $HtmlTitleForIndex;
}


# Re-Generate Header Fields from the header in the distributed article.
sub GetHdrField
{ 
    local(*e) = @_;
    local($cf);

    for (split(/\n/, $e{'Hdr'})) {
	if (/^(\S+):(.*)/) {
	    $cf = $1;
	    $FieldHash{$cf} .= $2;
	}
	elsif (/^(\s+\S+.*)/) {
	    $FieldHash{$cf} .= "\n".$1;
	}
	else {
	    undef $cf;
	}
    }
}


sub StyleSheeRelativePath 
{
    local($dir, $f) = @_;
    if (-f "$dir/../$f") { return "../$f";}
    if (-f "$dir/./$f")  { return $f;}
}


sub ConvSpecialChars
{
    local(*s) = @_;

    ### special character convertion
    &jcode'convert(*s, 'euc'); #';
    $s =~ s/\r\n/\n/g; # too obstinate ;-) to cut off \r ?
    $s =~ s/\r//g;     # too obstinate ;-) to cut off \r ?
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/\"/&quot;/g;
    &jcode'convert(*s, 'jis'); #';
    ### special character convertion ends
}


sub ShowPointer
{
    return unless $main'HTML_THREAD; #';

    local($level) = @_;
    local($ptr);

    # based on fml-support: 03451 Manami TSUBOI <tsuboi@po.across.or.jp>
    if ($level eq "second") {
	$ptr = "<DIV CLASS=topnav>\n";

	if (-e "../index.html") {
	    $ptr .= "<A HREF=\"../index.html\" CLASS=topcount>[Top Index of this ML]</A>;\n";
	}

	if (-e "../thread.html") {
	    $ptr .= "      <A HREF=\"../thread.html\" CLASS=topthread>[Top Thread Index of this ML]</A>;\n"
	    if $main'HTML_THREAD; #';
	}

	$ptr .= "    </DIV>";
    }

    local($_) = qq#;
    <DIV CLASS=localnav>;
      Index: ;
      <A HREF="index.html" CLASS=localcount>[Article Count Order]</A> ;
      <A HREF="thread.html" CLASS=localthread>[Thread]</A>;
    </DIV>;
    $ptr;
    <HR>;
    #;

    s/;//g;
    $_;
}

# 'mime-version', 'content-type', 'content-transfer-encoding',
sub ParseMultipart
{
    local($dir, $file, *e) = @_;
    local($suffix, $mp_count, $ct, $cte);
    local($boundary);
    
    # Header Info
    $ct  = $e{"content-type:"};
    $cte = $e{"content-transfer-encoding"};

    if ($ct =~ /boundary=\s*\"(.*)\"/i || $ct =~ /boundary=\s*(\S+)/i) {
	$boundary = "--".$1;
	print STDERR "boundary='$boundary'\n" if $debug;
    }
 
    # Split Body
    local($decode, $sep, $base64, $quoted_printable, $pb);
    local($buf) = $e{'Body'};

    # remove the preamble before the boundary.
    $pb  = index($buf, $boundary, $image);
    $buf = substr($buf, $pb);
    local(@s) = split(/\n\n|$boundary/, $buf);

    # input each paragraph as one buffer.
    # 1. --boundary\nContent-* ...
    # 2. base64/quoted-printable/... encoded part
    # 3. --boundary--
    #
    foreach (@s) {
	/ISO\-/i && ($_ = &DecodeMimeStrings($_)); 

	if (/^[\s\n]*$/) { next;} # ignore null line

	undef $sep; 
	undef $match;

	if (/$boundary/) { 
	    &Log("found boudary ");
	    &Debug("Found boundary=[$boundary]") if $debug;
	    s/$boundary\-\-//g;	# the last part
	    s/$boundary//g;
	    $sep++;
	}
	if (/\nContent-/i)  { $sep++;}

	# encoding type
	if (/content-transfer-encoding:\s*base64/i) { 
	    $base64 = 1;
	} 
	if (/content-transfer-encoding:\s*quoted-printable/i) { 
	    $quoted_printable = 1;
	} 

	## get file type
	# image
	if (/Content-Type:\s+image/) { $image = 1;}

	# speculate type from mime.types
	if (/Content-Type:\s+([\-a-z]+)\/([\-0-9a-z\.]+)/i) { 
	    $suffix = &SearchMimeTypes("$1/$2") || $2;
	    $suffix =~ s/^x-//i; # remove x- in x-hoehoe type.
	    $sep++;
	}
	## type ends ##

	next if $sep; # avoid the separators.

	# 
	# DECODE BASE64 encoded parts
	# 
	if ($base64) { # now BASE64 strings here
	    # if not defined, try search bin/base64decede.pl
	    if ($BASE64_DECODE && &ProgExecuteP($BASE64_DECODE)) {
		$decode = $BASE64_DECODE;
	    }
	    elsif (! $BASE64_DECODE) {
		$decode = &SearchFileInLIBDIR("bin/base64decode.pl");
		$decode = $^X . " " . $decode; # perl base64decode.pl

		if (! $decode) {
		    &Log("SyncHtml::\$BASE64_DECODE is not defined");
		    next;
		}
	    }
	    # when $BASE64_DECODE is defined, but not found
	    elsif (! &ProgExecuteP($BASE64_DECODE)) {
		&Log("SyncHtml::\$BASE64_DECODE is not found");
		next;
	    }

	    $mp_count++; # global in one mail
	    &Log("\$mp_count++ => $mp_count") if $debug_html;

	    # write a splitted part of the multipart mail.
	    &Log("multipart::split to $dir/${file}_$mp_count.$suffix");
	    &Debug("|$decode > $dir/${file}_$mp_count.$suffix") 
		if $debug; 
	    open(IMAGE, "|$decode > $dir/${file}_$mp_count.$suffix") 
		|| &Log($!);
	    select(IMAGE); $| = 1; select(STDOUT);
	    print IMAGE $_;
	    close(IMAGE);

	    # reflect reference to the part in the \d+.html file.
	    if ($HTML_MULTIPART_IMAGE_REF_TYPE eq 'A' || (!$image)) {
		print OUT "<A HREF=\"${file}_$mp_count.$suffix\">";
		print OUT "${file}_$mp_count.$suffix</A>\n";
	    }
	    elsif ($HTML_MULTIPART_IMAGE_REF_TYPE eq 'IMAGE' ||
		   !$HTML_MULTIPART_IMAGE_REF_TYPE) {
		print OUT "</PRE>\n";
		print OUT "<IMAGE SRC=\"${file}_$mp_count.$suffix\">\n";
		print OUT "<PRE>\n";
	    }


	    # reset
	    undef $base64;
	    undef $suffix; 
	    undef $image;
	    next;
	}

	&ConvSpecialChars(*_);

	s#(http://\S+)#&Conv2HRef($1)#eg;
	print OUT "$_\n";
    }

    return $NULL;
}


# s#(http://\S+)#<A HREF="$1">$1</A>#g;
sub Conv2HRef
{
    local($url) = @_;
    local($x);
    local($re_euc_c) = '[\241-\376][\241-\376]';
    local($re_euc_s)  = "($re_euc_c)+";

    &jcode'convert(*url, 'euc'); #';

    if ($url =~ /($re_euc_s)+/) {
	$x   = $1;
	$url =~ s/$x//;
    }

    print STDERR "Conv2HRef(\$url = $url, \$x = $x)\n" if $debug || $debug_html;
    &jcode'convert(*x, 'jis'); #';

    "<A HREF=\"$url\">$url</A>$x";
}


# bin/Html.pl
sub ReWrite
{
    local($readdir, $writedir, $file, *e) = @_;
    local(%le, $header);# le: local envelope; 

    local($f)   = "$readdir/$file";
    local($dir) = $writedir;

    open(F, $f) || return;
    while (<F>) {
	if (1 .. /^$/) {
	    $header .= $_;
	}
	else {
	    $le{'Body'} .= $_;
	}
    }
    close(F);

    for (@HtmlHdrFieldsOrder, 'expire', 'keyword', 'field') {
	$header =~ s/$_:\s*(.*)\n/$le{"h:$_:"} = $1/ie;
    }

    # rewrite:ID
    $header =~ s/$XMLCOUNT:\s*(\S+)\n/$le{"rewrite:ID"} = $1/ie;

    #if ($debug) { while (($k,$v) = each %le) { &Debug("le [$k]=>\n$v");}}

    if (-f "$dir/$file.html") {
	unlink "$dir/,$file.html" if -f "$dir/,$file.html";
	if (rename("$dir/$file.html", "$dir/,$file.html")) {
	    &Debug("rename $dir/$file.html -> $dir/,$file.html");
	}
	else {
	    &Debug("Fail rename $dir/$file.html -> $dir/,$file.html");
	}
    }

    &Write($dir, $file, *le);
}


# modify index.html ...
sub Configure 
{ 
    local($dir, $file, $title, $li, *e) = @_;
    
    # caching ... (with threading)
    &Append2Cache(@_);

    # require reconfig of index.html for expiration
    if (@HTML_FIELD) {
	print STDERR "do ReConfigureEachFieldIndex(@_);\n" if $debug;
	&ReConfigureEachFieldIndex(@_);
    }
    #  append only, but may be 'of no use' ...???
    else {
	&MakeIndex(@_);

	# print STDERR "do RemakeIndex(@_);\n" if $debug;
	# &RemakeIndex($dir, $file, $title, $li, *e)

	&MakeThread(@_) if $HTML_THREAD;
    }
}


# append only
sub Append2Cache
{
    local($dir, $file, $title, $li, *e) = @_;
    local($title) = $HtmlTitleForIndex;

    $title =~ s/\n/ /g;
    &Append2("      <LI><A HREF=\"$file.html\">$title</A></LI>", $HtmlDataCache);

    if ($HTML_THREAD) { &MakeThreadData($dir, $file, *e);}
}


sub Uniq
{
    local($p, @p);

    for (@_) {
	next if $p eq $_;
	push(@p, $_);
	$p = $_;
    }

    @p;
}


sub MakeThreadData
{
    local($dir, $file, *e) = @_;
    local($id, $m, $mid, @mid, $prev_mid, $tmp);
    local($org) = $HtmlThreadCache;
    local($new) = "${HtmlThreadCache}.new";

    # original Message-ID:
    $id = $e{'h:Message-Id:'};
    $id =~ s/\s*//g;
    
    # message id lists to refer
    if ((! $HTML_THREAD_REF_TYPE) || 
	($HTML_THREAD_REF_TYPE eq "default")) {
	$mid = $e{"h:In-Reply-To:"}. $e{"h:References:"};
    }
    elsif ($HTML_THREAD_REF_TYPE eq "prefer-in-reply-to") {
	$mid = $e{"h:References:"}.$e{"h:In-Reply-To:"};
    }

    $mid =~ s/\n/\s/g;
    for (split(/\s+/, $mid)) { 
	if (/(<\S+\@\S+>)/) {
	    push(@mid, $1);
	    $tmp = $1 if $1 ne $id; # ignore Message-ID myself
	}
    }

    if ($HTML_THREAD_REF_TYPE eq "prefer-in-reply-to") {
	@mid = ($tmp);
    }
    else {
	# uniq
	@mid = &Uniq(@mid);
    }

    # rewrite;
    open(THREAD, $org)  || &Log("cannot open $org");
    open(OUT, "> $new") || &Log("cannot write $new");
    select(OUT); $| = 1; select(STDOUT);
    
    local($line);
    while (<THREAD>) {
	chop;
	$line = $_;

	next if /^\#/;
	next if /^\s*$/;

	($m) = (split)[0];

	# search the reference relations;
	for $mid (@mid) { $line .= " $file" if $m eq $mid;}
	
	print OUT "$line\n";
    }

    # my message-id cache on 
    $mid = $e{'h:Message-Id:'};
    $mid =~ s/\s*//g;
    print OUT "$mid\t$file \n";

    close(THREAD);
    close(OUT);

    rename($new, $org) || &Log("cannot rename $new $org");
}


# type:  $index := index | thread 
# 
#
# TOP_DIR/{index,thread}.html
sub RemakeIndex
{
    local($index, $dir, $file, $title, $list, *e) = @_;

    # fix at fml-support: 03415 by tmu@ikegami.co.jp (MURASHITA Takuya)
    &SyncHtml'Init;#'; # when called even if Init is not called.

    local(@c) = caller if $debug;
    &Debug("RemakeIndex called: @c") if $debug;

    &Log("RemakeIndex($index, $dir, $file, $title, $list, *e);") if $debug;

    &AppendIndexInformation(@_);
    &ReConfigureIndex(@_);
}

# TOP_DIR/{index,thread}.html
sub AppendIndexInformation
{
    local($index, $dir, $file, $title, $list, *e) = @_;

    # reset
    $title = $title || $HTML_INDEX_TITLE || $HtmlTitle || "Spool $ML_FN";

    if (! -f "$dir/$index.hdr") {
	&Append2($INDEX_HTML_FORMAT_PREAMBLE, "$dir/$index.hdr");
	if ($HTML_STYLESHEET_BASENAME) {
	    &Append2("    <LINK REL=stylesheet TYPE=\"text/css\" HREF=\"$HTML_STYLESHEET_BASENAME\">", "$dir/$index.hdr");
	}
        &Append2("    <TITLE>$title</TITLE>", "$dir/$index.hdr");
        &Append2($INDEX_HTML_DOCUMENT_SEPARATOR, "$dir/$index.hdr");
        &Append2(&ShowPointer, "$dir/$index.hdr");
        &Append2("    <UL>", "$dir/$index.hdr");
    }

    ### list: append to list ###
    # backward compatible; initialize();
    #    index.html exists but index.list NOT
    #    reverse-orderde file not exist, so cp is O.K.
    if (-f "$dir/$index.html" && ! -f "$dir/$index.list") {
	&Copy("$dir/$index.html", "$dir/$index.list");

	# add current hierarchy
	&Append2("      <LI><A HREF=\"$file.html\">$list</A></LI>", "$dir/$index.list");
	&Log("Append Entry=$file.html >> $dir/$index.list") if $debug;
    }
    # initialize();
    else {
	&Append2("      <LI><A HREF=\"$file.html\">$list</A></LI>", "$dir/$index.list");
	&Log("Append Entry=$file.html >> $dir/$index.list") if $debug;
    }
}


# TOP_DIR/{index,thread}.html
sub ReConfigureIndex
{
    # Hmm, $file is not used ...?
    local($index, $dir, $file, $title, $list, *e) = @_;
    local(%uniq, $index_file);
    local(@cache);

    &Log("ReConfigureIndex> $HTML_INDEX_REVERSE_ORDER") if $debug_index;

    local(@c) = caller if $debug;
    &Debug("ReConfigureIndex called: @c") if $debug;

    print STDERR "\n--ReConfigureIndex($dir/$index) BEGIN\n\n" if $debug;

    # generate index.new from the current data
    # (require to be reconfigured for e.g. expiration)
    if (-f "$dir/$index.hdr") {
	&Copy("$dir/$index.hdr", "$dir/$index.new");
    }
    else {
	&Log("Error: $dir/$index.hdr not exist");
    }

    open(LIST, "$dir/$index.list")  || &Log("cannot open $dir/$index.list");
    if ($HTML_OUTPUT_FILTER) {
	open(OUT, "|$HTML_OUTPUT_FILTER > $dir/$index.new") || do {
	    &Log("cannot open $dir/$index.new");
	    return $NULL;
	};
    }
    else {
	open(OUT, ">> $dir/$index.new") || do {
	    &Log("cannot open $dir/$index.new");
	    return $NULL;
	};
    }
    select(OUT); $| = 1; select(STDOUT);
 
    while (<LIST>) {
	# we use an "A HREF" line only. 
	# This depends on our "one line" output.
	next unless /A\s+HREF/i;

	# existence check
	if (/HREF="(\S+\.html)"/) { # check {index,thread,\d+}.html
	    &Debug("check0 -e $dir/$1") if $debug;
	    &Debug("**ignore  $dir/$1") if $debug && ! -e "$dir/$1";
	    next unless -e "$dir/$1";
	}
	elsif (/HREF="(\S+)"/) { 
	    &Debug("check0 -e $dir/$1") if $debug;
	    next unless -d "$dir/$1";
	}

	# e.g. HREF line in index.html, thread.html
	if (/A\s+HREF="(\S+\.html)"/i) {
	    $index_file = $1;

	    if ($debug) {
		&Debug("#b LIST $dir/$index_file");
		&Debug("$dir/$index_file is removed") 
		    unless (-e "$dir/$index_file" && -s "$dir/$index_file");
	    }

	    # unique (if dup, but where is not dup case?)
	    next if $uniq{$index_file};
	    $uniq{$index_file} = 1;

	    # first time
	    if ($e{'tmp:subdir_first_time'}) {
		;
	    }
	    # expire case
	    else {
		# expire case
		# non-zero index.html exists or not
		next unless (-e "$dir/$index_file" && -s "$dir/$index_file");

		if ($debug) {
		    print STDERR "  url list: $dir/$index_file\n";
		    print STDERR "  skip      $dir/$index_file\n"
			if ! -f "$dir/$index_file";
		}

		# for expire but error in the first time.
		next if ! -f "$dir/$index_file";
	    }
	}

	# reverse mode; patch by tmu@ikegami.co.jp (fml-support:03234)
	if ($HTML_INDEX_REVERSE_ORDER) {
	    push(@cache, $_);
	}
	else {
	    print OUT $_;
	}
    }

    # reverse output; patch by tmu@ikegami.co.jp (fml-support:03234)
    if ($HTML_INDEX_REVERSE_ORDER) {
	for (reverse @cache) { print OUT $_;}
    }

    close(OUT);
    close(LIST);

    &Append2("    </UL>", "$dir/$index.new");
    &Append2($INDEX_HTML_FORMAT_TRAILER, "$dir/$index.new");

    print STDERR "\n  rename $dir/{$index.new -> $index.html}\n" if $debug;
    rename("$dir/$index.new", "$dir/$index.html") || 
	&Log("cannot $dir/{$index.new -> $index.html}");

    print STDERR "\n  ReConfigureIndex($dir/$index) END\n" if $debug;
}


sub Copy
{
    local($in, $out) = @_;

    open(COPY_IN,  $in) || (&Log("Error: Copy cannot open [$in]"), return);
    open(OUT, "> $out") || (&Log("Error: Copy cannot open [$out]"), return);
    select(OUT); $| = 1; select(STDOUT); 
    while (sysread(COPY_IN, $_, 4096)) { print OUT $_;}
    close(OUT);
    close(COPY_IN); 
}


sub GetEntry
{
    local($f) = @_;
    local($k, $s, $header, $mlname);

    open(F, $f) || &Log("Cannot open $f", return);
    while (<F>) {
	if (1 .. /^$/) {
	    $header .= $_;
	    last if /^$/;
	}
    }
    close(F);

    # Get fields
    $XMLCOUNT = $XMLCOUNT || 'X-ML-Count';
    $header =~ s/\n(\s+)/$1/g;
    $header =~ s/keyword:\s*(\S+)\n/$k = $1/ie;
    $header =~ s/subject:\s*(.*)\n/$s = $1/ie;
    $header =~ s/$XMLCOUNT:\s*(.*)\n/$c = $1/ie;
    $header =~ s/X-ML-NAME:\s*(.*)\n/$mlname = $1/ie;

    # search key. exact match under case-insensitive
    foreach $key (@HTML_FIELD) { 
	($k =~ /^$key$/i) && ($k = $key) && last;
    }

    $f =~ s#(\S+)/(\S+)#$2#;
    (($k || $DEFAULT_HTML_FIELD || 'misc'), ($c && "[$c]").($s || $f));
}


sub ReConfigureEachFieldIndex
{
    local($dir, $file, *e) = @_; # file is dummy:-);
    local($key, $subject, $url);

    # FIX
    unshift(@HTML_FIELD, $DEFAULT_HTML_FIELD);

    foreach $key (@HTML_FIELD) { unlink "$dir/$key.html";}

    opendir(DIR, $dir) || &Log("Cannot opendir $dir", return);
    foreach $file (sort {$b <=> $a} readdir(DIR)) {
	next if     $file =~ /^\.|^\s*$/o;
	next unless $file =~ /^\d+\.html$/;

	($key, $subject) = &GetEntry("$dir/$file");
	$url = "\t<LI><A HREF=\"$file\">$subject\n\t</A></LI>";
	&Append2($url, "$dir/$key.html");
    }
    closedir(DIR);

    ### O.K. reconfigure index.html
    if ($HTML_OUTPUT_FILTER) {
	open(OUT, "|$HTML_OUTPUT_FILTER > $dir/index.html") || 
	    (&Log("cannot open index.html"), return);
    }
    else {
	open(OUT, "> $dir/index.html") || 
	    (&Log("cannot open index.html"), return);
    }
    select(OUT); $| = 1; select(STDOUT);

    print STDERR "INDEX:<TITLE>Index $ML_FN</TITLE>\n" if $debug;
    print OUT $INDEX_HTML_FORMAT_PREAMBLE;
    if ($HTML_STYLESHEET_BASENAME) {
	local($css) = &StyleSheeRelativePath($dir, $HTML_STYLESHEET_BASENAME);
	print OUT "    <LINK REL=stylesheet TYPE=\"text/css\" HREF=\"$css\">\n";
    }
    print OUT "    <TITLE>Index $ML_FN</TITLE>\n";
    print OUT "$INDEX_HTML_DOCUMENT_SEPARATOR\n";
    print OUT "    <UL>\n";

    foreach $key (@HTML_FIELD) { 
	print OUT "<HR>\n\t<UL>\n\t<H2>$key</H2>\n";
	open(IN, "$dir/$key.html");
	print OUT <IN>;
	close(IN);
	print OUT "\t</UL>\n\n";
    }

    print OUT "</UL>\n";
    print OUT $INDEX_HTML_FORMAT_TRAILER;
    close(OUT);

    &Log("reconfig $dir/index.html") if $debug_html;
}


sub MakeThread
{
    local($dir, $file, $title, $li, *e) = @_;
    &DoMakeIndex('thread', @_);
}


sub MakeIndex
{
    local($dir, $file, $title, $li, *e) = @_;
    &DoMakeIndex('index', @_);
}


# main {index, thread}.html re-creation (mainly subdir)
sub DoMakeIndex
{
    local($index, $dir, $file, $title, $li, *e) = @_;
    local(@cache);
    local(@entry, %entry, @list, %list);

    &Log("DoMakeIndex> $HTML_INDEX_REVERSE_ORDER") if $debug_index;

    &Debug("SyncHtml::MakeIndex[$index](".
	   ($HTML_INDEX_REVERSE_ORDER ? "reverse" : "").")") if $debug;
    
    ### O.K. reconfigure index.html
    if ($HTML_OUTPUT_FILTER) {
	open(OUT, "|$HTML_OUTPUT_FILTER > $dir/$index.html") || 
	    (&Log("cannot open $index.html"), return);
    }
    else {
	open(OUT, "> $dir/$index.html") || 
	    (&Log("cannot open $index.html"), return);
    }
    select(OUT); $| = 1; select(STDOUT);

    # generating {index,thread}.html ...;
    if ($index eq 'thread') {
	print OUT $INDEX_HTML_FORMAT_PREAMBLE;
	if ($HTML_STYLESHEET_BASENAME) {
	    local($css) = &StyleSheeRelativePath($dir, $HTML_STYLESHEET_BASENAME);
	    print OUT "    <LINK REL=stylesheet TYPE=\"text/css\" HREF=\"$css\">\n";
	}
	print OUT "    <TITLE>Threaded Index $ML_FN</TITLE>\n";
	print OUT "$INDEX_HTML_DOCUMENT_SEPARATOR\n";
	print OUT &ShowPointer("second");
    }
    elsif ($index eq 'index') {
	print OUT $INDEX_HTML_FORMAT_PREAMBLE;
	if ($HTML_STYLESHEET_BASENAME) {
	    local($css) = &StyleSheeRelativePath($dir, $HTML_STYLESHEET_BASENAME);
	    print OUT "    <LINK REL=stylesheet TYPE=\"text/css\" HREF=\"$css\">\n";
	}
	print OUT "    <TITLE>Index $ML_FN</TITLE>\n";
	print OUT "$INDEX_HTML_DOCUMENT_SEPARATOR\n";
	print OUT &ShowPointer("second");
    }

    if ($index eq 'thread') {
	&GenThread(*entry, $dir);
    }
    elsif ($index eq 'index') {
	print OUT "<UL>\n";

	# read .cache and output > dir/index.html
	open(CACHE, $HtmlDataCache) || &Log("cannot open $HtmlDataCache");
	while (<CACHE>) { 
	    if (/HREF="(\d+\.html)"/) { # check {index,thread,\d+}.html 
		&Debug("check1 -e $dir/$1") if $debug;
		&Debug("**ignore  $dir/$1") if $debug && ! -e "$dir/$1";
		next unless -e "$dir/$1";
	    }
	    elsif (/HREF="(\S+)"/) { 
		&Debug("check1 -e $dir/$1") if $debug;
		next unless -d "$dir/$1";
	    }

	    if ($HTML_INDEX_REVERSE_ORDER) {
		push(@cache, $_);
	    }
	    else {
		print OUT $_;
	    }
	}
	close(CACHE);

	# reverse output;
	if ($HTML_INDEX_REVERSE_ORDER) {
	    for (reverse @cache) { print OUT $_;}
	}

	print OUT "</UL>\n";
    }

    print OUT $INDEX_HTML_FORMAT_TRAILER;
    close(OUT);

    &Log("reconfig $dir/$index.html [reverse order]") if $debug_html;

    undef @cache;
}


sub GetCache
{
    local(*list) = @_;
    local($file);

    open(CACHE, $HtmlDataCache) || &Log("cannot open $HtmlDataCache");
    while (<CACHE>) { 
	chop;
	if (/HREF="(\d+)\.html"/) { $file = $1;}
	$list{$file} = $_;
    }
    close(CACHE);
}


sub OutQueueOn
{
    local($i, *next, *queue) = @_;

    # Anyway queue on itself;
    $queue .= " $i " if $i;

    # "$i" refers itself only;
    return unless $next{$i}; 

    $queue .= " ( " if $next{$i} =~ /\d+\s+/ && ($HTML_INDENT_STYLE eq 'UL');
    $queue .= " ( " if $next{$i} =~ /\d+\s+\d+/;

    # $i -> somewhere;
    for (split(/\s+/, $next{$i})) { 
	&OutQueueOn($_, *next, *queue);
    }

    $queue .= " ) " if $next{$i} =~ /\d+\s+/ && ($HTML_INDENT_STYLE eq 'UL');
    $queue .= " ) " if $next{$i} =~ /\d+\s+\d+/;
}


sub GenThread
{
    local(*entry, $dir) = @_;
    local($m, $x, @x);
    local(%list, %next, $first, $last, $i, $queue, @queue);
    local($seq, $prev_seq);

    &GetCache(*list);

    open(CACHE, $HtmlThreadCache) || &Log("cannot open $HtmlThreadCache");
    while (<CACHE>) {
	($m, $x, @x) = split(/\s+/, $_);
	$first = $x unless $first;
	$last  = $x;

	$next{$x} = " @x ";
	#$next{$x} =~ s/$x//g;
	$next{$x} =~ s/^\s*$//g;
    }
    close(CACHE);

    ### XXX
    if ($HTML_INDENT_STYLE eq 'UL') {
	require 'libhtmlsubr.pl';
	&AggregateLinks(*next);
	&OutPutAggrThread(*list, *next);
	return 1;
    }
    ### XXX


    ### the original threading
    # next $x -> (only-next);
    # replace %next;
    for ($i = $first; $i <= $last; $i++) {
	next if $queue =~ / $i /;
	$queue .= "\n";
	&OutQueueOn($i, *next, *queue);
    }

    # the first and last () ignored;
    # $queue =~ s/^\s*\(//;
    # $queue =~ s/\)\s*$//;

    local($indent) = 0;

    for (split(/\n/, "$queue\n")) {
	next if /^\s*$/;
	print STDERR "QUEUE $_\n" if $debug;

	$_ = &QueueUniq($_);
	$_ = &ConsiderQueueExpiration($dir, $_);

	&Log("QUEUE $_") if $debug_html;

	for $i (split(/\s+/, $_)) {
	    if ($i eq '(') {
		$indent++;
		print OUT "\n";
		print OUT "<!- $_ ->\n" if $debug;
		print OUT "<!- $indent ->\n" if $debug;
		print OUT " " x $indent;
		print OUT "<UL>\n"; next;
	    }
	    if ($i eq ')') { 
		print OUT "\n";
		print OUT "<!- $_ ->\n" if $debug;
		print OUT "<!- $indent ->\n" if $debug;
		print OUT " " x $indent;
		print OUT "</UL>\n\n";
		$indent--;
		next;
	    }

	    if ($list{$i}) {
		print OUT $list{$i};
	    }
	} # split $_ (one on split $queue)
	# print OUT "\t</UL>\n";

	print OUT "\n\n<HR>\n";
    } # split queue
}


sub QueueUniq
{
    local(@x, $x, $p, $buf);
    
    for $x (split(/\s+/, $_[0])) {
	next if ($p eq $x || $p == $x);
	$buf .= " $x ";
	$p = $x;
    }
    $buf;
}


sub ConsiderQueueExpiration
{
    local($dir, $buffer) = @_;
    local($x, $buf);

    for $x (split(/\s+/, $buffer)) {
	if ($x =~ /^\d+$/ && (! -e "$dir/$x.html")) {
	    print STDERR "ignore $dir/$x.html\n" if $debug_html;
	    next;
	}

	$buf .= " $x ";
    }

    # remove non-contents threads
    $buf =~ s/\(\s*\)//g;

    # (a b (c)) => (a (b) (c)) => (a (b c)) => ( a (b (c))) 
    # while ($buf =~ s/(\d+)\s+(\d+)/$1 ( $2 )/) { 1;}
    # $buf =~ s/\)\s+\(//g;
    # while ($buf =~ s/(\d+)\s+(\d+)/$1 ( $2 )/) { 1;}

    # check the close of parentheses
    # ( a b (c d) )
    local($r, $l);
    $buffer = $buf;
    undef $buf;
    for $x (split(/\s+/, $buffer)) {
	$r++ if $x eq '(';
	$l++ if $x eq ')';
	$buf .= " $x ";
    }

    $r = $r - $l;
    if ($r > 0) {
	while ($r-- > 0) { $buf .= " ) ";}
    }
    else {
	while ($r++ < 0) { $buf = " ( " . $buf;}
    }

    ### return clean-up'ed link relation ###
    $buf;
}


# ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#       $atime,$mtime,$ctime,$blksize,$blocks)
#         = stat($filename);
# "last access, modify, change" = 8,9,10
sub Expire
{
    local($html_dir, $file, *e) = @_; # file is a dummy:-);
    local($t, $expire, $time, $unlinked_p);

    &Log("Expire $html_dir") if $main'debug_expire;#';

    # variable set
    $expire = $HTML_EXPIRE_LIMIT || 14; # 2 weeks.
    $expire = $expire * 24 * 3600;
    $time   = time;

    &Debug("SyncHtml::Expire->expire = $expire") if $debug;

    opendir(DIR, $html_dir) || (&Log("Cannot open $html_dir"), return);
    for (readdir(DIR)) {
	next if /^\./;

	# find expire candidates
	if (-d "$html_dir/$_" && /\S+\.expire$/) {
	    $ExpireDirList{"$html_dir/$_"} = 1;
	    next;
	}

	# here we go
	if (-d "$html_dir/$_") {
	    &ExpireByDirectoryUnit("$html_dir/$_", $expire);
	    next;
	}
	elsif ($HTML_INDEX_UNIT eq 'infinite' && -f "$html_dir/$_") {
	    next unless /^\d+\.html$/;

	    $_ = "$html_dir/$_";

	    # last modify time;
	    $t = $time - (stat($_))[9]; 

	    &Debug("unlink $_ if $t > $expire;") if $debug;
	    next unless $t > $expire;

	    print STDERR "unlink $_\n" if $debug;
	    unlink($_) ? &Log("unlink $_") : &Log("fails to unlink $_");
	    $unlinked_p = 1;
	}
	# file ?
	elsif (-f "$html_dir/$_") {
	    next unless /\.html$/;
	    next unless /index\.html$/;
	    next unless /thread\.html$/;

	    $_ = "$html_dir/$_";

	    # last modify time;
	    $t = $time - (stat($_))[9]; 

	    print STDERR "unlink $_ if $t > $expire;\n" if $debug;
	    next unless $t > $expire;

	    print STDERR "unlink $_\n" if $debug;
	    unlink($_) ? &Log("unlink $_") : &Log("fails to unlink $_");
	}
    }
    closedir(DIR);


    ### touch expire flag and regenerate htdocs/{index,thread}.html
    $title = $li = "dummy";

    # Attention! directory based re-creation of htdocs/{index,thread}.html
    if (%ExpireDirList) {
	&Log("if (%ExpireDirList) { &ReConfigureIndex;") if $debug_expire;
	&ReConfigureIndex('index',  $html_dir, "$id/index",  $title, $li, *e);
	&ReConfigureIndex('thread', $html_dir, "$id/thread", $title, $li, *e) 
	    if $HTML_THREAD;
    }
    elsif ($HTML_INDEX_UNIT eq 'infinite' && $unlinked_p) {
	&Log("if (unit is infinite) { &ReConfigureIndex;") if $debug_expire;
	&MakeIndex($html_dir, "$id/index",  $title, $li, *e);
	&MakeThread($html_dir, "$id/thread", $title, $li, *e) 
	    if $HTML_THREAD;
    }
}


sub ExpireByDirectoryUnit
{
    local($subdir, $expire) = @_;
    local($f, $t, $expire_count, $total_count, $time);

    $expire_count = 0;
    $time = time;

    &Log("  expire $subdir ") if $main'debug_expire;#';

    opendir(SUBDIR, $subdir) || (&Log("Cannot open $subdir"), return);
    for $f (readdir(SUBDIR)) {
	next if $f =~ /^\./;
	next if $f =~ /(index|thread)\.html$/;

	$total_count++;

	$f = "$subdir/$f";
	$t = $time - (stat($f))[9];
	if ($t > $expire) { $expire_count++;}
    }
    closedir(SUBDIR);

    # If all files are expired, we remove this directory
    if ($expire_count == $total_count) {
	&Log("Expire{$subdir -> $subdir.expire}");
	rename($subdir, "$subdir.expire") || 
	    &Log("cannot rename $subdir -> $subdir.expire"); 
	$ExpireDirList{"$subdir.expire"} = 1;
    }
    else {
	&Log("      not expired since too early [$expire_count/$total_count].")
	    if $main'debug_expire;#';
    }
}


sub Remove
{
    local($html_dir, *e) = @_;
    local($dir, $f);

    # %ExpireDirList 's key is already "$html_dir/sub-dir/" style.
    for $dir (keys %ExpireDirList) {
	next unless $ExpireDirList{$dir};

	print STDERR "--Expire::remove($dir)\n" if $debug;

	opendir(SUBDIR, $dir) || 
	    (&Log("HtmlExpire::Remove cannot open $dir"), next);

	for $f (readdir(SUBDIR)) {
	    print STDERR "unlink(\"$dir/$f\");\n" if $debug;
	    if (-f "$dir/$f") {
		unlink("$dir/$f") || 
		    &Log("HtmlExpire::Remove cannot unlink $dir/$f");
	    }
	}
	closedir(SUBDIR);

	# logs
	undef $ExpireDirList{$dir};

	print STDERR "rmdir(\"$dir\");\n" if $debug;
	rmdir($dir) || &Log("HtmlExpire::Remove cannot rmdir $dir");
    }
}


### Section: Utilities
sub SearchMimeTypes
{
    local($type) = @_;
    local($def, $suffix); 

    $def = &SearchFileInLIBDIR("etc/mime.types");

    $def || return $NULL;

    if (-f $def) {
	open(DEF, $def) || &Log("SearchMimeTypes: cannot open $def");
	while (<DEF>) {
	    if (/^$type\s+(\S+)/) {
		$suffix = $1;
	    }
	}
	close(DEF);
    }

    &Log("SearchMimeTypes: found $type => suffix=$suffix") if $debug_html;

    $suffix;
}

1;
