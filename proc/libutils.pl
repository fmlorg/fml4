# Library of fml.pl
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# Auto registraion procedure
# Subject: subscribe
#        or 
# subscribe ... in Body.
# return 0 or 1 to use the return of &MLMemberCheck
sub AutoRegist
{
    local(*e) = @_;
    local($from, $s, $b, $r);
    local($file_to_regist) = $FILE_TO_REGIST || $MEMBER_LIST;

    # for &Notify,  reply-to ? reply-to : control-address
    $e{'h:Reply-To:'} = $e{'h:reply-to:'} || $e{'Reply2:'};

    if ($REQUIRE_SUBSCRIBE && (! $REQUIRE_SUBSCRIBE_IN_BODY)) {
	# Syntax e.g. "Subject: subscribe"...
	# 
	# [\033\050\112] is against a bug in cc:Mail
	# patch by yasushi@pier.fuji-ric.co.jp
	$s = $e{'h:Subject:'};
	$s =~ s/(^\#\s*|^\s*)//;
	$s =~ s/\n(\s)/$1/g;	# may be multiple lines
	$s =~ s/^\033\050\112\s*($REQUIRE_SUBSCRIBE.*)/$1/;
	&Debug("AUTO REGIST SUBJECT ENTRY [$s]") if $debug;

	if ($s =~ /^$REQUIRE_SUBSCRIBE\s*(.*)/) { 
	    $from = $1;
	    &Debug("AUTO REGIST FROM ENTRY [$from]") if $debug;
	    $from =~ s/^(\S+).*/$1/;
	    &Debug("AUTO REGIST FROM ENTRY [$from]") if $debug;
	}
	else {
	    &Debug("AUTO REGIST SUBJECT[$s] SYNTAX ERROR") if $debug;
	    $sj = "Bad syntax subject in autoregistration";
	    $b  = "Subject: $REQUIRE_SUBSCRIBE [your-email-address]\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";

	    &Log($sj, "Subject => [$s]");
	    &Warn("$sj $ML_FN", &WholeMail);

	    # notify
	    $e{'message:h:subject'} .= $sj;
	    $e{'message'}           .= $b. &WholeMail;

	    return 0;
	}
    }
    elsif ($REQUIRE_SUBSCRIBE && $REQUIRE_SUBSCRIBE_IN_BODY) {
	# Syntax e.g. "subscribe" in body
	$s = $e{'Body'};
	$s =~ s/(^\#\s*|^\s*)//;
	$s =~ s/\n(\s)/$1/g;	# may be multiple lines
	&Debug("AUTO REGIST BODY ENTRY [$s]") if $debug;

	if ($s =~ /^$REQUIRE_SUBSCRIBE\s*(.*)/) { 
	    $from = $1;
	    &Debug("AUTO REGIST FROM ENTRY [$from]") if $debug;
	    $from =~ s/^(\S+).*/$1/;
	    &Debug("AUTO REGIST FROM ENTRY [$from]") if $debug;
	}
	else {
	    &Debug("AUTO REGIST BODY[$s] SYNTAX ERROR") if $debug;
	    $sj = "Bad syntax body in autoregistration";
	    $b  = "Body: $REQUIRE_SUBSCRIBE [your-email-address]\n";
	    $b .= "\t[] is optional\n";
	    $b .= "\tfor changing your address to regist explicitly.\n";

	    &Log($sj, "Body => [$s]");
	    &Warn("$sj $ML_FN", &WholeMail);

	    # notify
	    $e{'message:h:subject'} .= $sj;
	    $e{'message'}           .= $b. &WholeMail;

	    return 0;
	}
    }
    else {
	# DEFAULT
	# Determine the address to check
	# In default, when changing your registerd address
	# use "subscribe your-address" in body.
	$s = $e{'Body'};
	$s =~ s/(^\#\s*|^\s*)//;
	$s =~ s/\n(\s)/$1/g;	# may be multiple lines

	$DEFAULT_SUBSCRIBE || ($DEFAULT_SUBSCRIBE = "subscribe");

	if ($s =~ /^$DEFAULT_SUBSCRIBE\s*(\S+)/i) { 
	    $from = $1;
	    &Debug("AUTO REGIST DEFAULT ENTRY [$from]") if $debug;
	    $from =~ s/^(\S+).*/$1/;
	    &Debug("AUTO REGIST DEFAULT ENTRY [$from]") if $debug;
	}
    }# end of REQUIRE_SUBSCRIBE;
	
    &Debug("AUTO REGIST CANDIDATE>$from<") if $debug;
    $from = ($from || $From_address);
    &Debug("AUTO REGIST FROM     >$from<") if $debug;

    return 0 if     &LoopBackWarn($from); 	# loop back check	
    return 0 unless &Chk822_addr_spec_P($from);	# permit only 822 addr-spec 

    ### duplicate check (patch by umura@nn.solan.chubu.ac.jp 95/06/08)
    if (&CheckMember($from, $MEMBER_LIST)) {	
	&Log("Dup: $from");
	$e{'message'} .= "Address [$from] already subscribed.\n";
	$e{'message'} .= &WholeMail;
	return 0;
    }

    ##### ADD the newcomer to the member list
    local($ok, $er);		# ok and error-strings

    # WHEN CHECKING MEMBER...
    if ($ML_MEMBER_CHECK) {
	&Append2($from, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	&Append2($from, $ACTIVE_LIST)    ? $ok++ : ($er .= " $ACTIVE_LIST");
	($ok == 2) ? &Log("Added: $from") : do {
	    &Warn("ERROR[sub AutoRegist]: cannot operate $er", &WholeMail);
	    return 0; 
	};
    }
    # AUTO REGISTRATION MODE
    else {
	&Append2($from, $file_to_regist) ? $ok++ : ($er  = $file_to_regist);
	$ok == 1 ? &Log("Added: $from") : do {
	    &Warn("ERROR[sub AutoRegist]: cannot operate $er", &WholeMail);
	    return 0;
	};
    }

    ### WHETHER DELIVER OR NOT?
    # 7 is body 3 lines and signature 4 lines, appropriate?
    local($limit) = $AUTO_REGISTRATION_LINES_LIMIT || 8;
    &Log("Deliver? $e{'nlines'} <=> $limit") if $debug;

    if ($e{'nlines'} < $limit) { 
	&Log("Not deliver: lines:$e{'nlines'} < $limit");
	$AUTO_REGISTERD_UNDELIVER_P = 1;
	$r  = "The number of mail body-line is too short(< $limit),\n";
	$r .= "So NOT FORWARDED to ML($MAIL_LIST). O.K.?\n\n";
	$r .= ('-' x 30) . "\n\n";
    }
    elsif ($AUTO_REGISTERD_UNDELIVER_P) {
	$r  = "\$AUTO_REGISTERD_UNDELIVER_P is set, \n";
	$r .= "So NOT FORWARDED to ML($MAIL_LIST).\n\n";
	$r .= ('-' x 30) . "\n\n";
    }
    
    &Warn("New added member: $from $ML_FN", $r . &WholeMail);
    &SendFile($from, $WELCOME_STATEMENT, $WELCOME_FILE);

    ### Ends.
    ($AUTO_REGISTERD_UNDELIVER_P ? 0 : 1);
}


# Get a option value for msend..
# Parameter = opt to parse
# If required e.g. 3mp, parse to '3' and 'mp', &ParseM..('mp')
# return option name || NULL (fail)
sub ParseMSendOpt
{
    local($opt) = @_;

    foreach $OPT (keys %MSendOpt) {
	return $MSendOpt{$OPT} if $opt eq $OPT;
    }

    return $NULL;
}


# &ModeLookup($d+$S+) -> $d+ and $S+. 
# return ($d+, $S+) or a NULL list
sub ModeLookup
{
    local($opt) = @_;    
    local($when, $mode);

    print STDERR "ModeLookup($opt)\n" if $debug;

    # Require called by anywhere
    &MSendModeSet;

    # Parse option 
    # return NULL LIST if fails
    if ($opt =~ /(\d+)(.*)/) {
	$when = $1;
	$mode = $2;
    }
    elsif ($opt =~ /(\d+)/) {
	$when = $1;
	$mode = '';
    }else {
	return ($NULL, $NULL);
    }

    # try to find 
    $mode = $MSendOpt{$mode};

    # Not match or document
    $mode || do { return ($NULL, $NULL);};
    ($mode =~ /^\#/) &&  do { return ($NULL, $NULL);};

    # O.K. 
    return ($when, $mode);
}


# &ModeLookup($d+$S+) -> $d+ and $S+. 
# return DOCUMENT string
sub DocModeLookup
{
    local($opt) = @_;    
    $opt =~ s/\#\d+/\#/g;

    print STDERR "DocModeLookup($opt)\n" if $debug;

    # Require called by anywhere
    &MSendModeSet;

    if ($opt =~ /^\#/ && ($opt = $MSendOpt{$opt})) {
	($opt =~ /^\#(.*)/) && (return $1);
    }
    else {
	return '[No document]';
    }
}


# Setting Mode association list
# return NONE
sub MSendModeSet
{
    #            KEY        MODE
    # DOCUMENT   #KEY       #MODE 
    %MSendOpt = (
		 '#gz',     '#gzipped(UNIX FROM)', 
		 'gz',      'gz',


		 '#tgz',    '#tar + gzip', 
		 '',        'tgz',
		 'tgz',     'tgz',


		 '#mp',     '#MIME/multipart', 
		 'mp',      'mp',


		 '#uf',     '#PLAINTEXT(UNIX FROM)', 
		 'u',       'uf', 
		 'uf',      'uf',
		 'unpack',  'uf',


		 '#lhaish', '#LHA+ISH', 
		 'li',      'lhaish',
		 'i',       'lhaish',
		 'ish',     'lhaish',
		 'wait#lhaish', 1,


		 '#lhauu',   '#LHA+Uuencoded', 
		 'lu',       'lhauu',
		 'lhauu',    'lhauu',


		 '#rfc934', '#RFC934(mh-burst)', 
		 'b',       'rfc934', 
		 'rfc934',  'rfc934',


		 '#uu',      '#Uuencoded(USENET Traditional)', 
		 'uu',       'uu', 


		 '#ui',      '#Ished(for BBS use)', 
		 'ui',       'ui', 
		 'uish',     'uish', 
		 'wait#uish', 1,


		 '#rfc1153','#Digest (RFC1153)',
		 '#rfc1153','#Digest (RFC1153)',
		 'd',       'rfc1153',
		 'rfc1153', 'rfc1153'

		 );

    $MSEND_OPT_HOOK && &eval($MSEND_OPT_HOOK, 'MSendModeSet:');
}


# I learn "how to extract from a tar file " from taro-1.3 by
# utashiro@sra.co.jp.
# So several codes are stolen from taro-1.3.
sub TarZXF
{
    local($tarfile, $total, *cat, $outfile) = @_;
    local($header_size)   = 512;
    local($header_format) = "a100 a8 a8 a8 a12 a12 a8 a a100 a*";
    local($nullblock)     = "\0" x $header_size;
    local($buf, $totalsize);
    local($tmptotal) = 1;
    
    &Debug("TarZXF local($tarfile, $total, ". 
	join(" ", keys %cat) .", $outfile)\n") if $debug;
    
    # check the setting on ZCAT
    if (! defined($ZCAT)) { return "ERROR of ZCAT";}
    
    open(TAR, $tarfile) || &Log("TarZXF: Cannot open $tarfile: $!");
    open(TAR, '-|') || exec($ZCAT, $tarfile) || die("zcat: $!\n")
	if ($tarfile =~ /\.gz$/);
    select(TAR); $| = 1; select(STDOUT);

    if ($outfile) {
	&OpenStream($outfile, 0, 0, $tmptotal) 
	    || do { &Log("TarZXF: Cannot Open $outfile"); return "";};
    };
    
    while (($s = read(TAR, $header, $header_size)) == $header_size) {
	if ($header eq $nullblock) {
	    last if ++$null_count == 2;
	    next;
	}
	$null_count = 0;
	
	@header = unpack($header_format, $header);
	
	($name = $header[0]) =~ s/\0*$//;
	&Debug("Extracting $name ...\n") if $debug;
	local($catit) = $cat{$name};

	local($bufsize) = 8192;
	local($size)    = oct($header[4]);
	$totalsize     += $size; # total size?
	$size           = 0 if $header[7] =~ /1/;

	# suppose 80 char/line
	if ($outfile && $catit && $totalsize > 80 * $MAIL_LENGTH_LIMIT) { 
	    close(OUT);
	    $tmptotal++; 
	    $outfile && &OpenStream($outfile, 0, 0, $tmptotal) 
		|| do { &Log("TarZXF: Cannot Open $outfile"); return "";};    
	    $totalsize = 0;
	}
	
	while ($size > 0) {
	    $bufsize = 512 if $size < $bufsize;
	    if (($s = read(TAR, $buf, $bufsize)) != $bufsize) {
		&Log("TarZXF: Illegal EOF: bufsize:$bufsize, size:$size");
	    }

	    if ($catit) {	    
		if ($outfile) {
		    $B = substr($buf, 0, $size);
		    $B =~ s/Return\-Path:.*\n/From $MAINTAINER\n/;
		    print OUT $B;
		}
		else {
		    $buf .= substr($buf, 0, $size);
		}
	    }

	    $size -= $bufsize;
	}
	
	print OUT "\n" if $catit;# \nFrom UNIX-FROM;

	if ($catit && ! --$total) {
	    close TAR;
	    close OUT;
	    return $outfile ? $tmptotal : $buf;
	}
    }# end of Tar extract
    
    close TAR; 
    close OUT;

    return $outfile ? $tmptotal : $buf;
}

# InterProcessCommunication
# return the answer from <S>(socket) since for jcode-converson
sub ipc
{
    local(*ipc, *r) = @_;
    local($err) = "Error of IPC";

    local($addrs)  = (gethostbyname($ipc{'host'} || 'localhost'))[4];
    local($proto)  = (getprotobyname($ipc{'tcp'}))[2];
    local($port)   = (getservbyname($ipc{'serve'}, $ipc{'tcp'}))[2];
    $port          = 13 unless defined($port); # default port:-)
    local($target) = pack($ipc{'pat'}, &AF_INET, $port, $addrs);

    socket(S, &PF_INET, &SOCK_STREAM, 6) || (&Log($!), return $err);
    connect(S, $target)                  || (&Log($!), return $err);
    select(S); $| = 1; select(STDOUT); # need flush of sockect <S>;

    foreach (@ipc) {
	print S $_;
	while (<S>) { $r .= $_;}
    }

    close(S);
}


# Pseudo system()
# fork and exec
# $s < $in(file) > $out(file)
#          OR
# $s < $write(file handle) > $read(file handle)
# 
# PERL:
# When index("$&*(){}[]'\";\\|?<>~`\n",*s)) > 0, 
#           which implies $s has shell metacharacters in it, 
#      execl sh -c $s
# if not in it, (automatically)
#      execvp($s) 
# 
# and wait untile the child process dies
# 
sub system
{
    local($s, $out, $in, $read, $write) = @_;
    local($c_w, $c_r) = ("cw$$", "cr$$"); # for child handles

    &Debug("system ($s, $out, $in, $read, $write)") if $debug;

    # Metacharacters check, but we permit only '|' and ';'.
    local($r) = $s;
    $r =~ s/[\|\;]//g;		
    
    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Log("System:[$s] matches the shell metacharacters, exit");
	return 0;
    }

    # File Handles "pipe(READHANDLE,WRITEHANDLE)"
    $read  && (pipe($read, $c_w)  || (&Log("ERROR pipe(pr, wr)"), return));
    $write && (pipe($c_r, $write) || (&Log("ERROR pipe(cr, pw)"), return));

    # Go!;
    if (($pid = fork) < 0) {
	&Log("Cannot fork");
    }
    elsif (0 == $pid) {
	if ($write){
	    open(STDIN, "<& $c_r") || die "child in";
	}
	elsif ($in){
	    open(STDIN, $in) || die "in";
	}
	else {
	    close(STDIN);
	}

	if ($read) {
	    open(STDOUT, ">& $c_w") || die "child out";
	    $| = 1;
	}
	elsif ($out){
	    open(STDOUT, '>'. $out) || die "out";
	    $| = 1;
	}
	else {
	    close(STDOUT);
	}

	exec $s;
	&Log("Cannot exec $s:".$@);
    }

    close($c_w) if $c_w;# close child's handles.
    close($c_r) if $c_r;# close child's handles.
    
    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
}


sub Copy
{
    local($in, $out) = @_;
    open(IN,  $in)      || (&Log("CopyIN: $!"), return);
    open(OUT, "> $out") || (&Log("CopyOUT: $!"), return);
    select(OUT); $| = 1; select(STDOUT); 
    while (<IN>) { print OUT $_;}
    close(OUT);
    close(IN); 
}


sub Move
{
    local($old, $new) = @_;

    if (-f "$new.0") { unlink "$new.0"; &Log("unlink $new.0");}
    if (-f $new)     { rename($new, "$new.0"); &Log("$new -> $new.0");}
    rename($old, $new) && &Log("$old -> $new");
}


sub Link
{
    local($old, $new) = @_;
    local($symlink_exists);
    $symlink_exists = (eval 'symlink("", "");', $@ eq "");

    if ($symlink_exists) {
	symlink($old, $new);
	&Log("ln -s $old $new");
    }
    else {
	&Log("link failed [ln -s $old $new]");
    }
}


sub SecWarn
{
    local($s);
    if ($_[0] =~ /[\#\s\w_\-\[\]\?\*\.\\\:]+/) {
	&Log("INSECURE [$_[0]] has illegal characters", "$`($&)$'");
	$s = "INSECURE WARNING\nFrom: $From_address\n\n$_[0]\nIllegal chars \"$`$'\"\n";
    }
    &Warn("Insecure [$_[0]] $ML_FN", "$s\n".('-' x 30)."\n". &WholeMail);
}


# check addr-spec in RFC822
# patched by umura@nn.solan.chubu.ac.jp 95/6/8
# return 1 if O.K. 
sub Chk822_addr_spec_P
{
    local($from) = @_;

    if ($from !~ /\@/) {
	&Log("NO \@ mark: $from");
        $Envelope{'message'} .= "WARNING From AUTO REGIST ROUTINE.\n";
        $Envelope{'message'} .= "Address [$from] contains no \@.\n";
        $Envelope{'message'} .= "\tHence, EXIT! Try Again!\n\n";
        $Envelope{'message'} .= &WholeMail;
	return 0;
    }

    1;
}


##### sendmail.cf
# $w hostname
# $j fully quarified domain name 
# $m domain mail(BSD)
#


sub DefineMacro 
{
    &Append2("\$Envelope{'macro:$_[0]'}\t= '$_[1]';", "config.ph");
    $_[1] || &Append2("1;", "config.ph");
    $Envelope{"macro:$_[0]"} = $_[1]; # return value;
}


sub Define_j { $Envelope{'macro:j'} || &DefineMacro('j', &GetFQDN);}

sub Define_m { $Envelope{'macro:m'} || &DefineMacro('m', (split(/\@/, $MAIL_LIST))[1]);} 

sub Define_s { $Envelope{'macro:s'} || &DefineMacro('s', &GetFQDN);}

sub GetFQCtlAddr 
{ 
    if ($Envelope{'macro:fqca'}) { return $Envelope{'macro:fqca'};}

    if ($CONTROL_ADDRESS && ($CONTROL_ADDRESS =~ /\@/)) {
	&DefineMacro('ca',   (split(/\@/, $CONTROL_ADDRESS))[0]); 
	&DefineMacro('fqca', $CONTROL_ADDRESS);
    }
    elsif ($CONTROL_ADDRESS) {
	&DefineMacro('ca',   $CONTROL_ADDRESS);
	&DefineMacro('fqca', "$CONTROL_ADDRESS\@".&Define_m);
    }
    else {
	$MAIL_LIST;
    }
}


# $j in /etc/sendmail.cf
# seems $DOMAIN   = (gethostbyname('localhost'))[1]; do not work
# So, we make domainname via $MAIL_LIST(must be user@domain form)
sub GetFQDN 
{
    local($domain, $hostname);

    # $m
    $domain = $Envelope{'macro:m'} || &Define_m;

    # Get HOSTNAME 
    # WARN:4.4BSD getdomainname return 'domain', but 4.3 return NIS domain
    chop($hostname = `hostname`); # must be /bin/hostname

    ($domain =~ /^$hostname/i) ? $domain : "$hostname.$domain";
}


# Generate additional information for command mail reply.
# return the STRING
sub GenInfo
{
    local($addr)  = $MAIL_LIST;
    local($s, $c, $d);
    local($del) = ('*' x 60);
    local($c)   = &GetFQCtlAddr if $CONTROL_ADDRESS;

    $s .= "\n$del\n";
    $s .= "If you have any questions or problems,\n";
    $s .= "   please make a contact with $MAINTAINER\n";
    $s .= "       or \n";
    $s .= "   send a mail with the body '# help' to \n";
    $s .= "   ".($c || $addr)."\n\n";
    $s .= "e.g. \n";
    $s .= "(shell prompt)\% echo \# help |Mail ".($c || $addr);
    $s .= "\n\n$del\n";

    $s;
}


# "# chaddr"  command
sub ChAddrModeOK
{
    local($a) = @_;
    chop $a;
    local($old, $new);
    local($addr_chk, $mem_chk);
    local($C) = 'ChAddr';

    # GET PARAM
    $a =~ /^\#\s*($CHADDR_KEYWORD)\s+(\S+)\s+(\S+)/i;
    ($old, $new) = ($2, $3);

    # NOTIFY
    $Envelope{'message:h:@to'} = "$old $new $MAINTAINER";

    &AddressMatch($old, $From_address) && $addr_chk++;
    &AddressMatch($new, $From_address) && $addr_chk++;
    &CheckMember($old, $MEMBER_LIST)   && $mem_chk++;
    &CheckMember($new, $MEMBER_LIST)   && $mem_chk++;

    &Log("$C:addr   ".($addr_chk ? "ok": "fail")) if $debug;
    &Log("$C:member ".($mem_chk  ? "ok": "fail")) if $debug;

    if ($addr_chk && $mem_chk) {
	&Log("ChAddr: Either $old and $new Authentified!");
	return 1;
    } 
    else {
	&Log("$C:addr   ".($addr_chk ? "ok\n": "fail\n"));
	&Log("$C:member ".($mem_chk  ? "ok\n": "fail\n"));
    }

    0;
}


# NAME
#      daemon - run in the background
# 
# SYNOPSIS
#     #include <stdlib.h>
#     daemon(int nochdir, int noclose)
#
# C LANGUAGE
#  f = open( "/dev/tty", O_RDWR, 0);
#  if( -1 == ioctl(f ,TIOCNOTTY, NULL))
#    exit(1);
#  close(f);
sub daemon
{
    local($nochdir, $noclose) = @_;
    local($s, @info);

    if ($ForkCount++ > 1) {	# the precautionary routine
	$s = "WHY FORKED MORE THAN ONCE"; 
	&Log($s, "[ @info ]"); 
	die($s);
    }

    if (($pid = fork) > 0) {	# parent dies;
	exit 0;
    }
    elsif (0 == $pid) {		# child is new process;
	if (! $NOT_USE_TIOCNOTTY) {
	    eval "require 'sys/ioctl.ph';";

	    if (defined &TIOCNOTTY) {
		require 'sys/ioctl.ph';
		open(TTY, "+> /dev/tty")   || die("$!\n");
		ioctl(TTY, &TIOCNOTTY, "") || die("$!\n");
		close(TTY);
	    }
	}

	close(STDIN);
	close(STDOUT);
	close(STDERR);
	return 1;
    }
    else {
	&Log("daemon: CANNOT FORK");
	return 0;
    }
}



###### EMERGENCY STOP AND RESTART
sub EmergencyNotify
{
    local($s, $b);
    $s  = $b = "Found Emergency control file, Exit!";
    $b .= "If using Remote Administration\n";
    $b .= "\t'\# admin start' command.\n"; 
    &Log($s);
    &Warn($s, $b);
}

sub EmergencyRestart 
{ 
    unlink "$TMP_DIR/emerg.stop";
    &LogWEnv("ML Server Restart!", *Envelope);
}

sub EmergencyStop  
{ 
    &Touch("$TMP_DIR/emerg.stop");
    &LogWEnv("O.K. ML Server stop!", *Envelope);
}

1;
