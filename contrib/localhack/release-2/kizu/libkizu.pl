#! /usr/local/bin/perl
# Copyright (C) 1997 kizu@ics.es.osaka-u.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid  .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

if ($0 eq __FILE__) {
    exit 0;
}

# sub AddressMatching($addr1, $addr2, $expanded)
# if (! $expanded) then
#     return 1 given addresses are matched
#              at the accuracy of $ADDR_CHECK_MAX or 3 fields
# if ($expanded) then
#      return 1 if ((both local-parts match exactly)
#           && (domain part of $addr2 under domain part of $addr1))
sub AddressMatching { &AddressMatch(@_);}
sub AddressMatch
{
    local($addr1, $addr2, $expanded) = @_;
    local($accuracy);

    # canonicalize to lower case
    $addr1 =~ y/A-Z/a-z/;
    $addr2 =~ y/A-Z/a-z/;

    # try exact match. must return here in a lot of cases.
    if ($addr1 eq $addr2) {
	&Debug("\tFAddr::match { Exact Match;}") if $debug;
	return 1;
    }

    # for further investigation, parse account and host
    local($acct1, $addr1) = split(/@/, $addr1);
    local($acct2, $addr2) = split(/@/, $addr2);

    # At first, account is the same or not?;    
    if ($acct1 ne $acct2) { return 0;}

    # Get an array "jp.ac.titech.phys" for "fukachan@phys.titech.ac.jp"
    local(@d1) = reverse split(/\./, $addr1);
    local(@d2) = reverse split(/\./, $addr2);

    if (! $expanded) {
	$accuracy = ($ADDR_CHECK_MAX || 3);
    } else {
	$accuracy = @d1;
    }

    # Check only "jp.ac.titech" part( = 3)(default)
    # If you like to strict the address check, 
    # change $ADDR_CHECK_MAX = e.g. 4, 5 ...
    local($i) = 0;
    while ($d1[$i] && $d2[$i] && ($d1[$i] eq $d2[$i])) { $i++;}

    &Debug("\tFAddr::match { $i >= $accuracy;}") if $debug;

    ($i >= $accuracy);
}

# sub CheckFromInFile($addr, $file)
# return 1 if "From: " in $file and $addr matched
sub CheckFromInFile
{
    local($addr, $file) = @_;

    local($field, $contents);
    local($filefromaddr);

    open(CHECKFILE, $file) || (&Log($!), return 0);
    while(<CHECKFILE>) {
	chop;
	if (/^\s+\S/) {
	    chop;
	    $field =~ /^From$/i && ($filefrom .= "\n$_");
	} else {
	    ($field, $contents) = /^([^: ]*): *(.*)/;
	    $field =~ /^From$/i && ($filefrom = $contents);
	}
	last if (/^$/);
    }
    close(CHECKFILE);
    if ( $filefrom =~ /<(\S+@\S+)>/) {
	$filefromaddr = $1;
    } elsif ( $filefrom =~ /(\S+@\S+)/ ){
	$filefromaddr = $1;	
    }
    return(&AddressMatch($filefromaddr, $addr, 1));
}

sub ProcMySummary
{
    local($proc, *Fld, *e, *misc) = @_;
    local($s) = $e{'r:Subject'};

    if ($Fld[2] && ($proc eq 'summary')) {
	&Mesg(*e, "\n>>> $proc $Fld[2]\n");
	&MySearchKeyInSummary(*e, $Fld[2], 's');
	&Log(($s && "$s ")."Restricted Summary [$Fld[2]]");
    }
    elsif ($Fld[2] && ($proc eq 'list')) {
	&Mesg(*e, "\n>>> $proc $Fld[2]\n");
	&MySearchKeyInSummary(*e, $Fld[2], 'rs');
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


sub MySearchKeyInSummary
{
    require 'jcode.pl';
    local($a, $b, $buf);
    local(*e, $s, $fl) = @_;

    if ($fl eq 's') {
	;
    }
    elsif ($s =~ /^(\d+)\-(\d+)$/) {
	$a = $1; 
	$b = $2; 
	if (($b - $a + 1) > $MAIL_LENGTH_LIMIT) {
	    &Mesg(*e, "Restricted Summary: too many lines you want.\n");
	    &Mesg(*e, "send top $MAIL_LENGTH_LIMIT lines.");
	    $b = $a + $MAIL_LENGTH_LIMIT -1;
	}
    }
    elsif ($s =~ /^last:(\d+)$/) {
	if ($1 > $MAIL_LENGTH_LIMIT) {
	    &Mesg(*e, "Restricted Summary: too many lines you want.\n");
	    &Mesg(*e, "send top $MAIL_LENGTH_LIMIT lines.");
	    $s = "last:$MAIL_LENGTH_LIMIT";
	}
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
	local($lc) = 0;
	&jcode'jis2euc(*s);
	while (<TMP>) {
           &jcode'jis2euc(*_);
           if (/$s/i) {
              &jcode'euc2jis(*_);
	      &Debug("\tMySearchKeyInSummary::line \"$_\"") if $debug;
              $buf .= $_;
              if ($lc++ > $MAIL_LENGTH_LIMIT) {
	         &Mesg(*e, "Restricted Summary: too many lines you want");
	         &Mesg(*e, "send top $MAIL_LENGTH_LIMIT lines.");
                 last;
              }
           }
        }
	&Mesg(*e, $buf);
    }
    close(TMP);
}

sub SecureP 
{ 
    local($s) = @_;

    $s =~ s#(\w)/(\w)#$1$2#g; # permit "a/b" form

    return(1) if ($s =~ /^#\s*summary/);

    # permit m=12u; e.g. admin subscribe addr m=1;
    # permit m=12 for digest format(subscribe)
    $s =~ s/\s+m=\d+/ /g; $s =~ s/\s+[rs]=\w+/ /g;
    $s =~ s/\s+[rms]=\d+\w+/ /g; 

    if ($s =~ /^[\#\s\w\-\[\]\?\*\.\,\@\:]+$/) {
	1;
    }
    else {
	&Log("SecureP: Security Alert for [$s]", "[$s] ->[($`)<$&>($')]");
	$s = "Security alert:\n\n\t$s\n\t[$'$`] HAS AN INSECURE CHAR\n";
	&Warn("Security Alert $ML_FN", "$s\n".('-' x 30)."\n". &WholeMail);
	0;
    }
}
1;
