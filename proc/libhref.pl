# Library of fml.pl 
# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");


sub HRefInit { require 'jcode.pl'; &SocketInit;}


sub Http { &HRef(@_);}
sub HRef
{
    local($_, *e) = @_;
    local($host, $port, $request, $tp, $hp);

    &HRefInit;

    ### PARSING
    # http://www.phys.titech.ac.jp/... -> (http, www.phys.titech.ac.jp/...)
    if (/(\S+):\/\/(\S+)/) {
	$tp = $1;# http, gopher, ftp...     ;
	$hp = $2;# www.phys.titech.ac.jp/...;
    }
    else {
	&LogWEnv("Illegal HRef [$_]", *e);
	return;
    }# "split http://host (http, host, ...);;";

    ### Get REQUEST 
    foreach (split(/\//, $hp)) { # www.phys.titech.ac.jp/...
	if (! $host) { 
	    $host = $_;
	    s/(\S+):(\d+)/$host = $1, $port = $2/e;# $host:80
	    next;# get host entry and go next!;
	}

	$request .= "/".$_;	 
    }

    ### Calling
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

	$request =~ s#^/##;
	&TalkWithHttpServer($host, $port, $request, $tp, *e); 
    }
    elsif ($tp =~ /ftp/i) {
	&use('ftp');

	if ($host eq $Envelope{'macro:s'}) {# myown;
	    &Ftp;
	}
	else {
	    &Ftpmail(*e, $host, $request);
	}
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

    ### IPC
    if (socket(S, &PF_INET, &SOCK_STREAM, 6) && connect(S, $target)) {
	select(S); $| = 1; select(STDOUT); # need flush of sockect <S>;

	### INPUT 
	if ($tp eq 'http') {
	    print S "GET $body\n"; 
	}
	else {
	    print S "$body\n";
	}


	### RETRIEVE (sysread for binary)
	while (sysread(S, $_, 4096)) { print HOUT $_;}

	### CLOSE 
	close(HOUT);
	close(S);


	### SPECIAL for bin/geturl.pl
	$e{'special:geturl'} && (return $e{'special:geturl'} = $tmpf);

	
	### PLAIN TEXT FILE
	if (-T $tmpf) {
	    if (! open(HIN, $tmpf)) {
		$re{'message'} .= "canont open tmpf"; 
		return;
	    }

	    while (<HIN>) { 
		# next if /^\.$/o; # skip for sendmail

		s/\015//g; # cut "\m";

		# fix for each href type
		# e.g. "1AIKO 1/AIKO axion.phys.titech.ac.jp 1070"
		if ($tp =~ /gopher/io ) {
		    /\d(\S+)\s+\d(\S+)\s+(\S+)\s+(\d+)/;
		    $_ = "$host:$port/$body/$1\n";
		    s#//#/#g;
		    $_ = "gopher://$_";
		}

		# Append Body to reply.
		&jcode'convert(*_, 'jis');# KANJI CONVERSION. ';
		$re{'message'} .= $_;
	    }
	    close(HIN);
	}
	### BINARY FILE 
	else {
	    local($name) = reverse split(/\//, $body);
	    if (! (open(HIN,"-|") || exec $UUENCODE, $tmpf, $name)) {
		$re{'message'} .= "canont open tmpf"; 
		return;
	    }
	    while (<HIN>) { $re{'message'} .= $_;}
	    close(HIN);
	}
    } 
    # fails 'socket() or connect()'
    else { 
	&LogWEnv("Cannot connect $host", *re);
    }

    unlink $tmpf unless $debug;
}

1;
