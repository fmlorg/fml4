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
$ML         = '_ML_'; # automatically replaced by makefml
# tricy \_ML\_ syntax to avoid "makefml &Conv() replacement'
if ($ML eq "\_ML\_" || (!$ML)) {
    &Err("Error: mailing list is not defined.");
}

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

    $ML        = $config{'ML_DEF'} || $config{'ML'};
    $MAIL_ADDR = $config{'MAIL_ADDR'};
    $PROC      = $config{'PROC'};
    $LANGUAGE  = $config{'LANGUAGE'};
    @PROC_ARGV = split(/\s+/, $config{'ARGV'});

    # menu
    $VARIABLE  = $config{'VARIABLE'};
    $VALUE     = $config{'VALUE'};
    $PTR       = $config{'PTR'};

    # fix
    $PTR       =~ s#^\/{1,}#\/#;
    $PROC      =~ tr/A-Z/a-z/;

    if ($LANGUAGE eq 'Japanese') {
	push(@INC, $EXEC_DIR);
	require 'jcode.pl';
	eval "&jcode'init;";
	require 'libmesgle.pl';
	$MESG_FILE = "$EXEC_DIR/messages/Japanese/makefml";
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

    if ($ErrorString) { &Exit($ErrorString);}

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
    local($mail_addr)  = '[A-Za-z0-9\.\-_]+\@[A-Za-z0-9\.\-]+';

    if ($ML !~ /^($secure_pat)$/i) {
	&P("ERROR: ML is insecure.");
	0;
    }
    elsif ($PROC !~ /^($secure_pat)$/i) {
	&P("ERROR: PROC is insecure.");
	0;
    }
    elsif ($LANGUAGE !~ /^[A-Za-z]+$/) {
	&P("ERROR: LANGUAGE is insecure.");
	0;
    }
    elsif ($MAIL_ADDR !~ /^($mail_addr)$/) {
	&P("ERROR: \$MAIL_ADDR is insecure.");
	0;
    }
    elsif ($VARIABLE !~ /^($secure_pat)$/i) {
	&P("ERROR: VARIABLE is insecure.");
	0;	
    }
    elsif ($VALUE !~ /^($secure_pat)$/i) {
	&P("ERROR: VALUE is insecure.");
	0;	
    }
    elsif ($PTR !~ /^([0-9A-Z_\/]+)$/i) {
	&P("ERROR: PTR is insecure.");
	0;	
    }
    # 
    # check @PROC_ARGV
    # 
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

	if ($VARIABLE && $VALUE) {
	    &Control($ML, "html_config_set", $PTR, $VARIABLE, $VALUE);
	}
	else {
	    &Control($ML, $PROC, $PTR);
	}
    }
    else {
	&ERROR("unknown PROC");
    }
}


sub Finish
{
    &P("</PRE>");
    &P("</BODY>");
    &P("</HTML>");
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

	&P("GetBuffer: $k\t$v<br>\n") if $debug;
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


1;
