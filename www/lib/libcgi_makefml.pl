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


sub Parse
{
    &GetBuffer(*Config);

    $ML        = $Config{'ML_DEF'} || $Config{'ML'};
    $MAIL_ADDR = $Config{'SPECIFIC_MAIL_ADDR'} || $Config{'MAIL_ADDR'};
    $PROC      = $Config{'PROC'};
    $LANGUAGE  = $Config{'LANGUAGE'};

    # @PROC_ARGV = split(/\s+/, $Config{'ARGV'});

    # menu
    $VARIABLE  = $Config{'VARIABLE'};
    $VALUE     = $Config{'VALUE'};
    $PTR       = $Config{'PTR'};

    # password
    $PASSWORD      = $Config{'PASSWORD'};
    $PASSWORD_VRFY = $Config{'PASSWORD_VRFY'};

    # MTA
    $MTA    = $MTA || $Config{'MTA'};

    # misc
    $OPTION = $Config{'OPTION'};

    # CGI
    $CGI_ADMIN_USER = 
	$Config{'CGI_ADMIN_USER_DEF'} || $Config{'CGI_ADMIN_USER'};
    $ACTION = $Config{'ACTION'};

    # fix variable values for later use
    $PTR       =~ s#^\/{1,}#\/#;
    $PROC      =~ tr/A-Z/a-z/;


    ## Example:
    ## SCRIPT_FILENAME => /usr/local/fml/www/cgi-bin/admin/makefml.cgi
    ## SCRIPT_NAME     => /cgi-bin/fml/admin/makefml.cgi
    ## HTTP_REFERER    => http://beth.fml.org/cgi-bin/fml/admin/makefml.cgi
    ## REQUEST_URI     => /cgi-bin/fml/../fml/admin/makefml.cgi

    # extract $ML name for later use
    my $req_uri = $ENV{'REQUEST_URI'};
    $req_uri =~	
	qq{$CGI_PATH/([A-Za-z0-9\-\._]+)/(|[A-Za-z0-9\-\._]+)(|/)makefml.cgi};
    my ($cgimode , $cgiml) = ($1, $2);
    $ML = $cgiml if ($cgimode ne "admin");

    # We should not use raw $LANGUAGE (which is raw input from browser side).
    # We should check it matches something exactly and use it.
    if ($LANGUAGE eq 'Japanese' || $LANGUAGE eq 'English') {
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
    &P("Content-Type: text/html");
    &P("Pragma: no-cache");
    &P("");
    &P("<HTML>");
    &P("<HEAD>");
    &P("<TITLE>");
    &P("fml configuration interface");
    &P("</TITLE>");
    &P("</HEAD>");
    &P("<BODY BGCOLOR=\"E6E6FA\">");
    &P("<A HREF=\"menu.cgi\" target=\"_parent\">return to menu</A>");

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
    local($s);

    if ($proc eq 'run_newaliases') {
	&P(""); &P("*** setup aliases ***"); &P("");
	&P("-- run newaliases");

	if ($CGI_CF{'HOW_TO_UPDATE_ALIAS'}) {
	    &P("run \"$CGI_CF{'HOW_TO_UPDATE_ALIAS'}\"");
	    &P($NULL);
	    &SpawnProcess($CGI_CF{'HOW_TO_UPDATE_ALIAS'});
	    &P($NULL);
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

	&jcode::convert(*x, 'jis');
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
		&P( &XSTranslate($xbuf) )  if $xbuf;

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
	    &P($_);
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
    local($account)    = '[A-Za-z0-9\-_]+';

    &P("ERROR: ML is empty.") unless $ML;
    &P("ERROR: PROC is empty.") unless $PROC;

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
    elsif ($CGI_ADMIN_USER && ($CGI_ADMIN_USER !~ /^($mail_addr|$account)$/)) {
	&P("ERROR: CGI_ADMIN_USER is insecure.");
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
    else {
        # if (@PROC_ARGV) { 1;} # check 'ARGV'

	1;
    }
}


sub Translate2LogOption
{
    local($x) = @_;

    if ($x eq 'tail') {
	if ($Config{'TAIL_SIZE'} =~ /^\d+$/) {
	    "-$Config{'TAIL_SIZE'}";
	}
    }
    elsif ($x eq 'day') {
	if (($Config{'YYYY'} =~ /^\d+$/) &&
	    ($Config{'MM'}   =~ /^\d+$/) &&
	    ($Config{'DD'}   =~ /^\d+$/)) {
	    my $s = sprintf("%04d%02d%02d", 
			    $Config{'YYYY'}, $Config{'MM'}, $Config{'DD'});
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

	&P("</PRE>");
	&P("<HR>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1);
	&P("<HR>");
	&P("<PRE>");
    }
    elsif ($PROC eq 'add_admin' || $PROC eq 'bye_admin' ||
	   $PROC eq 'addadmin' || $PROC eq 'byeadmin') {
	$PROC =~ s/_admin/admin/;

	&Control($ML, $PROC, $MAIL_ADDR);

	&P("</PRE>");
	&P("<HR>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1);
	&P("<HR>");
	&P("<PRE>");
    }
    elsif ($PROC eq 'add_cgi_admin' || $PROC eq 'bye_cgi_admin') {
	$PROC =~ s/_//g;
	&Control($ML, $PROC, $MAIL_ADDR);
    }
    elsif ($PROC eq 'mladmincgi') {
	&Control($ML, 'mladmin.cgi', 'update');
    }
    elsif ($PROC eq 'newml') {
	&P("</PRE>");
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/$PROC.html", 1);
	&P("<HR>");
	&P("<PRE>");

	&Control($ML, $PROC);
	&MailServerConfig('run_newaliases', $CGI_CF{'MTA'});
    }
    elsif ($PROC eq 'destructml' || $PROC eq 'rmml') {
	&P("<PRE>");
	&Control($ML, $PROC);
	&P("</PRE>");
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

		&P("</PRE>");
		&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/${saved_proc}.html", 1);
		&P("<HR>");
		&P("<PRE>");
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

    &P("</PRE>");

    if ($ControlThrough) {
	;# &P("<META HTTP-EQUIV=refresh CONTENT=\"2; URL=menubar.cgi\">");
    }

    &P("</BODY>");
    &P("</HTML>");
}


1;
