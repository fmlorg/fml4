#!/usr/local/bin/perl
#
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

# For the insecure command actions
$ENV{'PATH'}  = '/bin:/usr/ucb:/usr/bin';	# or whatever you need
$ENV{'SHELL'} = '/bin/sh' if $ENV{'SHELL'} ne '';
$ENV{'IFS'}   = '' if $ENV{'IFS'} ne '';

#################### MAIN ####################
require 'sys/socket.ph';
require 'getopts.pl';
&Getopts("f:");

# a little configuration before the action
umask (077);			# rw-------

&InitConfig;			# initialize date etc..

$pat  = $STRUCT_SOCKADDR || 'n n a4 x8';
$inet = 2;
$port = 2345;
$host = 'axion.phys.titech.ac.jp';

# DNS. $HOST is global variable
# it seems gethostbyname does not work if the parameter is dirty?
($name,$aliases,$addrtype,$length,$addrs) = gethostbyname($host);

$this = pack($pat, &AF_INET, $port, $addrs);

select(S); $| = 1; select(STDOUT);

if (socket(S,2,1,6)) { print STDERR "socket ok\n";} else { die $!; }
if (connect(S,$this)){ print STDERR "connect ok\n";}   else { die $!; }

do { $_ = <S>; print STDERR "$_";} while(/^\d\d\d\-/o);

while(<>) {
    print STDERR $_;
    print S $_;
    do { $_ = <S>; print STDERR "$_";} while(/^\d\d\d\-/o);

    if(/^354/oi) {
      in: while(<S>) { 
	  if(/^FILE:(\S+)/) {
	      &CloseStream();
	      &OpenStream($1);
	      next in;
	  }elsif(/^250/oi) {
	      &CloseStream();
	      last in;
	  }

	  print FILE $_;
      }#in;
    }#354;
}

exit 0;				# the main ends.
#################### MAIN ENDS ####################

##### SubRoutines #####

sub GetTime
{
    @WDay = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    @Month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
	      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];
    $Now = sprintf("%02d/%02d/%02d %02d:%02d:%02d", 
		   ($year % 100), $mon + 1, $mday, $hour, $min, $sec);
    $MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", 
			$WDay[$wday], $mday, $Month[$mon], 
			1900 + $year, $hour, $min, $sec, $TZone);

    # /usr/src/sendmail/src/envelop.c
    #     (void) sprintf(tbuf, "%04d%02d%02d%02d%02d", tm->tm_year + 1900,
    #                     tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
    # 
    $CurrentTime  = sprintf("%04d%02d%02d%02d%02d", 
			   1900 + $year, $mon + 1, $mday, $hour, $min);
    $PCurrentTime = sprintf("%04d%02d%02d%02d%02d%02d", 
			    1900 + $year, $mon + 1, $mday, $hour, $min, $sec);
}


sub InitConfig
{
    # moved from Distribute and codes are added to check log files
    # Initialize the ML server, spool and log files.  
    if(!-d $SPOOL_DIR)     { mkdir($SPOOL_DIR,0700);}
    $TMP_DIR = $TMP_DIR ? $TMP_DIR : "$DIR/tmp"; # backward compatible
    if(!-d $TMP_DIR)       { mkdir($TMP_DIR,0700);}
    for($ACTIVE_LIST, $LOGFILE, $MEMBER_LIST, $MGET_LOGFILE, 
	$SEQUENCE_FILE, $SUMMARY_FILE) {
	if(!-f $_) { 
	    open(TOUCH,"> $_"); close(TOUCH);
	}
    }

    &GetTime;
}

# Alias but delete \015 and \012 for seedmail return values
sub Log { 
    local($str, $s) = @_;
    $str =~ s/\015\012$//;
    &Logging($str);
    &Logging("   ERROR: $s", 1) if $s;
}

# Logging(String as message)
# $errf(FLAG) for ERROR
sub Logging
{
    local($str, $e) = @_;

    &GetTime;

    open(LOGFILE, ">> $LOGFILE");
    print LOGFILE "$Now $str ". ((!$e)? "($From_address)\n": "\n");
    close(LOGFILE);
}

sub OpenStream
{
    local($f) = @_;

    print STDERR "Get $f \n";

    open(FILE, "> $f") || return 0;
    return 1;
}

sub CloseStream
{
    close(FILE);
}

1;
