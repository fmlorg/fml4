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

# local scope in this
local($CurrentMode);

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
    require $_FOPH{'inc', $mode} if $_FOPH{'inc', $mode};

    foreach $proc ( # order 
		   'hdr',
		   'cnstr', 
		   'retrieve',
		   'encode',
		   'split',
		   'encode_as',
		   'destr'
		   ) {

	$prog = $_FOPH{$proc, $mode};
	if ($debug) {
	    print STDERR "Call [$proc]\t";
	    print STDERR "$prog(*conf, *r, *misc);" if $prog;
	    print STDERR "\n";
	}
	$CurrentMode = $mode;
	&$prog(*conf, *r, *misc) if $prog;
    }

    undef %conf;

    $r{'total'};
}


# Initialization of msending interface. 
# return NONE
sub InitDraftGenerate
{
    ### 2.1B test ###
    $FOP_HACK = 1;
    ### 2.1B test end ###

    &MSendModeSet;

    # PLAIN TEXT with UNIX FROM
    $_FOPH{'cnstr',    'uf'} = 'Cnstr_uf';
    $_FOPH{'retrieve', 'uf'} = 'FOP_RetrieveFile';
    $_FOPH{'split',    'uf'} = '';
    $_FOPH{'destr',    'uf'} = '';

    # PLAINTEXT by RFC934
    $_FOPH{'cnstr',    'rfc934'}  = 'Cnstr_rfc934';
    $_FOPH{'retrieve', 'rfc934'}  = 'FOP_RetrieveFile';
    $_FOPH{'destr',    'rfc934'}  = 'Destr_rfc934';

    # PLAINTEXT by RFC1153
    $_FOPH{'cnstr',    'rfc1153'} = 'Cnstr_rfc1153';
    $_FOPH{'retrieve', 'rfc1153'} = 'FOP_RetrieveFile';

    # PLAINTEXT by MIME/Multipart
    $_FOPH{'cnstr',    'mp'} = 'Cnstr_mp';
    $_FOPH{'retrieve', 'mp'} = 'FOP_RetrieveFile';

    ### encoding ###

    # UUENCODE ONLY
    $_FOPH{'retrieve', 'uu'}     = 'FOP_uu';
    $_FOPH{'split',    'uu'}     = 'FOP_SplitFile';

    # Base64 Encode Only
    $_FOPH{'cnstr',    'base64'} = 'Cnstr_message_partial';
    $_FOPH{'retrieve', 'base64'} = 'FOP_RetrieveFile';
    $_FOPH{'encode',   'base64'} = 'FOP_base64';
    $_FOPH{'split',    'base64'} = 'FOP_SplitFile';
    $_FOPH{'encode_as','base64'} = 'Cnstr_message_partial';

    ### compression + encoding ###

    # Gzipped UNIX FROM
    $_FOPH{'cnstr',    'gz'} = 'Cnstr_gz';
    $_FOPH{'retrieve', 'gz'} = 'FOP_gz';
    $_FOPH{'encode',   'gz'} = 'FOP_gz_encode';
    $_FOPH{'split',    'gz'} = 'FOP_SplitFile';

    # PACK: TAR + GZIP
    $_FOPH{'cnstr',    'tgz'} = 'Cnstr_tgz';
    $_FOPH{'retrieve', 'tgz'} = 'FOP_tgz';
    $_FOPH{'encode',   'tgz'} = 'FOP_gz_encode';
    $_FOPH{'split',    'tgz'} = 'FOP_SplitFile';

    # PACK: TAR + GZIP
    $_FOPH{'cnstr',    'zip'} = 'Cnstr_message_partial';
    $_FOPH{'retrieve', 'zip'} = 'FOP_zip';
    $_FOPH{'encode',   'zip'} = 'FOP_base64';
    $_FOPH{'split',    'zip'} = 'FOP_SplitFile';

    # PACK: LHA + ISH
    $_FOPH{'cnstr',    'lhaish'} = '';
    $_FOPH{'retrieve', 'lhaish'} = 'FOP_Lha';
    $_FOPH{'encode',   'lhaish'} = 'FOP_lha_encode';
    $_FOPH{'split',    'lhaish'} = 'FOP_SplitFile';

    # PACK: LHA + UUENCODE
    $_FOPH{'cnstr',    'lhauu'}  = '';
    $_FOPH{'retrieve', 'lhauu'}  = 'FOP_Lha';
    $_FOPH{'encode',   'lhauu'}  = 'FOP_lha_encode';
    $_FOPH{'split',    'lhauu'}  = 'FOP_SplitFile';
}


