# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
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
	&Mesg(*e, "$proc: Authenticated");
	&Log("$proc; Authenticated");
	if (&ChangePasswd($PASSWD_FILE, $curaddr, $new)) {
	    &Mesg(*e, "$proc; change passwd succeed");
	    &Log("$proc; change passwd succeed");
	}
	else {
	    &Mesg(*e, "$proc; change passwd fail");
	    &Log("$proc; change passwd fail");
	}
    }
    else {
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
    local($no_md5_p);

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
    srand(time|$$);
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
    $e = crypt("fukachan", 00);
    $c eq $e ? 1 : 0;
}

# compare ENCRYPTED-PASSWD and PLAIN-PASSWD
# return 1 if matched
sub CmpPasswd
{
    local($c, $p) = @_;
    local($seed);

    &Log("CmpPasswd: $c eq crypt($p)") if $debug;

    # fml-support: 03441 oota@pes.com1.fc.nec.co.jp
    if ($CPU_TYPE_MANUFACTURER_OS =~ /freebsd/i) {
       if ($c =~ /^\$1\$/) { # using MD5 crypt
           $seed = substr($c, 3, index($c, "\$", 3) - 3);
       } 
       else { # using DES crypt
           $seed = substr($c, 0, 2);
       }

       $p = &Crypt($p, $seed);
    }
    else {
	($c =~ /^(\S\S)/) && ($p = &Crypt($p, $1));
    }

    &Log("CmpPasswd: $c eq $p") if $debug;

    ($c eq $p) ? 1: 0;
}


# in password file $file
# check '$passwd' for '$from' address
# return the retult
sub CmpPasswdInFile
{
    local($file, $from, $passwd) = @_;
    local($ok) = 0;

    open(FILE, $file) || return 0;
    while(<FILE>) {
	chop;

	if (/^$from\s+(\S+)/) {
	    #CmpPasswd(encrypt, plain-passwd)
	    &CmpPasswd($1, $passwd) && $ok++; 
	    &Log("O.K. CmpPasswdInFile: $passwd Authenticated") if $debug && $ok;
	}
    }
    close(FILE);

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
	return 0;
    };

    open(OUT,  "> $file.new")  || do {
	select(OUT); $| = 1;
	&Log("Cannot open $file.new");
	&Mesg(*Envelope, "Cannot make new passwd file");
	return 0;
    };

    open(BAK,  ">> $file.bak") || do {
	select(BAK); $| = 1;
	&Log("Cannot open $file.bak");
	&Mesg(*Envelope, "Cannot make passwd backup");
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
	return 0;
    }
}

1;
