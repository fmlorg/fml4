#!/usr/local/bin/perl
#
# $FML: fml_version.pl,v 1.19 2001/04/05 12:06:01 fukachan Exp $
#

require 'getopts.pl';
&Getopts("iqtsp:L:X:Tm:b:Nr");

$FML           = $opt_X || $ENV{'FML'};
$TRUNK_ID      = "$FML/conf/release";
$RELEASE_ID    = "$FML/conf/release_version";
$STATUS        = "$FML/conf/status";
$RELEASE_DATE  = "$FML/var/tmp/release_date";
$SHOW_ID       = $opt_s;
$RCSID_FNAME   = $opt_r;
$query         = $opt_q;
$patchlevel    = $opt_p;
$Label         = $opt_L;
$MODE          = $opt_m;
$BRANCH        = $opt_b;

if (! -f $RELEASE_DATE) {
	system "date > $RELEASE_DATE";
}

&StoreTime if $opt_t;

&GetTime;
$Year     = 1900 + $year;

chop($Trunk = `cat $TRUNK_ID`);
chop($Branch = `cat "$FML/conf/branch" `);
if ($Branch eq 'stable') {
    $Branch =~ tr/a-z/A-Z/;
}
else {
    undef $Branch;
}

if ($opt_T) {
    chop($_ = `cat $TRUNK_ID`);
    print $_, "\n";
    exit 0;
}

if ($Label) {
	$ID = $Label;
}
else {
	($ID, $PL) = &GetID;

	if ($opt_i) { # initialize;
	    print STDERR "@ARGV INCREMENT: $PL -> ";
	    $PL++; # $PL = &PLIncrement($PL);
	    print STDERR "$PL\n";
	} 
}

$MailDate = &GetDate;

$PL = "${PL}pl$patchlevel" if $patchlevel;

$DailyID = $BRANCH. " ". &YYYYMMDD;

# 3.0B new id system
if ($opt_N || $RCSID_FNAME) {
    $ID = $Trunk . " ". $Branch;
    $PL = " (". &__YYYYMMDD .")";
}

if ($SHOW_ID || $RCSID_FNAME) {
   if ($MODE eq 'daily') {
       print "fml $DailyID\n";
   }
   else {
       if ($RCSID_FNAME) {
	   $PL =~ s/[\s\(\)]//g;
	   print $PL, "\n";
       }
       else {
	   print "fml $ID$PL\n";
       }
   }
   exit 0;
}

while (<>) {
    if (/^\$Rcsid.*=\s+[\'\"](\S+)/) {
	$prog = $1;	# reset;
	
	if ($query) {
	    #print "fml $ID$PL \#: ${MailDate}JST $Year\n";
	    print "fml $ID$PL \#:\n";
	    last;
	}

	if ($MODE eq 'daily') {
		print STDERR "Replaced -> '$prog [fml $DailyID]';\n";
		print "\$Rcsid   = '$prog [fml $DailyID]';\n";
	}
	else {
		print STDERR "Replaced -> '$prog [fml $ID$PL]';\n";
		print "\$Rcsid   = '$prog [fml $ID$PL]';\n";
	}

	next;
    }

    print $_ unless $query;
}

&StoreID if $opt_i;

exit 0;

sub GetID
{
    return ($NULL, $NULL) if $opt_N;

    open(F, $RELEASE_ID) || die("cannot open $RELEASE_ID :$!");
    chop($ID = <F>);
    $ID =~ s/\s*//g;

    print STDERR "GetID: $ID =>\t";

    if ($ID =~ /([\d\._]+[A-Z]\#)(\d+)$/) {
	$ID = $1;
	$PL = $2;
    }
    elsif ($ID =~ /([\d\._]+[\#\w\.]+\#)(\d+)$/) {
	$ID = $1;
	$PL = $2;
    }
    elsif ($ID =~ /([\d\.]+)/) {
	$ID = $1;
	$PL = "";
    }

    print STDERR "<$ID $PL>\n";
    ($ID, $PL);
}


sub GetDate
{
    open(F, $RELEASE_DATE) || die("cannot open $RELEASE_DATE :$!");
    chop($DATE = <F>);
    $DATE;
}


sub PLIncrement
{
    local($PL) = @_;

    for (A..ZZ) {
	if ($PL eq $_) { $match++; next;}
	next unless $match;
	return ($PL = $_);
    }
}


sub StoreID
{
    open(F, "> $RELEASE_ID") || die("cannot open $RELEASE_ID :$!");
    select(F); $| = 1; select(STDOUT);
    print F "$ID$PL", "\n";
    close(F);
    print STDERR "ID incremented -> $ID$PL\n";
}


sub StoreTime
{
    &GetTime;
    open(F, "> $RELEASE_DATE") || die("cannot open $RELEASE_DATE :$!");
    select(F); $| = 1; select(STDOUT);
    print F "$MailDate\n";
    close(F);
    print STDERR "Set the present time to $MailDate\n\tin $RELEASE_DATE\n";
}

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   $year % 100, $mon + 1, $mday, $hour, $min, $sec);

    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);


### OVERWRITE ###

    $MailDate = sprintf("%s %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $Month[$mon], $mday, 
			$hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}


# return YYYYMMDD at Greenwich standard timezone (tricky:-)
sub YYYYMMDD
{
    local($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime(time);
    sprintf("%4d%02d%02d.%02d%02d",
		$year + 1900, $mon + 1, $mday,
		$hour, 0);
}


# return YYYYMMDD at Greenwich standard timezone (tricky:-)
sub __YYYYMMDD
{
    local($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime(time);

    my $status = '';
    if (-f $STATUS) {
	chop($status = `cat $STATUS`);
	$status = "/$status";
    }
    sprintf("%4d%02d%02d%s",
		$year + 1900, $mon + 1, $mday, $status);
}


1;
