#-*- perl -*-
#
# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

# SecureP()
require 'libcgi_cleanup.pl';


sub UpperHalf
{
    &P("Content-Type: text/html");
    &P("Pragma: no-cache");
    &P("");
    &P("<HTML>");
    &P("<HEAD>");
    &P("<HEAD>");
    &P("<META http-equiv=\"Content-Type\"
        content=\"text/html; charset=EUC-JP\">");
    &P("<TITLE>");
    &P("fml configuration interface");
    &P("</TITLE>");
    &P("</HEAD>");
    &P("<BODY BGCOLOR=\"E6E6FA\">");
    &P("<A HREF=\"menu.cgi\" target=\"_parent\">return to menu</A>");

    if ($ErrorString) { &Exit($ErrorString);}

    &PRE;
}


# I'll try to show what do we do now?
sub MakefmlInputTranslate
{
    my ($command, $ml, @argv) = @_;
    my ($buf);
    local(%xe);

    return $NULL unless $MESSAGE_LANGUAGE;
    return $NULL if $ml eq 'etc';

    # print "(debug) &MesgLE(*xe, makefml.$command, $ml, @argv);\n";
    $buf = &MesgLE(*xe, "makefml.$command", $ml, @argv);
    &P($buf);
}


sub Control
{
    local($ml, $command, @argv) = @_;
    my ($tmpbuf, $tmpdir);

    $tmpdir = &SetUpTmpDir;
    $tmpbuf = $tmpdir ? "$tmpdir/makefml.ctlbuf.$$" : '/dev/stdout';

    &P("---Control($ml, $command, @argv)") if $debug;

    if (open(CTL, "|$MAKE_FML -E HTTPD -i stdin > $tmpbuf 2>&1")) {
	select(CTL); $| = 1; select(STDOUT);

	&MakefmlInputTranslate($command, $ml, @argv);

	# debug message
	print join("\t", $command, $ml, @argv),"\n" if $debug;

	print CTL join("\t", $command, $ml, @argv);
	print CTL "\n";

	close(CTL);

	&OUTPUT_FILE($tmpbuf);
	$ControlThrough = 1;
    }
    else {
	&ERROR("cannot execute makefml");
    }

    unlink $tmpbuf;
}


sub MailServerConfig
{
    local($proc, *config) = @_;

    if ($proc eq 'run_newaliases') {
	&PRE;

	if ($CGI_CF{'HOW_TO_UPDATE_ALIAS'}) {
	    # /usr/sbin/postalias
	    $ENV{'PATH'} = '/bin:/usr/ucb:/usr/bin:/sbin:/usr/sbin';

	    &_P("updated aliases (ran \"$CGI_CF{'HOW_TO_UPDATE_ALIAS'}\")");
	    &SpawnProcess($CGI_CF{'HOW_TO_UPDATE_ALIAS'});
	}
	else {
	    &ERROR("I don't know how to update aliases map");
	}

	&EndPRE;
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
	&MesgConv('cgi.ok') || $mesg;
    }
    elsif ($mesg =~ /(ERROR:|WARN:)\s*(\S+)(.*)/i) {
	local($tag, $key, $tbuf) = ($1, $2, $3);
	$r = &MesgConv($key);
	$tag ." ". ($r ? $r : $key.$tbuf);
    }
    else {
	$mesg;
    }
}


sub MesgConv
{
    local($key) = @_;
    local($x);

    if ($LANGUAGE eq 'Japanese' || $LANGUAGE eq 'English') {
	$x = &MesgLE::Lookup($key, $MESG_FILE);
	return $NULL unless $x;

	&jcode::convert(*x, 'euc');
	$x;
    }
    else {
	$key;
    }
}


sub Log
{
    print "LOG: ", @_, "\n";
}


