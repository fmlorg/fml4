# Lock library functions, 
# This lock functions uses proceses ID

# $Author$
$lockid   = q$Id$;
($lockid) = ($lockid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid   .= "/$lockid";

# if the younger process number exists in $LOCKDIR, return 1;
# using system call is four or five times faster than `ls`.
# Pay attention! readdir system call not return sorted filenames.
sub CheckWaitMatrix
{
    local($file) = '';
    opendir(DIRD, "$LOCKDIR");
    foreach $file (readdir(DIRD)) {
	print STDERR $file,"\n" if($debug);
	next if($file =~ /\./);
	if("$LOCKFILE" > "$file") { # If only one is satisfied, wait!
	    closedir(DIRD);
	    return 1; 
	}
    }
    closedir(DIRD);
    return 0;
}

# if process number inversed, create the greater lock number
sub CheckProcessTable
{
    local($file) = '';
    local($UPGRADE) = 100000;
    local($maxnumber) = "$LOCKFILE";
    opendir(DIRD, "$LOCKDIR");
    foreach $file (readdir(DIRD)) {
	print STDERR $file,"\n" if($debug);
	next if($file =~ /\./);
	if("$maxnumber" < "$file"){ $LOCKFILE += $UPGRADE;}
    }
    closedir(DIRD);
    return;
}

# locking 
sub Lock
{
    $0 = "--Locked and waiting <$FML $LOCKFILE>";
    &CheckProcessTable;
    print STDERR "> $LOCKDIR/$LOCKFILE\n" if($debug);
    open(LOCK, "> $LOCKDIR/$LOCKFILE") || die "Can't make LOCK\n";
    close(LOCK);
    for($timeout = 0; $timeout < $MAX_TIMEOUT; $timeout++) {
	if(&CheckWaitMatrix) { sleep(rand(3)+5);}
	else { last;}
    }
    
# save incoming mail, send warning to maintainer, put log, die
    if ($timeout >= $MAX_TIMEOUT) {
	$TIMEOUT = sprintf("TIMEOUT.%2d%02d%02d%02d%02d%02d", 
			   $year, $mon+1, $mday, $hour, $min, $sec);
	open(TIMEOUT, "> $TIMEOUT") || (&Logging("$!"), return);
	while(<>) { print TIMEOUT $_;}
	close(TIMEOUT);
	&Sendmail($MAINTAINER, "Locked:<$LOCKFILE>. $TIMEOUT $ML_FN");
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 1;
    }
}

1;
