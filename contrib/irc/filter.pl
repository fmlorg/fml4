#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("daf:Aht:L:");

if ($opt_h) { &USAGE; exit 0;}

&GetTime;

# flush
$| = 1; 
$SIG{'HUP'} = 'ReadFilterConf';
$SIG{'INT'} = $SIG{'QUIT'} = $SIG{'TERM'} = 'SignalLog';

$FILTER_CONF = $opt_f || &die("Please define -f filter-config");
$LOGFILE     = $opt_L || "$ENV{'PWD'}/filter.log";
$SetProcTitle = $opt_t;

$FILE = shift || &die("Please define logfile\n");
print STDERR "FILE: $FILE\n";
open(F, $FILE) || &die("cannot open $FILE");
seek(F, 0, 2) if !$opt_d; # not test mode

&Log("start");

$0 = "--filter $SetProcTitle";

&ReadFilterConf;

for (;;) {
    if (-f "${FILTER_CONF}.reload") {
	&Log("reload $FILTER_CONF (in loop)");
	&ReadFilterConf;
    }

    $EVAL = qq#
	\$i = 600;
	while (\$i-- > 0) {
	    while (<F>) { 
		$Filter;
	    }
	    select(undef, undef, undef, 1);
	}
    #;

    print STDERR $EVAL if $debug;
    eval($EVAL); 
    &Log($@) if $@;
}

exit 0;


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

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
}


sub ReadPat
{
    local($f, $pat) = @_;

    # modified;
    if ($mtime >= (stat($f))[9]) {
	return $pat;
    }

    # reset
    undef $pat;

    &GetTime;
    print "-- $MailDate log_monitor: reload pattern file\n\t[$f]\n";

    open(IN, $f) || &die("cannot open $f");
    while (<IN>) {
	chop;
	$pat .= $pat ? "|$_" : $_;
    }
    close(IN);

    $mtime = (stat($f))[9];

    $pat;
}


sub ReadFilterConf
{
    &Log("ReadFilterConf: $FILTER_CONF");

    $Filter = "\n";

    open(CONF, $FILTER_CONF) || &die("cannot open $FILTER_CONF");
    while (<CONF>) { $Filter .= "\t$_";}
    close(CONF);
}


sub Log
{
    local($s) = @_;

    if (open(APP, ">> $LOGFILE")) { 
        select(APP); $| = 1; select(STDOUT);
        print APP "$Now [$$] $s\n";
        close(APP);
    }
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

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime = sprintf("%04d%02d%02d%02d%02d", 
                           1900 + $year, $mon + 1, $mday, $hour, $min);
}


sub USAGE 
{
    $x = $0;
    $x =~ s#.*/(.*)#$1#;

    $_ = qq#;
    $x [options];

    -h\t\tthis message;
    -d\t\tdebug mode;

    -f file\tfilter config file (perl script);
    -L logfile\tlogfile;

    -a\t\tshow all in a day (default is \"tail -f\" mode);
    -A\t\tshow all in the current /var/log/messages;
    -t\t\ttest mode;
    ;
    #;

    s/;//g;
    print "$_\n";
}


sub die
{
    local($s) = @_;
    &Log($s);
    die($s);
}


sub SignalLog 
{ 
    local($sig) = @_; 
    &Log("Caught SIG$sig, shutting down");
    sleep 1;
    exit(1);
}


1;
