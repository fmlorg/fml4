#!/usr/local/bin/perl

require 'getopts.pl';
&Getopts("hbdcmsDE");

$diff             = $opt_D;
$compare_manifest = $opt_m;
$compare_smm      = $opt_s;
$debug            = $opt_d;
$brief_summary    = $opt_b;

print STDERR "

-D\tshow diff
-E\treference  with variables
-m\tcomparison with cf/MANIFEST
-s\tcomparison with doc/smm
-d\tdebug
-b\tBrief Summary

";

undef %define;

if ($compare_manifest) { &ReadMANIFEST(*define);}
if ($compare_smm)      { &ReadDocSMM(*smm);}

foreach $file (@ARGV) {
    next if $file =~ /sid\.pl$/;
    next if $file =~ /^sim\.pl$/;
    next if $file =~ /libcompat_cf1\.pl/;
    next if $file =~ /libcompat\S+\.pl/;
    next if $file =~ /libcompat\.pl/;
    next if $file =~ /libkern\.pl/;
    next if $file =~ /fwix\.pl/;

    open(F, $file) || next;
    while (<F>) {
	next if /^\s*\#/;

	while (s/([\$\@\%])\{([A-Z][\w\d\_]+)\}/$1$2/g) {1;}

	# s/([\$\@\%][A-Z][A-Z0-9\_]+[a-z]+)/print "--DELETE $1\n"/eg;
	s/[\$\@\%][A-Z][A-Z0-9\_]+[a-z]+//g;

	# special eval \$FP_\$ (fml.pl)
	s/[\$\@\%][A-Z][A-Z0-9\_]+\$//g;

	# $var[], $var{} syntax;
	while (s/\$([A-Z][A-Z0-9\_]+)\{/$var{"\%$1"} .= "$file "/e) { 1;}
	while (s/\$([A-Z][A-Z0-9\_]+)\[/$var{"\@$1"} .= "$file "/e) { 1;}

	# $var @var %var
	while (s/([\$\@\%][A-Z][A-Z0-9\_]+)/$var{$1} .= "$file "/e) { 1;}
    }
}

if ($diff && (!$opt_E)) {
    print "Variable REFERENCE WARNING(diff mode -D):\n\n";
}
elsif ($diff && $opt_E) {
    print "Variable REFERENCE WARNING (O.K. if somewhere refered -D -E):\n\n";
}


while (($key, $value) = each %var) {
    next if $diff  && $define{$key} && $smm{$key};
    next if $opt_E && ($define{$key} || $smm{$key});

    printf "\n%s\n", $key;

    if ($define{$key}) { print "\tDEFINED in cf/MANIFEST\n";}
    if ($smm{$key}) { print "\tDEFINED in doc/smm{".$smm{$key}."}\n";}

    undef $prev;
    for (split(/\s+/, $value)) {
	next if $prev eq $_;
	printf "%-30s %s\n", "", $_;
	$prev = $_;
    }

}

exit 0;

sub ReadMANIFEST
{
    local(*define, $file) = @_;
    local($key, $local_config);

    foreach ($file, './cf/MANIFEST', './MANIFEST') { 
	-f $_ && ($file = $_, last);
    }

    open(MANIFEST, $file) || die "CANNOT OPEN $file\n";
    select(MANIFEST); $| = 1; select(STDOUT);

    print STDERR "MANIFEST: $file\n\n";

    while (<MANIFEST>) {
	next if /^\#C\s+/i;

	undef $local_config if /^(INFO|FML_CONFIG|LOCAL_CONFIG):/;

	if (/^LOCAL_CONFIG/) {
	    $local_config = 1;
	    push(@order, "LOCAL_CONFIG");
	    next;
	}

	if ($local_config) {
	    $value{"LOCAL_CONFIG"} .= $_;
	    next;
	}
	elsif (/^(\S+):\s*(.*)/) {	# VARIABLE NAME: DEFAULT VALUE
	    $key = $1;
	    $define{"\$$key"} = 1;
	    # print STDERR "\$define{\$$key} = 1;\n";
	    # print STDERR "\$define{\$$key} = 1;\n"; # beth
	}
    }
    
    close(MANIFEST);
}


sub ReadDocSMM
{
    local(*smm) = @_;

    opendir(DIRD, 'doc/smm') || die $!;

    foreach $file (readdir(DIRD)) {
	next if $file =~ /^\./;
	next if $file !~ /\.wix$/;

	open(F, "doc/smm/$file") || next;
	while (<F>) {
	    next if /^\s*\#/;
	    while (s/([\$\@\%][A-Z][A-Z0-9\_]+)/&add(*smm, $1, $file)/e) {1;}
	}
    }
}

sub add
{
    local(*smm, $k, $file) = @_;

    #print "[$k] ($file)\n";

    if ($smm{$k} !~ /$file/) {
	$smm{$k} .= "$file ";
    }
}

1;
