#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

&Init;
if ($MODE eq 'html') { &InitHTMLMode;}

while (<>) {
    next if /^INFO:/;
    last if /^LOCAL_CONFIG:/;

    # set up translation alias
    if (/^\.translate/) { 
	&SetupTranslationTable($_);
	next;
    }

    if ($LANG eq 'Japanese') {
	if ($EvalBuf) { 
	    eval $EvalBuf;
	    print STDERR $@ if $@;
	    if ($EvalBufTrail) { eval $EvalBufTrail;}
	    print STDERR $@ if $@;
	}
    }

    if ($MODE eq 'html') {
	# &jcode'convert(*s, 'euc'); #';
	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	s/\"/&quot;/g;
	# &jcode'convert(*s, 'jis'); #';
    }

    if ($LANG eq 'Japanese') {
	next if /^\#.*Section:/;

	# Section
	if (/^\.j\s+(Section::\S+)\s+(.*)/) {
	    &SectionOutput($1, $2);
	    next;
	}

	print STDERR ">>> $_\n" if /Section:/;

	# get description
	if (/^\.j\s+(.*)/) {
	    $buf .= "   ".$1."\n";
	}
    }
    else {
	/\S+[\#\s]{3,}$/ && s/[\#\s]{3,}$//;

	# Section
	if (/^[\#\s]+(Section:)\s*(.*)/) {
	    &SectionOutput($1.$2, $2);
	    next;
	}

	next if /Sub Section:/;

	# get description
	if (/^\#\s+(.*)/) {
	    $buf .= "   ".$1."\n";
	}
    }


    # variable name
    if (/^([A-Z0-9_]+):/) {
	if ($SORT) {
	    $Variable{"\$${1}"} = $buf;
	}
	else {
	    print "\$${1}\n$buf\n\n";
	}
    }

    # reset
    if (/^\s*$/) { undef $buf;}
}

if ($MODE eq 'html') { 
    &FinishHTMLMode;
}
elsif ($Key) {
    print $Key, "\n";
    print $Variable{$Key};
}
else {
    if ($SORT) {
	&OutputSortedList;
    }
}

exit 0;


sub Init
{
    # getopt()
    require 'getopts.pl';
    &Getopts("dhm:sL:t:V:");

    $MODE  = $opt_m || 'text';
    $SORT  = $opt_s ? 1 : 0;
    $LANG  = $opt_L || die($!);
    $TITLE = $opt_t || 'variable list (cf/MANIFEST)';

    if ($opt_V) {
	$Key = $opt_V;
	if ($Key !~ /^\$/) { 
	    $Key = "\$".$Key;
	}
	$SORT = 1; # fake
    }

    $TmpBuf = "/tmp/manifest$$";
}


sub InitHTMLMode
{
    select(STDOUT);
    print "<HTML>\n";
    print "<TITLE>\n";
    print $TITLE, "\n";
    print "</TITLE>\n";
    print "<BODY>\n";
    print "<PRE>\n";

    open(TMP, "> $TmpBuf") || die($!);
    select(TMP);
}


sub FinishHTMLMode
{
    close(TMP);
    select(STDOUT);

    if ($SORT) {
	&OutputSortedList;
    }
    else {
	print "[Index]\n";
	print "<UL>\n";
	print $Index;
	print "</UL>\n";

	open(IN, $TmpBuf); 
	while (<IN>) { print STDOUT $_;};
	close(IN);
	unlink $TmpBuf;
    }

    print "</PRE>\n";
    print "</BODY>\n";
    print "</HTML>\n";
}


sub SectionOutput
{
    local($section, $buf) = @_;

    return $NULL if $SORT;

    if ($MODE eq 'text') {
	print "-" x 60;
	print "\n";
	print "* $buf\n\n";
    }
    elsif ($MODE eq 'html') {
	$section =~ s/::/-/g;
	$section =~ s/\s+/-/g;
	$Index .= "   <LI> <A HREF=\"\#${section}\"> $buf</A>\n";
	print "<A NAME=$section>\n";
	print "* $buf\n\n";
    }
}


sub OutputSortedList
{
    my(@v) = keys %Variable;
    @v = sort @v;

    for (@v) {
	print $_, "\n";
	print $Variable{$_}, "\n\n";
    }
}


sub SetupTranslationTable
{
    local($buf) = @_;
    local(@x);

    $buf =~ s/[\r\n]+$//;
    ($x0, $x1, $x2, $buf) = split(/\s+/, $buf, 4);

    if ($x0 eq '.translate') {
	$EvalBuf      .= "/^\\#\\s+$x1/ && do { s/$x2/$buf/g; \$Flag=1;};\n";
	$EvalBufTrail .= "\$Flag && s/^\\#/.j/; \$Flag=0;\n";
    }
    else {
	die("SetupTranslationTable: invalid input");
    }
}

1;
