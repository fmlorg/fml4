# Library of fml.pl
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# Aliases
# sub SendFileMajority  { &SendFile('#dummy', @_);}
# sub SendFile2Majority { &SendFile('#dummy', @_);}
sub SendFileMajority  { &SendFile2Majority(@_);}

# ($subject, $file, 0, @to);
sub SendFile2Majority 
{ 
    local($subject, $file, @to) = @_;
    local(@files) = $file;

    &NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
}


&use('utils');

# Parameters:
# $tmpf     : a temporary file
# $mode     : mode 
# $file     : filename of encode e.g. uuencode , ish ...
# @filelist : filelist of packing and encodeing. !REQUIRE push(@here,$file)!
#
# INSIDE VARIABLES:
# *conf : input 
# *r    : output
# *misc : output as an additional
sub DraftGenerate
{
    local(*conf, *r, *misc);
    local($prog, $proc);
    local($tmpf, $mode, $file, @conf) = @_; # attention! *conf above
    $conf = $tmpf;
    $r    = $file;
    $conf{'total'} = 0;

    &Debug("DraftGenerate ($tmpf, $mode, $file, @conf)") if $debug;

    &InitDraftGenerate;

    # INCLUDE
    require $_fp{'inc', $mode} if $_fp{'inc', $mode};

    foreach $proc ( # order 
		    'hdr',
		    'cnstr', 
		    'retrieve',
		    'split',
		    'destr'
		    ) {

	$prog = $_fp{$proc, $mode};
	if ($debug) {
	    print STDERR "Call [$proc]\t";
	    print STDERR "$prog(*conf, *r, *misc);" if $prog;
	    print STDERR "\n";
	}
	&$prog(*conf, *r, *misc) if $prog;
    }

    $r{'total'};
}


# Initialization of msending interface. 
# return NONE
sub InitDraftGenerate
{
    &MSendModeSet;

    # PLAIN TEXT with UNIX FROM
    $_fp{'cnstr',    'uf'} = 'Cnstr_uf';
    $_fp{'retrieve', 'uf'} = 'f_RetrieveFile';
    $_fp{'split',    'uf'} = '';
    $_fp{'destr',    'uf'} = '';

    # PLAINTEXT by RFC934
    $_fp{'cnstr',    'rfc934'}  = 'Cnstr_rfc934';
    $_fp{'retrieve', 'rfc934'}  = 'f_RetrieveFile';
    $_fp{'destr',    'rfc934'}  = 'Destr_rfc934';

    # PLAINTEXT by RFC1153
    $_fp{'cnstr',    'rfc1153'} = 'Cnstr_rfc1153';
    $_fp{'retrieve', 'rfc1153'} = 'f_RetrieveFile';

    # PLAINTEXT by MIME/Multipart
    $_fp{'cnstr',    'mp'} = 'Cnstr_mp';
    $_fp{'retrieve', 'mp'} = 'f_RetrieveFile';

    # Gzipped UNIX FROM
    $_fp{'cnstr',    'gz'} = 'Cnstr_gz';
    $_fp{'retrieve', 'gz'} = 'f_gz';
    $_fp{'split',    'gz'} = 'f_SplitFile';

    # PACK: TAR + GZIP
    $_fp{'cnstr',    'tgz'} = 'Cnstr_tgz';
    $_fp{'retrieve', 'tgz'} = 'f_tgz';
    $_fp{'split',    'tgz'} = 'f_SplitFile';

    # PACK: LHA + ISH
    $_fp{'cnstr',    'lhaish'} = '';
    $_fp{'retrieve', 'lhaish'} = 'f_LhaAndEncode2Ish';
    $_fp{'split',    'lhaish'} = 'f_SplitFile';

    # PACK: LHA + ISH
    $_fp{'cnstr',    'lhauu'} = '';
    $_fp{'retrieve', 'lhauu'} = 'f_LhaAndEncode2UU';
    $_fp{'split',    'lhauu'} = 'f_SplitFile';

    # UUENCODE ONLY
    $_fp{'retrieve', 'uu'}     = 'f_uu';
    $_fp{'split',    'uu'}     = 'f_SplitFile';

}


############################## CONSTRUCTORS


