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

    # MTA
    $MTA = $Config{'MTA'};

    # fix
    $PTR       =~ s#^\/{1,}#\/#;
    $PROC      =~ tr/A-Z/a-z/;

    # For example:
    # * input ../ syntax  
    # SCRIPT_FILENAME => /usr/local/fml/www/cgi-bin/admin/makefml.cgi
    # SCRIPT_NAME => /cgi-bin/fml/admin/makefml.cgi
    # HTTP_REFERER => http://beth.fml.org/cgi-bin/fml/admin/makefml.cgi
    # REQUEST_URI => /cgi-bin/fml/../fml/admin/makefml.cgi
    # 
    $SCRIPT_NAME  = $ENV{'SCRIPT_NAME'};
    $HTTP_REFERER = $ENV{'HTTP_REFERER'};

    # fix (tricky:-)
    $SCRIPT_NAME  =~ s/makefml.cgi$/menu.cgi/;
    $SCRIPT_NAME  =~ s/makefml.cgi.+$/menu.cgi/;
    $HTTP_REFERER =~ s/makefml.cgi.+$/menu.cgi/;
    
    # We should not use raw $LANGUAGE (which is raw input from browser side).
    # We should check it matches something exactly and use it.
    if ($LANGUAGE eq 'Japanese') {
	push(@INC, $EXEC_DIR);
	require 'jcode.pl';
	eval "&jcode'init;";
	require 'libmesgle.pl';
	$MESG_FILE        = "$EXEC_DIR/messages/$LANGUAGE/cgi";
	$MESSAGE_LANGUAGE = $LANGUAGE;
	push(@LIBDIR, $EXEC_DIR);
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
    &P("<BODY BGCOLOR=\"E6E6FA\">");

    if ($ErrorString) { &Exit($ErrorString);}

    &P("<PRE>");

    if ($debug) {
	while (($k, $v) = each %ENV)    { &P("ENV: $k => $v");}
	while (($k, $v) = each %Config) { &P("Config: $k => $v");}
    }
}


# I'll try to show what do we do now?
sub MakefmlInputTranslate
{
    local($command, $ml, @argv) = @_;
    local($buf, %xe);

    return unless $MESSAGE_LANGUAGE;

    # print "(debug) &MesgLE(*xe, makefml.$command, $ml, @argv);\n";
    $buf = &MesgLE(*xe, "makefml.$command", $ml, @argv);
    print $buf, "\n";
}


sub Control
{
    local($ml, $command, @argv) = @_;
    local($tmpbuf) = "/tmp/makefml.ctlbuf.$$";

    &P("---Control($ml, $command, @argv)") if $debug;

    if (open(CTL, "|$MAKE_FML -E HTTPD -i stdin > $tmpbuf 2>&1")) {
	select(CTL); $| = 1; select(STDOUT);

	&MakefmlInputTranslate($command, $ml, @argv);

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


sub MailServerConfig
{
    local($proc, *config) = @_;
    local($s);

    if ($proc eq 'mail_server_config') {
	$s = $config{'MTA'};
	if ($s =~ /^(sendmail|postfix|qmail)$/) {
	    $CGI_CF{'MTA'} = $s;
	    &SaveCGICF;
	}
	else {
	    &ERROR("unknown MTA (Mail Trasnport Agent)");
	    &ERROR("I have preparations for sendmail, postfix, qmail.");
	}
    }
    elsif ($proc eq 'newaliases_config') {
	$CGI_CF{'HOW_TO_UPDATE_ALIAS'} = $config{'HOW_TO_UPDATE_ALIAS'};
	$CGI_CF{'HOW_TO_UPDATE_ALIAS'} =~
	    s/^\s*\[\S+\]\s*//g;
	&SaveCGICF;
    }
    elsif ($proc eq 'run_newaliases') {
	&P("-- run newaliases");

	if ($CGI_CF{'HOW_TO_UPDATE_ALIAS'}) {
	    &P("run \"$CGI_CF{'HOW_TO_UPDATE_ALIAS'}\"");
	    &SpawnProcess($CGI_CF{'HOW_TO_UPDATE_ALIAS'});
	}
	else {
	    &ERROR("I don't know how to update aliases map");
	}
    }
    else {
	&ERROR("MailServerConfig: unknown $proc");
    }
}


# XS: eXit Status
sub XSTranslate
{
    local($mesg) = @_;
    local($r);

    $mesg =~ s/^\s*//;

    if ($mesg =~ /OK:/) {
	&Mesg2Japanese('cgi.ok') || $mesg;
    }
    elsif ($mesg =~ /(ERROR:|WARN:)\s*(\S+)(.*)/i) {
	local($tag, $key, $tbuf) = ($1, $2, $3);
	$r = &Mesg2Japanese($key);
	$tag ." ". ($r ? $r : $key.$tbuf);
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
	return $NULL unless $x;

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
    local(%ncache, $xbuf, $inbuf);

    if (open($file, $file)) {
	# firstly check "ExitStatus:" 
	while (<$file>) {
	    chop($inbuf = $_);

	    if ($inbuf =~ /^ExitStatus:(.*)/) {
		$xbuf = $1;

		# uniq
		next if $ncache{$inbuf};
		$ncache{$inbuf} = 1;

		# output with language conversion
		print &XSTranslate($xbuf), "\n" if $xbuf;

		next;
	    }
	}
	close($file);

	local($found);
	$found = &Grep('End of HtmlConfigMode Header', $file);

	open($file, $file);
	while (<$file>) {
	    if ($found) {
		next if 1 .. /### End of HtmlConfigMode Header/;
	    }
	    else {
		next if /THIS HOST/;
		next if /Loading the configuration/
	    }

	    next if /^\-\-\-/ && (!/(lock|unlock)/i);
	    next if /^ExitStatus:/;
	    next if /config.ph;.*\$CFVersion/;
	    next if /^\*\*\* /;

	    chop;

	    $_ ? ($space_count = 0) : $space_count++;
	    next if $space_count > 1;

	    # hide environment
	    s/$EXEC_DIR/\$EXEC_DIR/g;
	    s/$ML_DIR/\$ML_DIR/g;
	    print $_, "\n";
	}
	close($file);
    }
    else {
	&ERROR("cannot open logfile");	
    }
}


sub Grep
{
    local($key, $file) = @_;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/i;}
    close(IN);

    $NULL;
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
    &ShowReferer;

    if ($PROC eq 'add' || $PROC eq 'bye') {
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'add_admin' || $PROC eq 'bye_admin') {
	$PROC =~ s/_admin/admin/;
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'newml') {
	&Control($ML, $PROC);
    }
    elsif ($PROC eq 'destructml') {
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
    # not "makefml" calls
    elsif ($PROC eq 'mail_server_config') {
	&MailServerConfig($PROC, *Config);
    }
    elsif ($PROC eq 'newaliases_config') {
	&MailServerConfig($PROC, *Config);
    }
    elsif ($PROC eq 'run_newaliases') {
	&MailServerConfig($PROC, $CGI_CF{'MTA'});
    }
    else {
	&ERROR("Command: unknown PROC");
    }
}


sub Finish
{
    if ($ErrorString) { &Exit($ErrorString);}

    &P("</PRE>");
    &ShowReferer;
    &P("</BODY>");
    &P("</HTML>");
}


sub ShowReferer
{
    if ($SCRIPT_NAME) {
	print "<H2>\n";
	print "<A HREF=\"";
	print $SCRIPT_NAME;
	print "\">[back to main menu]</A>\n";
	print "</H2>\n";
    }
}


1;
