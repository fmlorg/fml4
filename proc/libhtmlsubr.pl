# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML$
#

# speculate multipart block
#
# Parameters:
#   (%mbpcb, block header for each multipart block)
#
# Returns:
#   hash %mbpcb;
#
sub MPBProbe
{
    local(*mpbcb, $bh) = @_;
    local($suffix, $x);
    
    # check multipart block (mpb) type
    # encoding type
    if ($bh =~ /content-transfer-encoding:\s*base64/i) {
	$mpbcb{'enc'} = 'base64';
    }
    if ($bh =~ /content-transfer-encoding:\s*quoted-printable/i) { 
	$mpbcb{'enc'} = 'quoted-printable';
    }

    # speculate type from mime.types
    if ($bh =~ /Content-Type:\s+([\-a-z]+)\/([\-0-9a-z\.]+)/i) {
	$mpbcb{'type'}    = $1;
	$mpbcb{'subtype'} = $2;
	$suffix = &SearchMimeTypes("$1/$2"); # &Search.. || $2;
	$x      = $2;

	# if valid mime type 
	if ($suffix && $suffix ne 'bin') {
	    $suffix =~ s/^x-//i; # remove x- in x-hoehoe type.
	}
	# speculate type by filename if not valid mime type
	else {
	    if ($bh =~ /iso/i) {
		require 'libMIME.pl';
		$bh = &DecodeMimeStrings($bh);
	    }		

	    if ($bh =~ /filename=\".*\.([a-z0-9-]+)\"/i) {
		$suffix = $1;
	    }
	    elsif ($bh =~ /;\*name=\".*\.([a-z0-9-]+)\"/i) {
		$suffix = $1;
	    }
	}

	$mpbcb{'suffix'} = $suffix || $x;
    }


    # check image-or-not for the choice to use "<IMAGE" or not
    if ($bh =~ /Content-Type:\s+image/) { 
	$mpbcb{'image'} = 1;
    }

    $mpbcb{'type'}    =~ tr/A-Z/a-z/;
    $mpbcb{'subtype'} =~ tr/A-Z/a-z/;
}


# Parameters:
#   (*envelope, *mpbcb, line pointer, max pointer, sub directory,
#                article id, number of called)
#
# Returns: none
#
sub WriteHtmlFile
{
    local(*e, *mpbcb, $lpp, $pe, $dir, $file, $mp_count) = @_;
    local($lp, $xbuf, $fn, $fp, $noconv);

    $WriteHtmlFileCount++;

    &Log("WriteHtmlFile: $mpbcb{'type'}/$mpbcb{'subtype'}") if $debug;

    if ($WriteHtmlFileCount > 1) {
	$noconv = 1; # always really?

	if ($mpbcb{'subtype'} eq 'html') {
	    $fn = "${file}_${mp_count}.html";
	    $fp = "$dir/$fn";
	}
	elsif ($mpbcb{'subtype'} eq 'plain') {
	    $fn = "${file}_${mp_count}.txt";
	    $fp = "$dir/$fn";
	}
	else {
	    $fn = "${file}_${mp_count}.". $mpbcb{'subtype'};
	    $fp = "$dir/$fn";
	}

	if (open($fp, "> $fp")) {
	    &Log("create $fp");
	}
	else {
	    &Log("cannot open $fp");
	    undef $fp;
	}
    }

    while(1) {
	$lp   = &main'GetLinePtrFromHash(*e, "Body", $lpp);#';
	$xbuf = substr($e{'Body'}, $lpp, $lp-$lpp+1);

	last if $lp > $pe;

	if ($xbuf =~ /ISO\-/i) { $xbuf = &DecodeMimeStrings($xbuf);}

	&ConvSpecialChars(*xbuf) unless $noconv;

	$xbuf =~ s#([a-z]+://\S+)#&Conv2HRef($1)#eg;

	if ($fp) {
	    print $fp $xbuf;
	}
	else {
	    print OUT $xbuf;
	}

	print STDERR ">", $xbuf if $debug;

	$lpp = $lp + 1;
    }

    if ($fp) { 
	print OUT "\t<P><A HREF=\"$fn\">$fn (attatchment)</A>\n";
	close($fp);
    }
}


# Search base64decoder program
#
sub FindBase64Decoder
{
    local($decode);

    # if not defined, try search bin/base64decede.pl
    if ($BASE64_DECODE && &ProgExecuteP($BASE64_DECODE)) {
	$BASE64_DECODE;
    }
    elsif (! $BASE64_DECODE) {
	$decode = &SearchFileInLIBDIR("bin/base64decode.pl");

	if (! $decode) {
	    &Log("SyncHtml::\$BASE64_DECODE is not defined");
	    return $NULL;
	}

	$^X . " " . $decode; # perl base64decode.pl
    }
    # when $BASE64_DECODE is defined, but not found
    elsif (! &ProgExecuteP($BASE64_DECODE)) {
	&Log("SyncHtml::\$BASE64_DECODE is not found");
	$NULL;
    }
}


# Parameters:
#   (*envelope, line pointer, max pointer, output file)
#
# Returns: none
#
sub DecodeAndWriteFile
{
    local(*e, $lpp, $pe, $file) = @_;
    local($lp, $xbuf, $decode);

    $decode = &FindBase64Decoder;

    &Log("create $file");
    &Debug("|$decode > $file") if $debug; 
    open(IMAGE, "|$decode > $file") || do {
	&Log($!);
	return;
    };
    select(IMAGE); $| = 1; select(STDOUT);
    binmode(IMAGE);

    while(1) {
	$lp   = &main'GetLinePtrFromHash(*e, "Body", $lpp);#';
	$xbuf = substr($e{'Body'}, $lpp, $lp-$lpp+1);

	last if $lp > $pe;
	print IMAGE $xbuf;
	$lpp = $lp + 1;
    }

    close(IMAGE);
}


