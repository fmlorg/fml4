#!/usr/local/bin/perl
#
# $FML: showvar.pl,v 1.1 2001/09/29 13:26:17 fukachan Exp $
#

my %define = {};
my %var    = {};

for my $file (<kern/* proc/*>) {
    next if $file =~ /libcompat/;
    next if $file =~ /libkern\.pl/;
    next if $file =~ /fwix\.pl/;

    read_file($file, \%var);
}

read_manifest(\%define);

init_ignore_list(\%define);

while (($key, $value) = each %var) {
    next if $key =~ /HOOK/;

    unless ($define{$key}) { 
	print $key, "\n";
    }
}

exit 0;

sub read_manifest
{
    my ($define, $file) = @_;
    my ($local_config);

  FIND_MANIFEST:
    foreach ($file, './cf/MANIFEST', './MANIFEST') { 
	if (-f $_) { 
	    $file = $_; 
	    last FIND_MANIFEST;
	}
    }

    use FileHandle;
    my $fh = new FileHandle $file;

    if (defined $fh) {
	print STDERR "MANIFEST: $file\n\n";

	while (<$fh>) {
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
		$define->{ '$'.$1 } = 1;
	    }
	}
	
	$fh->close;
    }
    else {
	use Carp;
	croak "cannot open manifest file: $file\n";
    }
}


sub read_file
{
    my ($file, $var) = @_;

    use FileHandle;
    my $fh = new FileHandle $file;

    if (defined $fh) {
	while (<$fh>) {
	    next if /^\s*\#/;

	    if (/([\$\@\%][A-Z][A-Z\d\_]+)(\s|$|=)/) {
		$var->{$1} = $1;
	    }
	}
    }
    else {
	use Carp;
	croak ("cannot open $file\n");
    }
}


sub init_ignore_list
{
    my ($ignore_list) = @_;
    my $list = {
	'@INC'         => 1,
	'@LIBDIR'      => 1,
	'@MEMBER_LIST' => 1,
	'@ACTIVE_LIST' => 1,

	'$FML'         => 1,
	'$DIR'         => 1,
	'$LIBDIR'      => 1,
	'$NULL'        => 1,
	'$DO_NOTHING'  => 1,
    };

    for (keys %$list) {
	$ignore_list->{ $_ } = 1;
    }

}


1;

