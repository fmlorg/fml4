# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;


sub DoPasswd
{
    local($proc, *Fld, *e, *misc) = @_;
    local($curaddr) = $misc || $Addr || $From_address;
    local($old, $new) = @Fld[2,3];

    $PASSWD_FILE        = $PASSWD_FILE || "$DIR/etc/passwd";
    (!-f $PASSWD_FILE) && open(TOUCH,">> $_") && close(TOUCH);

    # if you know the old password, you are authenticated.
    if (&CmpPasswdInFile($PASSWD_FILE, $curaddr, $old)) {
	&Mesg(*e, $NULL, 'auth.ok');
	&Mesg(*e, "$proc: Authenticated");
	&Log("$proc; Authenticated");
	if (&ChangePasswd($PASSWD_FILE, $curaddr, $new)) {
	    &Mesg(*e, $NULL, 'auth.change_password.ok', $proc);
	    &Mesg(*e, "$proc; change passwd succeed");
	    &Log("$proc; change passwd succeed");
	}
	else {
	    &Mesg(*e, $NULL, 'auth.change_password.fail', $proc);
	    &Mesg(*e, "$proc; change passwd fail");
	    &Log("$proc; change passwd fail");
	}
    }
    else {
	&Mesg(*e, $NULL, 'auth.invalid_password');
	&Mesg(*e, "$proc: Illegal password");
	&Log("$proc: Illegal password");
    }
}


################################################################

eval("crypt('fukachan', 11);");
$HasCrypt = $@ eq "" ? 1 : 0; # should be global!

# PLAIN passwd -> crypt(passwd, DES-function)
# return 'encrypted passwd' if     crypt() exists
# return passwd itself      if not crypt() exists 
sub Crypt
{
    local($passwd, $salt) = @_;

    # required on sys/WINDOWS_NT4/
    return $passwd if $CryptNoEncryptionMode;
    
    if ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "md5" && 
	&PerlModuleExistP("MD5")) {
	require "libmd5.pl";
	return &Md5($passwd);
    }
    elsif ($REMOTE_ADMINISTRATION_AUTH_TYPE eq "md5") {
	&Log("MD5::Fail, so MD5 -> crypt(3)");
    }

    &Log("HasCrypt: $HasCrypt") if $debug;

    # if not have crypt();
    return $passwd unless $HasCrypt;

    # if DES function is not given
    # fml-support: 03447 oota@pes.com1.fc.nec.co.jp
    &SRand();
    if ($CPU_TYPE_MANUFACTURER_OS =~ /freebsd/i &&
	!&TraditionalCryptP) {
        if (! $salt) {
            $salt = "\$1\$" . rand(64) . time % 60;
        }
    } else {
        $salt = $salt || rand(64);
    }

    # crypt
    crypt($passwd, $salt);
}

sub TraditionalCryptP
{
    local($c, $e);
    $c = "0./Qb5B6ICfvA";
    $e = crypt("fukachan", "0.");
    $c eq $e ? 1 : 0;
}

# compare ENCRYPTED-PASSWD and PLAIN-PASSWD
# return 1 if matched
sub CmpPasswd
{
    local($ep, $p) = @_;

    &Log("CmpPasswd: $ep eq crypt($p)") if $debug;

    # fml-support: 03441 oota@pes.com1.fc.nec.co.jp (obsolete)
    if ($CPU_TYPE_MANUFACTURER_OS =~ /freebsd/i) {
	$p = &Crypt($p, $ep);
    }
    else {
	($ep =~ /^(\S\S)/) && ($p = &Crypt($p, $1));
    }

    # now $p (given plain password) has been encrypted by crypt().
    # compare $ep (given encrypted password) with $p
    &Log("CmpPasswd: $ep eq $p") if $debug;

    ($ep eq $p) ? 1: 0;
}


# in password file $file
# check '$passwd' for '$from' address
# return the retult
sub CmpPasswdInFile
{
    local($file, $from, $passwd) = @_;
    local($found, $ok);

    open(FILE, $file) || return 0;
    while(<FILE>) {
	chop;

	if (/^$from\s+(\S+)/) {
	    $found++;

	    # CmpPasswd(encrypt, plain-passwd)
	    &CmpPasswd($1, $passwd) && $ok++; 

	    &Log("O.K. CmpPasswdInFile: password [$passwd] is authenticated")
		if $debug && $ok;
	}
    }
    close(FILE);

    if (! $found) { &Log("CmpPasswdInFile: address [$from] is not found");}

    $ok ? 1 : 0;
}


# in password file $file
# change the password to new password $new_passwd for $from 
# PASSWORD($new_passwd) is PLAIN 
# return the result value
sub ChangePasswd
{
    local($file, $from, $new_passwd, $init) = @_;
    local($r) = 0;

    # new password: plain -> crypt
    $new_passwd = &Crypt($new_passwd);

    open(FILE, "< $file")      || do {
	select(FILE); $| = 1;
	&Log("Cannot open $file");
	&Mesg(*Envelope, "Cannot open passwd file");
	&Mesg(*Envelope, $NULL, 'auth.password.cannot_open');
	return 0;
    };

    open(OUT,  "> $file.new")  || do {
	select(OUT); $| = 1;
	&Log("Cannot open $file.new");
	&Mesg(*Envelope, "Cannot make new passwd file");
	&Mesg(*Envelope, $NULL, 'auth.password.cannot_mk_pwdb');
	return 0;
    };

    open(BAK,  ">> $file.bak") || do {
	select(BAK); $| = 1;
	&Log("Cannot open $file.bak");
	&Mesg(*Envelope, "Cannot make passwd backup");
	&Mesg(*Envelope, $NULL, 'auth.password.cannot_mk_pwdb.bak');
	return 0;
    };

    print BAK "--- $Now ---\n";
    local($a, $b);
    while(<FILE>) {
	print BAK $_;

	($a, $b) = split;
	if($a eq $from) {
	    print OUT "$a $new_passwd\n";
	    $r = 1;
	}else {
	    print OUT $_;
	}
    }

    # Initialize
    if ((!$r) && $init) {
	&Log("Initializing Passwd Entry[$from] in $file");
	print OUT "$from\t$new_passwd\n";
	$r = 1;
    }

    close FILE;
    close OUT;
    close BAK;

    # Really Matched?
    if (! $r) {
	&Log("Not Matched Passwd Entry[$from] in $file");
	return 0;
    }

    if(rename("$file.new", $file)) {
	return 1;
    }else {
	&Log("Cannot rename $file.new");
	&Mesg(*Envelope, "Cannot rename passwd backup");
	&Mesg(*Envelope, $NULL, 'auth.password.rename.fail');
	return 0;
    }
}

1;
