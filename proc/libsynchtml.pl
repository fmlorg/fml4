### Syncronization of spool and html files directory
# Copyright (C) 1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


# Obsolete SyncHtml.ph 
#   $DEFALUT_EXPIRE = 10;
#   $TITLE = "Index of Seminars";
#   @keyword   = 
#   ('non-linear', 'comp', 'material', 'hp', 'misc', 'book', 'info');
# 
#
# &SyncHtml($SPOOL_DIR, $ID, *Envelope)
# 
# if ($HTML_EXPIRE == 0) { NOT do EXPIRE, ONLY APPEND;}
# 
# return NONE
sub SyncHtml
{
    local($dir, $file, *e) = @_;

    -d $dir || mkdir($dir, 0755);

    # MIME Decoding, suggested by domeki@trd.tmg.nec.co.jp, thanks
    &use('MIME') if $USE_LIBMIME;

    &SyncHtml'Init;#';
    &SyncHtml'Write(@_) || return; #';
    &SyncHtml'Expire(@_) if $HTML_EXPIRE > 0; #';
    &SyncHtml'Configure(@_); #';
}



##### DEFINITION OF NAME SPACE #####

### import main functions
sub SyncHtml'DecodeMimeStrings { &main'DecodeMimeStrings(@_);}
sub SyncHtml'Log               { &main'Log(@_);}
sub SyncHtml'Debug             { &main'Debug(@_);}
sub SyncHtml'Append2           { &main'Append2(@_);}

### DECLARE DIFFERENT NAME SPACE ###
package SyncHtml;

### import main variable
#
# @HTML_FIELD       = (uja, misc); KEYWORD -> EACH FIELD.
# $HTML_EXPIRE      = "EXPIRE DAYS. if < 0, no expiration, append only";
# $HTML_INDEX_TITLE = "THE TITLE of index.html";
#

@Import = (debug, HTML_EXPIRE, ID, ML_FN, USE_LIBMIME, XMLCOUNT,
	   DEFAULT_HTML_FIELD, HTML_INDEX_TITLE);


sub Init
{
    @SyncHtml'HTML_FIELD = @main'HTML_FIELD;
    for (@Import) { eval("\$SyncHtml'$_ = \$main'$_;");}
}

# scope is this package
$HtmlTitle = "Auto generated $ID";


sub Write
{
    local($dir, $file, *e) = @_;
    local($s);
    local($f) = "$dir/$file";

    # write permission is required for anybody
    umask(022);	

    # file existence check
    -f "$f.html" && (&Log("Already $f.html exists"), return $NULL);

    # open
    open(OUT, "> $f.html") || (&Log("Can't open $f.html"),return 0);

    # fflush
    select(OUT); $| = 1; select(STDOUT);
    
    # TITLE
    $HtmlTitle = $e{"h:http-subject:"} || $e{"h:Subject:"} || "spool/$ID";
    $HtmlTitle = &DecodeMimeStrings($HtmlTitle) 
	if $USE_LIBMIME && ($HtmlTitle =~ /ISO/);

    ### HTML HEADER (REQUIRE SUPERFLUOUS \012 FOR RECONFIGURE OF index
    print OUT "<TITLE>\n$HtmlTitle\n</TITLE>\n<PRE>\n";

    ### Header
    for ('Date', 'From', 'Subject', 'Sender', 'To', 
	 'expire', 'keyword', 'field') {
	if ($s = $e{"h:$_:"}) {
	    $s = &DecodeMimeStrings($s) if $USE_LIBMIME && ($s =~ /ISO/);
	    print OUT "$_: $s\n";
	}
    }

    # append time() for convenience 
    # print OUT "X-Unixtime: ".(time)."\n";
    printf OUT ("$XMLCOUNT: %05d\n", $e{'rewrite:ID'} || $ID)
	if $e{'rewrite:ID'} || $ID;

    ### Body
    print OUT "\n";
    print OUT $USE_LIBMIME ? &DecodeMimeStrings($e{"Body"}) : $e{"Body"};
    print OUT "</PRE>\n";

    ### fclose
    close(OUT);

    &Log("Converted to HTML[$f.html]");

    1;
}