sub Cnstr_uf
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "From $MAINTAINER\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub Cnstr_rfc1153
{
    local(*conf, *r, *misc) = @_;
    local($mode) = 'rfc1153';

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n\n".('-' x 30)."\n\n";

    &use('rfc1153');
    local($PREAMBLE, $TRAILER) = &Rfc1153Custom($mode, @conf);

    print STDERR "PREAMBLE $PREAMBLE\nTRALER $TRAILER\n";

    $conf{'rfhook'}   = &Rfc1153ReadFileHook;
    $conf{'preamble'} = $PREAMBLE;
    $conf{'trailer'}  = $TRAILER;

    # set Destructor used in MSendv4.pl 
    # to increment the issue count of the digest
    $_cf{'Destr'} .= "&Rfc1153Destructer;\n";
}


sub Cnstr_rfc934
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n------- Forwarded Message\n\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';

    $conf{'rfhook'} = q#
	s/^-/- -/;
    #;
}


sub Destr_rfc934
{
    local(*conf, *r, *misc) = @_;

    undef $conf{'rfhook'};
}


# patched by mikami@saturn.hcs.ts.fujitsu.co.jp
# Posted:  Tue, 16 May 1995 23:20:32 JST
# fml-supoort ML: 00363
# Following this fix, modify
# $ORG_MIME_MULTIPART_BOUNDARY -> $MIME_MULTIPART_BOUNDARY
# $MIME_MULTIPART_BOUNDARY     -> $MIME_MULTIPART_DELIMITER
#
sub Cnstr_mp
{
    local(*conf, *r, *misc) = @_;
    local($boundary) = "--$MailDate--";
    $boundary =~ s/,//g; $boundary =~ s/\s+JST//g; $boundary =~ s/ /_/g;

    # MIME CONFIGURATION
    $MIME_VERSION              = $MIME_VERSION || '1.0';
    $MIME_CONTENT_TYPE         = $MIME_CONTENT_TYPE || 'multipart/mixed;';
    $MIME_MULTIPART_BOUNDARY   = $MIME_MULTIPART_BOUNDARY || $boundary;
    $MIME_MULTIPART_DELIMITER  = $MIME_MULTIPART_BOUNDARY;
    $MIME_MULTIPART_DELIMITER .= "\nContent-Type: message/rfc822\n";
    $MIME_MULTIPART_CLOSE_DELIMITER = $MIME_MULTIPART_BOUNDARY;

    # configurations 
    $conf{'plain'}     = 1;
    $conf{'total'}     = 1;
    $conf{'delimiter'} = "\n--$MIME_MULTIPART_DELIMITER\n";
    $conf{'preamble'}  = $MIME_MULTIPART_PREAMBLE if $MIME_MULTIPART_PREAMBLE;
    $conf{'trailer'}   = "\n--$MIME_MULTIPART_CLOSE_DELIMITER--\n";
    $conf{'trailer'}  .= $MIME_MULTIPART_TRAILER if $MIME_MULTIPART_TRAILER;

    # make MIME Header
    undef $Envelope{'r:MIME'};
    $Envelope{'r:MIME'} .= "MIME-Version: $MIME_VERSION\n";
    $Envelope{'r:MIME'} .= "Content-type: $MIME_CONTENT_TYPE\n";
    $Envelope{'r:MIME'} .= "\tboundary=\"$MIME_MULTIPART_BOUNDARY\"\n";
}


