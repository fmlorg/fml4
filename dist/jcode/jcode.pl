package jcode;
;######################################################################
;#
;# jcode.pl: Japanese character code conversion library
;#
;# Copyright (c) 1995 Kazumasa Utashiro <utashiro@iij.ad.jp>
;# Internet Initiative Japan Inc.
;# Sanban-cho, Chiyoda-ku, Tokyo 102, Japan
;#
;# Copyright (c) 1992,1993,1994 Kazumasa Utashiro
;# Software Research Associates, Inc.
;# Original by srekcah@sra.co.jp, Feb 1992
;#
;# Redistribution for any purpose, without significant modification,
;# is granted as long as all copyright notices are retained.  THIS
;# SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
;# IMPLIED WARRANTIES ARE DISCLAIMED.
;#
;; $rcsid = q$Id: jcode.pl,v 1.12.1.1 1996/09/08 14:42:16 utashiro Exp $;
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
;#	&jcode'convert(*line, $ocode [, $icode])
;#		Convert the line in any Japanese code to specified
;#		code in second argument $ocode.  $ocode is any of
;#		'jis', 'sjis' or 'euc'.  Input code is recognized
;#		automatically from the line itself when $icode is not
;#		supplied.  $icode also can be specified, but xxx2yyy
;#		routine is more efficient when both codes are known.
;#
;#		It returns a list of pointer of convert subroutine and
;#		input code.  It means that this routine returns the
;#		input code of the line in scalar context.
;#
;#	&jcode'xxx2yyy(*line)
;#		Convert Japanese code from xxx to yyy.  xxx and yyy
;#		are one of "jis", "sjis" or "euc".  These subroutines
;#		return number of converted substrings.  So return
;#		value 0 means the line was not converted at all.
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
;#	$jcode'convf{'xxx', 'yyy'}
;#		The value of this associative array is pointer to the
;#		subroutine jcode'xxx2yyy().
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
;#	&jcode'tr(*line, $from, $to [, $option]);
;#		&jcode'tr emulates tr operator for 2 byte code.  This
;#		funciton is under construction and doesn't have full
;#		feature of tr.  Range operator like a-z is not
;#		supported.  Only 'd' is interpreted as option.
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
;# The safest way for converting to JIS.
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
;# Call initialize function if not called yet.  This sounds strange
;# but this makes easy to embed the jcode.pl in the script.  Call
;# &jcode'init at the beginning of the script in that case.
;#
&init unless defined $version;

;#
;# Initialize variables.
;#
sub init {
    ($version) = ($rcsid =~ /,v ([\d.]+)/);
    $re_sjis_c = '[\201-\237\340-\374][\100-\176\200-\374]';
    $re_sjis_s = "($re_sjis_c)+";
    $re_euc_c  = '[\241-\376][\241-\376]';
    $re_euc_s  = "($re_euc_c)+";
    $re_jin    = '\033\$[\@B]';
    $re_jout   = '\033\([BJ]';
    $re_binary = '[\000-\006\177\377]';
    &jis_inout("\033\$B", "\033(B");
    $cache = 1;

    for $from ('jis', 'sjis', 'euc') {
	for $to ('jis', 'sjis', 'euc') {
	    eval "\$convf{$from, $to} = *${from}2${to};";
	}
    }
}

;#
;# Set JIS in and out final characters.
;#
sub jis_inout {
    $jin = shift || $jin;
    $jout = shift || $jout;
    $jin = "\033\$".$jin if length($jin) == 1;
    $jout = "\033\(".$jout if length($jout) == 1;
    ($jin, $jout);
}

