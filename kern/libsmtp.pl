# Smtp library functions, 
# smtp does just connect and put characters to the sockect.
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");


##### local scope in Calss:Smtp #####
local($SMTP_TIME); 
local($SENDMAIL) = $SENDMAIL || "/usr/lib/sendmail -bs ";


# sys/socket.ph is O.K.?
sub SmtpInit
{
    local(*e, *rcpt, *smtp) = @_;

    @smtp = ("HELO $e{'macro:s'}", "MAIL FROM: $MAINTAINER");

    # Set Defaults
    $SMTP_TIME = time() if $TRACE_SMTP_DELAY;

    $VAR_DIR    = $VAR_DIR    || "$DIR/var";
    $VARLOG_DIR = $VARLOG_DIR || "$DIR/var/log";  # absolute for ftpmail
    $SMTP_LOG0  = $SMTP_LOG0  || "$DIR/_smtplog"; # Backward compatibility;
    $SMTP_LOG   = $SMTP_LOG   || "$VARLOG_DIR/_smtplog";

    # LOG: on IPC
    if ($NOT_TRACE_SMTP) {
	$SMTP_LOG = '/dev/null';
    }
    else {
	(-d $VAR_DIR)    || mkdir($VAR_DIR, 0700);
	(-d $VARLOG_DIR) || mkdir($VARLOG_DIR, 0700);
	(-l $SMTP_LOG0)  || do {
	    $symlink_exists = (eval 'symlink("", "");', $@ eq "");
	    unlink $SMTP_LOG0;
	    $symlink_exists && symlink($SMTP_LOG, $SMTP_LOG0);
	    if ($symlink_exists) {
		&Log("ln -s $SMTP_LOG $SMTP_LOG0");
	    }
	    else {
		&Log("unlink $SMTP_LOG0, log -> $SMTP_LOG");
	    }
	};
    }

    ##### PERL 5  
    local($eval, $ok);
    if ($_cf{'perlversion'} == 5) { 
	eval "use Socket;", ($ok = $@ eq "");
	&Log($ok ? "Socket O.K.": "Socket fails. Try socket.ph") if $debug;
	return 1 if $ok;
    }

    ##### PERL 4
    $EXIST_SOCKET_PH = eval "require 'sys/socket.ph';", $@ eq "";
    &Log("sys/socket.ph is O.K.") if $EXIST_SOCKET_PH && $debug;

    if ((! $EXIST_SOCKET_PH) && $COMPAT_SOLARIS2) {
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {2;}; sub SOCK_DGRAM  {1;};";
	&eval($eval) && $debug && &Log("Set socket [Solaris2]");
    }
    elsif (! $EXIST_SOCKET_PH) {	# 4.4BSD
	$eval  = "sub AF_INET {2;};     sub PF_INET { &AF_INET;};";
	$eval .= "sub SOCK_STREAM {1;}; sub SOCK_DGRAM  {2;};";
	&eval($eval) && $debug && &Log("Set socket [4.4BSD]");
    }
}



# delete logging errlog file and return error strings.
sub Smtp 
{
    local(*e, *rcpt) = @_;
    local($pat)  = 'S n a4 x8'; # 'S n C4 x8'? which is correct? 
    local($time, *smtp);

    ### Initialize, e.g. use Socket, sys/socket.ph ...
    &SmtpInit(*e, *rcpt, *smtp);
    

    ### open LOG
    open(SMTPLOG, "> $SMTP_LOG") || (return "Cannot open $SMTP_LOG");


    ### IPC 
    if ($e{'mci:mailer'} eq 'ipc') {
	local($addrs) = (gethostbyname($HOST || 'localhost'))[4];
	local($port, $proto) = (getservbyname('smtp', 'tcp'))[2..3];
	$port = 25 unless defined($port); # default port
	local($target) = pack($pat, &AF_INET, $port, $addrs);

	# IPC open
	if (socket(S, &PF_INET, &SOCK_STREAM, $proto)) { 
	    print SMTPLOG  "socket ok\n";
	} 
	else { 
	    return "Smtp:sockect:$!";
	}

	if (connect(S, $target)) { 
	    print SMTPLOG  "connect ok\n"; 
	} 
	else { 
	    return "Smtp:connect:$!";
	}
    }
    ### not IPC, try popen(sendmail) ...
    elsif($e{'mci:mailer'} eq 'prog') {
	&Log("open2") if $debug;
	require 'open2.pl';
	&open2(OUT, S, $SENDMAIL) || return "Cannot exec $SENDMAIL";
    }

    ### need flush of sockect <S>;
    select(S);       $| = 1; select(STDOUT);
    select(SMTPLOG); $| = 1; select(STDOUT);

    ### Do talk with sendmail via smtp connection
    # interacts smtp port, see the detail in $SMTPLOG
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);
    foreach $s (@smtp, @rcpt, 'DATA') {
	$0 = "-- $s <$FML $LOCKFILE>";

	print SMTPLOG ($s . "<INPUT\n");
	print S ($s . "\n");
	do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

	# Approximately correct :-)
	if ($TRACE_SMTP_DELAY) {
	    $time = time() - $SMTP_TIME;
	    $SMTP_TIME = time();
	    &Log("SMTP DELAY[$time sec.]:$s") if $time > $TRACE_SMTP_DELAY;
	}
    }
    ### (HELO .. DATA) sequence ends



    ### BODY INPUT
    # putheader()
    $0 = "-- BODY <$FML $LOCKFILE>";
    print SMTPLOG ('-' x30)."\n";
    print SMTPLOG $e{'Hdr'}."\n";
    print S $e{'Hdr'}."\n";

    # Preamble
    if ( (! $e{'mode:dist'}) && $e{'preamble'}) {
	$e{'preamble'} =~ s/\n\./\n../g;
	$e{'preamble'} =~ s/\.\.$/./g;
	print SMTPLOG $e{'preamble'};
	print S       $e{'preamble'};
    }

    # putfile
    if ($e{'file'}) { 
	while(<FILE>) { 
	    s/^\./../; 
	    print S $_;
	    print SMTPLOG $_;
	};
	print S "\n" if (!/\n$/); # fix the lost '\012'
    } 
    # ON MEMORY
    else {
	# rfc821 4.5.2 TRANSPARENCY, fixed by koyama@kutsuda.kuis.kyoto-u.ac.jp
	$e{'Body'} =~ s/\n\./\n../g;               # enough for body ^. syntax
	$e{'Body'} =~ s/\.\.$/./g;	           # trick the last "."
	$e{'Body'} .= "\n" unless $e{'Body'} =~ /\n$/o;	# without the last "\n"
	print SMTPLOG $e{'Body'};
	print S       $e{'Body'};
    }

    # Trailer
    if ( (! $e{'mode:dist'}) && $e{'trailer'}) {
	$e{'trailer'} =~ s/\n\./\n../g;
	$e{'trailer'} =~ s/\.\.$/./g;
	print SMTPLOG $e{'trailer'};
	print S       $e{'trailer'};
    }

    # close smtp with '.'
    print SMTPLOG ('-' x30)."\n";
    print S ".\n";
    $s = "BODY";		#CONVENIENCE: infomation for errlog
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    ### close connection 
    $s = "QUIT";		#CONVENIENCE: infomation for errlog
    $0 = "-- $s <$FML $LOCKFILE>";

    print S "$s\n";
    print SMTPLOG "$s<INPUT\n";
    do { print SMTPLOG $_ = <S>; &Log($_) if /^[45]/o;} while(/^\d+\-/o);

    close S; 
    close SMTPLOG;

    0; # return status
}


