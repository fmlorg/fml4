# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


sub SubstituteTemplate
{
    local($s, *template_cf) = @_;

    print STDERR "subs tmpl: $s -> " if $debug;
    for (keys %template_cf) { $s =~ s/$_/$template_cf{$_}/g;}
    print STDERR "$s\n" if $debug;
    $s;
}


sub MIMESubstitute
{
    local($type, *mib) = @_;

    if ($type eq 'message/partial') {
	$Envelope{'GH:Content-Type:'} =~ s/number=\d+/number=$mib{'number'}/;
	$Envelope{'GH:Content-Type:'} =~ s/total=\d+/total=$mib{'total'}/;
    }
    else {
	&Log("MIMESubstitute: unknown type");
    }
}



# Get a option value for msend..
# Parameter = opt to parse
# If required e.g. 3mp, parse to '3' and 'mp', &ParseM..('mp')
# return option name || NULL (fail)
sub ParseMSendOpt
{
    local($opt) = @_;
    local($key);

    foreach $key (keys %MSendOpt) {
	return $MSendOpt{$key} if $opt eq $key;
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
	return $NULL if $NotShowDocMode;
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
		 'lhaish',  'lhaish',
		 'wait#lhaish', 1,
		 
		 '#zip',    '#zip',
		 'zip',     'zip',


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
		 'rfc1153', 'rfc1153',

		 'base64',  'base64',
		 '#base64',  '#base64',
		 );

    $MSEND_OPT_HOOK && &eval($MSEND_OPT_HOOK, 'MSendModeSet:');
}


# msend.pl uses this prototype generator.
sub GetProtoByMode
{
    local($type, $mode) = @_;

    if ($type =~ /matome/) {
	$mode =~ /tgz/ ? "matome.tar.gz" : "matome.gz";
    }
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
    local($buf, $buffer, $totalsize);
    local($tmptotal) = 1;
    
    &DiagPrograms('ZCAT');

    &Debug("TarZXF local($tarfile, $total, ". 
	join(" ", keys %cat) .", $outfile)\n") if $debug;
    
    # check the setting on ZCAT
    local($gzip);
    if (! $ZCAT) { &Log("Error: \$ZCAT NOT DEFINED"); return "";}
    ($gzip) = split(/\s+/, $ZCAT);
    if (!-x $gzip) { &Log("Error: ZCAT[$gzip] NOT EXISTS"); return "";}
    
    if ($tarfile =~ /\.(gz|z|Z)$/) {
	open(TAR, "$ZCAT $tarfile|") || (&Log("$!:$ZCAT $tarfile"), return "");
    }
    else {
	open(TAR, $tarfile) || &Log("TarZXF: Cannot open $tarfile: $!");
    }

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
	&Debug("  Detected $name") if $debug;
	local($catit) = $cat{$name};
	&Debug("\nExtracting $name ...") if $debug && $catit;

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
		    $B =~ s/Return\-Path:.*\n/From $MAINTAINER $MailDate\n/;
		    print OUT $B;
		}
		else {
		    $buffer .= substr($buf, 0, $size);
		}
	    }

	    $size -= $bufsize;
	}
	
	print OUT "\n" if $catit;# \nFrom UNIX-FROM;

	if ($catit && ! --$total) {
	    close TAR;
	    close OUT;
	    return $outfile ? $tmptotal : $buffer;
	}
    }# end of Tar extract
    
    close TAR; 
    close OUT;

    return $outfile ? $tmptotal : $buffer;
}

# InterProcessCommunication
# return the answer from <S>(socket) since for jcode-converson
sub ipc
{
    local(*ipc, *r) = @_;
    local($err)     = "Error of IPC";

    local($addrs)  = (gethostbyname($ipc{'host'} || 'localhost'))[4];
    local($proto)  = (getprotobyname($ipc{'tcp'} || 'tcp' ))[2];
    local($port)   = (getservbyname($ipc{'serve'}, $ipc{'tcp'}))[2];
    $port          = 13 unless defined($port); # default port:-)
    local($target) = pack($ipc{'pat'}, &AF_INET, $port, $addrs);

    socket(S, &PF_INET, &SOCK_STREAM, $proto) || (&Log($!), return $err);
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

    if ($debug) {
	print STDERR "\nsystem ($s, $out, $in, $read, $write)\n".
	    "exec:\t$s\nout:\t$out\nin:\t$in\n".
		"read:\t$read\nwrite:\t$write\n\n";
    }

    # Metacharacters check, but we permit only '|' and ';'.
    local($r) = $s;
    $r =~ s/[\|\;]//g;		
    
    if ($r =~ /[\$\&\*\(\)\{\}\[\]\'\\\"\;\\\\\|\?\<\>\~\`]/) {
	&Log("System:[$s] matches the shell metacharacters, exit");
	return 0;
    }

    # Windows NT ;_; TOO BAD! ;_;;_;;_;
    # Here is after fundamental check anyway (is a little hope;D
    if (! $UNISTD) { 
	$s =~ s#/#\\#g;
	system($s); 
	return $@;
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

	exec $s || &Log("Cannot exec $s:".$@);
    }

    close($c_w) if $c_w;# close child's handles.
    close($c_r) if $c_r;# close child's handles.
    
    # Wait for the child to terminate.
    while (($dying = wait()) != -1 && ($dying != $pid) ){
	;
    }
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


sub CleanUpDirectory
{
    local($dir) = @_;

    if (opendir($dir, $dir)) {
	while ($_ = readdir($dir)) {
	    next if /^\./;
	    unlink "$dir/$_" if -f "$dir/$_";
	}
	closedir($dir);
    }
    else {
	&Log("cannot opendir $dir");
    }
}


##### sendmail.cf
# $w hostname
# $j fully quarified domain name 
# $m domain mail(BSD)
#
sub Define_j { $FQDN;}
sub Define_m { $DOMAINNAME;}
sub Define_s { $FQDN;}


# "# chaddr"  command
sub ChAddrModeOK
{
    local($a) = @_;
    local($old, $new, $addr_chk, $mem_chk);
    local($C) = 'ChAddrModeOK';

    # GET PARAM
    # XXX: "# command" is internal represention
    # XXX: remove '# command' part if exist (since not use it here directly)
    $a =~ /^\#\s*($CHADDR_KEYWORD)\s+(\S+)\s+(\S+)/i;
    ($old, $new) = ($2, $3);

    # NOTIFY
    $Envelope{'message:h:@to'} = "$old $new $MAINTAINER";

    $addr_chk = $mem_chk = 0;
    &AddressMatch($old, $From_address) && $addr_chk++;
    &AddressMatch($new, $From_address) && $addr_chk++;
    &MailListMemberP($old) && $mem_chk++;
    &MailListMemberP($new) && $mem_chk++;

    &Log("$C:addr   ".($addr_chk ? "ok": "fail")) if $debug;
    &Log("$C:member ".($mem_chk  ? "ok": "fail")) if $debug;

    if ($addr_chk && $mem_chk) {
	&Log("$C: Either $old or $new Authenticated!");
	return 1;
    } 
    else {
	&Log("$C:addr   ".($addr_chk ? "ok": "fail"));
	&Log("$C:member ".($mem_chk  ? "ok": "fail"));
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

1;

