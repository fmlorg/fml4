#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

eval(' chop ($PWD = `pwd`); ');
$PWD = $ENV{'PWD'} || $PWD || '.'; # '.' is the last resort;)
$EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
push(@INC, $EXEC_DIR);
push(@INC, $PWD) if -d $PWD;

# getopt()
require 'getopts.pl';
&Getopts("dhvD:");
$DIR = $opt_D || die("ERROR: require -D \$DIR\n");

$opt_h && &Usage;

$debug = $opt_d ? 1 : 0;

eval($uname = `uname`);
$uname || die("This program runs only on unix.\n");

require 'libloadconfig.pl'; &__LoadConfiguration;
if (-f "config.ph") { require 'config.ph';}

&Resend(@ARGV);

exit 0;

sub Usage
{
    $_ = qq#Usage: $0 [-dh] [ID] [RCPT];

    [options];

    -d debug;
    -h this help;

    ID     article number/ID;
    RCPT   Receiver Email Address
    #;

    s/;//g;
    print STDERR $_, "\n";
    exit 0;
}


sub Resend
{
    local($id, $addr) = @_;
    my ($article);

    &InitTTY;

    while (! $id) {
	print "Article ID: ";
	$id = &GetString;
	print "\n";
    }

    while (! $addr) {
	print "address: ";
	$addr = &GetString;
	print "\n";
    }

    if (-f "$DIR/$SPOOL_DIR/$id") {
	$article = "$DIR/$SPOOL_DIR/$id";
    }

    if (-f $article) {
	if (open($article, $article)) {
	    if (open(SENDMAIL, "|sendmail $addr")) {
		select(SENDMAIL); $| = 1; select(STDOUT);
		while (<$article>) {
		    print SENDMAIL $_;
		}
		close(SENDMAIL);
	    }
	    else {
		&Log("ERROR: cannot exec sendmail $addr");
	    }

	    close($article);
	}
	else {
	    &Log("ERROR: cannot open article $article");
	}
    }
    else {
	&Log("ERROR: cannot find article $article");
    }
}



### Section: input

sub InitTTY
{
    if (-e "/dev/tty") { $console = "/dev/tty";}

    open(IN, "<$console") || open(IN,  "<&STDIN"); # so we don't dingle stdin
    open(OUT,">$console") || open(OUT, ">&STDOUT");# so we don't dongle stdout
    select(OUT); $| = 1; #select(STDOUT); $| = 1;
}


sub _GetS
{
    local($.);
    $_ = <IN>;
}


sub GetString
{
    local($s);

    $s = &_GetS;

    # ^D
    if ($s eq "")  { print STDERR "'^D' Trapped.\n"; exit 0;}
    chop $s;

    $s;
}

sub Log
{
    print STDERR @_, "\n";
}

1;
