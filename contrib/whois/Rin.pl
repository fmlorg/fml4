#!/usr/local/bin/perl

$rcsid = q$Id$;
($rcsid) = ($rcsid =~ /Id:.*.pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid = " Rynn Russel". $rcsid;

$FILE = "/home/axion/fukachan/work/spool/whois/whoisdb";
$USAGE = "Whois Server($rcsid): USAGE\n";
$USAGE .= q#
    % whois -h axion.phys.titech.ac.jp argument
    Ascii and EUC Japanese codes as argument is O.K.
    Argument may contain 
    * matches everything.
    . arbitrary one character
    ! is not implemented. Sorry(_o_)
#;

# Generate the key
$Key = <>; chop $Key; chop $Key;
#print $Key = <>; chop $Key;

$EXEC = q#
    $Key =~ s/\*/\\\*/g;
    $/ = ".\n\n";
    foreach (<FILE>) {
	chop;	chop;	chop;
	($from) = (/^(.*)\n/);
	next if $from =~ /^$/o;
	$addr{$from} = $_;
    }

    foreach (keys %addr) {
	print $addr{$_} if /$Key/io;
    }

    if($opt_ALL) {
	foreach (values %addr) {
	    print $_ if /$Key/io;
	}
    }
#;
#/$Key/io && print $_;

&USAGE if(! $Key);
&USAGE if( $Key =~ /help/oi);
&Init;
open(FILE);

eval $EXEC;
print STDERR $@ if $@;

close(FILE);
exit 0;

sub Init
{
    
    ;

}

sub USAGE
{
    print $USAGE;
    exit 0;
}

1;
