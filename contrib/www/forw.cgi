#!/usr/local/bin/perl
#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)
#

# RCS
$rcsid   = q$Id$;
$rcsid   =~ s/,v//;
$rcsid   =~ s/Id: (.*)\s+Exp\s+\S+/$1/;



##### variables to customize #####

$WWW_ADMIN = "www-admin\@sapporo.iij.ad.jp";
$RCPT_ADDR = 'questionnaire\@sapporo.iij.ad.jp';
$SENDMAIL  = 'sendmail';
$ADD_PATH  = ":/usr/sbin:/usr/lib:/usr/local/bin:/usr/contrib/bin";
$SUBJECT   = "questionnaire of www.sapporo.iij.ad.jp";

@SKIP_FIELDS = ('submit-p');
@SKIP_ENV    = ('HTTP_ACCEPT', 'HTTP_ACCEPT_ENCODING',
		SCRIPT_FILENAME, DOCUMENT_ROOT, PATH, SCRIPT_NAME, 
		SERVER_ADMIN, SERVER_SOFTWARE, HTTP_MIME_VERSION, 
		SERVER_PORT, SERVER_PROTOCOL, HTTP_REFERER, 
		SERVER_NAME, REQUEST_METHOD, SCRIPT_NAME);

$REPLY_MESSAGE = "\nYour message has been Sent.\nThanks in advance.\n\n";

$DNS_SPOOF_CHECK = 1;

##### variables to customize ENDS #####



########## Configure ##########
# sendmail
$SENDMAIL = &search_path($SENDMAIL);

# Hmm... O.K. like this?
$ENV{'PATH'} .= $ADD_PATH;

# Get Entry
&GetBuffer(*input);

# HTML MODE
print "Content-type: text/plain\n\n";

# Addr-spec check
$addr = $input{'address'};
if ($addr !~ /\S+\@\S+/) { &ErrorMesg; exit 0;}

# Configure field names to skip
for (@SKIP_FIELDS) { $SKIP_FIELDS{$_} = 1;}
for (@SKIP_ENV)    { $SKIP_ENV{$_}    = 1;}


### O.K. Forwarding ###
&Forw;

### REPLY FOR WWW ###
print $REPLY_MESSAGE;

exit 0;



sub Forw
{
    local($from);

    open(S, "|$SENDMAIL $RCPT_ADDR");

    &GetTime;

    $from = $ENV{'HTTP_FROM'} || $WWW_ADMIN;

    print S "From $WWW_ADMIN\n";
    print S "Date: $MailDate\n";
    print S "From: $from\n";
    print S "Subject: $SUBJECT\n";
    print S "X-Forw: $rcsid\n";
    print S "\n";

    # convert for multiple lines 
    # \n => \n\t 
    foreach (sort keys %input) { 
	($k, $v) = ($_, $input{$_});
	next if $SKIP_FIELDS{$k};
	$v =~ s/\n/\n\t/g;
	print S "$k\t$v\n" if $v;
    }

    print S "\n\# end\n\n";
    print S "-" x 60;
    print S "\n\nEnverionment Variables Information (for Server Admin):\n\n";

    if ($DNS_SPOOF_CHECK) {
	print S "DNS Cheking ... \n";

	local($addr, $raddr, $rhost);
	$addr  = $ENV{'REMOTE_ADDR'};
	$rhost = $ENV{'REMOTE_HOST'};
	$raddr = (gethostbyname($rhost))[4];
	$raddr = sprintf("%d.%d.%d.%d", unpack('C4', $raddr));

	if ($addr ne $raddr) {
	    print S "Spoofed DNS \?: $raddr != $rhost\n";
	}
	else {
	    print S "Verified: $raddr == $rhost\n";
	}
    }

    foreach (sort keys %ENV) { 
	($k, $v) = ($_, $ENV{$_});
	next if $SKIP_ENV{$k};
	print S "$k\t$v\n" if $v;
    }

    close(S);
}

sub GetPeerInfo
{
    local($family, $port, $addr) = unpack('S n a4 x8', getpeername(STDIN));
    local($clientaddr) = gethostbyaddr($addr, 2);

    if (! defined($clientaddr)) {
	$clientaddr = sprintf("%d.%d.%d.%d", unpack('C4', $addr));
    }
    $PeerAddr = $clientaddr;
}

sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};

    foreach $dir (split(/:/, $path)) { 
	if (-f "$dir/$f") { return "$dir/$f";}
    }

    "";
}

sub GetBuffer
{
    local(*s) = @_;

    $ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;

    if ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    else {
	$buffer = $ENV{'QUERY_STRING'};
    }

    foreach (split(/&/, $buffer)) {
	($k, $v) = split(/=/, $_);
	$v =~ tr/+/ /;
	$v =~ s/%(..)/pack("C", hex($1))/eg;
	$s{$k} = $v;
    }
}

sub ErrorMesg
{
    print "Your Email Address is incomplete!!!\n";
    print "So, cannot be sent\n\n";
    print ("*" x 60); print "\n";
    print "Please define your Email Address!\n";
    print ("*" x 60); print "\n";
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

1;
