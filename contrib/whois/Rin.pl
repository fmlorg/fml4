#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$


$FILE      = "/home/axion/fukachan/work/spool/EXP/contrib/whois/whoisdb";
$LOGFILE   = "/home/axion/fukachan/work/spool/EXP/contrib/whois/log";
$HELP_FILE = "/home/axion/fukachan/work/spool/EXP/contrib/whois/help";
$USAGE = "Whois Server($rcsid): USAGE\n";

&InitConfig;

if(open(HELP_FILE)) {
    while(<HELP_FILE>) { $USAGE .= $_;}
    close(HELP_FILE);
} else {
    &Logging("Cannot open help file");
    print "Sorry\nCannot open help file\nCannot exec\n";
};

# Generate the key
$Key = <>; chop $Key; chop $Key;
if ($Key =~ /help/oi || (! $Key) ) {
    &Logging("Help");
    print $USAGE;
    exit 0;
}
elsif (&MetaCharP($Key)) {
    &Logging("Help for metachars");
    print ('*' x 40);
    print "\n";
    print "NOT PERMIT META CHARACTERS\n";
    print ('*' x 40);
    print "\n\n";
    print $USAGE;
    exit 0;
}
else {
    $DOMAIN_SEARCH  = 1 if($Key =~ /^\@/oi);
    $ML_LIST_SEARCH = 1 
	if($Key =~ /^mailinglist/oi || $Key =~ /^mailing-list/oi);
    $WHEN_SEARCH = 1 if($Key =~ /^when/oi);
}


# FIX
$Key =~ s/^\s*(.*)\s*$/$1/;


$EXEC = q#
    $Key =~ s/\*/\\\*/g;
    foreach (keys %addr) {
	if(/$Key/io) {
	    print $addr{$_};
	    next if $DOMAIN_SEARCH;
	}else {
	    $_ = $addr{$_};
	    print $_ if /$Key/io;
	}
    }
#;

##### MAIN #####

if(open(FILE)) {
    $/ = ".\n\n";
    foreach (<FILE>) {
	chop;	chop;	chop;
	($from) = (/^(.*)\n/);
	next if $from =~ /^$/o;
	if(/X-MailingList/io) {	$ML{$from}   = $_; next;} 
	if(/X-When/io)        { $When{$from} = $_; next;} 
	$addr{$from} = $_;
    }

    &Logging($Key);

    if($ML_LIST_SEARCH) {
	foreach (keys %ML) { print $ML{$_}; print "\n---\n";}
    } elsif( $WHEN_SEARCH) {
	foreach (keys %When) { print $When{$_}; print "\n---\n";}
    } elsif($Key =~ /all/oi) {
	foreach (keys %addr) { print $addr{$_}; print "\n---\n";}
    }else {
	eval $EXEC;
	&Logging($@) if $@;
    }
    close(FILE);
} else {
    print "Sorry!\nCannot exec well\nPlease contact the admin\n.";
}

exit 0;

##### LIBRARIES #####

sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0700);}
    for($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	$SEQUENCE_FILE, $SUMMARY_FILE) {
	if(!-f $_) { open(TOUCH,"> $_"); close(TOUCH);}
    }

    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
			$mday, $Month[$mon], $year, $hour, $min, $sec, $TZone);
}


# Logging(String as message)
sub Logging
{
    open(LOGFILE, ">> $LOGFILE");
    printf LOGFILE "$Now ".@_." ($clientaddr)\n";
    close(LOGFILE);
}

# Check the string contains Shell Meta Characters
# return 1 if match
sub MetaCharP
{
    local($r) = @_;

    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Logging("Match: $r -> $`($&)$'");
	return 1;
    }

    0;
}

1;