########### CONSTRUCTORS ##########


sub Cnstr_uf
{
    local(*conf, *r, *misc) = @_;

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "From $MAINTAINER $MailDate\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';

    $conf{'MimeDecodable'} = 1;
}


sub Cnstr_rfc1153
{
    local(*conf, *r, *misc) = @_;
    local($mode) = 'rfc1153';

    $conf{'plain'} = 1;
    $conf{'total'} = 1;
    $conf{'delimiter'} = "\n\n".('-' x 30)."\n\n";

    &use('rfc1153');
    local($preamble, $trailer) = &Rfc1153Custom($mode, *conf);

    &Debug("preamble $preamble\ntrailer $trailer") if $debug;

    $conf{'rfhook'}   = &Rfc1153ReadFileHook;
    $conf{'preamble'} = $preamble;
    $conf{'trailer'}  = $trailer;

    # set Destructor used in MSendv4.pl 
    # to increment the issue count of the digest
    $_PCB{'Destr'} .= "&Rfc1153Destructer;\n";

    $conf{'MimeDecodable'} = 1;
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
    undef $Envelope{'GH:Mime-Version:'};
    undef $Envelope{'GH:Content-Type:'};
    $Envelope{'GH:Mime-Version:'} = $MIME_VERSION;
    $Envelope{'GH:Content-Type:'} = 
	"$MIME_CONTENT_TYPE\n\tboundary=\"$MIME_MULTIPART_BOUNDARY\"";
}


sub Cnstr_gz
{
    local(*conf, *r, *misc) = @_;

    &DiagPrograms('UUENCODE', 'COMPRESS');

    $conf{'total'} = 0;
    $conf{'delimiter'} = "From $MAINTAINER $MailDate\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


sub Cnstr_tgz
{
    local(*conf, *r, *misc) = @_;

    &DiagPrograms('UUENCODE', 'COMPRESS', 'TAR');

    $conf{'total'} = 0;
    $conf{'delimiter'} = "From $MAINTAINER $MailDate\n";
    $conf{'preamble'} = '';
    $conf{'trailer'}  = '';
}


# DEBUG OPTION: 
# $debug_rf (RF == Retrive File)?
sub FOP_RetrieveFile
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
	# $new_p++; # not increment against separator-only-file
    }

    # Retrieve files
    local($s);
    local($curhf); # alloc special variable for rfhook

    for $file (@conf) {
	$lines = &WC($file);
	
	# open the next file
	&Debug("open(FILE, $file) || next;") if $debug_rf; 
	open(FILE, $file) || next; 
	print OUT $conf{'delimiter'} if $conf{'delimiter'};

 	if ($conf{'rfhook'}) {
	    # rfhook is evaluated after (1 .. /^$/) condition
	    # since eval() influences this $. check?
	    $s = qq#
		while (<FILE>) { 
		    if (1 .. /^\$/) {
			if (\$FOP_HACK && \$USE_MIME &&
			    \$conf{'MimeDecodable'} && 
			    /=\\?ISO\\-2022\\-JP\\?/io) {
			    &use('MIME');
			    \$_ = &DecodeMimeStrings(\$_);
			}
		    }

		    $conf{'rfhook'};

		    print OUT \$_; 
		    \$linecounter++;
		}
	    #;

	    &Debug(">>$s<<") if $debug;
	    &eval($s, 'Retrieve file hook');
	}
	else {
	    while (<FILE>) {
		if (1 .. /^$/) {
		    if ($FOP_HACK && $USE_MIME &&
			$conf{'MimeDecodable'} && /=\?ISO\-2022\-JP\?/io) {
			&use('MIME');
			$_ = &DecodeMimeStrings($_);
		    }
		}
		
		print OUT $_; 
		$linecounter++;
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
    if ($new_p && $conf{'trailer'}) { # already wirte at least one file 
	print OUT $conf{'trailer'};
	# $new_p++; # not increment against separator-only-file
    }

    # CLOSE
    &CloseStream;

    # if write filesize=0, decrement total.
    # decrement the seq and should unlink it(size=0)
    if (! $new_p) {
	unlink "$tmpf.$total" if -z "$tmpf.$total"; # if size = 0;
	$total--;
    }

    $r{'total'} = $total;
}


sub FOP_Lha
{
    local(*conf, *r, *misc) = @_;
    &Lha($conf, $r, @conf); # input:$conf;
}


sub FOP_gz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &FOP_RetrieveFile(*conf, *r, *misc);
    # &system("$COMPRESS $tmpf.0|$UUENCODE $r", $tmpf);
    &system("$COMPRESS $tmpf.0", $tmpf);
}


sub FOP_tgz
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    # &system("$TAR ".join(" ", @conf)."|$COMPRESS|$UUENCODE $r", $tmpf);
    &system("$TAR ".join(" ", @conf)."|$COMPRESS", $tmpf);
}


