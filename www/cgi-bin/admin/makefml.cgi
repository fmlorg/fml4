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
&Parse;
&UpperHalf;

if (&SecureP) { &Command;}

&Finish;

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
}


sub Parse
{
    &GetBuffer(*config);

    $debug     = $config{'debug'};
    $ML        = $config{'ML_DEF'} || $config{'ML'};
    $MAIL_ADDR = $config{'MAIL_ADDR'};
    $PROC      = $config{'PROC'};
    @PROC_ARGV = split(/\s+/, $config{'ARGV'});

    # fix
    $PROC =~ tr/A-Z/a-z/;
}


sub UpperHalf
{
    &P("Content-Type: text/html\n");
    &P("<HTML>");
    &P("<HEAD>");
    &P("<TITLE>");
    &P("fml configuration interface");
    &P("</TITLE>");
    &P("</HEAD>");
    &P("<BODY>");
    &P("<PRE>");
}


sub Control
{
    local($ml, $command, @argv) = @_;
    local($tmpbuf) = "/tmp/makefml.ctlbuf.$$";

    if (open(CTL, "|$MAKE_FML -i stdin > $tmpbuf 2>&1")) {
	select(CTL); $| = 1; select(STDOUT);

	print CTL $command, "\t", $ml, "\t";
	print CTL join("\t", @argv);
	print CTL "\n";

	close(CTL);
	&OUTPUT_FILE($tmpbuf);
    }
    else {
	&ERROR("cannot execute makefml");
    }

    unlink $tmpbuf;
}


sub OUTPUT_FILE
{
    local($file) = @_;

    if (open($file, $file)) {
	while (<$file>) { print $_;}
	close($file);
    }
    else {
	&ERROR("cannot open logfile");	
    }
}


sub SecureP
{
    local($secure_pat) = '[A-Za-z0-9\-_]+';

    if ($ML !~ /^($secure_pat)$/i) {
	&P("ERROR: ML=$ML is invalid.");
	0;
    }
    elsif ($PROC !~ /^($secure_pat)$/i) {
	&P("ERROR: PROC=$PROC is invalid.");
	0;
    }
    else {
	1;
    }
}


sub Command
{
    if ($PROC eq 'add' || $PROC eq 'bye') {
	&P("&Control($ML, $PROC, $MAIL_ADDR);") if $debug;
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'add_admin' || $PROC eq 'bye_admin') {
	$PROC =~ s/_admin/admin/;
	&P("&Control($ML, $PROC, $MAIL_ADDR);") if $debug;
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'new') {
	&P("&Control($ML, $PROC);") if $debug;
	&Control($ML, $PROC);
    }
    elsif ($PROC eq 'config') {
	&ERROR("not yet implemented PROC=$PROC");
    }
    else {
	&ERROR("unknown PROC=$PROC");
    }
}


sub Finish
{
    &P("</PRE>");
    &P("</BODY>");
    &P("</HTML>");
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
