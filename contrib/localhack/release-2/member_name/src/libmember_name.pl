# version control is only by fukachan@sapporo.iij.ad.jp
# $Id$


&InitMemberName;

sub InitMemberName
{
	$USE_MEMBER_NAME = 1;

	# $MEMBER_NAME_FILE Define & Touch
	$MEMBER_NAME_FILE = $MEMBER_NAME_FILE || "$DIR/members-name";
	-f $MEMBER_NAME_FILE || &Touch($MEMBER_NAME_FILE);

	# KEYWORD for 'name'
	$NAME_KEYWORD = $NAME_KEYWORD || 'NAME';

	# Rewrite built-in command procedure
	for ( 'chaddr', 'change-address', 'change',
	      'bye', 'unsubscribe', 'unsubscribe-confirm' ) {
		$ExtProcedure{$_} = 'ProcSetMemberNameFile';
	}

	# Rewrite 'members' & 'member' command procedure
	$ExtProcedure{'members'} = 'ProcFileSendBackMemberNameFile';
	$ExtProcedure{'member'}  = 'ProcFileSendBackMemberNameFile';

	# Define 'name' command proc
	$ExtProcedure{'name'} = 'DoSetMemberNameFile';
	$ExtProcedure{'r#name'} = 1;

	# Rewrite built-in admin command procedure
	for ( 'admin:chaddr', 'admin:change-address', 'admin:change',
	      'admin:bye', 'admin:unsubscribe' ) {
		$ExtAdminProcedure{$_} = 'ProcAdminSetMemberNameFile';
	}

	# Rewrite 'admin members' command procedure
	$ExtAdminProcedure{'admin:members'} = 'ProcFileSendBackMemberNameFile';

	# Define 'admin name' command proc
	$ExtAdminProcedure{'admin:name'} = 'ProcAdminSetMemberNameFile';

	# Off Secure Alert
	# $SECURE_REGEXP{'#*\s*[nN][aA][mM][eE]\s+.*'} = 1;
	# $SECURE_REGEXP{'#*\s*[aA][dD][mM][iI][nN]\s+[nN][aA][mM][eE]\s+.*'} = 1;
	#
	# Sorry, fix %SECURE_REGEXP code bug; so modified to the following.
	# fukachan@fml.org 1998/11/06
	$SECURE_REGEXP{'member_name_secreg1'} = '#*\s*[nN][aA][mM][eE]\s+.*';
	$SECURE_REGEXP{'member_name_secreg2'} = 
		'#*\s*[aA][dD][mM][iI][nN]\s+[nN][aA][mM][eE]\s+.*';
}

sub AutoRegistMemberName
{
	local(*e, $from) = @_;

	if ( &CheckMemberNameFile($from) ) {
		&Log("AutoRegistMemberName: Dup $from");
		&Mesg(*e, "Address [$from] 's name is already registered in $MEMBER_NAME_FILE.");
		&Mesg(*e, &WholeMail);
		return 0;
	}

	local($name) = $e{'macro:x'};
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;

        if (!$name) {
		&Log("AutoRegistMemberName : No name given $from. skip.");
		return 1;
	}

	if ($e{'MIME'}) {
		&use('MIME');
		$name = &DecodeMimeStrings($name);
	}

	require 'jcode.pl';
	&jcode'convert(*name, 'jis');

	local($appendline) = "$from\t$name";

        if (&Append2($appendline, $MEMBER_NAME_FILE)) {
		&Log("Added MemberName: '$appendline'");
		return 1;
	} else {
		&Warn("ERROR[sub AutoRegistMemberName]: cannot operate $MEMBER_NAME_FILE", &WholeMail);
		return 0;
	}
}


sub ProcSetMemberNameFile
{
    local($proc, *Fld, *e, *misc) = @_;
    local($status);

    $status = &ProcSetMemberList($proc, *Fld, *e, *misc);
    return $NULL if ( $status eq $NULL );
    &DoSetMemberNameFile($proc, *Fld, *e);
    return $status;
}

sub ProcAdminSetMemberNameFile
{
    local($proc, *Fld, *e, *opt) = @_;
    local($cmdline) = $Fld;

    # Variable Fixing...
    @Fld = ('#', $proc, @opt);

    if ( $proc =~ /^($NAME_KEYWORD)$/i ) { # NAME
	$cmdline =~ s/^#\s*//;
	&Log($cmdline);

    } else { # CHADDR, BYE
	local($address) = $opt;
	&Log("admin $proc ".join(" ", @opt));
	&Debug("A::SetMemberList($proc, (@Fld), *e, $address);")   if $debug;
	return 1 unless &ProcSetMemberList($proc, *Fld, *e, *address);
    }

    &Debug("A::DoSetMemberNameFile($proc, (@Fld), *e);") if $debug;
    &DoSetMemberNameFile($proc, *Fld, *e);

    1;
}

