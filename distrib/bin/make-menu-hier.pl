#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
# $NetBSD$
# $FML$
#

# getopt()
require 'getopts.pl';
&Getopts("dhjt");

if ($opt_t) {
    print <<'_EOF_';
\begin{quote}
\small
\begin{verbatim}
_EOF_
}

while (<>) {
    if (m@^(/.*)@) {
	$tophier = 0;
	$curhier = $1;
	$hier    = $1;
	# $hier =~ s@/@ -> @g;

	if ($curhier =~ m@^/\S+/@) {
	    $tophier = 0;
	}
	else {
	    print STDERR "TOP $curhier\n";
	    $tophier = 1;
	}

	undef $found;
	undef $found_name;
	undef $varname;
	next;
    }

    if (/^=config/) {
	$found = 1;
	next;
    }

    if (/^=name/) {
	$found_name = 1;
	next;
    }

    if ($found) {
	s/^\s*//g;
	($varname) = split;
	$HIER{$varname} = $hier;
	undef $found;
    }

    if ($found_name && $tophier) {
	s/^\s*//g;
	s/\s*$//g;
	my ($varname) = $_;
	$varname =~ s/\s*\(.*$//;
	$ALIAS .= "\$x =~ s!$curhier!/ $varname!;\n";
	print STDERR $ALIAS;
	$found_name = 0;
	next;
    }

    if ($query) {
	if (/type:/) {
	    s/^\s*//g;	    
	    my ($x, $type) = split(/\s+/);

	    $type =~ s@y-or-n@y/n@;
	    $type =~ s@reverse-y-or-n@n/y@;
	    if ($opt_j) { 
		$type =~ s@number@数の入力@;
		$type =~ s@select@選択@;
	    }

	    $TYPE{$varname} = $type if $type;
	    $query = 0;
	}
    }
    elsif (/^=query/) {
	$query = 1;
    }

}

foreach my $n (sort keys %HIER) {
    next unless $n;

    if ($opt_j) {
	&ResetAlignedBuffer;

	print "\n";

	if ($DESCRIPTION{$n}) {
	    printf "変数 \$%s (%s)\n", $n, $DESCRIPTION{$n};
	}
	else {
	    printf "変数 \$%s\n", $n;
	}

	my $x = $HIER{$n};
	eval $ALIAS;
	$x =~ s@/@ -> @g;
	print STDERR $@ if $@;
	$x = "メニュー". $x. " -> ". $TYPE{$n};
	for my $s (split(/\s+/, $x)) {
	    &GobbleAlignedBuffer($s);
	}
	&PrintAlignedBuffer;
	&ResetAlignedBuffer;
    }
    else {
	printf "\n%s\n          TOP%s -> %s\n",  $n, $HIER{$n}, $TYPE{$n};
    }
}

if ($opt_t) {
    print <<'_EOF_';
\end{verbatim}
\end{quote}
_EOF_
}



##### import makefml functions
sub ResetAlignedBuffer
{
    $OutBufferLine = 0;
    undef $OutBuffer;
    undef @OutBuffer;
    undef %OutBuffer;
}

sub GobbleAlignedBuffer
{
    my ($s) = @_;

    my($x) = $OutBuffer[$OutBufferLine];

    # next line
    if (length($x) + length($s) > 68) { 
        $OutBufferLine++;
        $OutBuffer[$OutBufferLine] = "    ";
    }
    elsif (! $x) {
        $OutBuffer[$OutBufferLine] = "    ";
    }

    $OutBuffer[$OutBufferLine] .= " ". $s;
}

sub PrintAlignedBuffer
{
    for (@OutBuffer) { print $_, "\n";}
}

