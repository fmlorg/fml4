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

    if ($MODE eq 'html') {
	# &jcode'convert(*s, 'euc'); #';
	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	s/\"/&quot;/g;
	# &jcode'convert(*s, 'jis'); #';
    }

    if ($LANG eq 'Japanese') {
	# Section
	if (/^\.j\s+(Section::\S+)\s+(.*)/) {
	    &SectionOutput($1, $2);
	    next;
	}

	# get description
	if (/^\.j\s+(.*)/) {
	    $buf .= "   ".$1."\n";
	}
    }
    else {
	next if /^\#.*Sub Section/;

	s/[\#\s]+$//;

	# Section
	if (/^[\#\s]+(Section:)\s*(.*)/) {
	    &SectionOutput($1.$2, $2);
	    next;
	}

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
    &Getopts("dhm:sL:");

    $MODE = $opt_m || 'text';
    $SORT = $opt_s ? 1 : 0;
    $LANG = $opt_L || die($!);

    $TmpBuf = "/tmp/manifest$$";
}


sub InitHTMLMode
{
    select(STDOUT);
    print "<HTML>\n";
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

    return if $SORT;

    if ($MODE eq 'text') {
	print "-" x 60;
	print "\n";
	print "¡û $buf\n\n";
    }
    elsif ($MODE eq 'html') {
	$section =~ s/::/-/g;
	$section =~ s/\s+/-/g;
	$Index .= "   <LI> <A HREF=\"\#${section}\"> $buf</A>\n";
	print "<A NAME=$section>\n";
	print "¡û $buf\n\n";
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


1;
