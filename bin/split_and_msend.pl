#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");

$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

# "Directory of Mailing List(where is config.ph)" and "Library-Paths"
# format: fml.pl [-options] DIR(for config.ph) [PERLLIB's -options]
# Now for the exist-check (DIR, LIBDIR), "free order is available"
foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
}
$DIR    = $DIR    || '/home/axion/fukachan/work/spool/EXP';
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);

#################### MAIN ####################
# including libraries
require 'libkern.pl';

require 'config.ph';		# configuration file for each ML
eval("require 'sitedef.ph';");  # common defs over ML's
&use('smtp');			# a library using smtp

chdir $DIR || die "Can't chdir to $DIR\n";

&InitConfig;			# initialize date etc..
&Init;

&Lock;				# Lock!

$START_HOOK && &eval($START_HOOK, 'Start hook'); # additional before action

&SplitAndMSend;			# Mail MatomeOkuri file

&Unlock;			# UnLock!

&RunHooks;			# run hooks after unlocking

&Notify if $Envelope{'message'} || $Envelope{'error'};
				# some report or error message if needed.
				# should be here for e.g., mget, ...

exit 0;



sub Init
{
    $From_address = "split_and_msend";
}


sub SplitAndMSend
{
    $0 = "--Matomete Sending <$FML $LOCKFILE>";

    local($to, $file, $Status, $lines, $mlist);
    local($i, $mode, $subject, $sleep, $tmpbase);
    local(@to, $mlist); 
    
    ### 
    $file = $_cf{"opt:f"} || die ("Please define -f file-to-send");
    print STDERR "FILE: $file\n" if $debug;

    if (! -f $file) { &Log("Not exist such a file:$file"); return;}

    ### the numer of the lines of matome okuri file
    open(F, $file) || (&Log("MSend R1:$!"), return);
    while (<F>) { $lines++;} 
    close(F);

    # if no spooled, do nothing.
    if (0 == $lines) { &Log("No spooled mail to send"); return;}

    # the member list
    $mlist = $ML_MEMBER_CHECK ? ACTIVE_LIST : $MEMBER_LIST;
    &GetMember(*to, *mlist);
    if (! @to) { &Log("MSend R1: No member to send"); return;}

    &use('fop');

    ### Variables
    $mode    = 'uf';
    $subject = "Matome Okuri $ML_FN";
    $sleep   = $SLEEPTIME || 30;
    $tmpbase = "$TMP_DIR/split_and_msend$$";

    $i = &SplitUnixFromFile($file, $tmpbase);
    &SendingBackInOrder($tmpbase, $i, $subject, $sleep, @to);

    ### reset
    truncate($file, 0);	# truncate is BSD only;
}


sub SplitUnixFromFile
{
    local($file, $tmpbase) = @_;
    local($i, $buflines, $buf);

    $i = 1;			# 1 not 0;

    open(F, $file) || (&Log("MSend R1:$!"), return);
    open(OUT, "> $tmpbase.$i") || (&Log("MSend R1:$!"), return);
    select(OUT); $| = 1; select(STDOUT);

    $MAIL_LENGTH_LIMIT = $MAIL_LENGTH_LIMIT || 1000;

    while (<F>) { 
	if ($buflines > $MAIL_LENGTH_LIMIT) {
	    close(OUT);
	    $i++;
	    open(OUT, "> $tmpbase.$i") || (&Log("MSend R1:$!"), return);
	    undef $buflines;
	}

	if (/^From\s+$MAINTAINER/i && $buf) {
	    print OUT $buf;
	    undef $buf;
	}

	$buf .= $_;
	$buflines++;
    }

    close(OUT);
    close(F);

    $i;
}

sub GetMember
{
    local(*to, *list) = @_;

    open(LIST, $list) || (&Log("MSend R1:$!"), return);

    # Get a member list to deliver
    # After 1.3.2, inline-code is modified for further extentions.
  line: while (<LIST>) {
      chop;

      # pre-processing
      /^\s*(.*)\s*\#.*/o && ($_ = $1);# strip comment, not \S+ for mx
      next line if /^\#/o;	# skip comment and off member
      next line if /^\s*$/o;	# skip null line
      next line if /^$MAIL_LIST$/io; # no loop back
      next line if $CONTROL_ADDRESS && /^$CONTROL_ADDRESS$/io;

      # Backward Compatibility.	tricky "^\s".Code above need no /^\#/o;
      s/\smatome\s+(\S+)/ m=$1 /i;
      s/\sskip\s*/ s=skip /i;
      local($rcpt, $opt) = split(/\s+/, $_, 2);
      $opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

      printf STDERR "%-30s %s\n", $rcpt, $opt if $debug;
      next line unless $opt =~ /\s[ms]=/i;	# tricky "^\s";

      print STDERR "push(\@to, $rcpt)\n\n" if $debug;
      push(@to, $rcpt);
      $num_rcpt++;
  }

    close(ACTIVE_LIST);
    $num_rcpt;
}


### :include: -> libkern.pl
# Getopt
sub Opt { push(@SetOpts, @_);}

1;
