#!/usr/local/bin/perl

chop($PWD = `cd`);
$PWD =~ s#\\#/#g;

@DIRS = ("bin", "sbin", "libexec", "cf", "etc", "doc", "var\\html");

$EXEC_DIR   = shift @ARGV;
$EXEC_DIR   =~ s#/#\\#g;

$ARCH_DIR   = "$EXEC_DIR\\arch";
$DOC_DIR    = "$EXEC_DIR\\doc";
$DRAFTS_DIR = "$DOC_DIR\\drafts";

-d $EXEC_DIR   || mkdir($EXEC_DIR, 0755);
-d $ARCH_DIR   || mkdir($ARCH_DIR, 0755);
-d $DOC_DIR    || mkdir($DOC_DIR, 0755);
-d $DRAFTS_DIR || mkdir($DRAFTS_DIR, 0755);

for (@DIRS) {
    print  "Installing $dir ...\n";
    &RecursiveCopy($_);
}

print "Installing perl scripts (*.pl) files ...\n";

# since rm -fr ...
-d $DOC_DIR    || mkdir($DOC_DIR, 0755);
-d $DRAFTS_DIR || mkdir($DRAFTS_DIR, 0755);

system "copy src\\*.pl $EXEC_DIR";
system "copy src\\arch\\*.pl $ARCH_DIR";
system "copy sys\\arch\\WINDOWS_NT4\\* $EXEC_DIR";

for ("help*", "guide", "deny", "objective") {
    system "copy $_ $DRAFTS_DIR";
}

system "copy sbin\\makefml $EXEC_DIR\\makefml";

exit 0;

sub RecursiveCopy
{
    local($dir) = @_;

    -d "$EXEC_DIR/$dir" || mkdir("$EXEC_DIR/$dir", 0755);

    if (opendir(DIRD, $dir)) {
	for (readdir(DIRD)) {
	    next if /^\./;

	    if (-d "$dir/$_") {
		# print STDERR "directory $dir/$_\n";

		-d "$EXEC_DIR/$dir/$_" || mkdir("$EXEC_DIR/$dir/$_", 0755);
		&RecursiveCopy("$dir/$_");
	    }
	    elsif (-f "$dir/$_") {
		# print STDERR "file      $dir/$_\n";
	    }
	    else {
		# print STDERR "N         $dir/$_\n";
	    }
	}
	closedir(DIRD);

	$dir =~ s#/#\\#g;
	print STDERR "copy $dir\\* $EXEC_DIR\\$dir\n";
	system "copy $dir\\* $EXEC_DIR\\$dir";
    }
}

1;
