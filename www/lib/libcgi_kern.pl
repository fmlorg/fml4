#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#


sub Init
{
    $| = 1;

    # getopt()
    require 'getopts.pl';
    &Getopts("dh");

    # fml system configuration
    require "$CONFIG_DIR/system";

    $WWW_DIR      = "$EXEC_DIR/www";
    $WWW_CONF_DIR = "$WWW_DIR/conf";
    $CGI_CF       = "$WWW_CONF_DIR/cgi.cf";

    if (-f $CGI_CF) {
        eval("&LoadCGICF;");
	&Err($@) if $@;
    }

    # makefml location
    $MAKE_FML = "$EXEC_DIR/makefml";

    # version
    $VERSION_FILE = "$EXEC_DIR/etc/release_version";

    open($VERSION_FILE, $VERSION_FILE);
    sysread($VERSION_FILE,$VERSION,1024);
    $VERSION =~ s/[\s\n]*$//;

    # htdocs/
    $HTDOCS_TEMPLATE_DIR = $HTDOCS_TEMPLATE_DIR || "$EXEC_DIR/www/template";

    # /cgi-bin/ in HTML
    $CGI_PATH = $CGI_PATH || '/cgi-bin/fml';
}


sub ExpandOption
{
    local($dir);
    if (opendir(DIRD, $ML_DIR)) {
	while ($dir = readdir(DIRD)) {
	    next if $dir =~ /^\./;
	    next if $dir =~ /^etc/;
	    next if $dir =~ /^fmlserv/;

	    # @listname@list.com must not exists!
	    next if $dir =~ /^\@/;

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

	    s/_CGI_PATH_/$CGI_PATH/g;
	    s/_FML_VERSION_/$VERSION/g;

	    print;
	}
	close($file);
    }
    else {
	&ERROR("cannot open $file");	
    }
}


### Section: IO
sub GetBuffer
{
    local(*s) = @_;
    local($buffer, $k, $v);

    $GETBUFLEN = $GETBUFLEN || 2048;
    
    $ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;

    if ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    else {
	$buffer = $ENV{'QUERY_STRING'};
    }

    if (length($buffer) > $GETBUFLEN) {
	&Err("Error: input data is too large");
    }

    foreach (split(/&/, $buffer)) {
	($k, $v) = split(/=/, $_);
	$v =~ tr/+/ /;
	$v =~ s/%(..)/pack("C", hex($1))/eg;
	$s{$k} = $v;

	&P("GetBuffer: $k\t$v\n<br>") if $debug;
    }

    # pass the called parent url to the current program;
    $PREV_URL = $s{'PREV_URL'};

    $buffer;
}


sub Err
{
    local($s) = @_;
    $ErrorString .= $s;
}


sub Exit
{
    local($s) = @_;
    print "<PRE>";
    print $s;
    print "\nStop.\n";
    print "</PRE>";
    exit 0;
}


sub ERROR { &P(@_);}


sub P { print @_, "\n";}


### Section: conf/cgi.cf
###
### %CGI_CF is global.
###
sub LoadCGICF
{
    local($key, $value);

    if (open(CFTMP, $CGI_CF)) {
	while (<CFTMP>) {
	    next if /^\#/;
	    next if /^\s*$/;
	    chop;

	    ($key, $value) = split(/\s+/, $_, 2);
	    $CGI_CF{$key} = $value;
	}
	close(CFTMP);
    }
    else {
	&ERROR("cannot open $CGI_CF");
    }
}


sub SaveCGICF
{
    local($key, $value);
    local($new);

    $new = $CGI_CF. ".new";

    if (open(CFTMP, "> $new")) {
	foreach $key (sort keys %CGI_CF) {
	    printf CFTMP "%-20s   %s\n", $key, $CGI_CF{$key};
	} 
	close(CFTMP);
	rename($new, $CGI_CF) || &ERROR("cannot rename $new $CGI_CF");

	&ShowCGICF;
    }
    else {
	&ERROR("cannot open $CGI_CF");
    }
}


sub ShowCGICF 
{
    if (open(CFTMP, $CGI_CF)) {
	local($p);
	print "<PRE>";
	print "\n\n-- \"$CGI_CF\" configuration --\n\n";
	while ($p = sysread(CFTMP, $_, 1024)) {
	    syswrite(STDOUT, $_, $p);
	}
	print "</PRE>";
    }
}


1;
