# Copyright (C) 1993-1998,2001 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998,2001 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $FML: libsmtpmci.pl,v 2.6 2001/08/25 12:14:40 fukachan Exp $
#
# SMTP Pararell Delivery Library


use vars qw($debug $debug_smtp);
use vars qw(@HOSTS); # list of smtp servers  


sub SmtpDLAMCIDeliver
{
    local(*e, *rcpt, *smtp, *files) = @_;
    my ($i, $error);
    for ($i = 0; $i < $MCI_SMTP_HOSTS; $i++) {
	($error = &SmtpIO(*e, *rcpt, *smtp, *files)) && (return $error);
    }
}


sub SmtpMCIDeliver
{
    local(*e, *rcpt, *smtp, *files) = @_;
    my ($nh, $nm, $i, $j);
    my (%cache);

    if ($e{'mode:__deliver'}) {
	return &SmtpDLAMCIDeliver(*e, *rcpt, *smtp, *files);
    }

    $nh = $MCI_SMTP_HOSTS; # may be != scalar(@HOSTS);
    $nm = 0;

    # save @rcpt to the local cache entry
    while (@rcpt) { 
	foreach $i (1 .. $nh) { $cache{$i, $nm} = shift @rcpt;}; 
	$nm++;
    }

    foreach $i (1 .. $nh) { 
	undef @rcpt; # reset @rcpt
	for ($j = 0; $cache{$i, $j} ne ''; $j++) { 
	    push(@rcpt, $cache{$i, $j});
	    undef $cache{$i, $j}; # not retry, OK?;
	}

	if (@rcpt) {
	    &Log("SmtpMCIDeliver::HOST->$HOSTS[0]") if $debug_smtp;
	    my $error = &SmtpIO(*e, *rcpt, *smtp, *files);

	    # If all hosts are down, anyway try $HOST;
	    if ($error) {
		push(@HOSTS, $HOST);
		return $error;
	    }
	}
    }

    0; # O.K.;
}


1;