sub Cnstr_gz
{
    local(*conf, *r, *misc) = @_;

    $conf{'total'} = 0;
    $conf{'delimiter'} = "From $MAINTAINER\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub Cnstr_tgz
{
    local(*conf, *r, *misc) = @_;

    $conf{'total'} = 0;
    $conf{'delimiter'} = "From $MAINTAINER\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub f_RetrieveFile
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($file, $lines, $linecounter, $total, $new_p);
    local($total) = $conf{'total'};

    # OPEN
    &OpenStream($tmpf, 0, 0, $total) || (return 0);
    &Debug("OpenStream($tmpf, 0, 0, $total), success") if $debug; 
    
    # PREAMBLE
    if ($conf{'preamble'}) {
	print OUT $conf{'preamble'};
	$new_p++;
    }

    # Retrieve files
    foreach $file (@conf) {
	$lines = &WC($file);
	
	# open the next file
	&Debug("open(FILE, $file) || next;") if $debug_rf; 
	open(FILE, $file) || next; 
	print OUT $conf{'delimiter'} if $conf{'delimiter'};

 	if ($conf{'rfhook'}) {
	    local($s) = qq#
		while (<FILE>) { 
		    $conf{'rfhook'};
		    print OUT \$_; \$linecounter++;
		}
	    #;
	    &Debug(">>$s<<") if $debug;
	    &eval($s, 'Retreive file hook');
	}
	else {
	    while (<FILE>) { 
		print OUT $_; $linecounter++;
	    }
	}
	&Debug("close(FILE) [total=$total];") if  $debug_rf; 
	close(FILE);
	
	print OUT "\n"; $linecounter++;
	$new_p++;	# the number of files
	
	# If PLAIN TEXT, reset!
	if ($conf{'plain'} && ($linecounter + $lines) > $MAIL_LENGTH_LIMIT) {
	    # e.g. in the format of RFC1153, 
	    # each mail is perfect format is appropriate?
	    print OUT $conf{'trailer'} if $conf{'trailer'};

	    # Close Output
	    &CloseStream;

	    # Reconfig
	    $total++;
	    $linecounter = 0;

	    # Open new file(OUTPUT)
	    &OpenStream($tmpf, 0, 0, $total) || (return 0);

	    # if preamble only, not need to deliver, so new_p = 0
	    print OUT $conf{'preamble'} if $conf{'preamble'}; 
	    $new_p = 0;
	}
    }

    # TRAILER
    if ($conf{'trailer'}) {
	print OUT $conf{'trailer'};
	$new_p++ ;
    }

    # CLOSE
    &CloseStream;

    # if write filesize=0, decrement TOTAL.
    $total-- unless $new_p;

    $r{'total'} = $total;
}


sub f_LhaAndEncode2Ish 
{
    local(*conf, *r, *misc) = @_;
    &LhaAndEncode2Ish($conf, $r, @conf); # input:$conf;
}


sub f_LhaAndEncode2UU
{
    local(*conf, *r, *misc) = @_;
    &LhaAndEncode2UU($conf, $r, @conf); # input:$conf;
}


sub f_gz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &f_RetrieveFile(*conf, *r, *misc);
    &system("$COMPRESS $tmpf.0|$UUENCODE $r", $tmpf);
}


sub f_tgz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &system("$TAR ".join(" ", @conf)."|$COMPRESS|$UUENCODE $r", $tmpf);
}


sub f_uu
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($f, $dir);

    $r =~ s#(\S+)/(\S+)#$dir=$1, $f=$2#e;

    &system("chdir $dir; $UUENCODE $f $f", $tmpf);
}


sub f_gzuu
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &system("$COMPRESS $tmpf.0|$UUENCODE $r", $tmpf);
}


sub f_SplitFile
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($total) = $r{'total'};

    &Debug("f_SplitFile: $r => $tmpf") if $debug;

    local($totallines) = &WC($tmpf);
    $total = int($totallines/$MAIL_LENGTH_LIMIT + 1);
    &Debug("f_SplitFile: $total <= $totallines/$MAIL_LENGTH_LIMIT") if $debug;

    if ($total > 1) {
	local($s) = &SplitFiles($tmpf, $totallines, $total);
	if ($s == 0) {
	    &Log("f_SplitFile: Cannot split $tmpf");
	    return 0;
	}
    }
    elsif (1 == $total) {# a trick for &SendingBackInOrder;
	&Debug("f_SplitFile: rename($tmpf, $tmpf.1)") if $debug; 
	rename($tmpf, "$tmpf.1"); 
    }

    $r{'total'} = $total;
}
##############################


# Open FILEHANDLE 'OUT'.
# PACK_P is backward compatibility since 
# PACK_P is always 0!
# return 1 if succeed;
sub OpenStream_OUT { &OpenStream(@_);}
sub OpenStream
{
    local($WHERE, $PACK_P, $FILE, $TOTAL) = @_;

    &Debug("OpenStream: open OUT > $WHERE.$TOTAL;") if $debug;
    open(OUT, "> $WHERE.$TOTAL") || do { 
	&Log("OpenStream: cannot open $WHERE.$TOTAL");
	return $NULL;
    };
    select(OUT); $| = 1; select(STDOUT);

    1;
}


# Aliases for symmetry. close FILEHANDLE 'OUT'
sub CloseStream     { close(OUT);}
sub CloseStream_OUT { close(OUT);}


# Word Counting of the gigen file
# return lines
sub WC
{
    local($f) = @_;
    local($lines) = 0;

    open(TMP, $f) || return 0;
    while (<TMP>) { 
	$lines++;
    }
    close(TMP);

    $lines;
}


