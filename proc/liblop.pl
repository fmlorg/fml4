# Local and Log OPerations
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


local($id);

$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");
$Rcsid =~ s/\#:/(fml command mode)#:/;


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
    local($s, $rcpt, $opt, $d, $mode);
    
    &use('utils');

    open(ACTIVE_LIST, $ACTIVE_LIST) || 
	(&Log("cannot open $ACTIVE_LIST when $ID:$!"), return "No Match");

    &Log("Status [$who]");

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

    $s ? $s : "$who is NOT matched\n";
}


1;
