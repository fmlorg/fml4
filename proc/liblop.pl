# Local and Log OPerations
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$;

sub DoSummary
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s) = $e{'r:Subject'};

    if ($Fld[2] && ($proc eq 'search')) {
	&Mesg(*e, "\n>>> $proc key=$Fld[2] in summary file\n");
	&SearchKeyInSummary(*e, $Fld[2], 's');
	&Log(($s && "$s ")."Search [$Fld[2]]");
    }
    elsif ($Fld[2] && ($proc eq 'summary')) {
	&Mesg(*e, "\n>>> $proc $Fld[2]\n");
	&SearchKeyInSummary(*e, $Fld[2], 'rs');
	&Log(($s && "$s ")."Restricted Summary [$Fld[2]]");
    }
    else {
	$s = ($s || "Summary");
	&Log($s);

	local($lc);
	if (open(F, $SUMMARY_FILE)) { while (<F>) { $lc++;}}
	&Debug("$lc > $MAIL_LENGTH_LIMIT") if $debug;

	if ($lc > $MAIL_LENGTH_LIMIT) {	# line count > MAIL_LENGTH_LIMIT;
	    &use('sendfile');
	    &SendFilebySplit($SUMMARY_FILE, 'uf', $s, $e{'Addr2Reply:'});
	}
	else {
	    &SendFile($e{'Addr2Reply:'}, "$s $ML_FN", $SUMMARY_FILE);
	}
    }
}


