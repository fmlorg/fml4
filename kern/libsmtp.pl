# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


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

	if ($e{'preamble'}) { $e{'preamble'} =~ s/\n\./\n../g; $e{'preamble'} =~ s/\.\.$/./g;}
	if ($e{'trailer'})  { $e{'trailer'} =~ s/\n\./\n../g;  $e{'trailer'} =~ s/\.\.$/./g;}
    }

    # ANYTIME, Try fixing since plural mails are delivered
    $e{'Body'} =~ s/\n\./\n../g;               # enough for body ^. syntax
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
    &Log($ok ? "Socket(XS) O.K.": "Socket(Perl 5 XS) fails. Try socket.ph") if $debug;
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
    local($port)   = (getservbyname('smtp', 'tcp'))[2];
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
	return ($error = "Smtp:socket:$!");
    }
    
    if (connect(S, $target)) { 
	print SMTPLOG "connect ok\n"; 
    } 
    else { 
	return ($error = "Smtp:connect->$host[$!]");
    }

    ### need flush of sockect <S>;
    select(S);       $| = 1; select(STDOUT);

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

    if ($MCI_SMTP_HOSTS && (scalar(@rcpt) > 1)) {
	$nh = $MCI_SMTP_HOSTS;
	$nm = 0;

	# save @rcpt to the local cache entry
	while (@rcpt) { foreach $i (1 .. $nh) { $cache{$i, $nm} = shift @rcpt;}; $nm++;}

	foreach $i (1 .. $nh) { 
	    undef @rcpt;	# reset @rcpt
	    for ($j = 0; $cache{$i, $j} ne ''; $j++) { push(@rcpt, $cache{$i, $j});}

	    if (@rcpt) {
		$error = &SmtpIO(*e, *rcpt, *smtp, *files);
		push(@HOSTS, $HOST); # If all hosts are down, anyway try $HOST;
		return $error if $error;
	    }
	}
    }
    else {
	($error = &SmtpIO(*e, *rcpt, *smtp, *files)) && (return $error);
    }

    ### SMTP CLOSE
    close(SMTPLOG);
    0; # return status  %BAD FREE()%;
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
	    &Log($error) if $error;       # error log %BAD FREE()%;
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

    foreach $s (@smtp, 'm_RCPT', @rcpt, 'm_RCPT', 'DATA') {
	next if $s =~ /^\s*$/o;

	# RCPT TO:; trick for the less memory use;
	if ($s eq 'm_RCPT') { $in_rcpt = $in_rcpt ? 0 : 1; next;}
	$s = "RCPT TO: $s" if $in_rcpt;
	
	$0 = "-- $s <$FML $LOCKFILE>"; 

	print SMTPLOG ($s . "<INPUT\n");
	print S ($s . "\n");

	if ($ipc) {
	    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
	}
	else {
	    do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
	}

	# Approximately correct :-)
	if ($TRACE_SMTP_DELAY) {
	    $time = time() - $SmtpTime;
	    $SmtpTime = time();
	    &Log("SMTP DELAY[$time sec.]:$s") if $time > $TRACE_SMTP_DELAY;
	}
    }
    ### (HELO .. DATA) sequence ends

    ### BODY INPUT
    # putheader()
    $0 = "-- BODY <$FML $LOCKFILE>";
    print SMTPLOG ('-' x 30)."\n";
    print SMTPLOG $e{'Hdr'}."\n";
    print S $e{'Hdr'}."\n";	# "\n" == separator between body and header;

    # Preamble
    if ($e{'preamble'}) { print SMTPLOG $e{'preamble'}; print S $e{'preamble'};}

    # Put files as a body
    if (@files) { 
	&SmtpFiles2Socket(*files);
    }
    # BODY ON MEMORY
    else { 
	print SMTPLOG $e{'Body'}; print S $e{'Body'};
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
    print S ".\n";

    if ($ipc) {
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    $0 = "-- QUIT <$FML $LOCKFILE>";
    print S "QUIT\n";
    print SMTPLOG "QUIT<INPUT\n";

    if ($ipc) {
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }
    else {
	do { print SMTPLOG $_ = <RS>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    }

    close S;

    0;
}


sub SmtpFiles2Socket
{
    local(*f) = @_;
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
    local($e, %e, @rcpt, $error, $f, @f, %f);

    ### INFO
    &Debug("NeonSendFile[@info]:\n\nSUBJECT\t$subject\nFILES\t@files\n");# if $debug;

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
	    $Envelope{'message'} .= 
		"Sorry.\nError NeonSendFile: $f is not found."; #HERE Envelope
	}

	$error && &Warn("ERROR NeonSendFile", $error);
	return $NULL if $error;	# END if only one error is found. Valid?
    }

    ### DEFAULT SUBJECT. ABOVE, each subject for each file
    $e{'subject:'} = $subject;
    &GenerateHeader(*to, *e, *rcpt);

    $e = &Smtp(*e, *rcpt, *f);
    &Log("NeonSendFile:$e") if $e;
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub SendFile
{
    local(@to, %e, @rcpt, @files, %files);
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
    local(@to, %e, @rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeader

    $e{'subject:'} = $subject;
    &GenerateHeader(*to, *e, *rcpt);
    
    $e{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $e{'Body'}     .= $body;
    $e{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $e = &Smtp(*e, *rcpt);
    &Log("Sendmail:$e") if $e;
}


# Generating Headers, and SMTP array
sub GenerateMail    { &GenerateHeaders(@_);}
sub GenerateHeaders { &GenerateHeader(@_);}
sub GenerateHeader
{
    # old format == local(*to, $subject) 
    local(*to, *e, *rcpt) = @_;
    local($from) = $e{'F:From'} || $MAINTAINER || (getpwuid($<))[0]; # F=Force

    $to_org = $to; # required 
    undef $to; # required 

    if ($debug) {
	print STDERR "from = $from\nto   = @to\n";
	print STDERR "GenerateHeader: missing from||to\n" unless ($from && @to);
    }
    return unless ($from && @to);

    foreach (@to) {	
	push(@rcpt, $_); 
	$to .= $to ? (', '.$_) : $_; # a, b, c format
    }

    # fix by *Envelope
    $e{'macro:s'}    = $Envelope{'macro:s'};
    $e{'mci:mailer'} = $Envelope{'mci:mailer'};

    # the order below is recommended in RFC822 
    $e{'Hdr'} .= "Date: $MailDate\n";

    # From
    $e{'Hdr'} .= "From: $from";
    $e{'Hdr'} .= " ($MAINTAINER_SIGNATURE)" if $MAINTAINER_SIGNATURE;
    $e{'Hdr'} .= "\n";

    $e{'Hdr'} .= "Subject: $e{'subject:'}\n" if $e{'subject:'};
    $e{'Hdr'} .= "To: $to\n";
    $e{'Hdr'} .= 
	"Reply-to: $Envelope{'h:Reply-To:'}\n" if $Envelope{'h:Reply-To:'};

    # MIME (see RFC1521)
    # $_cf{'header', 'MIME'} => $Envelope{'r:MIME'}
    $e{'Hdr'} .= $Envelope{'r:MIME'} if $Envelope{'r:MIME'};

    # ML info
    $e{'Hdr'} .= "X-Debug: $rcsid\n"    if $debug && $rcsid;
    $e{'Hdr'} .= "X-MLServer: $Rcsid\n" if $Rcsid;

    $to = $to_org; # required 

}

1;
