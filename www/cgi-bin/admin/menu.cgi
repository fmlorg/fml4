#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


### AUTOMATICALLY REPLACED by makefml (Sun, 9 Mar 97 19:57:48 )
$CONFIG_DIR = '/usr/local/fml/.fml'; # __MAKEFML_AUTO_REPLACED_HERE__


### MAIN ###
&Init;

&P("Content-Type: text/html\n");

&Convert("$HTDOCS_DIR/Japanese/admin/index.html");

exit 0;
### MAIN ENDS ###


sub Init
{
    $| = 1;

    # getopt()
    require 'getopts.pl';
    &Getopts("dh");

    # fml system configuration
    require "$CONFIG_DIR/system";

    # makefml location
    $MAKE_FML = "$EXEC_DIR/makefml";

    # htdocs/
    $HTDOCS_DIR = "$EXEC_DIR/www/template";
}

sub ExpandOption
{
    if (opendir(DIRD, $ML_DIR)) {
	while ($dir = readdir(DIRD)) {
	    next if $dir =~ /^\./;
	    next if $dir =~ /^etc/;
	    next if $dir =~ /^fmlserv/;
	    print "\t\t\t<OPTION VALUE=$dir>$dir\n";
	}
	closedir(DIRD);
    }
    else {
	&ERROR("cannot open \$ML_DIR");
    }
}

sub Convert
{
    local($file) = @_;

    if (open($file, $file)) {
	while (<$file>) {
	    if (/__EXPAND_OPTION_ML__/) {
		&ExpandOption;
		next;
	    }

	    print;
	}
	close($file);
    }
    else {
	&ERROR("cannot open $file");	
    }
}


### Sectoin: common
sub GetBuffer
{
    local(*s) = @_;
    local($buffer, $k, $v);
    
    $ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;

    if ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    else {
	$buffer = $ENV{'QUERY_STRING'};
    }

    foreach (split(/&/, $buffer)) {
	($k, $v) = split(/=/, $_);
	$v =~ tr/+/ /;
	$v =~ s/%(..)/pack("C", hex($1))/eg;
	$s{$k} = $v;

	&P("GetBuffer: $k\t$v<br>\n") if $debug;
    }

    # pass the called parent url to the current program;
    $PREV_URL = $s{'PREV_URL'};

    $buffer;
}


### Section: IO

sub ERROR
{
    local($s) = @_;
    print $s, "\n";
}


sub P
{
    print @_;
    print "\n";
}


1;