sub FOP_gz_encode
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    # splitfile uses "$tmpf" as a mster.
    rename($tmpf, "$tmpf.1");

    &system("$UUENCODE $r", $tmpf, "$tmpf.1");
}


sub FOP_zip
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($t)    = "msend.zip";

    $ZIP = $ZIP || "/usr/local/bin/zip";

    &DiagPrograms('ZIP');

    if (!-x $ZIP) {
	&Log("FOP_zip: cannot find zip executable");
	return;
    }

    &system("$ZIP $t @conf");
    rename($t, "$tmpf.0") || &Log("cannot rename $t $tmpf.0");

    $Envelope{"GH:Content-Type:"} .= "\n\tname=\"msend.zip\";";
}


sub FOP_uu_conf_gobble
{
    local($out, *conf) = @_;

    open(OUT, "> $out") || return;
    select(OUT); $| = 1; select(STDOUT);

    for (@conf) {
	&Debug("   FOP_uu_conf_gobble::open($_)\n") if $debug;
	if (open(F, $_)) { 
	    while (<F>) { print OUT $_;};
	    close(F);
	}
    }

    close(OUT);
}


sub FOP_uu
{
    local(*conf, *r, *misc) = @_;
    local($f, $dir, $name, $output, $input);
    local($tmpf) = $conf;
    local($tmpr) = $r;

    # answer: cat @conf | uuencode msend.uu > $tmpf, isnt it?
    if (@conf) {
	$output = $tmpf;
	$input  = "$TMP_DIR/msend.uu";
	$name   = $r;
	&FOP_uu_conf_gobble($input, *conf);
    }
    # Example: $r=old/100.tar.gz $old=old $f=100.tar.gz if @conf == 1;
    else {
	$tmpr   =~ s#(\S+)/(\S+)#$dir=$1, $f=$2#e;
	$name   = $f;
	$dir    = $dir || '.';
	$f      = $f || $tmpr;
	$input  = "$dir/$f";
	$output = $tmpf;
    }

    # filename to use in uudecofing
    $name =~ s#^.*/(.*)#$1#;

    if ($debug) {
	&Debug("\n   FOP_uu_conf_gobble::($input @conf)");
	&Debug("   FOP_uu::conf=$conf r=$r misc=$misc name=$name");
	&Debug("   FOP_uu::system(uuencode < $input > $tmpf)");
	&Debug("   system($UUENCODE $name, $output, $input);");
    }

    # uuencode soure-file file-label
    # &system("chdir $dir; $UUENCODE $f $f", $tmpf);
    # &system("$UUENCODE $dir/$f $f", $tmpf); 
    # system($s, $out, $in, $read, $write)
    &DiagPrograms('UUENCODE');
    &system("$UUENCODE $name", $output, $input); 
    unlink "$TMP_DIR/msend.uu" if -f "$TMP_DIR/msend.uu";
}


sub Cnstr_message_partial
{
    local($id) = &GenMessageId;

    $MIME_VERSION              = $MIME_VERSION || '1.0';

    $Envelope{'GH:Mime-Version:'} = $MIME_VERSION;
    $Envelope{'GH:Content-Type:'} = 
	"message/partial;\n\tnumber=1; total=1;\n\tid=\"$id\";";
    $Envelope{'GH:Content-Transfer-Encoding:'} = "base64";
}


