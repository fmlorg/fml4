### Syncronization of spool and html files directory
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

# Obsolete SyncHtml.ph 
#   $DEFALUT_EXPIRE = 10;
#   $TITLE = "Index of Seminars";
#   @keyword   = 
#   ('non-linear', 'comp', 'material', 'hp', 'misc', 'book', 'info');

# &SyncHtml($SPOOL_DIR, "$SPOOL_DIR/$ID", *Envelope)
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

    &SyncHtml'Write(@_) || return; #';
    &SyncHtml'Expire(@_) if $HTML_EXPIRE > 0; #';
    &SyncHtml'Configure(@_); #';
}



##### NAME SPACE #####

# main 
sub SyncHtml'DecodeMimeStrings { &main'DecodeMimeStrings(@_);}
sub SyncHtml'Log               { &main'Log(@_);}
sub SyncHtml'Debug             { &main'Debug(@_);}
sub SyncHtml'Append2           { &main'Append2(@_);}

# main var 
@SyncHtml'HTML_FIELD = @main'HTML_FIELD;
for (HTML_EXPIRE, ID, ML_FN, USE_LIBMIME) {
  eval("\$SyncHtml'$_ = \$main'$_;");
}

# DECLARE DIFFERENT NAME SPACE
package SyncHtml;

# scope is this package
$HtmlTitle = "Auto generated $ID";

sub Write
{
    local($dir, $file, *e) = @_;
    local($s);

    # write permission is required for anybody
    umask(022);	

    # file existence check
    -f "$file.html" && (&Log("Already $file.html exists"), return $NULL);

    # open
    open(OUT, "> $file.html") || (&Log("Can't open $file.html"),return 0);

    # fflush
    select(OUT); $| = 1; select(STDOUT);
    
    # TITLE
    $HtmlTitle = $e{"h:http-subject:"} || $e{"h:Subject:"} || "spool/$ID";
    $HtmlTitle = &DecodeMimeStrings($HtmlTitle) 
	if $USE_LIBMIME && ($HtmlTitle =~ /ISO/);

    ### HTML HEADER
    print OUT "<TITLE>\n$HtmlTitle\n</TITLE>\n";
    print OUT "\n<PRE>\n";

    ### Header
    for ('Date', 'From', 'Subject', 'Sender', 'To', 
	 'expire', 'keyword', 'field') {
	if ($s = $e{"h:$_:"}) {
	    print STDERR "$USE_LIBMIME && ($s =~ /ISO/);\n";
	    $s = &DecodeMimeStrings($s) if $USE_LIBMIME && ($s =~ /ISO/);
	    print OUT "$_: $s\n";
	}
    }

    # append time() for convenience 
    # print OUT "X-Unixtime: ".(time)."\n";

    ### Body
    print OUT "\n";
    print OUT $USE_LIBMIME ? &DecodeMimeStrings($e{"Body"}) : $e{"Body"};
    print OUT "</PRE>\n";

    ### fclose
    close(OUT);

    &Log("Converted to HTML[$file.html]");

    1;
}


sub Configure 
{ 
    #  append only
    if ($HTML_EXPIRE <= 0) {	
	&Append2Index(@_);
	return;
    }
    # require reconfig of index.html for expiration
    else {
	&IndexReConfigure(@_) if(@HTML_FIELD);
    }
}


# append only
sub Append2Index
{
    local($dir, $file, *e) = @_;

    if (! -f "$dir/index.html") {
	&Debug("Create $dir/index.html") if $debug;
	&Log("Create $dir/index.html");
	&Append2("<TITLE>Spool $ML_FN</TITLE>", "$dir/index.html");
	&Append2("<HR><UL>", "$dir/index.html");
    }

    # append
    &Append2("<LI><A HREF=$file.html>$HtmlTitle</A>", "$dir/index.html");
    &Log("Append Entry=$file.html >> $dir/index.html");
}


sub GetEntry
{
    local($f) = @_;
    local($k, $v);

    open(F, $f) || &Log("Cannot open $f", return);
    while (<F>) {
	if (1 .. /^$/) {
	    s/keyword:\s*(\S+)/$k = $1/e;
	    s/subject:\s*(.*)/$s = $1/e;
	    last if /^$/;
	}
    }

    close(F);

    (($k || 'misc'), ($v || 'NONE'));
}


sub IndexReConfigure
{
    local($dir, $file, *e) = @_;
    local(*key, *subject);

    opendir(DIR, $dir) || &Log("Cannot opendir $dir", return);

    foreach $file (readdir(DIR)) {
	next if $file =~ /^\./o;
	next if $file =~ /^\s*$/o;

	($key, $subject) = &GetEntry("$dir/$file");
	next unless $key;

	$key{$file}      = $key;
	$subject{$file}  = $subject;
    }


    # O.K. reconfigure index.html
    open(OUT, "> $dir/index.html") || 
	(&Log("cannot open index.html"), return);
    select(OUT); $| = 1; select(STDOUT);


    close(OUT);

    &Log("$dir/index.html is reconfigured with fields");
}


# ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#       $atime,$mtime,$ctime,$blksize,$blocks)
#         = stat($filename);
# "last access, modify, change" = 8,9,10
sub Expire
{
    local($dir, $file, *e) = @_;
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
