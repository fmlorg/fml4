# Library of fml.pl 
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


# $Id$;

##### FRED ==  Functional Regurlar Expressional Derivative #####
local($Rfc822);

sub Fred
{
    local(*buffer, *mesg) = @_;
    local(%fred, %pat, %t, %e, $eval, %catch, %entry);

    ### load cf;
    # set %catch and %entry for each $domain
    &FredReadCF($FRED_CF, *catch, *entry);

    ### eval .. using %catch
    while (($key, $domain) = each %catch) {
	$eval .= qq#
	    /^($key)/ && (\$domain = \"$domain\", \$seq++);
	    \$var{\"\$domain\#\$seq\"} .= \$_;
	#;
    }

    $eval = qq#;
    \$domain = 'HEADER';
    foreach (split(/\\n/, \$buffer)) { 
	\$_ = "\$_\n";
	$eval;
    };
    ;#;
    
    &Mesg("[EVAL]\n$eval") if $debug;
    eval($eval);
    &Log($@) if $@;

    ### (%var / %catch) => check routine
    # Anyway 822 parsing %var -> %fred
    local($d, $v);
    while (($d, $v) = each %var) { 
	print STDERR "***** $d *****\n"   if $debug;
	print STDERR "\n$d() {\n\t$v}\n\n" if $debug;

	undef %fred; undef %pat; undef %ok; undef %fail;

	if ($Rfc822) {
	    &FredGetFields($v, *fred); # 822 unfold $v -> %fred
	}
	else {
	    &FredGetTABedFields($v, *fred); # split(/\t/, $_) -> %fred
	}
	&FredDebug(*fred) if $debug;

	# pattern entry is not include "pattern-entry#seq"
	$d =~ s/(\S+)\#(\S+)/$1/;

	&FredSetPat($entry{$d}, *pat, *ok, *fail); # set %pat, %ok, %fail 
	&FredTryMatch(*fred, *pat, *ok, *fail, *mesg) if %pat;
    }
}

# 
# DIAGNOSTICS:
# &$ok(*_, *pat, *fred, *opt);
# 
sub FredTryMatch
{
    local(*fred, *pat, *ok, *fail, *mesg) = @_;
    local($key, $value, @opt);

    while (($key, $value) = each %fred) { 
	&Debug("FredTryMatch:\n\tkey=[${key}] value=[${value}]") if $debug;

	$_ = $value;

	# pat ? ok: fail;
	$pat  = $pat{$key};
	$ok   = $ok{$key};
	$fail = $fail{$key};

	if ($debug) {
	    &Mesg("${key}() {\n   [$value] =~ /$pat/ ? &$ok : &$fail;\n}\n");
	}
	    &Mesg("${key}() {\n   [$value] =~ /$pat/ ? &$ok : &$fail;\n}\n");
	next unless $pat;

	### O.K. Try  ###
	undef @opt;
	if (/^($pat)/) {
	    @opt = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
	    if ($ok) { 
		eval("&$ok(*key, *value, *pat, *fred, *opt, *mesg);");
	    }
	}
	else {
	    if ($fail) { 
		eval("&$fail(*key, $value, *pat, *fred, *opt, *mesg);");
	    }
	    $mesg .= "$key: [$_] does not match [$pat]\n";
	    $ErrorCount++;
	}
    }
}


sub FredDebug
{
    local(*fred) = @_;

    print STDERR ('*' x 70),"\n";
    while (($k, $v) = each %fred) { printf STDERR "%-30s %s\n", $k, $v;} 
    print STDERR ('+' x 70),"\n";
}


sub FredReadCF
{
    local($cf, *catch, *entry) = @_;

    # open CF
    print STDERR "open(CF, $cf) \n" if $debug;
    open(CF, $cf) || die("$!\n");

    $domain = 'CONFIG';

    # READ CF
    while (<CF>){
	chop;

	# DOMAIN BEGINS
	if (/^\#(\S+):/) { $domain = $1;}

	# SKIP
	next if /^\#/;
	next if /^\s*$/;

	# CONFIG;
	if ($domain eq 'CONFIG') {
	    # CATCH KEY DOMAIN
	    if (/^TAB/)                   { $Rfc822 = 0;}
	    if (/^RFC822/)                { $Rfc822++;}
	    if (/^DEBUG/)                 { $debug++;}
	    if (/^CATCH\s+(\S+)\s+(\S+)/) { $catch{$1} = $2;}
	    if (/^INC\s+(\S+)/)           { push(@INC, $1);}
	    if (/^(INCLUDE|REQUIRE)\s+(\S+)/) { require $2;}
	    if (/^LIBRARY\s+(\S+)/)       { require $1;}
	    next;
	}


	# O.K. pattern matcing entry for $domain
	$entry{$domain} .= "$_\n";
    }

    # CLOSE CF
    close(CF);

    if ($debug) {
	print  STDERR ('=' x 70)."\n";

	while (($k, $v) = each %entry) { 
	    printf STDERR "ENTRY::%-30s\t%s\n", $k, $v;
	    print  STDERR ('=' x 70)."\n";
	}

	while (($k, $v) = each %catch) { 
	    printf STDERR "CATCH::%-30s\t%s\n", $k, $v;
	    print  STDERR ('=' x 70)."\n";
	}
    }
}


sub FredSetPat
{
    local($definition, *pat, *t, *e) = @_;

    foreach (split(/\n/, $definition)) {
	next if /^(\#|\s*)$/;

	($field, $p, $t, $e) = split(/\s+/, $_);

	$pat{$field}  = $p;
	$t{$field}    = $t;
	$e{$field}    = $e;
    }
}


sub FredGetFields
{
    local($s, *fred) = @_;
    local($field, $contents);

    ### Get @Hdr;
    local($s) = "\n$s\n";
    $s =~ s/\n(\S+):/\n\n$1:\n\n/g; #  trick for folding and unfolding.

    ### Parsing main routines
    for (@Hdr = split(/\n\n/, "$s#dummy\n"), $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {

	print STDERR "FIELD:          >$field<\n"    if $debug;

	$contents =~ s/^\s+//; # cut the first spaces of the contents.
	print STDERR "FIELD CONTENTS: >$contents<\n" if $debug;

	next if /^\s*$/o;		# if null, skip. must be mistakes.

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/ if $CASE_INSENSITIVE;

	# CASE SENSITIVE
	$fred{$field} = $contents;# if $contents;?
    }# FOR;
}


sub FredGetTABedFields
{
    local($s, *fred) = @_;
    local($field, $contents);

    ### Parsing main routines
    foreach $_ (split(/\n/, $s)) {
	next if /^\s*$/o;		# if null, skip. must be mistakes.

	if (/^(\S+)\s+(.*)/) {
	    $field    = $1;
	    $contents = $2;
	}

	print STDERR "FIELD          >$field<\n"    if $debug;
	print STDERR "FIELD CONTENTS >$contents<\n" if $debug;

	# Save Entry anyway. '.=' for multiple 'Received:'
	$field =~ tr/A-Z/a-z/ if $CASE_INSENSITIVE;

	# CASE SENSITIVE
	$fred{$field} = $contents;# if $contents;?
    }# FOR;
}


# TEST CODE
if ($0 eq __FILE__) {
    require 'getopts.pl';
    &Getopts("f:h");
    $FRED_CF = $opt_f;

    while (<>) { $buffer .= $_;};
    sub Mesg { &Debug(@_);};;
sub Debug { print STDERR "@_\n";};;


&Fred(*buffer, *mesg);

print "MESSAGE:\n$mesg\n";
} 

1;
