#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


require 'getopts.pl';
&Getopts("c:d:hia");

$opt_h && (&fc_diag, exit 0);

foreach (@ARGV) { 
    /^\-/   && &Opt($_) || push(@INC, $_);
    $LIBDIR || ($DIR  && -d $_ && ($LIBDIR = $_));
    $DIR    || (-d $_ && ($DIR = $_));
    -d $_ || push(@InputCommand, $_);
}
$DIR    = $DIR || $opt_d || $ENV{'PWD'} || die "\$DIR is not Defined, EXIT!\n";
$LIBDIR	= $LIBDIR || $DIR;
unshift(@INC, $DIR);

chdir $DIR || die "cannot chdir $DIR\n";

&InitTTY;
&FixINC;
&InitFC; 
&MainFC;
&fc_report;

exit0;


#################### LIBLARIES ####################


sub FixINC
{
    push(@INC, ".");
    push(@INC, "./proc");
}

sub MainFC
{
    eval &OverwriteLibraries;

    if ($$InteractiveMode) {
	&Interactive;
    }
    else {
	$ENABLE = $opt_a ? 1: 0;
	
	if ($ENABLE) { print "ADMIN MODE (# admin ...)\n";}
	
	$cmd = join(" ", @InputCommand);
	$cmd = $ENABLE ? "admin $cmd" : $cmd;
	
	print "   INPUT> $cmd\n";
	
	&Command("$cmd\n\n");
    }
}


sub InitTTY
{
    if (-e "/dev/tty") { $console = "/dev/tty";}

    open(IN, "<$console") || open(IN,  "<&STDIN"); # so we don't dingle stdin
    open(OUT,">$console") || open(OUT, ">&STDOUT");# so we don't dongle stdout
    select(OUT); $| = 1; #select(STDOUT); $| = 1;
}


sub InitFC
{
    $HOME         = $ENV{'HOME'};
    $PWD          = $ENV{'PWD'};
    $$InteractiveMode  = 1 if $opt_i;
    $ENABLE       = 0;		# 
    $From_address = "fmlctl";
    $rc_file = $opt_c ? $opt_c : "$HOME/.fmlctlrc";

    print "Fml Control ";
    print "(Interactive Interface)\n" if $$InteractiveMode;
    print "\n";
    print " chdir $DIR\n\n";

    foreach (@INC) {
	if (-f  "$_/config.ph") {
	    print " Loading the configuration [$_/config.ph]\n\n";
	    do "$_/config.ph";
	    last;
	}
    }

    if (-f $rc_file) {
	print " Loading your environment [$HOME/.fmlctlrc]\n\n";
	do  "$HOME/.fmlctlrc";
    }

    print "Setting the Mailing List [$MAIL_LIST], O.K.?\n\n";

    &fc_show_info;

    require "libkern.pl";
    require "libfml.pl";

    &InitConfig;
    $ACTIVE_LIST = $MEMBER_LIST unless $ML_MEMBER_CHECK; # tricky

    $debug = 1;
    $COMMAND_ONLY_SERVER = 1;
    $COMMAND_SYNTAX_EXTENSION = 1;
    $REMOTE_ADMINISTRATION_REQUIRE_PASSWORD = 0;
}

sub Interactive 
{
  CMD: while ((print OUT "  FmlCtl<", $#hist+1, ">$pr "), $cmd = &gets) { 
      if ($cmd eq "")  { exit 0;}

      chop $cmd;

      push(@hist, $cmd) if $cmd;

      if ($cmd =~ /^\!(\d+)$/) { $cmd = $hist[$1]; print " $cmd\n";}
      if ($cmd =~ /^\!(.*)$/)  { system $ENV{'SHELL'},"-c", $1; next CMD;}

      if ($cmd eq "H") { &fc_history; next CMD;}
      if ($cmd eq "h") { &fc_usage;   next CMD;}
      if ($cmd eq "?") { &fc_usage;   next CMD;}
      
      if ($cmd =~ /^\s*p (.*)/) { eval "print \"$1\\n\";"; next CMD;}
      if ($cmd =~ /^\s*e (.*)/) { 
	  print "eval \"$1;\";\n";
	  eval "$1;"; 
	  next CMD;
      }
      if ($cmd =~ /^\s*u (.*)/) { 
	  print "eval \"undef $1;\";\n";
	  eval "undef $1;"; 
	  next CMD;
      }
      if ($cmd eq "q") { last CMD;   next CMD;}
      
      next CMD if $cmd =~ /^\S$/;
      next CMD if $cmd =~ /^\s*$/;
    
      $cmd = $ENABLE ? "admin $cmd" : $cmd;
      print "   INPUT> $cmd\n";
      &Command($cmd);
      &fc_report;
  }
}

sub fc_diag 
{
    print STDERR "$0 [-c configfile] [-d ML_directory] [-h] [DIR] [LIBDIR]\n";
}

sub fc_report
{
    return unless $Envelope{'message'};

    print "\n########## Log ##########\n";
    print $Envelope{'message'};
    undef $Envelope{'message'};
    print "\n";
}


sub fc_show_info
{
    if ($ENABLE) {
	print " ***************************\n" ;
	print " *** PAY ATTENTION!      ***\n" ;
	print " *** Administration Mode ***\n" ;
	print " ***************************\n" ;
    }
    else {
	print " [[[ COMMAND MODE ]]]\n" ;    
    }

    print "\n";
}

sub gets
{
    local($.);
    $_ = <IN>;
}

sub fc_usage
{
    $_ = q#;
    !number   do the previous action of the number;
    !string   do the string in the shell;
    e         eval string;
              e.g. e $debug = 1;
    h         help;
    H         history;
    p         print the value;
              e.g. p $debug;
    q         quit;
    u         undef the value;
              e.g. u $debug;
    ;#;
    s/;//g;
    s/(\s)TAB/$1   /g;
    s/\n\s+/\n\t/g;
    print "$_\n";
}

sub fc_history
{
    local($i) = 0;
    foreach (@hist) {
	printf("%4d    %s\n", $i, $hist[$i]);
	$i++;
    }
}

1;

sub OverwriteLibraries
{
q#
    sub NeonSendFile
    {
	local(*to, *subject, *files) = @_;
	print "NeonSendFile\n";
	print "@to\n";
	print "@files\n";
    }

sub SendFile 
{
    local($to, $subject, $file, $zcat, @to) = @_;
    open(F, $file) ; 
    while(<F>) { print OUT $_;}
    close(F);
}

sub Sendmail
{
    local($to, $subject, $body, @to) = @_;

    print "To: $to\n";
    print "Subject: $subject\n";
    print "\n";
    print $body;
    print "\n";
}
#;
}

1;
