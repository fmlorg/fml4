# Smtp Relay usling libsmtp.pl
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.



local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


#########################################
### SMTP RELAY ###
###
### Usage:
### open(SENDMAIL, "|smtprelay.pl ") 
###   direct connection to the mail server without fork() in this machine
###   must be better then using open(SENDMAIL, "|/usr/sbin/sendmail ... ");


if ($0 eq __FILE__) {
    $HOST       = 'hikari.sapporo.iij.ad.jp';
    $MAINTAINER = 'fml-admin@sapporo.iij.ad.jp';
$debug++;
    push(@Rcpt, @ARGV);

    $DIR = '/var/tmp/smtprelay';
    $SMTP_LOG = "/dev/stderr";

    -d $DIR || mkdir($DIR, 0755);

    &GetTime;
    &SetDefaults;
    &Parse;
    &Relay(*Envelope);

    exit 0;
}


sub Log { print STDERR @_;}


sub Relay
{
    local(*e) = @_;
    $e{'Hdr'} = $e{'Header'};
    $status = &Smtp(*e, *Rcpt);
    &Log("Smtp:$status") if $status;
}

##############################################


#:include: fml.pl
#:sub SetDefaults GetTime Parse eval
#:~sub
#:replace
sub SetDefaults
{
    $Envelope{'mci:mailer'} = 'ipc'; # use IPC(default)
    $Envelope{'mode:uip'}   = '';    # default UserInterfaceProgram is nil.;
    $Envelope{'mode:req:guide'} = 0; # not member && guide request only

    { # DNS AutoConfigure to set FQDN and DOMAINNAME; 
	local(@n, $hostname, $list);
	chop($hostname = `hostname`); # beth or beth.domain may be possible
	$FQDN = $hostname;
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";
	@n    = split(/\./, $hostname); $hostname = $n[0]; # beth.dom -> beth
	@n    = (gethostbyname($hostname))[0,1]; $list .= " @n ";

	foreach (split(/\s+/, $list)) { /^$hostname\.\w+/ && ($FQDN = $_);}
	$FQDN       =~ s/\.$//; # for e.g. NWS3865
	$DOMAINNAME = $FQDN;
	$DOMAINNAME =~ s/^$hostname\.//;
    }

    # REQUIRED AS DEFAULTS
    %SEVERE_ADDR_CHECK_DOMAINS = ('or.jp', +1, 'ne.jp', +1);
    $REJECT_ADDR = 'root|postmaster|MAILER-DAEMON|msgs|nobody';
    $SKIP_FIELDS = 'Received|Return-Receipt-To';
    $MAIL_LIST   = "dev.null\@$DOMAINNAME";
    $MAINTAINER  = "dev.null-admin\@$DOMAINNAME";
    $ML_MEMBER_CHECK  = $CHECK_MESSAGE_ID = 1;

    # default security level
    $SECURITY_LEVEL = 2; undef %Permit;
    
    @HdrFieldsOrder =	# rfc822; fields = ...; Resent-* are ignored;
	('Return-Path', 'Date', 'From', 'Reply-To', 'Subject', 'Sender', 
	 'To', 'Cc', 'Errors-To', 'Message-Id', 'In-Reply-To', 
	 'References', 'Keywords', 'Comments', 'Encrypted',
	 ':XMLNAME:', ':XMLCOUNT:', 'X-MLServer', 
	 'XRef', 'X-Stardate', 'X-ML-Info', ':body:', ':any:', 
	 'Mime-Version', 'Content-Type', 'Content-Transfer-Encoding',
	 'Posted', 'Precedence', 'Lines');
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


# one pass to cut out the header and the body
sub Parsing { &Parse;}
sub Parse
{
    $0 = "--Parsing header and body <$FML $LOCKFILE>";
    local($nlines, $nclines);

    while (<STDIN>) { 
	if (1 .. /^$/o) {	# Header
	    $Envelope{'Header'} .= $_ unless /^$/o;
	} 
	else {
	    # Guide Request from the unknown
	    if ($GUIDE_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:req:guide'} = 1 if /^\#\s*$GUIDE_KEYWORD\s*$/i;
	    }

	    # Command or not is checked within the first 3 lines.
	    # '# help\s*' is OK. '# guide"JAPANESE"' & '# JAPANESE' is NOT!
	    # BUT CANNOT JUDGE '# guide "JAPANESE CHARS"' SYNTAX;-);
	    if ($COMMAND_CHECK_LIMIT-- > 0) { 
		$Envelope{'mode:uip'} = 'on'    if /^\#\s*\w+\s|^\#\s*\w+$/;
		$Envelope{'mode:uip:chaddr'}=$_ if /^\#\s*($CHADDR_KEYWORD)\s+/i;
	    }

	    $Envelope{'Body'} .= $_; # save the body
	    $nlines++;               # the number of bodylines
	    $nclines++ if /^\#/o;    # the number of command lines
	}
    }# END OF WHILE LOOP;

    $Envelope{'nlines'}  = $nlines;
    $Envelope{'nclines'} = $nclines;
}


# eval and print error if error occurs.
sub eval
{
    &CompatFML15_Pre  if $COMPAT_FML15;
    eval $_[0]; 
    $@ ? (&Log("$_[1]:$@"), 0) : 1;
    &CompatFML15_Post if $COMPAT_FML15;
}



1;
#:~replace

# FIX INCLUDES
#:include: .exports/libsmtp.pl all
#:~sub
#:replace
# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.



$rcsid .= " :smtp[2.0.17.2]";


##### local scope in Calss:Smtp #####
local($SmtpTime, $FixTransparency, $LastSmtpIOString); 


# sys/socket.ph is O.K.?
sub SmtpInit
{
    local(*e, *smtp) = @_;

    # IF NOT SPECIFIED, [IPC]
    $e{'mci:mailer'} = $e{'mci:mailer'} || 'ipc';
    $e{'macro:s'}    = $e{'macro:s'}    || $FQDN;

    @smtp = ("HELO $e{'macro:s'}", "MAIL FROM: $MAINTAINER");

    # Set Defaults (must be "in $DIR" NOW)
    $SmtpTime  = time() if $TRACE_SMTP_DELAY;

    # LOG: on IPC and "Recovery for the universal use"
    if ($NOT_TRACE_SMTP || (!$VAR_DIR) || (!$VARLOG_DIR)) {
	$SMTP_LOG = '/dev/null';
    }
    else {
	(-d $VAR_DIR)    || mkdir($VAR_DIR, 0700);
	(-d $VARLOG_DIR) || mkdir($VARLOG_DIR, 0700);
	$SMTP_LOG = $SMTP_LOG || "$VARLOG_DIR/_smtplog";
    }

    ### FIX: . -> .. 
    ### rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
    if (! $FixTransparency) {
	$FixTransparency = 1;	# Fixing is done once!

	undef $e{'preamble'} if  $e{'mode:dist'};
	undef $e{'trailer'}  if  $e{'mode:dist'};

	if ($e{'preamble'}) { 
	    $e{'preamble'} =~ s/\n\./\n../g; $e{'preamble'} =~ s/\.\.$/./g;
	}

	if ($e{'trailer'})  { 
	    $e{'trailer'} =~ s/\n\./\n../g;  $e{'trailer'} =~ s/\.\.$/./g;
	}
    }

    # ANYTIME, Try fixing since plural mails are delivered
    $e{'Body'} =~ s/\n\./\n../g;           # enough for body ^. syntax
    $e{'Body'} =~ s/\.\.$/./g;	           # trick the last "."
    $e{'Body'} .= "\n" unless $e{'Body'} =~ /\n$/o;	# without the last "\n"

    return 1 if $SocketOK;
    return ($SocketOK = &SocketInit);
}


sub SocketInit
{
    ##### PERL 5  
    local($eval, $ok, $ExistSocket_ph);

    eval "use Socket;"; $ok = $@ eq "";
    &Log("Set Perl 5::Socket O.K.") if $debug && $ok;
    return 1 if $ok;

    ##### PERL 4
    $ExistSocket_ph = eval("require 'sys/socket.ph';"), ($@ eq "");
    &Log("\"eval sys/socket.ph\" O.K.") if $ExistSocket_ph && $debug;
    return 1 if $ExistSocket_ph; 

    if ((! $ExistSocket_ph) && $COMPAT_SOLARIS2) {
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
    }
    elsif (! $ExistSocket_ph) {	# 4.4BSD
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
    }

    1;
}


# Connect $host to SOCKET "S"
# RETURN *error
sub SmtpConnect
{
    local(*host, *error) = @_;

    local($pat)    = 'S n a4 x8'; # 'S n C4 x8'? which is correct? 
    local($addrs)  = (gethostbyname($host || 'localhost'))[4];
    local($proto)  = (getprotobyname('tcp'))[2];
    local($port)   = $PORT || (getservbyname('smtp', 'tcp'))[2];
    $port          = 25 unless defined($port); # default port

    # Check the possibilities of Errors
    return ($error = "Cannot resolve the IP address[$host]") unless $addrs;
    return ($error = "Cannot resolve proto")                 unless $proto;

    # O.K. pack parameters to a struct;
    local($target) = pack($pat, &AF_INET, $port, $addrs);

    # IPC open
    if (socket(S, &PF_INET, &SOCK_STREAM, $proto)) { 
	print SMTPLOG "socket ok\n";
    } 
    else { 
	return ($error = "Smtp::socket->Error[$!]");
    }
    
    if (connect(S, $target)) { 
	print SMTPLOG "connect ok\n"; 
    } 
    else { 
	return ($error = "Smtp::connect($host)->Error[$!]");
    }

    ### need flush of sockect <S>;
    select(S); $| = 1; select(STDOUT);

    $error = "";
}


# delete logging errlog file and return error strings.
sub Smtp 
{
    local(*e, *rcpt, *files) = @_;
    local(@smtp, $error, %cache, $nh, $nm, $i);

    ### Initialize, e.g. use Socket, sys/socket.ph ...
    &SmtpInit(*e, *smtp);
    
    ### open LOG;
    open(SMTPLOG, "> $SMTP_LOG") || (return "Cannot open $SMTP_LOG");
    select(SMTPLOG); $| = 1; select(STDOUT);

    # primary, secondary -> @HOSTS (ATTENTION! THE PLURAL NAME)
    push(@HOSTS, @HOST); # the name of the variable should be plural
    unshift(@HOSTS, $HOST);

    if (($MCI_SMTP_HOSTS > 1) && (scalar(@rcpt) > 1)) {
	$nh = $MCI_SMTP_HOSTS;
	$nm = 0;

	# save @rcpt to the local cache entry
	while (@rcpt) { 
	    foreach $i (1 .. $nh) { $cache{$i, $nm} = shift @rcpt;}; 
	    $nm++;
	}

	foreach $i (1 .. $nh) { 
	    undef @rcpt; # reset @rcpt
	    for ($j = 0; $cache{$i, $j} ne ''; $j++) { 
		push(@rcpt, $cache{$i, $j});
		undef $cache{$i, $j}; # not retry, OK?;
	    }

	    if (@rcpt) {
		$error = &SmtpIO(*e, *rcpt, *smtp, *files);
		push(@HOSTS, $HOST); # If all hosts are down, anyway try $HOST;
		return $error if $error;
	    }
	}
    }
    else { # not use pararell hosts to deliver;
	($error = &SmtpIO(*e, *rcpt, *smtp, *files)) && (return $error);
    }

    ### SMTP CLOSE
    close(SMTPLOG);
    0; # return status BAD FREE();
}


sub SmtpIO
{
    local(*e, *rcpt, *smtp, *files) = @_;
    local($sendmail) = $SENDMAIL || "/usr/sbin/sendmail -bs ";
    local($host, $error, $in_rcpt, $ipc);

    ### IPC 
    if ($e{'mci:mailer'} eq 'ipc') {
	$ipc = 1;		# define [ipc]

	# primary, secondary, ...;already unshift(@HOSTS, $HOST);
	for ($host = shift @HOSTS; scalar(@HOSTS) >= 0; $host = shift @HOSTS) {
	    undef $error;
	    &SmtpConnect(*host, *error);  # if host is null, localhost
	    print STDERR "$error\n" if $error;
	    last         if $error eq ""; # O.K.
	    &Log($error) if $error;       # error log BAD FREE();
	    sleep(1);		          # sleep and try the secondaries

	    last         unless @HOSTS;	  # trial ends if no candidate
	}
    }
    ### not IPC, try popen(sendmail) ...
    elsif ($e{'mci:mailer'} eq 'prog') {
	&Log("open2") if $debug;
	require 'open2.pl';
	&open2(RS, S, $sendmail) || return "Cannot exec $sendmail";
    }

    ### Do talk with sendmail via smtp connection
    # interacts smtp port, see the detail in $SMTPLOG
    if ($ipc) {
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    ##### [SHOULDE BE INLINED HERE]
    #####  SINCE THE MOST HEAVY LOOP IS HERE;
    #####
    foreach $s (@smtp, 'm_RCPT', @rcpt, 'm_RCPT', 'DATA') {
	next if $s =~ /^\s*$/o;
	
	if ($Envelope{'mode:_Deliver'} && $in_rcpt && $DLA_HACK) { 
	    &SmtpPutActiveList2Socket($ipc);
	}

	# RCPT TO:; trick for the less memory use;
	if ($s eq 'm_RCPT') { $in_rcpt = $in_rcpt ? 0 : 1; next;}
	$s = "RCPT TO: $s" if $in_rcpt;

	&SmtpPut2Socket($s, $ipc);
    }
    ### (HELO .. DATA) sequence ends

    ##### "DATA" Session BEGIN; no reply via socket ######
    ###
    ### BODY INPUT
    ### putheader()
    $0 = "-- BODY <$FML $LOCKFILE>";
    print SMTPLOG ('-' x 30)."\n";
    print SMTPLOG $e{'Hdr'}."\n";
    print S $e{'Hdr'}."\n";	# "\n" == separator between body and header;

    # Preamble
    if ($e{'preamble'}) { 
	print SMTPLOG $e{'preamble'}; 
	print S $e{'preamble'};
    }

    # Put files as a body
    if (@files) { 
	&SmtpFiles2Socket(*files, *e);
    }
    # BODY ON MEMORY
    else { 
	print SMTPLOG $e{'Body'}; 
	print S $e{'Body'};
	$LastSmtpIOString = $e{'Body'}; 
    }

    # Trailer
    if ($e{'trailer'}) { 
	$LastSmtpIOString =  $e{'trailer'}; 
	print SMTPLOG $e{'trailer'}; 
	print S $e{'trailer'};
    }

    ### close smtp with '.'
    print S "\n" unless $LastSmtpIOString =~ /\n$/;	# fix the last 012
    print SMTPLOG ('-' x 30)."\n";

    ##### "DATA" Session ENDS; ######
    ### Closing Phase;
    &SmtpPut2Socket('.', $ipc);
    &SmtpPut2Socket('QUIT', $ipc);

    close(S);

    0;
}

sub SmtpPut2Socket
{
    local($s, $ipc) = @_;

    $0 = "-- $s <$FML $LOCKFILE>"; 
    print SMTPLOG "$s<INPUT\n";
    print S "$s\n";

    if ($ipc) {
	do { print SMTPLOG $_ = <S>;  &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    # Approximately correct :-)
    if ($TRACE_SMTP_DELAY) {
	$time = time() - $SmtpTime;
	$SmtpTime = time();
	&Log("SMTP DELAY[$time sec.]:$s") if $time > $TRACE_SMTP_DELAY;
	$TRACE_SMTP_DELAY if $Hack{'dnscache'};
    }
}

sub SmtpPutActiveList2Socket
{
    local($ipc) = @_;
    local($rcpt);

    open(ACTIVE_LIST) || (&Log("cannot open $ACTIVE_LIST ID=$ID:$!"), return);
    while (<ACTIVE_LIST>) {
	chop;

	print STDERR "\nRCPT ENTRY\t$_\n" if $debug_smtp;

	next if /^\#/o;	 # skip comment and off member
	next if /^\s*$/o; # skip null line
	next if /\s[ms]=/o;

	tr/A-Z/a-z/;		 # lower case;

	($rcpt) = split(/\s+/, $_);
	next if $SKIP{$rcpt};	 # skip case;
	$rcpt = $RelayRcpt{$rcpt} if $RelayRcpt{$rcpt};

	print STDERR "RCPT TO:\t$rcpt\n" if $debug_smtp;
	&SmtpPut2Socket("RCPT TO: $rcpt", $ipc);
    }

    close(ACTIVE_LIST);
}

# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.



$rcsid .= " :smtp[2.0.17.2] :smtp[2.0.17.2] :smtputils[1.1]";


sub DoSmtpFiles2Socket
{
    local(*f, *e) = @_;
    local($autoconv, $count, $boundary);

    $count = scalar(@f) > 1 ? 1 : 0;

    foreach $f (@f) {
	&Debug("SmtpFiles2Socket::($f)") if $debug;

	if ($f{$f, 'zcat'}) {
	    open(FILE,"-|") || exec($ZCAT, $f) || 
		(&Log("SmtpFiles2Socket: cannot zcat $f"), close(FILE), next);
	}
	elsif ($f{$f, 'uuencode'}) {
	    open(FILE,"-|") || exec($UUENCODE, $f, $f) || 
		(&Log("SmtpFiles2Socket: cannot uuencode $f"), close(FILE), next);
	}
	else {
	    open(FILE, $f) || (&Log("SmtpFiles2Socket: cannot open $f"), close(FILE), next);
	}

	$autoconv = $f{$f, 'autoconv'};

	if ($count) {		# if more than two files;
	    $boundary = ('-' x 20).$f.('-' x 20)."\n";
	    print S $boundary;
	    print SMTPLOG $boundary;
	}

	while (<FILE>) { 
	    s/^\./../; 
	    &jcode'convert(*_, 'jis') if $autoconv;#';

	    # guide, help, ...
	    if (/dev/ && $Envelope{'mode:doc:repl'}) {
		s/dev\.null\@domain.uja/$MAIL_LIST/g;
		s/dev\.null\-admin\@domain.uja/$MAINTAINER/g;
		s/dev\.null\-ctl\@domain.uja/$CONTROL_ADDRESS/g;
	    }

	    print S $_;
	    print SMTPLOG $_;
	    $LastSmtpIOString = $_;
	};

	close(FILE);
    }
}


# NEW VERSION FOR MULTIPLE @to and @files
# return NONE
sub NeonSendFile
{
    local(*to, *subject, *files) = @_;
    local(@info) = caller;
    local($le, %le, @rcpt, $error, $f, @f, %f);

    ### DEBUG INFO;
    &Debug("NeonSendFile[@info]:\n\nSUBJECT\t$subject\nFILES:\t") if $debug;
    &Debug(join(" ", @files)) if $debug;
	
    ### check again $file existence
    foreach $f (@files) {
	next if $f =~ /^\s*$/;

	if (-f $f) {		# O.K. anyway exists!
	    push(@f, $f);	# store it as a candidate;

	    # Anyway copy each entry of each subject(%files) to %f
	    $f{$f, 'subject'} = $files{$f, 'subject'} if $files{$f, 'subject'};

	    next if $SENDFILE_NO_FILECHECK; # Anytime O.K. if no checked;

	    # Check whether JIS or not
	    if (-B $f) {
		&Log("ERROR: NeonSendFile: $f != JIS ?");

		# AUTO CONVERSION 
		$ExistJcode = eval "require 'jcode.pl';", $@ eq "";

		if ($ExistJcode) {
		    &Log("NeonSendFile: $f != JIS ? Try Auto Code Conversion");
		    $f{$f, 'autoconv'} = 1;
		}
	    }

	    # misc checks
	    &Log("NeonSendFile: \$ZCAT not defined") unless $ZCAT;
	    &Log("NeonSendFile: cannot read $file")  unless -r $f;
	}
	### NOT EXISTS 
	else {
	    &Log("NeonSendFile: $f is not found.", "[ @info ]");
	    $f =~ s/$DIR/\$DIR/;
	    $error .=  "$f is not found.\n[ @info ]\n\n";
	    &Mesg(*Envelope, "Sorry.\nError NeonSendFile: $f is not found.\n");
	}

	$error && &Warn("ERROR NeonSendFile", $error);
	return $NULL if $error;	# END if only one error is found. Valid?
    }

    ### DEFAULT SUBJECT. ABOVE, each subject for each file
    $le{'GH:Subject:'} = $subject;
    &GenerateHeader(*to, *le, *rcpt);

    $le = &Smtp(*le, *rcpt, *f);
    &Log("NeonSendFile:$le") if $le;
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub DoSendFile
{
    local(@to, %le, @rcpt, @files, %files);
    local($to, $subject, $file, $zcat, @to) = @_;

    @to || push(@to, $to); # extention for GenerateHeader

    push(@files, $file);
    (1 == $zcat) && ($files{$f, 'zcat'} = 1);
    (2 == $zcat) && ($files{$f, 'uuencode'} = 1);

    &NeonSendFile(*to, *subject, *files); #(*to, *subject, *files);
}


# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local(@to, %le, @rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeader

    $le{'GH:Subject:'} = $subject;
    &GenerateHeader(*to, *le, *rcpt);
    
    $le{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $le{'Body'}     .= $body;
    $le{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $le = &Smtp(*le, *rcpt);
    &Log("Sendmail:$le") if $le;
}


# Generating Headers, and SMTP array
sub GenerateMail    { &GenerateHeaders(@_);}
sub GenerateHeaders { &GenerateHeader(@_);}
sub GenerateHeader
{
    # old format == local(*to, $subject) 
    # @Rcpt is passed as "@to" even if @to has one addr;
    # WE SHOULD NOT TOUCH "$to" HERE;
    local(*to, *le, *rcpt) = @_;
    local($tmpto);

    # @to is required; but we can make $from appropriatedly;
    @to || do { &Log("GenerateHeader:ERROR: NO \@to"); return;};

    # prepare: *rcpt for Smtp();
    foreach (@to) {
	push(@rcpt, $_); # &Smtp(*le, *rcpt);
	$tmpto .= $tmpto ? ", $_" : $_; # a, b, c format
    }

    $Rcsid  =~ s/\)\(/,/g;

    # fix *le(local) by *Envelope(global)
    $le{'macro:s'}    = $Envelope{'macro:s'};
    $le{'mci:mailer'} = $Envelope{'mci:mailer'};

    $le{'GH:To:'}          = $tmpto;
    $le{'GH:From:'}        = $MAINTAINER ||((getpwuid($<))[0])."\@$DOMAINNAME";
    $le{'GH:Date:'}        = $MailDate;
    $le{'GH:X-MLServer:'}  =  $Rcsid;
    $le{'GH:X-MLServer:'} .= "\n\t($rcsid)" if $debug;
    $le{'GH:From:'}      .= " ($MAINTAINER_SIGNATURE)" if $MAINTAINER_SIGNATURE;

    # MEMO:
    # MIME (see RFC1521)
    # $_cf{'header', 'MIME'} => $Envelope{'GH:MIME:'}
    # 
    for (@HdrFieldsOrder) {
	if ($Envelope{"GH:$_:"} || $le{"GH:$_:"}) {
	    $le{'Hdr'} .= "$_: ".($Envelope{"GH:$_:"} || $le{"GH:$_:"})."\n";
	}
    }
}


1;
