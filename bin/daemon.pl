#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.


# C LANGUAGE
#  f = open( "/dev/tty", O_RDWR, 0);
#  if( -1 == ioctl(f ,TIOCNOTTY, NULL))
#    exit(1);
#  close(f);

@ARGV || (&USAGE, exit 0);

if (($pid = fork) > 0) {
    exit 0;
}
elsif (0 == $pid) {
    eval "require 'sys/ioctl.ph';";

    if (defined &TIOCNOTTY) {
	require 'sys/ioctl.ph';
	open(TTY, "+> /dev/tty")   || die("$!\n");
	ioctl(TTY, &TIOCNOTTY, "") || die("$!\n");
	close(TTY);
    }

    close(STDIN);
    close(STDOUT);
    close(STDERR);

    exec @ARGV;
}
else {
    print STDERR "CANNOT FORK\n";
}

exit 0;

sub USAGE
{
    $0 =~ s|.*/||;

    local($_) = q#;
    $0 program;
    fork and exec the program;
#;

    s/\;\n/\n\t/g;
    s/\t$//g;
    print STDERR $_;
}

1;