sub _P
{
    my ($s) = @_;

    if ($UseLogMessage) {
	$LogMessage .= $s."\n";
    }
    else {
	&P($s);	
    }
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
		&_P( &XSTranslate($xbuf) )  if $xbuf;

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
	    &_P($_);
	}
	close($file);
    }
    else {
	my $f = $file;

	# hide environment
	$f =~ s/$EXEC_DIR/\$EXEC_DIR/g;
	$f =~ s/$ML_DIR/\$ML_DIR/g;
	&ERROR("cannot open logfile $f");	
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


sub Translate2LogOption
{
    local($x) = @_;

    if ($x eq 'tail') {
	if ($SafeConfig{'TAIL_SIZE'} =~ /^\d+$/) {
	    "-$SafeConfig{'TAIL_SIZE'}";
	}
    }
    elsif ($x eq 'day') {
	if (($SafeConfig{'YYYY'} =~ /^\d+$/) &&
	    ($SafeConfig{'MM'}   =~ /^\d+$/) &&
	    ($SafeConfig{'DD'}   =~ /^\d+$/)) {
	    my $s = sprintf("%04d%02d%02d", 
			    $SafeConfig{'YYYY'}, 
			    $SafeConfig{'MM'}, 
			    $SafeConfig{'DD'});
	    if ($s =~ /^\d+$/) { return "-D$s";}
	}
	else {
	    &ERROR("invalid date YYYYMMDD input");
	    return $NULL;
	}
    }
    elsif ($x eq 'all') {
	return 'all';
    }
    else {
	&ERROR("invalid 'log' command option");
	return $NULL;	
    }
}


sub Command
{
    if ($PROC eq 'add' || $PROC eq 'bye') {
	&Control($ML, $PROC, $MAIL_ADDR);

	&EndPRE;
	&P("<HR>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1)
	    unless ($SavedML);
	&P("<HR>");
	&PRE;
    }
    elsif ($PROC eq 'add_admin' || $PROC eq 'bye_admin' ||
	   $PROC eq 'addadmin' || $PROC eq 'byeadmin') {
	$PROC =~ s/_admin/admin/;

	&Control($ML, $PROC, $MAIL_ADDR);

	&EndPRE;
	&P("<HR>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1)
	    unless ($SavedML);
	&P("<HR>");
	&PRE;
    }
    elsif ($PROC eq 'add_cgi_admin' || $PROC eq 'bye_cgi_admin') {
	$PROC =~ s/_//g;
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'mladmincgi') {
	&Control($ML, 'mladmin.cgi', 'update');
    }
    elsif ($PROC eq 'newml') {
	&EndPRE;
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1);
	&P("<HR>");
	&PRE;

	$UseLogMessage = 1;
	&Control($ML, $PROC);
	&MailServerConfig('run_newaliases', $CGI_CF{'MTA'});
	$UseLogMessage = 0;

	if ($ErrorString) { &P($ErrorString);}
	if ($LogMessage) {
	    &PRE;
	    &P($LogMessage);
	    &EndPRE;
	}
    }
    elsif ($PROC eq 'destructml' || $PROC eq 'rmml') {
	&PRE;
	&Control($ML, $PROC);
	&EndPRE;
	&P("<HR>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/rmml.html", 1);
	&MailServerConfig('run_newaliases', $CGI_CF{'MTA'});
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
    elsif ($PROC eq 'passwd' || $PROC eq 'mladminpasswd') {
	local($saved_proc) = $PROC;
	$PROC = 'html_passwd';

	if ($PASSWORD && $PASSWORD_VRFY) {
	    if ($PASSWORD eq $PASSWORD_VRFY) {
		&Control($ML, $PROC, $CGI_ADMIN_USER || $MAIL_ADDR, $PASSWORD);

		&EndPRE;

		# not show when /ml-admin/$ml is processing...
		unless ($SavedML) {
		    &Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/${saved_proc}.html", 1);
		}
		&P("<HR>");
		&PRE;
	    }
	    else {
		&ERROR("input passwords are different each other.");
		&ERROR(&MesgConv("cgi.password.different"));
	    }
	}
	else {
	    &ERROR("empty password");
	    &ERROR(&MesgConv("cgi.password.empty"));
	}
    }
    elsif ($PROC eq 'cgiadmin_passwd') {
	$PROC = 'html_cgiadmin_passwd';

	if ($ACTION eq 'BYE') {
	    &Control($ML, $PROC, $CGI_ADMIN_USER, "dummympassword", "bye");
	    return;
	}

	if ($PASSWORD && $PASSWORD_VRFY) {
	    if ($PASSWORD eq $PASSWORD_VRFY) {
		&Control($ML, $PROC, $CGI_ADMIN_USER, $PASSWORD);
	    }
	    else {
		&ERROR("input passwords are different each other.");
		&ERROR(&MesgConv("cgi.password.different"));
	    }
	}
	else {
	    &ERROR("empty password");
	    &ERROR(&MesgConv("cgi.password.empty"));
	}
    }
    elsif ($PROC eq 'log') {
	&Control($ML, $PROC, &Translate2LogOption($OPTION));
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

    &EndPRE;

    if ($ControlThrough) {
	;# &P("<META HTTP-EQUIV=refresh CONTENT=\"2; URL=menubar.cgi\">");
    }

    &P("</BODY>");
    &P("</HTML>");
}


1;