# Split files and unlink the original
# $file - split -> $file.1 .. $file.$TOTAL files 
# return the number of splitted files
sub SplitFiles
{
    local($file, $totallines, $TOTAL) = @_;
    local($unit)  = int($totallines/$TOTAL); # equal lines in each file
    local($lines) = 0;
    local($i)     = 1;		# split to (1 .. $TOTAL)

    open(BUFFER,"< $file")    || do { &Log($!); return 0;};
    open(OUT,   "> $file.$i") || do { &Log($!); exit 1;};
    select(OUT); $| = 1; select(STDOUT);

    while (<BUFFER>) {
	print OUT $_; $lines++;

	# Reset
	if ($lines > $unit) { 
	    $lines = 0; 
	    close OUT; 
	    $i++;

	    &Debug("open(OUT, > $file.$i)") if $debug;

	    # Next file
	    open(OUT, "> $file.$i") || do { &Log($!); return 0;};
	    select(OUT); $| = 1; select(STDOUT);
	}
    }# WHILE;

    close(OUT);

    # delete original source
    unlink $file unless $_cf{'splitfile', 'NOT unlink'}; 
    &Debug("SplitFiles:unlink $file") if $debug;

    $i;
}


# Making files encoded and compressed for the given @filelist
# if PACK_P >0(PACKING),
# packed one is > "$WHERE.0"
# $FILE is an finally encoded name 
# if plain,
# $WHERE.1 -> $WHERE.$TOTAL(>=1) that is .1, .2, .3...
# return $TOTAL
sub MakeFilesWithUnixFrom { &DraftGenerate(@_);}
sub MakeFileWithUnixFrom  { &DraftGenerate(@_);}

# Lha + uuencode for $FILE
# &Lha..( inputfile, encode-name, @list ) ;
# return ENCODED_FILENAME
sub LhaAndEncode2Ish
{
    local($input, $name, @filelist) = @_;
    local($tmpout);

    &Debug("LhaAndEncode2Ish($input, $name, @filelist)") if $debug;

    # SJIS ENCODING
    if ($USE_SJIS_in_ISH) {
	require 'jcode.pl';
	@filelist = &Convert2Sjis(*filelist);
    }

    &Debug("LhaAndEncode2Ish($input, $name, @filelist)") if $debug;

    # Variable setting
    $name     =~ s#(\S+)/(\S+)#$2.lzh#;
    $name     =~ s/\.gz$/.lzh/;
    $name     =~ s/\.lzh\.lzh$/.lzh/;
    $tmpout   = "$TMP_DIR/$name";
    $LHA      = $LHA || "$LIBDIR/bin/lha";
    $ISH      = $ISH || "$LIBDIR/bin/aish";
    $COMPRESS = "$LHA a $tmpout ". join(" ", @filelist);
    $UUENCODE = "$ISH -s7 -o $input $tmpout";

    unlink $tmpout if -f $tmpout; # against strange behaviours by "lha";

    &system($COMPRESS);
    &system($UUENCODE);

    unlink @filelist if (!$debug) && $USE_SJIS_in_ISH; #unlnik tmp/spool/*
    unlink $tmpout unless $debug;	# e.g. unlink msend.lzh

    $input;
}


# Lha + uuencode for $FILE
# &Lha..( inputfile, encode-name, @list ) ;
# return ENCODED_FILENAME
sub LhaAndEncode2UU
{
    local($input, $name, @filelist) = @_;
    local($tmpout);

    &Debug("LhaAndEncode2Ish($input, $name, @filelist)") if $debug;

    # SJIS ENCODING
    if ($USE_SJIS_in_ISH) {
	require 'jcode.pl';
	@filelist = &Convert2Sjis(*filelist);
    }

    &Debug("LhaAndEncode2UU($input, $name, @filelist)") if $debug;

    # Variable setting
    $name     =~ s#(\S+)/(\S+)#$2.lzh#;
    $name     =~ s/\.gz$/.lzh/;
    $name     =~ s/\.lzh\.lzh$/.lzh/;
    $tmpout   = "$TMP_DIR/$name";
    $LHA      = $LHA || "$LIBDIR/bin/lha";
    $COMPRESS = "$LHA a $tmpout ". join(" ", @filelist);

    unlink $tmpout if -f $tmpout; # against strange behaviours by "lha";

    &system($COMPRESS);
    &system("$UUENCODE $name", $input, $tmpout);

    unlink @filelist if (!$debug) && $USE_SJIS_in_ISH; #unlnik tmp/spool/*
    unlink $tmpout unless $debug;	# e.g. unlink msend.lzh

    $input;
}


