#!/usr/local/bin/perl
#
# $Id$
#

&check_rename;
&check_crypt;

exit 0;


sub check_rename
{
    $test = "test$$";

    printf "%-30s ... ", "make file ${test}x";
    system "dir > ${test}x";
    print "ok\n" if -f "${test}x";

    printf "%-30s ... ", "make file ${test}y";
    system "dir > ${test}y";
    print "ok\n" if -f "${test}y";

    printf "%-30s ... ", "rename(2) works?";
    rename("${test}x", "${test}y");
    print "ok\n" if -f "${test}y" && ! -f "${test}x";
    unlink "${test}x";
    unlink "${test}y";
}


sub check_crypt
{

    $c  = '0082EibTV08Dc';
    $cx = crypt("uja", "00");

    printf "%-30s ... ", "crypt(3) works?";

    if ($c eq $cx) {
	print "ok\n";
    }
    else {
	print "fail\n";
	print "\n";
	print "    UNIX: $c\n";
	print " Windows: $cx\n";
	print "\n";
    }
}

1;
