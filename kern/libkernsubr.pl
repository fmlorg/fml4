# Copyright (C) 1993-2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libkernsubr.pl,v 2.5 2001/08/25 12:17:02 fukachan Exp $
#

###
### KernSubr::Sectoin: Security
###

sub __SecureP 
{ 
    my ($s, $command_mode) = @_;

    $s =~ s#(\w)/(\w)#$1$2#g; # permit "a/b" form

    # permit m=12u; e.g. admin subscribe addr m=1;
    # permit m=12 for digest format(subscribe)
    $s =~ s/\s+m=\d+/ /g; $s =~ s/\s+[rs]=\w+/ /g;
    $s =~ s/\s+[rms]=\d+\w+/ /g;

    # ignore <addr+ext@domain>; but this is ugly hack ;-)
    if ($command_mode eq 'admin') { 
	$s =~ s/\+[-\w\.]+\@[-\w\.]+//g;
    }

    # special hooks (for your own risk extension)
    if (%SecureRegExp || %SECURE_REGEXP) { 
	for (values %SecureRegExp, values %SECURE_REGEXP) {
	    next if !$_;
	    return 1 if $s =~ /^($_)$/;
	}
    }

    # special hooks to reject some patterns
    if (%INSECURE_REGEXP) {
	for (values %INSECURE_REGEXP) {
	    next if !$_; 
	    return 0 if $s =~ /^($_)$/;
	}
    }

    # XXX: "# command" is internal represention
    # XXX: and for permitting a special backward compatibility.
    # permit Email Address, 100.tar.gz, # command, # mget 100,last:10 mp ...
    # if ($s =~ /^[\#\s\w\-\[\]\?\*\.\,\@\:]+$/) {
    if ($s =~ /^[\#\s\w\-\.\,\@\:]+$/) {
	1;
    }
    # since, this ; | is not checked when interact with shell in command.
    elsif ($command_mode && $s =~ /[\;\|]/) {
	&Log("SecureP: [$s] includes ; or |"); 
	$s = "Security alert:\n\n\t$s\n\t[$'$`] HAS AN INSECURE CHAR\n";
	&WarnE("Security Alert $ML_FN", "$s\n".('-' x 30)."\n");
	0;
    }
    else {
	&Log("SecureP: Security Alert for [$s]", "[$s] ->[($`)<$&>($')]");
	$s = "Security alert:\n\n\t$s\n\t[$'$`] HAS AN INSECURE CHAR\n";
	&WarnE("Security Alert $ML_FN", "$s\n".('-' x 30)."\n");
	0;
    }
}


sub __RejectAddrP
{
    my ($from) = @_;

    if (! -f $REJECT_ADDR_LIST) {
	&Log("RejectAddrP: \$REJECT_ADDR_LIST NOT EXISTS");
	return $NULL;
    }

    if (open(RAL, $REJECT_ADDR_LIST)) {
	while (<RAL>) {
	    chop;
	    next if /^\s*$/;

	    # adjust syntax
	    s#\@#\\\@#g;
	    s#\\\\#\\#g;

	    if ($from =~ /^($_)$/i) { 
		&Log("RejectAddrP: we reject [$from] which matches [$_]");
		close(RAL);
		return 1;
	    }
	}
	close(RAL);
    }

    0;
}

###
### KernSubr::Sectoin: IO
###

# Write3: call by reference for effeciency
sub __Write3
{ 
    local(*e, $f) = @_; 

    open(APP, "> $f") || (&Log("cannot open $f"), return '');
    select(APP); $| = 1; select(STDOUT);

    if ($MIME_DECODED_ARTICLE) { 
	&use('MIME');
	local(%me) = %e;
	&EnvelopeMimeDecode(*me);

	# XXX 2.2E split code to 3 phases
	# we should not make string to avoid malloc()
	print APP $me{'Hdr'};
	print APP "\n";
	print APP $me{'Body'};
    }
    else {
	# XXX 2.2E split code to 3 phases
	# we should not make string to avoid malloc()
	print APP $e{'Hdr'};
	print APP "\n";
	print APP $e{'Body'};
    }

    close(APP);
}


###
### KernSubr::Sectoin: Message
###

# Notification of the mail on warnigs, errors ... 
sub __Notify
{
    my ($buf) = @_;
    my ($to, @to, $s, $proc, $m);

    # special flag
    return $NULL if $Envelope{'mode:disablenotify'};

    # refer to the original(NOT h:Reply-To:);
    $to   = $Envelope{'message:h:to'} || $Envelope{'Addr2Reply:'};

    # once only (e.g. used in chaddr)
    @to   = split(/\s+/, $Envelope{'message:h:@to'}); 
    undef $Envelope{'message:h:@to'};

    $s    = $Envelope{'message:h:subject'} || "Fml status report $ML_FN";
    $proc = $PROC_GEN_INFO || 'GenInfo';
    $GOOD_BYE_PHRASE = $GOOD_BYE_PHRASE || "--${MAIL_LIST}, Be Seeing You!   ";

    # send the return mail to the address (From: or Reply-To:)
    # (before it, checks whether the return address is not ML nor ML-Ctl)
    # Error Message is set to $Envelope{'error'} if loop is detected;
    if (($buf || $Envelope{'message'}) && 
	&CheckAddr2Reply(*Envelope, $to, @to)) {
	$REPORT_HEADER_CONFIG_HOOK .= 
	    q# $le{'Body:append:files'} = $Envelope{'message:append:files'}; #;
	
	$Envelope{'trailer'} .= "\n$GOOD_BYE_PHRASE $FACE_MARK\n";
	$Envelope{'trailer'} .= &$proc;

	if ($Envelope{'message:ebuf2socket'}) {
	    $Envelope{'ctl:smtp:ebuf2socket'} = 1;
	}
	&Sendmail($to, 
		  $s, 
		  ($buf || $Envelope{'message'}),
		  @to);
	if ($Envelope{'message:ebuf2socket'}) {
	    $Envelope{'ctl:smtp:ebuf2socket'} = 0;
	}
    }

    # if $buf is given, ignore after here.
    # admin error report is done in the last of fml.pl, &Notify(); 
    return if $buf;

    # send the report mail ot the maintainer;
    $Envelope{'error'} .= $m;
    if ($Envelope{'error'}) {
	&WarnE("fml system error message $ML_FN", $Envelope{'error'});
    }

    if ($Envelope{'message:to:admin'}) {
	&Warn("fml system message $ML_FN", $Envelope{'message:to:admin'});
    }
}


1;