sub DoSetMemberNameFile
{
    local($proc, *Fld, *e) = @_;
    local($curaddr, $newaddr, $newname);

    # KEYWORD for 'chaddr'
    $CHADDR_KEYWORD = $CHADDR_KEYWORD || 'CHADDR|CHANGE\-ADDRESS|CHANGE';

    # $curaddr, $newaddr, $newname define
    $curaddr = $e{'mode:admin'} ? $Fld[2] : ($Addr || $From_address);

    $cmd = $proc; $cmd =~ tr/a-z/A-Z/; $_ = $cmd;

    if ( /^($NAME_KEYWORD)$/i ) { # NAME
        if ($curaddr !~ /\@/) {
            &Log("NAME: Error: empty address is given");
            &Mesg(*e, "$cmd: Error: $cmd requires non-empty address.");
            return $NULL;
        }

	# LOOP CHECK
	if (&LoopBackWarn($curaddr)) {
	    &Log("$cmd: LOOPBACK ERROR, exit");
	    return $NULL;
	}
    
        $newname = $Fld;
        $newname =~ s/^#\s*//;
        if ( $e{'mode:admin'} ) {
            # COMMAND 'ADMIN NAME Address [NEWNAME]'
            $newname =~ s/^admin\s+($NAME_KEYWORD)\s+\S+\s*//i;
        } else {
            # COMMAND 'NAME [NEWNAME]'
            $newname =~ s/^($NAME_KEYWORD)\s*//i;
        }

	if ( $USE_SUBJECT_AS_COMMANDS && $e{'MIME'} ) {
		&use('MIME');
		$newname = &DecodeMimeStrings($newname);
	}

	require 'jcode.pl';
	&jcode'convert(*newname, 'jis');

        $newaddr = '';

        &Mesg(*e, "\t set $cmd => NAME") if $cmd ne "NAME";
        &Mesg(*e, "\tTry change name to '$newname'\n");
        $cmd = 'NAME';

    } elsif ( /^($CHADDR_KEYWORD)$/i ) { # CHADDR
        $newaddr = $Fld[3];
	$cmd = 'CHADDR';
    } else { # BYE
        $newaddr = $curaddr;
	$cmd = 'BYE';
    }

    &Debug("\n   DoSetMemberNameFile::(\n\tcur  $curaddr\n\tnew  $newaddr\n") if $debug;


    ### Modification routine is called recursively in ChangeMemberNameFile;

    if ( ($cmd ne 'NAME') && !&MailListMemberNameP($curaddr) ) {
        &Log("$cmd MEMBER_NAME_FILE [$curaddr] skipped");
        &Mesg(*e, "$cmd MEMBER_NAME_FILE [$curaddr] skipped.");
        return 'LAST';
    }


    if ( &ChangeMemberNameFile($cmd, $curaddr, $MEMBER_NAME_FILE, *newname, *newaddr) ) {
        &Log("$cmd MEMBER_NAME_FILE [$curaddr] accepted");
        &Mesg(*e, "$cmd MEMBER_NAME_FILE [$curaddr] accepted.");
    } else {
        &Log("$cmd MEMBER_NAME_FILE [$curaddr] failed");
        &Mesg(*e, "$cmd MEMBER_NAME_FILE [$curaddr] failed.");
    }

    return 'LAST';
}


# if found, return the non-null file name;
sub MailListMemberNameP
{
    local($addr) = @_;
    local($file) = $MEMBER_NAME_FILE;

    if (-f $file) {
        &Debug("   MailListMemberNameP(\n\t$addr\n\tin $file);\n") if ($debug);

        if (&CheckMemberNameFile($addr)) {
            &Debug("+++Hit: $addr in $file") if $debug;
            return $file;
        }
    }
    $NULL;
}