# Convert @filelist -> 
# return filelist(may be != given filelist e.g. spool -> tmp/spool)
# &system 's parameter is ($cmd , $out, $in)
# 
sub Convert2Sjis
{
    local(*f) = @_;
    local(*r, $tmp, $tmpf);

    $tmp  = $TMP_DIR;
    $tmpf = "$tmp/$$";
    $tmp  =~ s/^\.\///; # $SPOOL_DIR/,  tmp/, ...;

    # temporary directory
    -d "$TMP_DIR/spool" || mkdir("$TMP_DIR/spool", 0700);

    # GO!
    foreach $r (@f) { 
	$r =~ s/^\.\///; # $SPOOL_DIR/, tmp/, ...;

	&Debug("file2sjis($r, $tmpf)") if $debug;
	&file2sjis($r, $tmpf) || next;

	if ($r =~ /^$SPOOL_DIR/) {
	    rename($tmpf, "$TMP_DIR/$r") || 
		&Log("cannot rename $tmf $TMP_DIR/$r");
	    push(@r, "$TMP_DIR/$r");
	}
	elsif ($r =~ /^$tmp/) {
	    rename($tmpf, $r) || &Log("cannot rename $tmf $r");
	    push(@r, $r);
	}
	else {
	    ### SPECIAL EFFECT: for SendFileBySplit to send ONE FILE;
	    $r = $name;
	    $r =~ s#(\S+)/(\S+)#$tmp/$2#;
	    rename($tmpf, $r) || &Log("cannot rename $tmf $r");
	    push(@r, $r);	
	}
    }

    @r;	# return;
}


# using jcode.pl and add ^M and ^Z
# return 1 if succeed
sub file2sjis 
{
    local($in, $out) = @_;
    local($line);

    open(IN, $in)       || (&Log("file2sjis < $in: $!"),  return $NULL);
    open(OUT, "> $out") || (&Log("file2sjis > $out: $!"), return $NULL);
    select(OUT); $| = 1; select(STDOUT);

    while (<IN>) {
	&jcode'convert(*_, 'sjis');#';
	s/\012$/\015\012/; # ^M^J
	print OUT $_;
    }

    print OUT "\032\012";	# ^Z
    close(IN);
    close(OUT);

    1;
}


# Sending files back, Orderly is [a], not [ad] _o_
# $returnfile not include $DIR PATH
# return NONE
sub SendingBackOrderly { &SendingBackInOrder(@_);}
sub SendingBackInOrder
{
    local($returnfile, $TOTAL, $SUBJECT, $SLEEPTIME, @to) = @_;

    foreach $now (1..$TOTAL) {
	local($file) = "$DIR/$returnfile.$now";
	$0 = ($PS_TABLE || "--SendingBackInOrder $FML"). 
	    " Sending Back $now/$TOTAL";
	&Log("SendBackInOrder[$$] $now/$TOTAL $to");

	$subject = "$SUBJECT ($now/$TOTAL) $ML_FN";
	@files = ($file);
	&NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
	#    &SendFile2Majority("$SUBJECT ($now/$TOTAL) $ML_FN", $file, @to);
	# -> &NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);

	unlink $file unless $debug;

	$0 = ($PS_TABLE || "--SendingBackInOrder $FML"). 
	    " Sleeping [".($SLEEPTIME ? $SLEEPTIME : 3)."] $now/$TOTAL";
	sleep($SLEEPTIME ? $SLEEPTIME : 3);
    }

    &Debug("SBO:unlink $returnfile $returnfile.[0-9]*") if $debug;
    unlink $returnfile if ((! $_cf{'splitfile', 'NOT unlink'}) && (! $debug));
    unlink "$returnfile.0" unless $debug; # a trick for MakeFileWithUnixFrom

    undef $Envelope{'r:MIME'}; # destructor
}


# Split the given file and send back them
# ($f, $mode, $subject, @to)
# $f          the target file
# $mode
# $subject
# @to 
# return NONE
sub SendFilebySplit
{
    local($f, $mode, $enc, @to) = @_;
    local($total, $s, $target);
    local($sleep) = ($SLEEPTIME || 3);
    local($tmp)   = "$TMP_DIR/$$";

    $0 = "--Split and Sendback $f to $to $ML_FN <$FML $LOCKFILE>";
    $s = ($enc || "Matomete Send");

    # local($tmpf, $mode, $file, @conf)
    # $tmpf     : a temporary file 
    # $mode     : mode 
    # $file     : filename of encode e.g. uuencode , ish ...
    &Debug("SendFilebySplit::DraftGenerate($tmp, $mode, $f, $f)") 
	if $debug;
    $total = &DraftGenerate($tmp, $mode, $f, $f);

    &Debug("SendFilebySplit::($tmp, $total, $s, $sleep, @to)") if $debug;
    if ($total) {
	&SendingBackInOrder($tmp, $total, $s, $sleep, @to);
    }

    undef $Envelope{'r:MIME'}; # destructor. 
}


1;