;#
;# Get JIS in and out sequences from the string.
;#
sub get_inout {
    local($jin, $jout);
    $_[$[] =~ /$re_jin/o && ($jin = $&);
    $_[$[] =~ /$re_jout/o && ($jout = $&);
    ($jin, $jout);
}

;#
;# Character code recognition
;#
sub getcode {
    local(*_) = @_;
    return undef unless /[\033\200-\377]/;
    return 'jis' if /$re_jin|$re_jout/o;
    return 'binary' if /$re_binary/o;

    local($sjis, $euc);
    $sjis += length($&) while /$re_sjis_s/go;
    $euc  += length($&) while /$re_euc_s/go;
    (&max($sjis, $euc), ('euc', undef, 'sjis')[($sjis<=>$euc) + $[ + 1]);
}
sub max { $_[ $[ + ($_[$[] < $_[$[+1]) ]; }

;#
;# Convert any code to specified code
;#
sub convert {
    local(*_, $ocode, $icode) = @_;
    return (undef, undef) unless $icode = $icode || &getcode(*_);
    return (undef, $icode) if $icode eq 'binary';
    $ocode = 'jis' unless $ocode;
    local(*convf) = $convf{$icode, $ocode};
    do convf(*_);
    (*convf, $icode);
}

;#
;# JIS to JIS
;#
sub jis2jis {
    local(*_) = @_;
    s/$re_jin/$jin/go;
    s/$re_jout/$jout/go;
}

;#
;# SJIS to JIS
;#
sub sjis2jis {
    local(*_) = @_;
    s/$re_sjis_s/&_sjis2jis($&)/geo;
}
sub _sjis2jis {
    local($_) = @_;
    s/../$s2e{$&}||&s2e($&)/geo;
    tr/\241-\376/\041-\176/;
    $jin . $_ . $jout;
}

;#
;# EUC to JIS
;#
sub euc2jis {
    local(*_) = @_;
    s/$re_euc_s/&_euc2jis($&)/geo;
}
sub _euc2jis {
    local($_) = @_;
    tr/\241-\376/\041-\176/;
    $jin . $_ . $jout;
}

;#
;# JIS to EUC
;#
sub jis2euc {
    local(*_) = @_;
    s/$re_jin([!-~]*)$re_jout/&_jis2euc($1)/geo;
}
sub _jis2euc {
    local($_) = @_;
    tr/\041-\176/\241-\376/;
    $_;
}

;#
;# JIS to SJIS
;#
sub jis2sjis {
    local(*_) = @_;
    s/$re_jin([!-~]*)$re_jout/&_jis2sjis($1)/geo;
}
sub _jis2sjis {
    local($_) = @_;
    tr/\041-\176/\241-\376/;
    s/../$e2s{$&}||&e2s($&)/ge;
    $_;
}

;#
;# SJIS to EUC
;#
sub sjis2euc {
    local(*_) = @_;
    s/$re_sjis_c/$s2e{$&}||&s2e($&)/geo;
}
sub s2e {
    local($c1, $c2) = unpack('CC', $code = shift);
    if ($c2 >= 0x9f) {
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
    local(*_) = @_;
    s/$re_euc_c/$e2s{$&}||&e2s($&)/geo;
}
sub e2s {
    local($c1, $c2) = unpack('CC', $code = shift);
    if ($c1 % 2) {
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
;# SJIS to SJIS, EUC to EUC
;#
sub sjis2sjis { 0; }
sub euc2euc { 0; }

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
;# TR function for 2-byte code
;#
sub tr {
    local(*_, $from, $to, $opt) = @_;
    local(@from, @to, %table);
    local($wasjis, $count) = (0, 0);
    
    &jis2euc(*_), $wasjis++	if $_    =~ /$re_jin/o;
    &jis2euc(*from)		if $from =~ /$re_jin/o;
    &jis2euc(*to), $wasjis++	if $to   =~ /$re_jin/o;

    @from = $from =~ /[\200-\377].|./g;
    @to = $to =~ /[\200-\377].|./g;
    push(@to, ($opt =~ /d/ ? '' : $to[$#to]) x (@from - @to)) if @to < @from;
    @table{@from} = @to;

    s/[\200-\377].|./defined($table{$&}) && ++$count ? $table{$&} : $&/ge;

    &euc2jis(*_) if $wasjis;

    $count;
}

1;
