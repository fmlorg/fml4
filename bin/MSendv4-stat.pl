#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

&mhgetopt;

open(F, $File) || die("cannot open $File;$!\n");

while(<F>) {
    /mconf/i && $ok++;

    if (/^(\S+):/ && (!/^\$/) && (!/^MSend:/) && (!/^AL:/)) {
	if ($ok) {
	    $r .= '*' x 60;
	    $r .= "\n\n\t\t[ $maillist ]\n\n";
	    $r .= $s;
	    $s{$maillist}.= "$m\n";
	}
	undef $s;
	undef $m;
	undef $ok;

	$maillist = $1;
	next;
    };
    
    /^MSend:/ && (s/^MSend:/\t/, $m .= $_);
    /JST/     && ($m .= "\t$_");

    $s .= $_;
}
close(F);

print "*** Brief Summary ***\n";
foreach (keys %s) {
    print "\n$_:\n";
    print $s{$_};
}
print "\n\n*** Summary ***\n";
print $r;

if ($truncate) {
    truncate($File, 0);
}
else {
    print STDERR "$File not zero\'d\n";
}

exit 0;

sub mhgetopt 
{
    local(@b);

    # DEFAULT
    $truncate = 0;
    $File     = 'STDIN';

    while($_ = shift @ARGV) {
	if (/^\+(\S+)$/) {
	    $folder = $1;
	}
	elsif (/^\-file$/) {
	    $File = shift @ARGV;
	}
	elsif (/^\-truncate$/) {
	    $truncate = 1;
	}
	elsif (/^\-notruncate$/) {
	    $truncate = 0;
	}
	else {
	    push(@b, @_);
	}
    }

    @ARGV = @b;
}

1;
