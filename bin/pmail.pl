#!/usr/local/bin/perl
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && "$1[$2]");
$rcsid  .= '(1.6beta)';


@ARGV || die(&USAGE);
require 'getopts.pl';		# Getopt
&Getopts('s:f:hv8');
die(&USAGE) if $opt_h;

# variables
$DIR        = $ENV{'PWD'};
$e{'mci:mailer'} = 'ipc';

$user  = (split(/:/, getpwuid($<), 999))[0];
$domain = &domain || 'phys.titech.ac.jp';
eval "$machine = `hostname`;";

# default
$debug = 1;


# From
$MAINTAINER = "$user\@".($machine ? "$machine.$domain" : $domain);
$from = $opt_f || $MAINTAINER;

# To and SMTP
foreach (@ARGV) {
    $to .= $to ? ", $_" : $_;
    push(@Rcpt, "RCPT TO: $_");
}



##### MAIN #####
require 'libsmtp.pl';

# Header
$e{'Hdr'} .= "Return-Path: $MAINTAINER\n";
$e{'Hdr'} .= "From: $from\n";
$e{'Hdr'} .= "Subject: $opt_s\n";
$e{'Hdr'} .= "To: $to\n";
$e{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;

# Get Body
while(<STDIN>) { $e{'Body'} .= $_;}

### Smtp
if ($opt_v) {
    $\ = "\n";
    $, = "\n";

    print STDERR "In verbose mode, not connect smtp port";
    print STDERR "*** Recipients ***:";
    print STDERR @Rcpt;
    print STDERR "*** *e ***:";
    while(($k, $v) = each %e) {
	$v =~ s/\n/\n\t/g;
	print '-' x 30;
	printf "%s =>\n%s\n", $k, $v;
    }
}
else {
    &Smtp(*e, *Rcpt);
}

exit 0;
##############################


###### Library
# Alias but delete \015 and \012 for seedmail return values
sub Log { 
    local($str) = @_;
    $str =~ s/\015\012$//;

    print STDERR ">>> $str\n";
}

sub domain
{
    if (! $domain) {
	$domain = (gethostbyname('localhost'))[1];
	($domain)    = ($domain =~ /(\S+)\.$/i) if $domain =~ /\.$/i;
	($domain)    = ($domain =~ /localhost\.(\S+)/i); 
    }

    $domain;
}

sub USAGE
{
q#
$0 address(waiting STDIN INPUT)
Options
\t-s subject
\t-v verbose
\t-f UNIX from
\t-h this help
#;
}

1;