#
# SendFile is just an interface of Sendmail to send a file.
# Mainly send a "PLAINTEXT" back to @to, that is a small file.
# require $zcat = non-nil and ZCAT is set.
sub SendFile
{
    local(*to, *e, *rcpt);
    local($to, $subject, $file, $zcat, @to) = @_;
    local($body, $enc);

    # extention for GenerateHeaders
    @to || push(@to, $to);

    if ($_cf{'SendFile', 'Subject'}) {
	$enc = $_cf{'SendFile', 'Subject'};
    } 
    elsif($file =~ /tar\.gz$/||$file =~ /tar\.z$/||$file =~ /tar\.Z$/) {
	$enc = "spool.tar.gz";
    }
    elsif($file =~ /\.gz$/||$file =~ /\.z$/||$file =~ /\.Z$/) {
	$enc = "uja.gz";
    }

    if (open(FILE, $file) && ($SENDFILE_NO_FILECHECK ? 1 : -T $file)) { 
	;
    }
    elsif ((1 == $zcat) && 
	   $ZCAT && -r $file && open(FILE, "$ZCAT $file|")) {
	;
    }
    elsif ((2 == $zcat) 
	   && $ZCAT && -r $file && open(FILE, "$UUENCODE $file $enc|")) {
	;
    }
    else { 
	&Log("sub SendFile: no $file") if !-f $file;
	&Log("sub SendFile: binary?O.K.?: $file [zcat=$zcat]") 
	    if (!$zcat) && -B $file;
	&Log("sub SendFile: \$ZCAT not defined") unless $ZCAT; 	
	&Log("sub SendFile: cannot read $file")  unless -r $file;
	&Log("sub SendFile: must be cannot open $file") unless open(FILE, $file);
	return;
    }


    $e{'file'} = 1;    # trick for using smaller memory!
    $e{'subject:'} = $subject;
    &GenerateHeaders(*to, *e, *rcpt);

    $e = &Smtp(*e, *rcpt);
    &Log("SendFile:$e") if $e;
    undef $_cf{'Smtp', 'readfile'};

    close(FILE);
}


# Sendmail is an interface of Smtp, and accept strings as a mailbody.
# Sendmail($to, $subject, $MailBody) paramters are only three.
sub Sendmail
{
    local(*to, *e, *rcpt);
    local($to, $subject, $body, @to) = @_;
    push(@to, $to);		# extention for GenerateHeaders

    $e{'subject:'} = $subject;
    &GenerateHeaders(*to, *e, *rcpt);
    
    $e{'preamble'} .= $Envelope{'preamble'}.$PREAMBLE_MAILBODY;
    $e{'Body'}     .= $body;
    $e{'trailer'}  .= $Envelope{'trailer'}.$TRAILER_MAILBODY;

    $e = &Smtp(*e, *rcpt);
    &Log("Sendmail:$e") if $e;
}


# Generating Headers, and SMTP array
sub GenerateMail { &GenerateHeaders(@_);}
sub GenerateHeaders
{
    # old format == local(*to, $subject) 
    local(*to, *e, *rcpt) = @_;
    local($from) = $MAINTAINER ? $MAINTAINER : (getpwuid($<))[0];

    undef $to;			# required 

    if ($debug) {
	print STDERR "from = $from\nto   = ".join(" ", @to)."\n";
	print STDERR "GenerateHeaders: missing from||to\n" if(! ($from && @to));
    }
    return unless ($from && @to);

    foreach (@to) {	
	push(@rcpt, "RCPT TO: $_"); 
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
    $e{'Hdr'} .= $_cf{'header', 'MIME'} if $_cf{'header', 'MIME'};

    # ML info
    $e{'Hdr'} .= "X-MLServer: $rcsid\n" if $rcsid;
}

1;