# "rsummary" command
# search keyword in summary 
# return NONE
sub SearchKeyInSummary
{
    local($a, $b, $buf);
    local(*e, $s, $fl) = @_;

    if ($fl eq 's') {
	;
    }
    elsif ($s =~ /^(\d+)\-(\d+)$/) {
	$a = $1; 
	$b = $2; 
    }
    elsif ($s =~ /^last:\d+$/) {
	($a, $b) = &GetLastID($s);
    }
    else {
	&Mesg(*e, "Restricted Summary: the parameter not matched");
	return;
    }

    open(TMP, $SUMMARY_FILE) || do { &Log($!); return;};
    if ($fl eq 'rs') {
	while (<TMP>) { if (/\[$a:/ .. /\[$b:/) { $buf .= $_;}}
	&Mesg(*e, $buf);
    }
    elsif ($fl eq 's') {
	while (<TMP>) { if (/$s/) { $buf .= $_;}}
	&Mesg(*e, $buf);
    }
    close(TMP);
}


# Status of actives(members) files
# return the string of the status
sub MemberStatus
{
    local($who) = @_;
    local($r);
    local(@file) = @ACTIVE_LIST;

    &Log("Status [$who]");

    &use('utils');

    &Uniq(*file);
    for (@file) { $r .= &DoStatusInFile($who, $_);}

    $r ? $r : "$who is NOT matched\n";
}

sub DoStatusInFile
{
    local($who, $file) = @_;
    local($s, $rcpt, $opt, $d, $mode);

    open(ACTIVE_LIST, $file) || 
	(&Log("cannot open $ACTIVE_LIST when $ID:$!"), return "No Match");

    in: while (<ACTIVE_LIST>) {
	next if /^\#\#/o;
	chop;

	undef $sharp;
	/^\#\s*(.*)/ && do { $_ = $1; $sharp = 1;};

	# Backward Compatibility.	
	s/\smatome\s+(\S+)/ m=$1 /i;
	s/\sskip\s*/ s=skip /i;
	($rcpt, $opt) = split(/\s+/, $_, 2);
	$opt = ($opt && !($opt =~ /^\S=/)) ? " r=$opt " : " $opt ";

	if ($rcpt =~ /$who/i) {	# koyama@kutsuda.kuis 96/01/30
	    $s .= "$rcpt:\n";
	    $s .= "\tpresent not participate in. (OFF)\n" if $sharp;

	    $_ = $opt;

	    /\sr=(\S+)/ && ($s .= "\tRelay server is $1\n"); 
	    /\ss=/      && 
		($s .= "\tNOT delivered here, but can post to $ML_FN\n");

	    # KEY MARIEL;
	    if (/\sm=(\S+)\s/o) {
		($d, $mode) = &ModeLookup($1);
		$s   .= "\tMATOME OKURI mode = ";

		if ($d) {
		    $s .= &DocModeLookup("\#$d$mode");
		}
		else {
		    $s .= "Realtime Delivery";
		}

		$s .= "\n";
	    }
	    # REALTIME
	    else {
		$s .= "\tRealtime delivery\n";
	    }

	    $s .= "\n";
	}
    }

    close(ACTIVE_LIST);
    $s;
}


sub ResentForwFileInSpool
{
    local($proc, *Fld, *e, *misc, *cat, $ar, $mail_file) = @_;
    local($buffer, $header, $body, $subject, %org_e);

    # backup and reset;
    undef @ResentHdrFieldsOrder;
    for (keys %e) { 
	next unless /^GH:/;
	$org_e{$_} = $e{$_};
	undef $e{$_};
    }

    # for tar.gz syntax;
    $cat{"$SPOOL_DIR/$ID"} = 1;

    if ($ar eq 'TarZXF') {  
	&use('utils');
	$buffer = &TarZXF("$DIR/$mail_file", 1, *cat);

	if (! $buffer) { # empty;
	    &Log("Not found Article $ID");
	    &Log("Get $ID, Fail");
	    return $NULL;
	}
	else {
	    ($header, $body) = split(/\n\n/, $buffer, 2);
	}
    }
    else {
	if (open(ARTICLE, "$DIR/$mail_file")) {
	    while (<ARTICLE>) {
		if (1 .. /^$/) { 
		    $header .= $_ unless /^$/o;
		}
		else {
		    $body .= $_;
		}
	    }
	    close(ARTICLE);
	}
	else {
	    &Log("Cannot open Article $ID");
	    &Log("Get $ID, Fail");
	}
    }

    # Get Header;
    $header = "From $MAINTAINER $MailDate\n$header";
    $header =~ s/\n(\S+):/\n\n$1:\n\n/g;
    for (@Hdr = split(/\n\n/, "$header#dummy\n"), 
	 $_ = $field = shift @Hdr; #"From "
	 @Hdr; 
	 $_ = $field = shift @Hdr, $contents = shift @Hdr) {
	next if /^From\s+(\S+)/i;
	next if /^\s*$/o;

	# &GenerateHeader is to a new header not reuse;
	$contents =~ s/^\s*//;	
	$e{"GH:$field"} .= $e{"GH:$field"} ? "\n${_}$contents" : $contents;

	# conserve the original header information
	$field =~ s/://;
	push(@ResentForwHdrFieldsOrder, $field);
    }

    # Resent;
    $e{"GH:Resent-From:"} = $MAINTAINER;
    $e{"GH:Resent-To:"}   = $e{'Addr2Reply:'};
    $e{"GH:Resent-Date:"} = $MailDate;
    $e{"GH:Resent-Message-Id:"} = "<$CurrentTime.FML$$\@$FQDN>";

    # sleepy@maekawa.is.uec.ac.jp 97/02/02
    for (('Resent-From','Resent-To', 'Resent-Date', 'Resent-Message-Id')) {
	push(@ResentForwHdrFieldsOrder, $_);
    }

    # rewritten ?;
    # $e{'GH:Subject:'} = "Get $ID $ML_FN\n\t".$e{'GH:Subject:'};

    &Sendmail($e{'Addr2Reply:'}, "", $body);

    # reset for the sequel actions and restore backup
    for (@ResentForwHdrFieldsOrder) { 
	print STDERR "undef \$Envelope{\"GH:$_:\"};\n" if $debug;
	undef $Envelope{"GH:$_:"};
    }

    for (keys %org_e) { $Envelope{$_} = $org_e{$_};}
    undef @ResentForwHdrFieldsOrder; # staced entry

    &Log("Get $ID, Success");
}

1;
