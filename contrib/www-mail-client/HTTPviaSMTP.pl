#!/usr/local/bin/perl

$HOME 		= $ENV{'HOME'};
$WWWMAILDIR 	= $ENV{'WWWMAILDIR'} ? $ENV{'WWWMAILDIR'} : "$HOME/WWW_MAIL";
$SEQUENCE_FILE 	= "$WWWMAILDIR/seq";
$HTML  		= "$WWWMAILDIR/Elena.html";
$WHERE 		= "$WWWMAILDIR/dir";
$MBOX		= "$WWWMAILDIR/mbox";

# flock system call
$LOCK_SH 	= 1;
$LOCK_EX 	= 2;
$LOCK_NB 	= 4;
$LOCK_UN 	= 8;

$CURRENT_HTTP = $ARGV[0];

require 'sys/socket.ph';

local($pat)  = $STRUCT_SOCKADDR || 'n n a4 x8';
local($name,$aliases,$addrtype,$length,$addrs) = 
    gethostbyname("localhost");

# default port
$port = 8080 unless defined($port); 
$this = pack($pat, &AF_INET, $port, $addrs);
select(NS); $| = 1; select(stdout);

if (socket(S,2,1,6)) { print "socket ok\n"; } else { die $!; }
if (bind(S,$this)) { print "bind ok\n"; } else { die $!; }
if (listen(S,5)) { print "listen ok\n"; } else { die $!; }
for (;;) {
    $, = ' ';
    print "Listening again\n";

    if ($addr = accept(NS,S)) { print "accept ok\n"; } else { die $!; }

    print STDERR "=>",unpack($pat, $addr), "<=\n";

    while(<NS>) { 
#	print $_;
	if(/^GET\s*(.*)\s*HTT/) {
	    $COM = $1;
#	    print "$CURRENT_HTTP/$1\n";
	    print "$1\n";
	}
    }

}

exit 0;



sub talkHttp # ($host, $headers, $body)
{
    local($host, $port, $body, $tp) = @_;
    local($pat)  = 'S n a4 x8';
    local($ANSWER);

    # check variables
    $HOST = $host ? $host : 'localhost';

    # DNS. $HOST is global variable
    # it seems gethostbyname does not work if the parameter is dirty?
    local($name,$aliases,$addrtype,$length,$addrs) = 
	gethostbyname($HOST ? $HOST : $host);

    $port = 80 unless defined($port); # default port
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, 6) && connect(S, $target)) {
	select(S); $| = 1; select(stdout); # need flush of sockect <S>;
	if( $tp =~ /http/io) {
	    print S "GET $body\n";
	}else {
	    print S "$body\n";
	}
	while(<S>) { $ANSWER .= $_;}
	close S;
	return $ANSWER;
    } else { &Logging("Cannot connect $host");}
}

exit 0;

sub GetID
{
    # Get the present ID
    open(IDINC, "< $SEQUENCE_FILE") || die("cannot open $SEQUENCE_FILE");
    $ID = <IDINC>;		# get
    $ID++;			# increment
    close(IDINC);		# more safely
    
    return $ID;
}

sub ResetID
{
    # Get the present ID
    open(IDINC, "> $SEQUENCE_FILE") || die("cannot open $SEQUENCE_FILE");
    print IDINC $ID. "\n";
    close(IDINC);		# more safely
}

sub Daemon
{
    while(1) {
	sleep(60);
	open(LOCK, $MBOX);
	flock(LOCK, $LOCK_EX);

	if(-s $MBOX) {		# non zero
	    local($NEW) = 1;

	    open(MBOX) ;
	    while(<MBOX>) {
		if(/^REQUEST:/ .. /\/REQUEST/) { 
		    if($NEW) {
			$ID = &GetID;
			open(OUT, "> $WWWMAILDIR/$ID");
			$NEW = 0;
			&ResetID;
		    }
		    print OUT $_; 
		}
	    }

	    system "cp $WWWMAILDIR/$ID $WWWMAILDIR/html" unless $NEW;
	    close(OUT) unless $NEW;
	}# IF NON ZERO;

	close(LOCK);
	flock(LOCK, $LOCK_UN);
    }# END OF WHILE;
}

sub MailURL
{
    local($which) = @_;

    $NO_SHOW = 1;
    &ShowPage(20, 100);
    $HTTP = &GetHTTP;
    local($URL) = $URL{$which};

    print "Mail Request URL:";

    if($URL =~ /http:/oi || 
       $URL =~ /gopher:/oi ||
       $URL =~ /ftp:/oi  ||
       $URL =~ /wais:/oi  ) { 
	print $URL;
    } else {
	print "$HTTP/".$URL;	
    }

    print "\n";
}

sub GetHTTP
{
    open(HTML, "< $WHERE");
    $HTTP = <HTML>;
    chop $HTTP;
    close(HTML);

    return $HTTP;
}


sub Show
{
    local($BEGIN, $END) = @_;

    open(HTML, "< $HTML");
    while(<HTML>) {
	if($BEGIN <= $. && $. < $END) { 
	    print $_;
	}
    }
    close(HTML);
}

sub ShowPage
{
    local($ROWS, $WHICH) = @_;

    local($BEGIN) = $ROWS * ($WHICH - 1);
    local($END)   = $ROWS * ($WHICH);

    local($UL, $HREF, $URL);

    open(HTML, "< $HTML");
    while(<HTML>) { 
	s/  / /g;
	s/กว/'/g;
	next if /^$/;
	$ON = 1 if (/<A\s/oi);
	$ON = 0 if (/<\/A>/oi);

	if($ON) {
	    chop;
	    $STRING .= $_;
	    next;
	}
	$STRING .= $_;
    }
    close(HTML);

    $count = 0;

    line: foreach (split(/\n/, $STRING, 9999)) {
#	print ">>>$_\n";
	$URL = "";
	
	# cut the first spaces
	s/\s*(.*)/$1/;
	
	# UL 
	if(/<UL>/oi)   { $UL++;}
	if(/<\/UL>/oi) { $UL--;}
	local($i) = $UL;

	# get HREF
	if(/<A\s+HREF\s*=\s*(.*)>(.*)<\/A>/oi) { 
	    $HREF++;
	    $URL = $1;
	    $URL{$HREF} = $URL;
	    print "$HREF $URL\n" if $debug;
	    $_ = $2;
	}

	s/<P>//g;
	s/<.*>//g;
	next line if /^\s+$/o;
	next line if $NO_SHOW;
	$count++;

	# main output
	if($BEGIN <= $count && $count < $END) { 
	    while($i-- > 0) { print "\t";}
	    if($URL) {
		# s/\s*(.*)/$1/;
		print "$HREF\t$_\n";
	    } else {
		print "$_\n";
	    }
	}
    }

    close(HTML);
}
