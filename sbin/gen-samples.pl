#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1998 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

$CONFIG_PH	= shift @ARGV;
require $CONFIG_PH;
$ML             = (split(/\@/, $MAIL_LIST))[0];
$MAINTAINER	= (split(/\@/, $MAINTAINER))[0];
$FMLDIR		= shift @ARGV;

$USER		= $ENV{'USER'}|| getlogin || (getpwuid($<))[0] || $MAINTAINER;

($a, $d) = split(/@/,$ML);

open(F, "> ./etc/aliases.sample") || die("$!\n");
select(F); $| = 1;
print F "# ML itself\n";
print F "$a: :include:$FMLDIR/etc/include.sample\n";
print F "\n";
print F "# ML-command-server, NOT REQUIRED but just recommended\n";
print F "#${a}-ctl: :include:$FMLDIR/etc/include.sample\n";
print F "\n";
print F "#owner-$a: your-username (Sendmail R8)\n";
print F "owner-$a:$USER\n";
print F "\n";
print F "#maintainer. an error mail comes back here\n";
print F "$MAINTAINER:$USER\n";
print F "\n";

if ($MAINTAINER !~ /\-request/) {
    print F "#Conventionally we should also make ML-request\n";
    print F "#ML-request is a receipt of ML\n";
    print F "#It is O.K where ML-request is an alias of MAINTAINER\n";
    print F "${a}-request:$MAINTAINER\n";
    print F "\n";
}

close(F);

open(F, "> ./etc/include.sample") || die("$!\n");
select(F); $| = 1;
print F "\"|$FMLDIR/fml.pl $FMLDIR $FMLDIR\"\n";
close(F);

exit 0;
