#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

# getopt()
require 'getopts.pl';
&Getopts("dhar");

##################################################
if ($opt_r) {
    @AR = ("reject",
	   "auto_regist", 
	   "auto_symmetric_regist",
	   "auto_asymmetric_regist");
}
else {
    @AR = ("reject",
	   "auto_symmetric_regist",
	   "auto_regist", 
	   "auto_asymmetric_regist");
}

@NOT_AR = ("reject", "ignore");

$format  = "%8s %20s %20s | %3s %3s | %3s %3s\n";
$format2 = "%8s %20s %20s | %3s %3s | %3s %3s\n";
##################################################

push(@INC, "../../../kern");
push(@INC, "../../../proc");

require "libkern.pl";

print "\n\tReturn Value Matrix of &*AutoRegistP() and &*SeparateListP()\n\n";

printf $format2, "ctladdr", 
    "POST_HANDLER", 
    "COMMAND_HANDLER",
    "NAR", "SL", 
    "AR", 
    "NSL";

print "-" x 70, "\n";
for $ctladdr ("ctladdr", $NULL) {
    print "\n";

    $Envelope{'mode:ctladdr'} = $ctladdr;

    for $handler (@AR) {
	print "\n";

	$REJECT_POST_HANDLER = $handler;

	for $handler (@AR) {
	    $REJECT_COMMAND_HANDLER = $handler;

	    &Show;
	}
    }
}

$opt_a || do { exit 0;};

print "\n";
print "-" x 70, "\n";
for $ctladdr ("ctladdr", $NULL) {
    print "\n";

    $Envelope{'mode:ctladdr'} = $ctladdr;
    for $handler (@NOT_AR) {
	print "\n";

	$REJECT_POST_HANDLER = $handler;

	for $handler (@NOT_AR) {

	    $REJECT_COMMAND_HANDLER = $handler;
	    &Show;
	}
    }
}


print "\n";
exit 0;


sub Show
{
    return if $REJECT_POST_HANDLER eq 'auto_asymmetric_regist';

    if ($REJECT_POST_HANDLER =~ /auto\S+regist/ &&
	 $REJECT_COMMAND_HANDLER eq 'auto_asymmetric_regist') {
	return;
    }

    $rch = $REJECT_COMMAND_HANDLER;
    $rph = $REJECT_POST_HANDLER;

    $rch =~ s/auto_/AR /;
    $rph =~ s/auto_/AR /;
    $rch =~ s/regist//;
    $rph =~ s/regist//;
    $rch =~ s/_$//;
    $rph =~ s/_$//;

    printf $format,
    $ctladdr, 
    $rph,
    $rch,
    (&NonAutoRegistrableP ? 'o ' : ''),
    (&UseSeparateListP    ? 'o ' : ''),
    (&AutoRegistrableP    ? 'o ' : ''),
    (&NotUseSeparateListP ? 'o ' : '');
}
