#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

sub Parse
{
    &GetBuffer(*Config);

    $ML        = $Config{'ML_DEF'} || $Config{'ML'};
    $MAIL_ADDR = $Config{'MAIL_ADDR'};
    $PROC      = $Config{'PROC'};
    $LANGUAGE  = $Config{'LANGUAGE'};

    @PROC_ARGV = split(/\s+/, $Config{'ARGV'});

    # menu
    $VARIABLE  = $Config{'VARIABLE'};
    $VALUE     = $Config{'VALUE'};
    $PTR       = $Config{'PTR'};

    # password
    $PASSWORD      = $Config{'PASSWORD'};
    $PASSWORD_VRFY = $Config{'PASSWORD_VRFY'};

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
	while (($k, $v) = each %Config) { &P("Config: $k => $v");}
    }
}


sub Control
{
    local($ml, $command, @argv) = @_;
    local($tmpbuf) = "/tmp/makefml.ctlbuf.$$";

    &P("---Control($ml, $command, @argv)") if $debug;

    if (open(CTL, "|$MAKE_FML -E HTTPD -i stdin > $tmpbuf 2>&1")) {
	select(CTL); $| = 1; select(STDOUT);

	print CTL join("\t", $command, $ml, @argv);
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
    elsif ($mesg =~ /(ERROR:|WARN:)\s*(\S+)/) {
	$1 ." ". &Mesg2Japanese($2);
    }
    else {
	$mesg;
    }
}


sub Mesg2Japanese
{
    local($key) = @_;
    local($x);

    if ($LANGUAGE eq 'Japanese') {
	$x = &MesgLE'Lookup($key, $MESG_FILE); #';
	&jcode'convert(*x, 'jis'); #';
	$x;
    }
    else {
	$key;
    }
}

sub Log
{
    print "LOG: @_\n";
}


sub OUTPUT_FILE
{
    local($file) = @_;
    local(%ncache);

    if (open($file, $file)) {
	# firstly check "ExitStatus:" 
	while (<$file>) {
	    if (/^ExitStatus:(.*)/) {
		next if $ncache{$_};
		$ncache{$_} = 1;
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
    elsif ($LANGUAGE && ($LANGUAGE !~ /^[A-Za-z]+$/)) {
	&P("ERROR: LANGUAGE is insecure.");
	0;
    }
    elsif ($MAIL_ADDR && ($MAIL_ADDR !~ /^($mail_addr)$/)) {
	&P("ERROR: MAIL_ADDR is insecure.");
	0;
    }
    elsif ($VARIABLE && ($VARIABLE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VARIABLE $VARIABLE is insecure.");
	0;	
    }
    elsif ($VALUE && ($VALUE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VALUE is insecure.");
	0;	
    }
    elsif ($PTR && ($PTR !~ /^([0-9A-Z_\/]+)$/i)) {
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
    elsif ($PROC eq 'passwd') {
	$PROC = 'html_passwd';

	if ($PASSWORD && $PASSWORD_VRFY) {
	    if ($PASSWORD eq $PASSWORD_VRFY) {
		&Control($ML, "html_passwd", $MAIL_ADDR, $PASSWORD);
	    }
	    else {
		&ERROR("input passwords are different each other.");
		&ERROR(&Mesg2Japanese("cgi.password.different"));
	    }
	}
	else {
	    &ERROR("empty password");
	    &ERROR(&Mesg2Japanese("cgi.password.empty"));
	}
    }
    else {
	&ERROR("unknown PROC");
    }
}


sub Finish
{
    if ($ErrorString) { &Exit($ErrorString);}

    &P("</PRE>");
    &P("</BODY>");
    &P("</HTML>");
}


1;