# CheckMemberNameFile(address)
# return : if address in $MEMBER_NAME_FILE -> name string
#          if address not in $MEMBER_NAME_FILE -> $NULL
sub CheckMemberNameFile
{
    local($address) = @_;
    local($file) = $MEMBER_NAME_FILE;
    local($addr,$name);

    # more severe check;
    $address =~ s/^\s*//;
    ($addr) = split(/\@/, $address);
    
    &Open(FILE, $file) || return $NULL;

  getline: while (<FILE>) {
      chop; 

      next getline if /^\#/o;	# strip comments
      next getline if /^\s*$/o; # skip null line
      next getline unless /^\s*(\S+)\s+(.*)$/;

      $_ = $1;
      $name = $2;

      next getline unless /^$addr/i;

      if (&AddressMatch($_, $address) == 1) {
	  close(FILE);
	  return $name;
      }
  }# end of while loop;

    close(FILE);
    return $NULL;
}


sub ChangeMemberNameFile
{
    local($org_addr) = $ADDR_CHECK_MAX;	# save the present severity
    local($status);

    while ($ADDR_CHECK_MAX < 10) { # 10 is built-in;
	$status = &DoChangeMemberNameFile(@_);
	last if $status ne 'RECURSIVE';
	$ADDR_CHECK_MAX++;
	&Debug("Call Again ChangeMemberList(...)[$ADDR_CHECK_MAX]") if $debug;
    } 

    $ADDR_CHECK_MAX = $org_addr; # reset;
    $status;
}


# MAIN Routine of ChangeMemberList(cmd, address, file) 
# If multiply matched for the given address, 
# do Log [$log = "$addr"; $log_c++;]
sub DoChangeMemberNameFile
{
    local($cmd, $curaddr, $file, *newname, *newaddr) = @_;
    local($status, $log, $log_c, $r, $addr, $org_addr, $addr_opt);
    local($curname);
    local($mesg);
    local($acct) = split(/\@/, $curaddr);

    &Debug("DoChangeMemberNameFile($cmd, $curaddr, $file, $newname, $newaddr)") if $debug;

    if (! $file) {
	&Log("DoChangeMemberNameFile:: arg's file == null");
	return $NULL;
    }
    elsif (! -f $file) {
	&Log("DoChangeMemberNameFile::Cannot open file[$file]");
	return $NULL;
    }
    
    if ($cmd !~ /^BYE|CHADDR|NAME$/) {
	&Log("ChangeMemberNameFile: Unknown cmd = $cmd");
	return $NULL;
    }

    ### File IO
    # NO CHECK 95/10/19 ($MEMBER_LIST eq $file || $ACTIVE_LIST eq $file)
    # Backup
    open(BAK, ">> $file.bak") || (&Log($!), return $NULL);
    select(BAK); $| = 1; select(STDOUT);
    print BAK "----- Backup on $Now -----\n";

    # New
    open(NEW, ">  $file.tmp") || (&Log($!), return $NULL);
    select(NEW); $| = 1; select(STDOUT);

    # Input
    open(FILE,"<  $file") || (&Log($!), return $NULL);

    local($c, $rcpt, $o);

    in: while (<FILE>) {
	chop;

	print STDERR "TRY       [$_]\n" if $debug;
	&Debug("--change member list($_)") if $debug;

	# Backup
	print BAK "$_\n";
	next in if /^\s*$/o;
	next in unless /^\s*(\S+)\s+(.*)$/o;

	$addr = $1;
	$curname = $2;

	# for high performance
	if ($addr !~ /^$acct/i) {
	    print NEW "$_\n"; 
	    next in;
	} 
	elsif (! &AddressMatch($addr, $curaddr)) {
	    print NEW "$_\n"; 
	    next in;
	}

	print NEW "\#\#BYE $addr $curname\n" if $cmd eq 'BYE';

	if ($cmd eq 'CHADDR') {
	    &Log("ChangeMemberNameFile: CHANGE-ADDRESS : $addr -> $newaddr");
	    print NEW "$newaddr $curname\n"; 
	}

	if ($cmd eq 'NAME') {
	    if ($newname) {
		print NEW "$addr $newname\n"; 
		$mesg .= "$cmd [$addr] Your name changes from '$curname' to '$newname'.";
	        &Log("ChangeMemberNameFile: CHANGE-NAME : '$curname' -> '$newname'");

	    } else {
		$mesg .= "$cmd [$addr] Your name '$curname' deleted.";
	        &Log("ChangeMemberNameFile: DELETE-NAME : '$curname'");
	    }
	}

        $status = 'done'; 
	$log .= "$cmd $addr; "; $log_c++;

    } # end of while loop;

    if ($cmd eq 'NAME' && $newname && $status ne 'done') {
	print NEW "$curaddr $newname\n"; 
	$mesg .= "$cmd [$curaddr] Your name is registered as '$newname'.";
	&Log("ChangeMemberNameFile: APPEND-NAME : '$newname'");
        $status = 'done'; 
    }

    # END OF FILE OPEN, READ..
    close(BAK); close(NEW); close(FILE);

    # protection for multiplly matching, 
    # $log_c > 1 implies multiple matching;
    # ADMIN MODE permit multiplly matching($_cf{'mode:addr:multiple'} = 1);
    ## IF MULTIPLY MATCHED
    if ($log_c > 1 && 
	($ADDR_CHECK_MAX < 10) && 
	(! $_cf{'mode:addr:multiple'})) {
	&Log("$cmd: Do NOTHING since Muliply MATCHed..");
	$log =~ s/; /\n/g;
	&Mesg(*e, "Multiply Matched?\n$log");
	&Mesg(*e, "Retry to check your adderss severely");

	# Recursive Call
	return 'RECURSIVE';
    }
    ## IF TOO RECURSIVE
    elsif ($ADDR_CHECK_MAX >= 10) {
	&Log("MAXIMUM of ADDR_CHECK_MAX, STOP");
    }
    ## DEFAULT 
    else {
	rename("$file.tmp", $file) || 
	    (&Log("fail to rename $file"), return $NULL);
    }

    if ($status eq 'done') {
	&Mesg(*e, "O.K.");
	&Mesg(*e, $mesg) if $mesg;
    }
    else {
	&Mesg(*e, "Hmm,.. something fails.");
    }

    $status;
}

