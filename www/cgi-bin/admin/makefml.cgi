#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


### AUTOMATICALLY REPLACED by makefml (Sun, 9 Mar 97 19:57:48 )
$CONFIG_DIR = ''; # __MAKEFML_AUTO_REPLACED_HERE__


### MAIN ###
&Init;
&Parse; # set %config

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
    $LANGUAGE  = $config{'LANGUAGE'};
    @PROC_ARGV = split(/\s+/, $config{'ARGV'});

    # fix
    $PROC =~ tr/A-Z/a-z/;

    if ($LANGUAGE eq 'Japanese') {
	push(@INC, $EXEC_DIR);
	require 'jcode.pl';
	eval "&jcode'init;";
	require 'libmesgle.pl';
	$MESG_FILE = "$EXEC_DIR/messages/$LANGUAGE/makefml";
    }
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

    if ($debug) {
	while (($k, $v) = each %ENV)    { &P("ENV: $k => $v");}
	while (($k, $v) = each %config) { &P("config: $k => $v");}
    }
}


sub Control
{
    local($ml, $command, @argv) = @_;
    local($tmpbuf) = "/tmp/makefml.ctlbuf.$$";

    &P("---Control($ml, $command, @argv)") if $debug;

    if (open(CTL, "|$MAKE_FML -E HTTPD -i stdin > $tmpbuf 2>&1")) {
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


# XS: eXit Status
sub XSTranslate
{
    local($mesg) = @_;

    $mesg =~ s/^\s*//;

    if ($mesg =~ /OK:/) {
	&Mesg2Japanese('OK') || $mesg;
    }
    elsif ($mesg =~ /(ERROR:|WARN:)\s*makefml\.(\S+)/) {
	"$1 ". &Mesg2Japanese($2);
    }
    else {
	$mesg;
    }
}


sub Mesg2Japanese
{
    local($key) = @_;
    local($x);

    $x = &MesgLE'Lookup($key, $MESG_FILE); #';
    &jcode'convert(*x, 'jis'); #';

    $x;
}

sub Log
{
    print "LOG: @_\n";
}


sub OUTPUT_FILE
{
    local($file) = @_;

    if (open($file, $file)) {
	# firstly check "ExitStatus:" 
	while (<$file>) {
	    if (/^ExitStatus:(.*)/) { 
		print &XSTranslate($1), "\n";
		next;
	    }
	}
	close($file);

	open($file, $file);
	while (<$file>) {
	    next if 1 .. /config.ph; /;
	    next if /^\-\-\-/;
	    next if /^ExitStatus:/;
	    chop;
	    $_ ? ($space_count = 0) : $space_count++;
	    next if $space_count > 1;
	    
	    print $_, "\n";
	}
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
    elsif ($PROC eq 'newml') {
	&P("&Control($ML, $PROC);") if $debug;
	&P("&Control($ML, $PROC);");
	&Control($ML, $PROC);
    }
    elsif ($PROC eq 'config') {
	$PROC = 'html_config';
	local($ptr) = $config{'PTR'};
	$ptr =~ s#^\/{1,}#\/#;

	if ($config{'VARIABLE'} && $config{'VALUE'}) {
	    &Control($ML, "html_config_set", $ptr, 
		     $config{'VARIABLE'}, $config{'VALUE'});
	}
	else {
	    &Control($ML, $PROC, $ptr);
	}
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