sub FOP_base64
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($encode, $libdir);

    $encode = &SearchFileInLIBDIR("bin/base64encode.pl");
    $libdir = join(":", @LIBDIR);
    $BASE64_ENCODE = $BASE64_ENCODE || "$encode -I $libdir";

    &DiagPrograms('BASE64_ENCODE');

    open(IN, "$tmpf.0") || &Log("FOP_base64: cannot open $tmpf");
    open(BASE64, "|$BASE64_ENCODE > $tmpf.1") ||
	&Log("FOP_base64: cannot open $tmpf.1");
    select(BASE64); $| = 1; select(STDOUT);
    binmode(IN);
    while (<IN>) {
	print BASE64 $_;
    }
    close(IN);
    close(BASE64);

    &Debug("rename($tmpf.1, $tmpf);") if $debug;
    rename("$tmpf.1", $tmpf) || &Log("FOP_base64: cannot rename $tmpf.1 $tmpf");
}


sub FOP_gzuu
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;

    &DiagPrograms('UUENCODE', 'COMPRESS');
    &system("$COMPRESS $tmpf.0|$UUENCODE $r", $tmpf);
}


sub FOP_SplitFile
{
    local(*conf, *r, *misc) = @_;
    local($tmpf) = $conf;
    local($total) = $r{'total'};

    &Debug("FOP_SplitFile: $r => $tmpf") if $debug;

    local($totallines) = &WC($tmpf);
    $total = int($totallines/$MAIL_LENGTH_LIMIT + 1);
    &Debug("FOP_SplitFile: $total <= $totallines/$MAIL_LENGTH_LIMIT") if $debug;

    if ($total > 1) {
	local($s) = &SplitFiles($tmpf, $totallines, $total);
	if ($s == 0) {
	    &Log("FOP_SplitFile: Cannot split $tmpf");
	    return 0;
	}
    }
    elsif (1 == $total) {# a trick for &SendingBackInOrder;
	&Debug("FOP_SplitFile: rename($tmpf, $tmpf.1)") if $debug; 
	rename($tmpf, "$tmpf.1") || &Log("cannot rename $tmpf $tmpf.1"); 
    }

    $r{'total'} = $total;
}
##############################


