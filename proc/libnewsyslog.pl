#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;


### public
sub NewSyslog 
{
    local($f);
    local(@f) = @_;

    # Default
    @f = ("$MSEND_RC.bak", "$MEMBER_LIST.bak", "$ACTIVE_LIST.bak") unless @f;

    foreach $f (@f) {
	next if $f =~ /^\s*$/;
	-f $f || ($f =~ s/$DIR/\$DIR/, &Log("newsyslog: no $f, skip"), next);

	&Debug("\nCall NewSyslog::Fml($f)") if $debug;
	&NewSyslog'Fml($f);#';
    }
}


##################################################
### private
package NewSyslog;

$NEWSYSLOG_MAX = $main'NEWSYSLOG_MAX;#';
$TMP_DIR       = $main'TMP_DIR;#';
$FP_TMP_DIR    = $main'FP_TMP_DIR;#';
$debug         = $main'debug;#';
$DIR           = $main'DIR;#';
$VARLOG_DIR    = $main'VARLOG_DIR;#';
$FP_VARLOG_DIR = $main'FP_VARLOG_DIR;#';

sub Fml
{
    local($org) = @_;
    local($original) = $org;
    local($orgd, $orgf);

    &Debug("Try NewSyslog::Fml $org") if $debug;

    # Fix $org for FML *.bak files
    $org =~ s/.bak$//;
    if ($org =~ m#(.*)/(\S+)# ) {
	$orgd = $1,  $orgf = $2;
    }
    else {
	$orgd = ".", $orgf = $org;
    }
    
    $org = "$VARLOG_DIR/$orgf";	# should be both org and original full-path?
    
    # First Time EXCEPTION;
    &Debug("rename($original, $org.0)") if $debug;

    # $org = var/log/file
    # turn over var/log/file(not var/log/file.bak)
    &TurnOver($org);

    ### MUST BE "NO original, file.0 EXISTS" (file = $org)
    # O.K. after turn over var/log/file
    # mv var/log/file.bak var/log/file.0
    $org0 = "$org.0";

    -f $org0 || &Touch($org0);

    &Debug("NewSyslog::Fml::rename($original, $org0)") if $debug;
    rename($original, $org0) || &Log("Fail rename($original, $org0)");
}


# Turning Over 
# rm file.4
# file.3 -> file.4 ...
# DO NOT "file(original) -> file.0"
# so must be 
# NO original, file.0 EXISTS
# return NONE
sub TurnOver   
{
    local($file) = @_;
    local($max) = $NEWSYSLOG_MAX || 4;#';
    local($new) = "$file.$max";

    &Debug("TurnOver: Try TurnOver $file") if $debug;

    # unlink var/log/file.4
    if (-f $new) {
	&Debug("unlink $new\n") if $debug;
	unlink $new;
    }

    # mv var/log/file.3 -> var/log/file.4 ...;
    do { 
	$old = "$file.".($max - 1 > 0 ? $max - 1 : 0);
	$new = "$file.".($max);
	&Debug("rename($old, $new)") if -f $old && $debug;
	-f $old && rename($old, $new);
    } while ($max-- > 0);

}


# turn over log.msgid (this is exception for file without .0)
sub TurnOverW0
{
    local($file) = @_;

    &TurnOver($file);

    if (-f $file) {
	&Debug("rename($file, $file.0)") if $debug;
	rename($file, "$file.0");
	&Log("Turned over $file");
    }
}


# DEBUG in NewSyslog NAME SPACE;
if ($0 eq __FILE__) {
    $DIR        =  $ENV{'PWD'};
    $TMP_DIR    = $TMP_DIR    || "tmp" ; # backward compatible
    $VAR_DIR    = $VAR_DIR    || "var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR = $VARLOG_DIR || "var/log"; # absolute for ftpmail

    $debug = 1;

    @ARGV || die "No argv.\n";
    foreach(@ARGV) { &Fml($_);}
    exit 0;

sub Log   { print STDERR "LOG: @_ \n";}
sub Debug { &Log(@_);}
sub Touch { open(F,">> $_[0]"); close(F);}
}

1;
