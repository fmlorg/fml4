# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1998,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libsmtpsubr.pl,v 1.8 2001/08/24 11:07:03 fukachan Exp $
#

use vars qw($debug); 
use vars qw($LastSmtpIOString);
use vars qw($MIME_CONVERT_WHOLEMAIL);


### Mail Forwarding
sub ForwardSeparatorBegin { "\n------- Forwarded Message\n\n";}
sub ForwardSeparatorEnd { "\n\n------- End of Forwarded Message\n";}

sub DoSmtpFiles2Socket
{
    use vars qw(@f $f %f %e);
    local(*f, *e) = @_;
    my ($autoconv, $count, $ml, $hdr_found);

    $ml    = (split(/\@/, $MAIL_LIST))[0];
    $count = scalar(@f) > 1 ? 1 : 0;

    for $f (@f) {
	next if $f =~ /^\s*$/;
	&Debug("SmtpFiles2Socket::($f)") if $debug;

	if ($f{$f, 'zcat'}) {
	    &Log("SmtpFiles2Socket: \$ZCAT not defined") unless $ZCAT;
	    &DiagPrograms('ZCAT');
	}

	if ($f{$f, 'uuencode'}) {
	    &Log("SmtpFiles2Socket: \$UUENCODE not defined") unless $UUENCODE;
	    &DiagPrograms('UUENCODE');
	}

	if ($f{$f, 'zcat'} && open(FILE, " $ZCAT $f|")) {
	    &Log("SmtpFiles2Socket: cannot zcat $f"); close(FILE); next;
	}
	elsif ($f{$f, 'uuencode'} && open(FILE, "$UUENCODE $f $f|")) {
	    &Log("SmtpFiles2Socket: cannot uuencode $f"); close(FILE); next;
	}
	else {
	    if (! open(FILE, $f)) {
		&Log("SmtpFiles2Socket: cannot open $f");
		close(FILE);
		next;
	    }
	}

	$autoconv = $f{$f, 'autoconv'};

	if ($count) { # append the separator if more than two files;
	    my $boundary = ('-' x 60)."\r\n";
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
	    # XXX Here we must use %Envelope not %e ! (attention)
	    # XXX We should be split %Envelope to %Envelope and %PCB ?
	    if ($Envelope{'mode:doc:ignore#'}) {
		next if $hdr_found && (1 .. /^\#\.endFML HEADER/);
		next if /^\#/ && $Envelope{'mode:doc:ignore#'} eq 'a';
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
		s/_CTLADDR_/$e{'CtlAddr:'}/g;
		s/_MAIL_LIST_/$MAIL_LIST/g;

		s/_ARG0_/$e{'doc:repl:arg0'}/g;
		s/_ARG1_/$e{'doc:repl:arg1'}/g;
		s/_ARG2_/$e{'doc:repl:arg2'}/g;
		s/_ARG3_/$e{'doc:repl:arg3'}/g;
		s/_ARG4_/$e{'doc:repl:arg4'}/g;
		s/_ARG5_/$e{'doc:repl:arg5'}/g;
		s/_ARG6_/$e{'doc:repl:arg6'}/g;
		s/_ARG7_/$e{'doc:repl:arg7'}/g;
		s/_ARG8_/$e{'doc:repl:arg8'}/g;
		s/_ARG9_/$e{'doc:repl:arg9'}/g;
	    }

	    s/\n/\r\n/;
	    print S $_;
	    print SMTPLOG $_;
	    $LastSmtpIOString = $_;
	};

	close(FILE);
    }
}


sub Copy2SocketFromHash
{
    my ($key) = @_;
    my ($pp, $p, $maxlen, $len, $buf);

    $pp     = 0;
    $maxlen = length($Envelope{$key});

    if ($MIME_CONVERT_WHOLEMAIL && $key eq 'Header') { 
	&use('MIME'); 
	# $_ .= &DecodeMimeStrings($Envelope{'Header'});
    }

    while (1) {
	$p   = index($Envelope{$key}, "\n", $pp);
	$len = $p  - $pp + 1;
	$buf = substr($Envelope{$key}, $pp, ($p < 0 ? $maxlen-$pp : $len));

	if ($MIME_CONVERT_WHOLEMAIL && $key eq 'Header') { 
	    $buf = &DecodeMimeStrings($buf);
	}

	if ($buf !~ /\r\n$/) { $buf =~ s/\n$/\r\n/;}

	# ForwMail()
	if ($Envelope{'ctl:smtp:forw:ebuf2socket'}) {
	    if ($key eq 'Header' && $buf =~ /^From /i) {
		; # ignore UNIX FROM line
	    }
	    else {
		print SMTPLOG $buf;
		print S $buf;
	    }
	}
	# WholeMail()
	else {
	    print SMTPLOG "   ", $buf;
	    print S "   ", $buf;
	}

	$LastSmtpIOString = $buf;

	last if $p < 0;
	$pp = $p + 1;
    }
}


1;
