#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("iqtsp:L:");

$RELEASE_ID   = "$ENV{'FML'}/etc/release_version";
$RELEASE_DATE = "$ENV{'FML'}/etc/release_date";
$SHOW_ID      = $opt_s;
$query        = $opt_q;
$patchlevel   = $opt_p;
$Label        = $opt_L;

&StoreTime if $opt_t;

&GetTime;
$Year     = 1900 + $year;

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

if ($SHOW_ID) { 
    print "fml $ID$PL\n"; 
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

	#print "\$Rcsid   = '$prog [fml $ID$PL: ${MailDate}JST $Year]';\n";
	print "\$Rcsid   = '$prog [fml $ID$PL]';\n";

	#print STDERR "Replaced -> '$prog [fml $ID$PL: ${MailDate}JST $Year]';\n";
	print STDERR "Replaced -> '$prog [fml $ID$PL]';\n";

	next;
    }

    print $_ unless $query;
}

&StoreID if $opt_i;

exit 0;

sub GetID
{
    open(F, $RELEASE_ID) || die $!;
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
    open(F, $RELEASE_DATE) || die $!;
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
    open(F, "> $RELEASE_ID") || die $!;
    select(F); $| = 1; select(STDOUT);
    print F "$ID$PL", "\n";
    close(F);
    print STDERR "ID incremented -> $ID$PL\n";
}


sub StoreTime
{
    &GetTime;
    open(F, "> $RELEASE_DATE") || die $!;
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
    $Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", 
		   $year, $mon + 1, $mday, $hour, $min, $sec);

    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			$year, $hour, $min, $sec, $TZone);


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


1;