sub ReWrite
{
    local($readdir, $writedir, $file, *e) = @_;
    local(*le, *header);# le: local envelope; 

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

    for ('Date', 'From', 'Subject', 'Sender', 'To', 
	 'expire', 'keyword', 'field') {
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
    # require reconfig of index.html for expiration
    if (@HTML_FIELD) {
	print STDERR "do IndexReConfigure($_[0,1], e);\n" if $debug;
	&IndexReConfigure(@_);
    }
    #  append only, but may be 'of no use' ...???
    else {
	print STDERR "do Append2Index($_[0,1], e);\n" if $debug;
	&Append2Index(@_);
    }
}


# append only
sub Append2Index
{
    local($dir, $file, *e) = @_;
    local($title) = $HTML_INDEX_TITLE || "Spool $ML_FN";

    if (! -f "$dir/index.html") {
	&Debug("Create $dir/index.html") if $debug;
	&Log("Create $dir/index.html");
	&Append2("<TITLE>$title</TITLE>", "$dir/index.html");
	&Append2("<HR><UL>", "$dir/index.html");
    }

    # append
    &Append2("<LI><A HREF=$file.html>$HtmlTitle</A>", "$dir/index.html");
    &Log("Append Entry=$file.html >> $dir/index.html");
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


sub IndexReConfigure
{
    local($dir, $file, *e) = @_; # file is dummy:-);
    local(*key, *subject);

    # FIX
    unshift(@HTML_FIELD, $DEFAULT_HTML_FIELD);

    foreach $key (@HTML_FIELD) { unlink "$dir/$key.html";}

    opendir(DIR, $dir) || &Log("Cannot opendir $dir", return);
    foreach $file (sort {$a <=> $b} readdir(DIR)) {
	next if     $file =~ /^\.|^\s*$/o;
	next unless $file =~ /^\d+\.html$/;

	($key, $subject) = &GetEntry("$dir/$file");
	$url = "\t<LI>\n\t<A HREF=$file>\n\t$subject\n\t</A>";
	&Append2($url, "$dir/$key.html");
    }
    closedir(DIR);

    ### O.K. reconfigure index.html
    open(OUT, "> $dir/index.html") || 
	(&Log("cannot open index.html"), return);
    select(OUT); $| = 1; select(STDOUT);

    print OUT "<TITLE>Index $ML_FN</TITLE>\n";
    print OUT "<UL>\n";

    foreach $key (@HTML_FIELD) { 
	print OUT "<HR>\n\t<UL>\n\t<H2><P>$key</H2>\n";
	open(IN, "$dir/$key.html");
	print OUT <IN>;
	close(IN);
	print OUT "\t</UL>\n\n";
    }

    print OUT "</UL>\n";
    close(OUT);

    &Log("$dir/index.html is reconfigured with fields");
}


# ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#       $atime,$mtime,$ctime,$blksize,$blocks)
#         = stat($filename);
# "last access, modify, change" = 8,9,10
sub Expire
{
    local($dir, $file, *e) = @_; # file is a dummy:-);
    local($t, $expire);

    # variable set
    $expire = $HTML_EXPIRE || 14; # 2 weeks.
    $expire = $expire * 24 * 3600;

    opendir(DIR, $dir) || (&Log("Cannot open $dir"), return);
    foreach (readdir(DIR)) {
	next if /^\./;
	next unless /\.html$/;

	# file
	$_ = "$dir/$_";
	next unless -f $_;

	# last modify time;
	$t = time - (stat($_))[9]; 

	print STDERR "unlink $_ if $t > $expire;\n" if $debug;
	next unless $t > $expire;

	print STDERR "unlink $_\n" if $debug;
	unlink($_) ? &Log("unlink $_") : &Log("fails to unlink $_");
    }
    closedir(DIR);
}


1;
