# Lock library functions, 
# This lock functions uses proceses ID
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)
#
# local($id);
# $id = q$Id$;
# $rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

# Lock UNIX V7 age like..
# old lock extracted from fml 0.x and revised now :-)
sub V7Lock
{
    $0 = "--V7 Locked and waiting <$FML $LOCKFILE>";

    # set variables
    $LockFile = $LOCK_FILE || "$FP_VARRUN_DIR/lockfile.v7";
    $LockTmp  = "$FP_VARRUN_DIR/lockfile.$$";
    $rcsid .= ' :V7L';
    local($timeout) = 0;

    # create tmpfile
    &Touch($LockTmp) || die "Can't make LOCK\n";
    &Append2(&WholeMail."[$$]", $LockTmp) if $debug;

    # try within about 10min.
    for ($timeout = 0; $timeout < $MAX_TIMEOUT; $timeout++) {
	if (link($LockTmp, $LockFile) == 0) {	# if lock fails, wait&try
	    sleep (rand(3)+5);
	} else {
	    last;
	}
    }
    
    unlink $LockTmp;

    if ($timeout >= $MAX_TIMEOUT) {
	$TIMEOUT = sprintf("TIMEOUT.%2d%02d%02d%02d%02d%02d", 
			   $year, $mon+1, $mday, $hour, $min, $sec);

	open(TIMEOUT, "> $FP_VARLOG_DIR/$TIMEOUT");
	select(TIMEOUT); $| = 1; select(STDOUT);
	print TIMEOUT &WholeMail;
	close(TIMEOUT);

	&Warn("V7 LOCK TIMEOUT", 
	      "saved in $FP_VARLOG_DIR/$TIMEOUT\n\n".&WholeMail);
    }
}


sub V7Unlock
{
    $0 = "--V7 Unlocked <$FML $LOCKFILE>";
    unlink $LockFile;
}

1;
