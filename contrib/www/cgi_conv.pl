#!/usr/local/bin/perl

if ($0 eq __FILE__){
    %FORM = &read_input;

    foreach (keys %FORM) {
	print "$_\t";
	print $FORM{$_};
	print "\n";
    }
    exit 0;
}

sub read_input
{
    local ($buffer, @pairs, $pair, $name, $value, %FORM);
    # Read in text
    $ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;
    if ($ENV{'REQUEST_METHOD'} eq "POST")
    {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    } else
    {
	$buffer = $ENV{'QUERY_STRING'};
    }
    @pairs = split(/&/, $buffer);
    foreach $pair (@pairs)
    {
	($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%(..)/pack("C", hex($1))/eg;
	$FORM{$name} = $value;
    }
    %FORM;
}

1;