# Description:
#    output image file pointer
#
# Parameters:
#   (*mpbcb, file name to embed)
#
# Returns: none
#
sub TagOfDecodedFile
{
    local(*mpbcb, $file) = @_;

    # reflect reference to the part in the \d+.html file.
    if ($HTML_MULTIPART_IMAGE_REF_TYPE eq 'A' || (! $mpbcb{'image'})) {
	print OUT "<A HREF=\"${file}\">";
	print OUT "${file}</A>\n";
    }
    elsif ($HTML_MULTIPART_IMAGE_REF_TYPE eq 'IMAGE' ||
	   !$HTML_MULTIPART_IMAGE_REF_TYPE) {
	print OUT "</PRE>\n";
	print OUT "<IMAGE SRC=\"${file}\">\n";
	print OUT "<PRE>\n";
    }
}


# GenThread() calls this.
#
# Parameters:
#   pointor to %links
#
# Returns: none
#
sub AggregateLinks
{
    local(*links) = @_;
    local($p, $q, $recursive, %prev, %cache);

    while ($recursive++ < 16) {
	%prev = %links;
	undef %cache;
	&DoAggregateLinks(*links, *cache);

	# enough aggregated ?
	$p = join(",", sort {$a <=> $b} values %prev);
	$q = join(",", sort {$a <=> $b} values %links);
	$p =~ s/\s+/ /g;
	$q =~ s/\s+/ /g;
	if ($p eq $q) { last;}
    }

    # If a key in a list with no value is included in a %links, 
    # delete it.
    for $hp (keys %links) {
	next if $links{$hp};	# avoid non-empty list;

	if ($debug_html && $cache{$hp}) {
	    print STDERR "--delete $hp=>$links{$hp}\n";
	}

	delete $links{$hp} if $cache{$hp};
    }
}


# GenThread() calls AggregateLinks() ( <=> DoAggregateLinks() ).
#
# Parameters:
#   (pointor to %links, pointer to %cache)
#
# Returns: none
#
sub DoAggregateLinks
{
    local(*links, *cache) = @_;
    local($hp, $tp);

    undef $cache;

    for $hp (keys %links) {
	next unless $links{$hp};

	@x  = split(/\s+/, $links{$hp});
	$tp = $x[$#x];
	for (@x) { $cache{$_} = 1;}

	# (tail 'list) -> (head 'another_list)
	if ($links{$tp}) {
	    $links{$hp} .= " ". $links{$tp};
	    undef $links{$tp};
	}
    }

    if ($debug_html) {
	for $hp (sort {$a <=> $b} keys %links) {
	    print STDERR "$hp => $links{$hp}\n";
	}
    }
}


# GenThread() calls this.
#
# Parameters:
#   pointor to %links
#
# Returns: none
#
sub OutPutAggrThread
{
    local(*list, *links) = @_;
    local($p, $i, $level, %already);

    for $p (sort __SortHtmlThread keys %links) {
	next if $already{$p};

	if ($debug_thread) { print "==$p\n";}

	print OUT "\n<UL><!--$p-->\n";
	print OUT "\n<!-- UL $p -->\n";
	print OUT $list{$p};
	&ThreadPrint(*list, *links, *already, $p, 0);

	print OUT "\n</UL>\n";
    }
}


sub __SortHtmlThread
{
    if ($HTML_THREAD_SORT_TYPE eq 'reverse-number') {
	{$b <=> $a};
    }
    else {
	{$a <=> $b};
    }
}


# Description:
#   output folowing %links thread structure by using <UL> trick ;-)
#   It is dirty and not true but effective.
#
sub ThreadPrint
{
    local(*list, *links, *already, $np, $offset) = @_;
    local($i, $p, $level, %np);

    print OUT "\n", ("   " x ($offset+1)),"<!--    sets in   UL -->\n";

    # nesting check
    return 1 if $ThreadPrintNest++ > 10;

    # alrady print out :)
    $already{$np} = 1;

    # here we go!
    for $i (split(/\s+/, $links{$np})) {
	if ($list{$i}) {
	    $level++;

	    if ($debug_thread) {
		print STDERR "==", ("   " x ($level+$offset)), " $i\n";
	    }

	    if ($offset) {
		if ($level > 1) {
		    print OUT "\n", 
		    ("   " x ($level+$offset)), "<UL>\n";
		}
	    }
	    else {
		print OUT "\n", ("   " x ($level+$offset)), "<UL>\n";
	    }
	    
	    print OUT ("   " x ($level+$offset)), "<!-- UL $i-->\n";
	    print OUT $list{$i};

	    # links pointer;
	    $np{$level} = $i;
	}
    }

    if ($offset) { $level--;}

    while ($level > 0) {
	print OUT "\n", ("   " x ($level+$offset)), "</UL>\n";

	$level--;

	if ($p = $np{$level}) {
	    if ($links{$p}) {
		&ThreadPrint(*list, *links, *already, $p, $level - 1);
	    }
	}
    }

    print OUT "\n", ("   " x ($offset+1)),"<!--    sets out   UL -->\n";

    # nesting check
    $ThreadPrintNest--;
}


1;
