#!/usr/local/bin/perl

$| = 1;

push(@INC, "kern");
push(@INC, "proc");

require 'proc/libkern.pl';

sub Sendmail {}

&Setup();

#specials    =  "(" / ")" / "<" / ">" / "@"  ; Must be in quoted-
#    /  "," / ";" / ":" / "\" / <">  ;  string, to use
#    /  "." / "[" / "]"              ;  within a word.
for $addr (@addr) {
    if (&SecureP($addr)) {
	$ok{$addr} = $addr;
    }
    else {
	$bad{$addr} = $addr;
    }
}


print "\n\nValid:\n";
for $addr (sort keys %ok) {
    printf("%-40s   \n", $addr, "ok") if &Valid($addr);
}

print "\n\nValid(?):\n";
for $addr (sort keys %ok) {
    next if &Valid($addr);
    printf("%-40s   \n", $addr, "ok");
}

print "\n\nInvalid:\n";
for $addr (sort keys %bad) {
    printf("%-40s   \n", $addr, "bad");
}

exit 0;

sub Valid
{
    my ($a) = @_;
    $a =~ /^[a-z0-9-]+\@[a-z0-9\.-]+$/i ? 1 : 0;
}

sub Setup
{
    @addr = ('rudo@fml.org',
	     'rudo@f-ml.org',
	     'rudo@f;ml.org',
	     'rudo@f.ml.org',
	     'rudo@f|ml.org',
	     'rudo@f"ml.org',
	     'rudo@f0ml.org',
	     'rudo@00.fml.org',
	     'rudo@f_ml.org',
	     'rudo@f(ml.org',
	     'rudo@f)ml.org',
	     'rudo@f<ml.org',
	     'rudo@f>ml.org',
	     'rudo@f@ml.org',
	     'rudo@f@ml.org',
	     'rudo@f,ml.org',
	     'rudo@f:ml.org',
	     'rudo@f\ml.org',
	     'rudo@f\ml.org',
	     'rudo@f[ml.org',
	     'rudo@f]ml.org',
	     );

    for (@addr) {
	$p = $_;
	$p =~ s/\@//;
	$p =~ s/\.org/\@fml.org/;

	push(@xaddr, $p); 
    }

    push(@addr, @xaddr);
}
