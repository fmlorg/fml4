# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$
#

sub PopFmlSetUp
{
    &ResetVariables;

    print "\n\n\#\#\#\#\# POP and SMTP Server Configuration \#\#\#\#\n\n";

    &MakeDir("$ML_DIR/popfml");

    # $ML_DIR/popfml/config.ph
    &Append2('$MAIL_LIST       = "popfml";',     "$ML_DIR/popfml/config.ph");
    &Append2('$CONTROL_ADDRESS = "popfml-ctl";', "$ML_DIR/popfml/config.ph");
    &Append2("1;", "$ML_DIR/popfml/config.ph");

    # POP_SERVER

    # SMTP_SERVER
    #   1 == POP_SERVER
    #   2 == THIS MACHINE
    #   3 == other?

    while (1) {
	$POP_SERVER = $FQDN;
	print "POP SERVER [$POP_SERVER]: ";
	$POP_SERVER = &GetString || $POP_SERVER;
	$cmd = &Query("POP SERVER is [$POP_SERVER] O.K.? ", "y/n", "y|n", "n");

	if ($cmd eq 'y') { last;}
    }

    while (1) {
	$SMTP_SERVER = $POP_SERVER;
	print "SMTP SERVER [$SMTP_SERVER]: ";
	$SMTP_SERVER = &GetString  || $SMTP_SERVER;
	$cmd = &Query("SMTP SERVER is [$SMTP_SERVER] O.K.? ", "y/n", "y|n", "n");

	if ($cmd eq 'y') { last;}
    }

    open(POP_CF, "> $EXEC_DIR\\_fml\\pop") || die($!);
    select(POP_CF); $| = 1; select(STDOUT);

    print POP_CF "\# POP SERVER. I retrieve mails from this.\n";
    print POP_CF "\$POP_SERVER = '$POP_SERVER';\n\n";
    print POP_CF "\# SMTP SERVER which derivery mails from mailing lists.\n";
    print POP_CF "\$SMTP_SERVER = '$SMTP_SERVER';\n";
    print POP_CF "\$HOST = \$SMTP_SERVER;\n\n";
    print POP_CF "1;\n";

    close(POP_CF);

    # XXX: SHOULD NOT OVERWRITE
    open(POP_CF, ">> $EXEC_DIR\\sitedef.ph") || die($!);
    select(POP_CF); $| = 1; select(STDOUT);
    print POP_CF "\#\#\# include _fml\\pop (DO NOT DELETE THIS BLOCK!)\n";    
    print POP_CF "require '$EXEC_DIR/_fml/pop';\n";
    print POP_CF "1;\n";
    close(POP_CF);
}


sub PopFmlInputPasswd
{
    local($ml) = @_;
    local($buf);

    print "---Setting POP3 Passwd of the user $ml ($ml mailing list)\n";

    &ResetVariables;

    $buf .= &Grep('^\$MAIL_LIST', "$ML_DIR/$ml/config.ph");
    $buf .= &Grep('^\$CONTROL_ADDRESS', "$ML_DIR/$ml/config.ph");

    eval $buf;  print STDERR $@ if $@; 
    
    ($addr) = split(/\@/, $MAIL_LIST);
    &_do_pop_passwd($addr) if $addr;

    if ($MAIL_LIST ne $CONTROL_ADDRESS) {
	($addr) = split(/\@/, $CONTROL_ADDRESS);
	&_do_pop_passwd($addr) if $addr;
    }
}


sub _do_pop_passwd
{
    local($ml, $passwd) = @_;
    local($passwd_file);

    print "\n[$ml\'s POP password setting]\n\n";

    # We should not check $ml existence since
    # we may change $ml-ctl :)
    # &ResetVariables;

    # $ml/etc
    &MakeSubDir("$ML_DIR/etc") if ! -d "$ML_DIR/etc";

    # here we go! 
    &SetWritableUmask;
    $passwd_file= "$ML_DIR/etc/pop_passwd";

    -f $passwd_file || &Touch($passwd_file);

    while (!$ml || !$passwd) {
	if (! $ml) {
	    print "   Mailing List Name: ";
	    chop($ml = <STDIN>);
	}
	else {
	    print "   Mailing List Name: $ml\n";
	}

	if (! $passwd) {
	    # no echo
	    # system "stty", "-echo"; (only on UNIX)

	    print "       POP3 Password: ";
	    chop($passwd = <STDIN>);
	    print "\n";

	    # system "stty", "echo";
	}

	if (!$ml || !$passwd) {
	    &Warn("Error: Please input NOT NULL Address and Password.");
	    &Log("makefml::passwd address is not defined")  if !$ml;
	    &Log("makefml::passwd password is not defined") if !$passwd;
	}
    }

    ### etc/pop_passwd is clear text
    $CryptNoEncryptionMode = 1;

    require 'libcrypt.pl';
    $init = 1;	# if new-comer, initialize the passwd;

    if (&ChangePasswd($passwd_file, $ml, $passwd, $init)) {
	print "   Passwd Changed ($passwd_file).\n";
	&Log("makefml::passwd changing $passwd_file succeed");
    }
    else {
	print "   Passwd Change Fails ($passwd_file).\n";
	&Log("makefml::passwd changing $passwd_file fails");
    }

}



sub Grep
{
    local($key, $file) = @_;

    print STDERR "Grep $key $file\n" if $debug;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/i;}
    close(IN);

    $NULL;
}


sub GetPopPasswd
{
    local($ml) = @_;
    local($buf, @buf);

    $buf = &Grep("^$ml\\s+", "$ML_DIR/etc/pop_passwd");
    (split(/\s+/, $buf, 2))[1];
}


1;
