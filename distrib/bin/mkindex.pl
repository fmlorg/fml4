#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

###                                                ###
### index generator system for "fml/doc/Japanese/" ###
###                                                ###

# getopt()
require 'getopts.pl';
&Getopts("dhm:rf:");

$MODE = $opt_m || 'html';
$REPL = $opt_r ? 1 : 0;
$FILE = $opt_f || die("please define -f INDEX\n");

open($FILE, $FILE) || die("cannot open $FILE\n");

while (<$FILE>) {
    next if /^\#/;

    if ($REPL) {
	if (/^\.[a-z]/) {
	    ;
	}
	elsif (/^(\S+)\s*(.*)/) {
	    $HIER{$1} = $2;
	}
	next;
    }

    if (/^\.part\s+(.*)/) {
	if ($MODE eq 'html') {
	    print "<P>$1\n";
	    print "<UL>\n";
	    $Part = 1;
	}
	next;
    }
    elsif (/^\s*$/) {
	if ($Part) {
	    print "</UL>\n";
	    $Part = 0;
	}
	print ;
	next;
    }
    else {
	if ($MODE eq 'html') {
	    if (/^(\S+)\s*(.*)/) {
		print "\t<LI>\n";
		print "\t<A HREF=\"$1/index.html\">";
		print "\t$2\n";
		print "\t</A>\n";
	    }
	}
    }
}

close($FILE);

if ($REPL) {
    for $file (@ARGV) {
	&Replace($file);
    }
}

exit 0;

sub Replace
{
    local($hier) = @_;
    local($file) = "template/index.wix";

    if (open($file, $file)) {
	while (<$file>) {
	    if (/^\.__repl_title__/) {
		print ".# $_";
		printf "                %s\n", $HIER{$hier};
		next;
	    }
	    if (/^\.__repl_include__/) {
		print ".# $_";
		&ExpandSubDir($hier);
		next;
	    }

	    print $_;
	}
	close($file);
    }
    else {
	;
    }
}


sub ExpandSubDir
{
    local($hier) = @_;
    local($f, %uniq);

    opendir(DIRD, $hier);
    for $f ('overview.wix', sort readdir(DIRD)) {
	# uniq;
	next if $uniq{$f}; $uniq{$f} = 1;

	next if $f !~ /wix$/;
	next if $f eq 'index.wix';

	if (-f "$hier/$f") {
	    print ".include $f\n";
	}
    }

    closedir($hier);
}


1;
