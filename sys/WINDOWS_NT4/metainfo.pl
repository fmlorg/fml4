sub SetUpForMetaInfoSendmail
{
    &ResetVariables;

    &Conv4NT($ml, "$EXEC_DIR/etc/makefml/include.cmd", 
	     "$ML_DIR/$ml/include.cmd");
    &Conv4NT($ml, "$EXEC_DIR/etc/makefml/include-ctl.cmd", 
	     "$ML_DIR/$ml/include-ctl.cmd");

    # setup msend.cmd for cron(?)
    &Conv4NT($ml, "$EXEC_DIR/etc/makefml/msend.cmd", 
	     "$ML_DIR/$ml/msend.cmd");

    # etc/aliases
    &Conv4NT($ml, "$EXEC_DIR/etc/makefml/aliases.metainfo", 
	     "$ML_DIR/$ml/aliases", 1);
}


sub Conv4NT
{
    local($ml, $example, $out, $cmd_mode) = @_;
    local($uid, $gid, $format);

    open(EXAMPLE, $example)  || (&Warn("cannot open $example"), return 0);
    open(CF, "> $out")       ||  (&Warn("cannot open $out"), return 0);
    select(CF); $| = 1; select(STDOUT);
    
    print STDERR "\tGenerating $out\n";

    if ($COMPAT_ARCH eq "WINDOWS_NT4") {
	$PERL_PATH = &search_path('perl.exe');
	print STDERR "set perl_path $PERL_PATH\n";
	$USER = $ENV{'USERNAME'};
    }
    else {
	$PERL_PATH = &search_path('perl');
	$uid   = $uid || (getpwuid($<))[2];
	$gid   = $gid || (getpwuid($<))[3];
    }

    while (<EXAMPLE>) {
	# perl
	s/_PERL_PATH_/$PERL_PATH/g;

	# config
	s/_EXEC_DIR_/$EXEC_DIR/g;
	s/_ML_DIR_/$ML_DIR/g;
	s/_ML_/$ml/g;
	s/_DOMAIN_/$DOMAIN/g;
	s/_FQDN_/$FQDN/g;
	s/_USER_/$USER/g;
	s/_OPTIONS_/$opts/g;
	s/_CPU_TYPE_MANUFACTURER_OS_/$CPU_TYPE_MANUFACTURER_OS/g;
	s/_STRUCT_SOCKADDR_/$STRUCT_SOCKADDR/g;
	s/XXUID/$uid/g;
	s/XXGID/$gid/g;

	# repl for *.cmd on NT4
	s%/%\\%g;

	if ($cmd_mode) {
	    s#\\#\\\\#g;
	    while (s%\\\\\\%\\\\%g) { 1;}
	}
	else {
	    while (s%\\\\%\\%g) { 1;}
	}

	print CF $_;
    }

    close(EXAMPLE);
    close(CF);
}


1;
