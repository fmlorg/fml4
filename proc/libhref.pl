# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

require 'sys/socket.ph';
require 'jcode.pl';

sub Http { &HRef(@_);}
sub HRef
{
    local($_, *e) = @_;
    local($host, $port, $request, $tp, $hp);

    # http://www.phys.titech.ac.jp/... -> (http, www.phys.titech.ac.jp/...)
    if (/(\S+):\/\/(\S+)/) {
	$tp = $1;# http, gopher, ftp...     ;
	$hp = $2;# www.phys.titech.ac.jp/...;
    }
    else {
	&LogWEnv("Illegal HRef [$_]", *e);
	return;
    }# "split http://host (http, host, ...);;";
	
    foreach (split(/\//, $hp)) { # www.phys.titech.ac.jp/...
	if (! $host) { 
	    $host = $_;
	    s/(\S+):(\d+)/$host = $1, $port = $2/e;# $host:80
	    next;# get host entry and go next!;
	}

	$request .= "/".$_;	 
    }

    # Calling
    if ($tp =~ /http/i) {
	$host = $host || $DEFAULT_HTTP_SERVER;
	$port = $port || $DEFAULT_HTTP_PORT || 80;

	# connect http server
	$e{'message'} .= ">>> HREF=$tp://$host$request\n\n";
	&TalkWithHttpServer($host, $port, $request, $tp, *e); 
	$e{'message'} .= ">>> ENDS HREF=$tp://$host$request\n\n";
    } 
    elsif ($tp =~ /gopher/i) {
	$host = $host || $DEFAULT_GOPHER_SERVER;
	$port = $port || $DEFAULT_GOPHER_PORT || 70;

	$e{'message'} .= ">>>PLAIN TEXT(Begin with 0)\n\n";
	&TalkWithHttpServer($host, $port, "0$request", $tp, *e); 

	$e{'message'} .= ">>>DIRECTORY(Begin with 1)\n\n";
	&TalkWithHttpServer($host, $port, "1$request", $tp, *e); 
    }
    else {
	$e{'message'} .= ">>>Sorry.\n\t$tp://$host... is NOT IMPLEMENTED\n\n";
    }
}


sub TalkWithHttpServer
{
    local($host, $port, $body, $tp, *re) = @_;
    local($pat)  = 'S n a4 x8';
    local($addrs, $target, $tmpf);

    &Debug("TalkWithHttpServer($host, $port, $body, $tp, *re)") if $debug;

    # set variables
    $tmpf  = "$TMP_DIR/href:$$";
    $addrs  = (gethostbyname($host || 'localhost'))[4];
    $port   = 80 unless defined($port); # default port
    $target = pack($pat, &AF_INET, $port, $addrs);

    # temporary
    if (! open(HOUT, "> $tmpf")) { 
	select(HOUT); $| = 1; select(STDOUT);
	&Log("Cannot open $tmpf"); 
	$re{'message'} .= "Cannot write to tmporary file\n"; 
    }

    # IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, 6) && connect(S, $target)) {
	select(S); $| = 1; select(STDOUT); # need flush of sockect <S>;

	if ($tp =~ /http/io) {
	    print S "GET $body\n";
	}
	elsif ($tp =~ /gopher/io) {
	    $gopherflag = 1;
	    $gopherflag = 0 if $body =~ /^0/o;
	    print S "$body\n";
	}
	else {
	    print S "$body\n";
	}

	while(<S>) { 
	    s/\015//g;
	    next if /^\.$/o;	# skip for sendmail
	    &jcode'convert(*_, 'jis');# KANJI CONVERSION.;

	    if ($tp =~ /http/io) {
		print HOUT $_;
	    }
	    elsif ($tp =~ /gopher/io) {
		if(! $gopherflag) {
		    s/\064//g;
		    print HOUT $_;
		}
		else {
		    /^\d\S+\s+(\S+)/;
		    print HOUT "$1\n";
		}
	    }
	}# while;

	close HOUT;
	close S;
	
	if (-T $tmpf) {
	    if (! open(HIN, $tmpf)) {
		$re{'message'} .= "canont open tmpf"; 
		return;
	    }
	    while (<HIN>) { $re{'message'} .= $_;}
	    close(HIN);
	}
	else {
	    local($name) = reverse split(/\//, $body);
	    if (! open(HIN, "$UUENCODE $tmpf $host:$name|")) {
		$re{'message'} .= "canont open tmpf"; 
		return;
	    }
	    while (<HIN>) { $re{'message'} .= $_;}
	    close(HIN);
	}
    } 
    # fails of socket or connect
    else { 
	&LogWEnv("Cannot connect $host", *re);
    }
}

1;
