#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 2000 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#

$EXEC_DIR = $0; $EXEC_DIR =~ s@bin/.*@@;
push(@INC, $EXEC_DIR);
push(@INC, $ENV{'PWD'});

# getopt()
require 'getopts.pl';
&Getopts("dhv");

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
    local($article);

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

    if (-f "$SPOOL_DIR/$id") {
	$article = "$SPOOL_DIR/$id";
    }

    system "cat $article | sendmail $addr";
}



### Section: input

sub InitTTY
{
    if (-e "/dev/tty") { $console = "/dev/tty";}

    open(IN, "<$console") || open(IN,  "<&STDIN"); # so we don't dingle stdin
    open(OUT,">$console") || open(OUT, ">&STDOUT");# so we don't dongle stdout
    select(OUT); $| = 1; #select(STDOUT); $| = 1;
}


sub gets
{
    local($.);
    $_ = <IN>;
}


sub GetString
{
    local($s);

    $s = &gets;

    # ^D
    if ($s eq "")  { print STDERR "'^D' Trapped.\n"; exit 0;}
    chop $s;

    $s;
}


1;
