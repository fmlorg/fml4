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


sub Init
{
    $| = 1;

    # getopt()
    require 'getopts.pl';
    &Getopts("dh");

    # fml system configuration
    require "$CONFIG_DIR/system";

    push(@INC, $EXEC_DIR);

    require 'jcode.pl';
    eval "&jcode'init;";

    # cgi.conf
    $CGI_CONF = $CGI_CONF || "$EXEC_DIR/.fml/cgi.conf";
    if (-f $CGI_CONF) {	require $CGI_CONF;}

    # www menu specific configuration
    $WWW_DIR      = "$EXEC_DIR/www";
    $WWW_CONF_DIR = "$WWW_DIR/conf";
    $CGI_CF       = "$WWW_CONF_DIR/cgi.cf";

    # if exists, import cgi.cf to %CGI_CF hash.
    if (-f $CGI_CF) {
        eval("&LoadCGICF;");
	&Err($@) if $@;
    }

    # overwrite
    $CGI_CF{'MTA'}                 = $MTA || $CGI_CF{'MTA'};
    $CGI_CF{'HOW_TO_UPDATE_ALIAS'} = $HOW_TO_UPDATE_ALIAS ||
	$CGI_CF{'HOW_TO_UPDATE_ALIAS'};

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

    # 3.0B
    $DefaultConfigPH = "$EXEC_DIR/default_config.ph";
}


sub ShowHeader
{
    &P("Content-Type: text/html");
    &P("Pragma: no-cache\n");
}


# return YYYYMMDD at Greenwich standard timezone (tricky:-)
sub YYYYMMDD
{
    sprintf("%4d%02d%02d.%02d%02d",
            $year + 1900, $mon + 1, $mday,
          $hour, 0);
}


