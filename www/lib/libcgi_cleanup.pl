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
    my $req_uri = $SavedENV{'REQUEST_URI'};
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


sub SecureP
{
    my ($ok) = 1;

    &P("ERROR: ML is empty.")   unless $ML;
    &P("ERROR: PROC is empty.") unless $PROC;

    my ($secure_pat) = '[A-Za-z0-9\-_]+';
    my ($num_pat)    = '[0-9]+';
    my ($mail_addr)  = '[A-Za-z0-9\.\-_]+\@[A-Za-z0-9\.\-]+';
    my ($account)    = '[A-Za-z0-9\-_]+';

    if ($ML !~ /^($secure_pat)$/i) {
	&P("ERROR: ML is insecure.");
	$ok = 0;
    }
    elsif ($PROC !~ /^($secure_pat)$/i) {
	&P("ERROR: PROC is insecure.");
	$ok = 0;
    }
    elsif ($LANGUAGE && ($LANGUAGE !~ /^[A-Za-z]+$/)) {
	&P("ERROR: LANGUAGE is insecure.");
	$ok = 0;
    }
    elsif ($MAIL_ADDR && ($MAIL_ADDR !~ /^($mail_addr)$/)) {
	&P("ERROR: MAIL_ADDR is insecure.");
	$ok = 0;
    }
    elsif ($CGI_ADMIN_USER && ($CGI_ADMIN_USER !~ /^($mail_addr|$account)$/)) {
	&P("ERROR: CGI_ADMIN_USER is insecure.");
	$ok = 0;
    }
    elsif ($VARIABLE && ($VARIABLE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VARIABLE $VARIABLE is insecure.");
	$ok = 0;	
    }
    elsif ($VALUE && ($VALUE !~ /^($secure_pat)$/i)) {
	&P("ERROR: VALUE is insecure.");
	$ok = 0;	
    }
    elsif ($OPTION && ($OPTION !~ /^($secure_pat)$/i)) {
	&P("ERROR: OPTION is insecure.");
	$ok = 0;	
    }
    elsif ($ACTION && ($ACTION !~ /^($secure_pat)$/i)) {
	&P("ERROR: ACTION is insecure.");
	$ok = 0;	
    }
    elsif ($MTA && ($MTA !~ /^([a-z]+)$/i)) {
	&P("ERROR: MTA is insecure.");
	$ok = 0;	
    }
    elsif ($PTR && ($PTR !~ /^([0-9A-Z_\/]+)$/i)) {
	&P("ERROR: PTR is insecure.");
	$ok = 0;	
    }
    else {
	my $k;
	for $k ('YYYY', 'MM', 'DD', 'TAIL_SIZE') {
	    if ($Config{$k} ne '') {
		if ($Config{$k} =~ /^(\d+)$/) {
		    $SafeConfig{ $k } = $Config{ $k };
		}
		else {
		    &P("ERROR: $k is insecure.");
		    $ok = 0;
		}
	    }
	}
    }

    # ambiguous (cannot restrict it ...)
    if ((length($Config{'PASSWORD'})      > 64) ||
	(length($Config{'PASSWORD_VRFY'}) > 64) ) {
	&P("ERROR: too long password.");
	$ok = 0;
    }

    $ok;
}


1;