sub ProcFileSendBackMemberNameFile
{
    local($proc, *Fld, *e, *misc) = @_;
    local(%Addr2NameCache,%FileCache);
    local(@f);
    local($file,$orgline,$addr,$bye,$pre);
    local($c);

    # Read $MEMBER_NAME_FILE
    open(MEMBER_NAME,"< $MEMBER_NAME_FILE") || (&Log($!), return $NULL);

    while (<MEMBER_NAME>) {
        chop;

        $bye = ( s/^\#\#BYE\s*// ? '##BYE ' : '' );
        next if /^\#/;
        next if /^\s*$/;
        next unless /^(\S+)\s+(.+)$/;

        $Addr2NameCache{"$bye$1"} = $2;
    }

    close(MEMBER_NAME);

    foreach $file ($MEMBER_LIST, @MEMBER_LIST) {
        next if $FileCache{$file}++;
        next if ( ($file eq $ADMIN_MEMBER_LIST) && !$e{'mode:admin'} );
        next unless (-f $file);
        push(@f, $file);
    }

    $c = $#f;

    # Read $MEMBER_LIST & Create temporally MEMBER_LIST
    open(TMP_MEMBERS, "> $TMP_DIR/members.$$") || (&Log($!), return $NULL);

    foreach $file (@f) {
        print TMP_MEMBERS ('-' x 60)."\n" if $c;

        open(MEMBERS,"< $file") || (&Log($!), return $NULL);

        while (<MEMBERS>) {
            $orgline = $_;
            chop;

            $bye = $pre = '';

            if (/^(\#\#BYE\s+)/) {
                $bye = '##BYE ';
                $pre = $1;
                s/\#\#BYE\s+//;
            } elsif (/^(\#\s*)/) {
                $pre = $1;
                s/^\#\s*//;
            }

            $addr = ( /^(\S+)/ ? $1 : '' );
            print $orgline, next unless $addr;

            if ($Addr2NameCache{"$bye$addr"}) {
                print TMP_MEMBERS $pre,$addr," (",$Addr2NameCache{"$bye$addr"},")\n";
            } elsif ($pre) {
                print TMP_MEMBERS $orgline;
            } else {
                print TMP_MEMBERS $addr,"\n";
            }
        }

        close(MEMBERS);
    }

    close(TMP_MEMBERS);

    # Send temporally MEMBER_LIST
    if ( $e{'mode:admin'} ) {
	$AdminProcedure{"#$proc"} = "$TMP_DIR/members.$$";
    } else {
	$Procedure{"#$proc"} = "$TMP_DIR/members.$$";
    }

    &ProcFileSendBack($proc, *Fld, *e, *misc);

    # unlink temporally MEMBER_LIST
    unlink("$TMP_DIR/members.$$");
}

1;