sub ExpandDate
{
    local($pat) = @_;
    local($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
    local($x, $a, $b, $y);

    if ($pat eq 'YYYY') {
	for $a (0 .. 10) {
	    $x = (1900 + $year) - $a;
	    print "\t\t<OPTION VALUE=$x>$x\n";
	}
    }
    elsif ($pat eq 'MM') {
	for $x (01 .. 12) { 
	    print "\t\t<OPTION VALUE=$x>$x\n";
	}
    }
    elsif ($pat eq 'DD') {
	for $x (01 .. 31) { 
	    print "\t\t<OPTION VALUE=$x>$x\n";
	}
    }
    else {
	$NULL;
    }
}


sub ExpandOption
{
    local($dir, %ml);

    if (opendir(DIRD, $ML_DIR)) {
	while ($dir = readdir(DIRD)) {
	    next if $dir =~ /^\./;
	    next if $dir =~ /^etc/;
	    next if $dir =~ /^fmlserv/;

	    # @listname@list.com must not exists!
	    next if $dir =~ /^\@/;
	    $ml{$dir} = $dir;
	}
	closedir(DIRD);

	for $addr (sort {$a cmp $b} keys %ml) {
	    print "\t\t\t<OPTION VALUE=$addr>$addr\n";
	}

    }
    else {
	&ERROR("cannot open \$ML_DIR");
    }
}


sub ExpandMemberList
{
    local($mode) = @_;
    local($config_ph, @list, $list, $addr);
    local(%uniq, %addr);

    # XXX 3.0B
    # $DIR, @LIBDIR
    $DIR       = "$ML_DIR/$ML";
    $config_ph = "$DIR/config.ph";

    if (-f $config_ph) {
	package config_ph;
	$DIR = $main'DIR; #';
	require 'libloadconfig.pl'; &__LoadConfiguration;    
	package main;
    }
    else {
	&ERROR("cannot open $config_ph");
    }

    if ($mode eq 'admin_member_list') {
	@list = ($config_ph'ADMIN_MEMBER_LIST, @config_ph'ADMIN_MEMBER_LIST);
    }
    else {
	@list = ($config_ph'MEMBER_LIST, @config_ph'MEMBER_LIST);
    }

    undef %uniq;
    undef %addr;

    for $list (@list) {
	next unless $list;
	# uniq
	next if $uniq{$list}; $uniq{$list} = 1;

	if (open(LIST, $list)) {
	    while (<LIST>) {
		next if /^\#/;

		($addr) = split;
		$addr{$addr} = $addr;
	    }
	    close(LIST);
	}
	elsif ($mode eq 'admin_member_list') {
	    ; # ignore since $ADMIN_MEMBER_LIST is not required.
	}
	else {
	    &ERROR("cannot open '$list'");
	}
    }

    # XXX oops, I wanna less malloc() version ;-)
    for $addr (sort {$a cmp $b} keys %addr) {
	print "\t\t\t<OPTION VALUE=$addr>$addr\n";
    }
}


sub ExpandHowToUpdateAliases
{
    local($s);

    for $s (
	    "[postfix]  postalias $ML_DIR/etc/aliases",
	    "[sendmail] newaliases",
	    ) {
	print "\t\t\t<OPTION VALUE=\"$s\">$s\n";
    }
}


sub ExpandCGIAdminMemberList
{
    local($mode) = @_;
    local($list);

    $list = "$CGI_AUTHDB_DIR/admin/htpasswd";

    if (open(LIST, $list)) {
	while (<LIST>) {
	    next if /^\#/;

	    ($addr) = split(/:/,$_);
	    $addr{$addr} = $addr;
	}
	close(LIST);
    }
    else {
	&ERROR("cannot open '$list'");
    }

    # XXX oops, I wanna less malloc() version ;-)
    for $addr (sort {$a cmp $b} keys %addr) {
	print "\t\t\t<OPTION VALUE=$addr>$addr\n";
    }
}


sub ExpandCGIAdminMemberListForEachML
{
    local($mode, $ml) = @_;
    local($list);

    $list = "$CGI_AUTHDB_DIR/ml-admin/$ml/htpasswd";

    if (open(LIST, $list)) {
	while (<LIST>) {
	    next if /^\#/;

	    ($addr) = split(/:/,$_);
	    $addr{$addr} = $addr;
	}
	close(LIST);
    }
    else {
	&ERROR("cannot open '$list'");
    }

    # XXX oops, I wanna less malloc() version ;-)
    for $addr (sort {$a cmp $b} keys %addr) {
	print "\t\t\t<OPTION VALUE=$addr>$addr\n";
    }
}


sub Convert
{
    local($file, $inline) = @_;

    $TODAY = &YYYYMMDD;

    if (open($file, $file)) {
	while (<$file>) {
	    if ($inline) {
		next if 1 .. /__START__/;
	    }

	    if (/__EXPAND_(YYYY|MM|DD)__/) {
		&ExpandDate($1);
		next;
	    }

	    if (/__EXPAND_OPTION_ML__/) {
		&ExpandOption;
		next;
	    }

	    if (/__EXPAND_OPTION_MEMBER_LIST__/) {
		&ExpandMemberList;
		next;
	    }

	    if (/__EXPAND_OPTION_ADMIN_MEMBER_LIST__/) {
		&ExpandMemberList('admin_member_list');
		next;
	    }

	    if (/__EXPAND_HOW_TO_UPDATE_ALIASES__/) {
		&ExpandHowToUpdateAliases;
		next;
	    }

	    if (/__EXPAND_OPTION_CGI_ADMIN_MEMBER_LIST__/) {
		&ExpandCGIAdminMemberList;
		next;
	    }

	    if (/__EXPAND_OPTION_CGI_ADMIN_MEMBER_LIST_FOR_EACH_ML__/) {
		&ExpandCGIAdminMemberListForEachML($NULL, $ML);
		next;
	    }

	    s/_CGI_PATH_/$CGI_PATH/g;
	    s/_FML_VERSION_/$VERSION/g;
	    s/_HOW_TO_UPDATE_ALIAS_/$CGI_CF{'HOW_TO_UPDATE_ALIAS'}/g;

	    s/_EXEC_DIR_/$EXEC_DIR/g;
	    s/_ML_DIR_/$ML_DIR/g;

	    # added by PR from ikeda <ikeda@maple.or.jp>
	    # XXX $ML is global, defined in ml-admin/menu.cgi
	    # XXX or $ML is passed from /admin/menu.cgi
	    # http://www.maple.or.jp/~ikeda/diffs/fml/
	    s/_ML_/$ML/g;

	    # 
	    s/__TODAY__/$TODAY/g;

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


sub P
{ 
    local($s) = @_;
    &jcode'convert(*s, 'jis'); #';
    print $s, "\n";
}


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

    $new = $CGI_CF. ".$$.new";

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


### Section: utils
sub SpawnProcess
{
    local($prog) = @_;

    if (open(PROG, "$prog 2>&1 |")) {
	while (<PROG>) { &P($_);}
	close(PROG);

	&ERROR("exit (" .($? & 255). ")") if $? & 255;
	# &ERROR($!) if $!;
    }
}



### Real Function of *.cgi
sub ShowAdminMenu
{
    local($mode) = @_;

    if ($mode =~ /^[a-z]+$/) {
	if ($Config{'LANGUAGE'} eq 'Japanese') {
	    &Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/${mode}.html");
	}
	elsif ($Config{'LANGUAGE'} eq 'English') {
	    &Convert("$HTDOCS_TEMPLATE_DIR/English/admin/${mode}.html");
	}
	else {
	    if ($LANGUAGE eq 'Japanese') {
		&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/admin/${mode}.html");
	    }    
	    else {
		&Convert("$HTDOCS_TEMPLATE_DIR/English/admin/${mode}.html");
	    }
	}
    }
    else {
	&ERROR("insecure xxx.cgi call");
    }
}


1;
