# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

sub DoSmtpFiles2Socket
{
    local(*f, *e) = @_;
    local($autoconv, $count, $boundary, $fn, $ml);
    local($hdr_found) = 0;

    $ml    = (split(/\@/, $MAIL_LIST))[0];
    $count = scalar(@f) > 1 ? 1 : 0;

    for $f (@f) {
	next if $f =~ /^\s*$/;
	&Debug("SmtpFiles2Socket::($f)") if $debug;

	if ($f{$f, 'zcat'}) {
	    &Log("SmtpFiles2Socket: \$ZCAT not defined") unless $ZCAT;
	}

	if ($f{$f, 'zcat'} && open(FILE, " $ZCAT $f|")) {
	    &Log("SmtpFiles2Socket: cannot zcat $f"); close(FILE); next;
	}
	elsif ($f{$f, 'uuencode'} && open(FILE, "$UUENCODE $f $f|")) {
	    &Log("SmtpFiles2Socket: cannot uuencode $f"); close(FILE); next;
	}
	else {
	    &Open(FILE, $f) || 
		(&Log("SmtpFiles2Socket: cannot open $f"), close(FILE), next);
	}

	$autoconv = $f{$f, 'autoconv'};

	if ($count) { # append the separator if more than two files;
	    $boundary = ('-' x 60)."\r\n";
	    print S $boundary;
	    print SMTPLOG $boundary;
	}

	$hdr_found = 0;
	while (<FILE>) { 
	    s/^\./../; 
	    &jcode'convert(*_, 'jis') if $autoconv;#';

	    # header
	    $hdr_found  = 1 if /^\#\.FML HEADER/;
	    
	    # guide, help, ...
	    if ($Envelope{'mode:doc:ignore#'}) {
		next if $hdr_found && (1 .. /^\#\.endFML HEADER/);
		next if /^\#/   && $Envelope{'mode:doc:ignore#'} eq 'a';
		# next if /^\#\#/ && $Envelope{'mode:doc:ignore#'} eq 'm';
		if ($Envelope{'mode:doc:ignore#'} eq 'm') {
		    next if /^\#\#/;
		    s/^\#\s*//;
		}
	    }

	    # guide, help, ...
	    if ($Envelope{'mode:doc:repl'}) {
		s/_DOMAIN_/$DOMAINNAME/g;
		s/_FQDN_/$FQDN/g;

		s/_ML_/$ml/g;
		s/_CTLADDR_/$Envelope{'CtlAddr:'}/g;
		s/_MAIL_LIST_/$MAIL_LIST/g;

		s/_ARG0_/$Envelope{'doc:repl:arg0'}/g;
		s/_ARG1_/$Envelope{'doc:repl:arg1'}/g;
		s/_ARG2_/$Envelope{'doc:repl:arg2'}/g;
		s/_ARG3_/$Envelope{'doc:repl:arg3'}/g;
		s/_ARG4_/$Envelope{'doc:repl:arg4'}/g;
		s/_ARG5_/$Envelope{'doc:repl:arg5'}/g;
		s/_ARG6_/$Envelope{'doc:repl:arg6'}/g;
		s/_ARG7_/$Envelope{'doc:repl:arg7'}/g;
		s/_ARG8_/$Envelope{'doc:repl:arg8'}/g;
		s/_ARG9_/$Envelope{'doc:repl:arg9'}/g;
	    }

	    s/\n/\r\n/;
	    print S $_;
	    print SMTPLOG $_;
	    $LastSmtpIOString = $_;
	};

	close(FILE);
    }
}


1;