# Open FILEHANDLE 'OUT'.
# packp is backward compatibility since 
# packp is always 0!
# return 1 if succeed;
sub OpenStream_OUT { &OpenStream(@_);}
sub OpenStream
{
    local($where, $packp, $file, $total) = @_;

    &Debug("OpenStream: open OUT > $where.$total;") if $debug;
    open(OUT, "> $where.$total") || do { 
	&Log("OpenStream: cannot open $where.$total");
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
# $file - split -> $file.1 .. $file.$total files 
# return the number of splitted files
sub SplitFiles
{
    local($file, $totallines, $total) = @_;
    local($unit)  = int($totallines/$total); # equal lines in each file
    local($lines) = 0;
    local($i)     = 1;		# split to (1 .. $total)

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
    unlink $file unless $_PCB{'splitfile', 'NOT unlink'}; 
    &Debug("SplitFiles:unlink $file") if $debug;

    $i;
}


# Making files encoded and compressed for the given @filelist
# if PACK_P >0(PACKING),
# packed one is > "$where.0"
# $file is an finally encoded name 
# if plain,
# $where.1 -> $where.$total(>=1) that is .1, .2, .3...
# return $total
sub MakeFilesWithUnixFrom { &DraftGenerate(@_);}
sub MakeFileWithUnixFrom  { &DraftGenerate(@_);}

# Lha + uuencode for $file
# &Lha..( inputfile, encode-name, @list ) ;
# return ENCODED_FILENAME
# sub LhaAndEncode2Ish
sub Lha
{
    local($input, $name, @filelist) = @_;
    local($tmpout, @unlink);
    local($compress, $uuencode);

    &Debug("Lha($input, $name, @filelist)") if $debug;

    # SJIS ENCODING
    if ($USE_SJIS_in_ISH || $USE_SJIS_IN_ISH) {
	require 'jcode.pl';
	@filelist = &Convert2Sjis(*filelist); # reset 
	push(@unlink, @filelist);
	&Debug("LhaAndEncode2Ish($input, $name, @filelist)") if $debug;
    }

    # Variable setting
    $name     =~ s#(\S+)/(\S+)#$2.lzh#;
    $name     =~ s/\.gz$//i;
    $name     =~ s/\.lzh$//i;
    $tmpout   = "$TMP_DIR/$name.lzh";
    push(@unlink, $tmpout);	# unlink

    &DiagPrograms('LHA');

    $LHA      = $LHA || "$LIBDIR/bin/lha";

    $compress = "$LHA a $tmpout @filelist ";

    # against unremoved left files;
    unlink $tmpout if -f $tmpout; 

    &system($compress);

    $misc{'name'}   = $name;
    $misc{'input'}  = $input;
    $misc{'tmpout'} = $tmpout;
    $misc{'unlink'} = join(" ", @unlink);
}


sub FOP_lha_encode
{
    local(*conf, *r, *misc) = @_;
    local($name, $input, $tmpout, @unlink);

    $name   = $misc{'name'};
    $input  = $misc{'input'};
    $tmpout = $misc{'tmpout'};

    if ($CurrentMode =~ /uu/) {
	&DiagPrograms('UUENCODE');
	&system("$UUENCODE $name.lzh", $input, $tmpout);
    }
    elsif ($CurrentMode =~ /ish/) {
	$ISH      = $ISH || "$LIBDIR/bin/ish";
	$tmpish   = "$TMP_DIR/$name.ish";

	# FIX for 'aish' when NOT "aish -d"
	($ISH =~ /aish/) && ($ISH !~ /\s+\-d\s+/) && ($ISH .= " -d ");

	&DiagPrograms('ISH');

	$uuencode = "$ISH -s7 $name.lzh"; # since in $TMP_DIR
	#OLD: $uuencode = "$ISH -s7 -o $input $tmpout";

	# ish cannot understand ">tmp/*.lzh.ish"
	if ($INSECURE_SYSTEM) {
	    system("(cd $TMP_DIR; $uuencode)");
	}
	else {
	    &use('utils');

	    local($pwd);
	    chop($pwd = `pwd`);
	    (chdir $TMP_DIR) ? 
		&system($uuencode) :
		    &Log("FOP_lha_encode: cannot chdir $TMP_DIR");
	    chdir $pwd || &Log("FOP_lha_encode: cannot chdir $pwd");
	}

	unlink $tmpout if -f $tmpout; # lha
	rename($tmpish, $input) || &Log("canot rename $tmpish $input");
    }

    # temporary files to remove
    @unlink = split(/\s+/, $misc{'unlink'});

    if ($debug) { 
	print STDERR "   Unlink @unlink \n";
    }
    else { 
	unlink @unlink if @unlink;
    }

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
    -d "$TMP_DIR/spool" || &Mkdir("$TMP_DIR/spool");

    # GO!
    foreach $r (@f) { 
	$r =~ s/^\.\///; # $SPOOL_DIR/, tmp/, ...;

	&Debug("FileConv2SJIS($r, $tmpf)") if $debug;
	&FileConv2SJIS($r, $tmpf) || next;

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
	    rename($tmpf, $r) || &Log("cannot rename $tmpf $r");
	    push(@r, $r);	
	}
    }

    @r;	# return;
}


# using jcode.pl and add ^M and ^Z
# return 1 if succeed
sub FileConv2SJIS 
{
    local($in, $out) = @_;

    open(IN, $in)       || (&Log("FileConv2SJIS < $in: $!"),  return $NULL);
    open(OUT, "> $out") || (&Log("FileConv2SJIS > $out: $!"), return $NULL);
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


sub SendingBackInOrderTimeOut 
{ 
    &SocketTimeOut;
    $SendingBackInOrderTimeOut = 1;
}

# Sending files back, Orderly is [a], not [ad] _o_
# $returnfile not include $DIR PATH
# return NONE
sub SendingBackInOrder { &SendBackInOrder(@_);}
sub SendingBackOrderly { &SendBackInOrder(@_);}
sub SendBackInOrder
{
    local($returnfile, $total, $subj, $sleeptime, @to) = @_;
    local($file, @files, $evid, $evidk, $evidk0, %mib);

    # reset timeout flag;
    undef $SendingBackInOrderTimeOut;

    # sleep time;
    $sleeptime = $sleeptime ? $sleeptime : 3;

    # set the final remove event (the case "$total == 0" is possible???)
    $evidk0 = &SetEvent((60 + $sleeptime)*($total+1), 'TimeOut') if $HAS_ALARM;

    for $now (1..$total) {
	if ($SendingBackInOrderTimeOut) { # time out 
	    $now-- if $now > 1;
	    &Log("SendingBackInOrder::TimeOut, give up to send $now<=>$total");
	    last;
	}

	# timeout: dead timeout and socket timeout
	$evidk = &SetEvent($sleeptime + 120, 'TimeOut') if $HAS_ALARM;
	$evid  = &SetEvent($sleeptime + 60, 'SendingBackInOrderTimeOut');

	if ($COMPAT_ARCH eq 'WINDOWS_NT4') {
	    $file = "$returnfile.$now";
	}
	else {
	    $file = ($returnfile =~ m%^/% ? "" : $DIR)."/$returnfile.$now";
	}
	
	$0 = "${FML}: SendingBackInOrder $now/$total";
	&Log("SendBackInOrder[$$] $now/$total $to");

        # subject is reset anytime;
	%template_cf = ("_PART_",  "($now/$total)",
			"_ML_FN_", $ML_FN);
	$subject = &SubstituteTemplate($subj, *template_cf);

	# message/partial
	if ($Envelope{'GH:Content-Type:'} =~ /partial/) {
	    $mib{'number'} = $now;
	    $mib{'total'}  = $total;
	    &MIMESubstitute('message/partial', *mib);
	}

	@files = ($file);
	&NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
	#    &SendFile2Majority("$subj ($now/$total) $ML_FN", $file, @to);
	# -> &NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
		 
	unlink $file unless $debug;

	$0 = "${FML}: SendingBackInOrder sleep($sleeptime) cur=$now/$total";

	# remove event handler
	&ClearEvent($evid)  if $evid;  $evid  = 0;
	&ClearEvent($evidk) if $evidk; $evidk = 0;

	sleep(($total == $now) ? 1 : $sleeptime); # no wait when ends;
    }

    &Debug("SBO:unlink $returnfile $returnfile.[0-9]*") if $debug;
    unlink $returnfile if ((! $_PCB{'splitfile', 'NOT unlink'}) && (! $debug));
    unlink "$returnfile.0" unless $debug; # a trick for MakeFileWithUnixFrom

    # for example, msend.pl uses this routine several times.
    # We should clean up all events.
    &ClearEvent($evid)   if $evid;
    &ClearEvent($evidk)  if $evidk;
    &ClearEvent($evidk0) if $evidk0;

    # Destructor; 
    &ClearMimeHdr;
}


sub DelaySendFileDividedly
{
    # for unique tmp file
    $DSFD_Counter++;

    local($f, $mode, $enc, @to) = @_;
    local($total, $s, $target);
    local($sleep) = ($SLEEPTIME || 3);
    local($tmp)   = "$TMP_DIR/sfbs:${DSFD_Counter}:$$";

    $0 = "${FML}: split and send back $f to $to <$MyProcessInfo>";
    $s = $enc || $DEFAULT_MGET_SUBJECT;

    ### IF MIME mode, you are afraid of a lot ...
    if ($mode ne 'uf') {
	&Log("DelaySendFileDividedly: accept only 'uf' mode");
	return $NULL;
    }

    ##### SAME AS "SendFileDividedly" #####
    $total = &DraftGenerate($tmp, $mode, $f, $f);

    # Hmm, O.K. In some case
    # back to the first filename for the use of SplitFiles
    local($lc) = &WC("$tmp.1");
    if ($lc > $MAIL_LENGTH_LIMIT && $total == 1) {
	rename("$tmp.1", $tmp) || &Log("cannot rename $tmp.1 $tmp");
	$total = &SplitFiles($tmp, $lc, int($lc/$MAIL_LENGTH_LIMIT) + 1);
    }

    if ($total) {
	$SFD_MIB{"$DSFD_Counter:tmp"}   = $tmp;
	$SFD_MIB{"$DSFD_Counter:total"} = $total;
	$SFD_MIB{"$DSFD_Counter:s"}     = $s;
	$SFD_MIB{"$DSFD_Counter:sleep"} = $sleep;
	$SFD_MIB{"$DSFD_Counter:\@to"}  = join(" ", @to);

	$FmlExitHook{'DelaySendFileDividedly'} = q#;
	&GoDelaySendFileDividedly;
	#;
    }
    else {
	&Log("DelaySendFileDividedly: error \$total=0");
    }
}


sub GoDelaySendFileDividedly
{
    local($i) = 0;

    for $i (1 .. $DSFD_Counter) {
	next unless $SFD_MIB{"$i:total"};

	# &SendingBackInOrder($tmp, $total, $s, $sleep, @to);
	&SendingBackInOrder(
			    $SFD_MIB{"$i:tmp"},
			    $SFD_MIB{"$i:total"},
			    $SFD_MIB{"$i:s"},
			    $SFD_MIB{"$i:sleep"},
			    $SFD_MIB{"$i:\@to"}
			    );
    }
}


# GIVEN "ONE FILE"(hence DraftGenerate always total=1)
# Split the given file and send back them
# ($f, $mode, $subject, @to)
# $f          the target file
# $mode
# $subject
# @to 
# return NONE
sub SendFilebySplit { &SendFileDividedly(@_);}
sub SendFileDividedly
{
    # for unique tmp file
    $SFD_Counter++;
    
    local($f, $mode, $enc, @to) = @_;
    local($total, $s, $target);
    local($sleep) = ($SLEEPTIME || 3);
    local($tmp)   = "$TMP_DIR/sfbs:${SFD_Counter}:$$";

    $0 = "${FML}: split and send back $f to $to <$MyProcessInfo>";
    $s = $enc || $DEFAULT_MGET_SUBJECT;

    if ($mode eq 'mp') {
	local($lc, @f, $tmpmp);
	$tmpmp = "$TMP_DIR/sfbs:mp:$$";
	$lc = &WC($f);
	if ($lc > $MAIL_LENGTH_LIMIT) {
	    &Copy($f, $tmpmp);
	    $total = &SplitFiles($tmpmp, $lc, int($lc/$MAIL_LENGTH_LIMIT) + 1);
	    # prepare an array of temporary files
	    for (1 .. $total) { push(@f, "$tmpmp.$_");}
	    $total = &DraftGenerate($tmp, $mode, $f, @f);
	    for ($tmpmp, @f) { unlink $_;}
	}
	else {
	    $total = &DraftGenerate($tmp, $mode, $f, $f);
	}
    }
    else {
	# local($tmpf, $mode, $file, @conf)
	# $tmpf     : a temporary file 
	# $mode     : mode 
	# $file     : filename of encode e.g. uuencode , ish ...
	&Debug("SendFilebySplit::DraftGenerate($tmp, $mode, $f, $f)") 
	    if $debug;
	$total = &DraftGenerate($tmp, $mode, $f, $f);

	# Hmm, O.K. In some case
	# back to the first filename for the use of SplitFiles
	local($lc) = &WC("$tmp.1");
	if ($lc > $MAIL_LENGTH_LIMIT && $total == 1) {
	    rename("$tmp.1", $tmp) || &Log("cannot rename $tmp.1 $tmp");
	    $total = &SplitFiles($tmp, $lc, int($lc/$MAIL_LENGTH_LIMIT) + 1);
	}
    }


    if ($debug) {
	&Debug("&SplitFiles($tmp, $lc, int($lc/$MAIL_LENGTH_LIMIT));");
	&Debug("SendFilebySplit::($tmp, $total, $s, $sleep, @to)");
    }

    if ($total) {
	&SendingBackInOrder($tmp, $total, $s, $sleep, @to);
    }

    # Destructor; 
    &ClearMimeHdr;
}


sub ClearMimeHdr
{
    undef $Envelope{'GH:Mime-Version:'};
    undef $Envelope{'GH:Content-Type:'};
    undef $Envelope{'GH:Content-Transfer-Encoding:'};
}

1;
