#!/usr/local/bin/perl
#
# $FML$
#

# crontab SAMPLE
#
#   0 0 * * * /home/user/script/lntgz.pl /home/user/archive/elena
#

# original by Masaki Hojo <hojo@CyberAssociates.co.jp>
# fml-help: 00409
#

exit(1) unless @ARGV;

$WORK_DIR = $ARGV[0];

if (-d $WORK_DIR) {
    opendir(DIR, $WORK_DIR) || die "can't opendir $WORK_DIR: $!";
    @targz = grep(/\.tar\.gz$/, readdir(DIR));
    closedir(DIR);

    for ($i = 0; $targz[$i] ne ''; $i++) {
	$tar = $targz[$i];
	next unless -f "$WORK_DIR/$tar";

	$tgz = $targz[$i];
	$tgz =~ s/\.tar\.gz$/.tgz/o;
	next if -f "$WORK_DIR/$tgz";

	if (symlink($tar, $tgz)) {
	    printf("%d : %s <--- %s\n", $i+1, $tar, $tgz);
	}
	else {
	    print STDERR "Error: fail to symlink $tar $tgz\n";
	}
    }
}
else {
    print STDERR "Error: specified $WORK_DIR is not a directory\n";
}

exit 0;
