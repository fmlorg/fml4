require 'sys/socket.ph';
$HTMLDIR = "/usr/tmp";
$RECURSIVE = 30;
$LEVEL = 1;
$OriginalURL = "http://www.phys.titech.ac.jp/uja/";

$d = &Http($OriginalURL);

foreach(split(/\n/, $d, 9999)) {
    /\<A\s+HREF=\s*(\S+)\>/ && do {
	# print $_, "\t", $1, "\n";
	print $1, "\n";
    }
}

exit 0;




sub WriteHtml 
{
    local($html, $original, $_) = @_;

    print STDERR "W ($html\t$original)\n";

    if("" eq $LogHtml{$original}) {
	$LogHtml{$original} = $html;
    }else { # already exist
	return $LogHtml{$original};
    }

    open(HTML, "> /usr/tmp/$html");
    print HTML "$_\nOriginal URL is $original\n";
    close(HTML);

    return $html;
}


sub Http
{
    local($_) = @_;
    local($host, $port, $tp, $REQUEST, $tp, $hp);

    if(/(\S+):\/\/(\S+)/) {
	$tp = $1;# http, gopher, ftp...
	$hp = $2;# http://www.phys.titech.ac.jp/...
	$GOPHER = 1 if($tp =~ /gopher/i);
	$HTTP   = 1 if($tp =~ /http/i);

	foreach (split(/\//, $hp, 999)) {
	    if(! $host) { 
		$host = $_;

		if($host =~ /(\S+):(\d+)/) {
		    $host = $1;
		    $port = $2;
		}

		next;
	    }

	    $REQUEST .= "/".$_;	 
	}
	
    }else {
	print STDERR "$_\n";
    }

    if($HTTP) {
	$host = $host ? $host : $DEFAULT_HTTP_SERVER;
	$port = $port ? $port : 80;
    }elsif($GOPHER) {
	$host = $host ? $host : $DEFAULT_GOPHER_SERVER;
	$port = $port ? $port : $DEFAULT_GOPHER_PORT;
    }

    if($HTTP) {
	# connect http server
	print STDERR "($host, $port, $REQUEST)\n"; 
	return &talkHttp($host, $port, $REQUEST, $tp); 
    }elsif($GOPHER) {
	print STDERR "($host, $port, $REQUEST)\n"; 
	local($r);
	$r  = ">>>PLAIN TEXT(Begin with 0)\n\n";
	$r .= &talkHttp($host, $port, "0$REQUEST", $tp);
	$r .= ">>>DIRECTORY(Begin with 1)\n\n";
	$r .= &talkHttp($host, $port, "1$REQUEST", $tp); 
	return $r;
    }else {
	$REQUEST =~ s/^\///;
    }

}


sub talkHttp # ($host, $headers, $body)
{
    local($host, $port, $body, $tp) = @_;
    local($pat)  = 'S n a4 x8';
    local($ANSWER);

    print STDERR "talkHttp local($host, $port, $body, $tp)\n";

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

	if($tp =~ /http/io) {
	    print S "GET $body\n";
	}elsif($tp =~ /gopher/io) {
	    $gopherflag = 1;
	    $gopherflag = 0 if $body =~ /^0/;
	    print S "$body\n";
	}else {
	    print S "$body\n";
	}

	while(<S>) { 
	    s/\015/\012/g;
	    next if /^\.$/o;	# skip for sendmail
	    if($HTTP) {
		$ANSWER .= $_;
	    }

	    if($GOPHER) {
		if(! $gopherflag) {
		    s/\064//g;
		    $ANSWER .= $_;
		}else {
		    /^\d\S+\s+(\S+)/;
		    $ANSWER .= "$1\n";
		}
	    }
	}
	close S;

	return "$ANSWER\n";
    } else { &Logging("Cannot connect $host");}
}

# FOR DEBUG
if($0 =~ __FILE__) {
    &RecursiveHttp(<>);
#    print &Http(<>);
}

1;
