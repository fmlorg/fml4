#!/usr/local/bin/perl
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)
# q$Id$;


### public
sub NewSyslog 
{
    local(*f);
    local(@f) = @_;

    # Default
    @f = ("$MSEND_RC.bak", "$MEMBER_LIST.bak", "$ACTIVE_LIST.bak") unless @f;

    foreach $f (@f) {
	next if $f =~ /^\s*$/;
	-f $f || (&Log("newsyslog: cannot find $f, skip"), next);

	&Debug("\nCall NewSyslog::Fml($f)") if $debug;
	&NewSyslog'Fml($f);#';
    }
}


##################################################
### private
package NewSyslog;

$NEWSYSLOG_MAX = $main'NEWSYSLOG_MAX;#';
$TMP_DIR       = $main'TMP_DIR;#';
$debug         = $main'debug;#';
$DIR           = $main'DIR;#';
$VARLOG_DIR    = $main'VARLOG_DIR;#';

sub Fml
{
    local($org) = @_;
    local($original) = $org;
    local($in_varlog);

    &Debug("Try NewSyslog::Fml $org") if $debug;
    
    # Fix $org for FML *.bak files
    ($org =~ /$VARLOG_DIR/) && $in_varlog++;
    ($org =~ s/\.bak$//) && ($org !~ /$VARLOG_DIR/) && ($org = "./$VARLOG_DIR/$org");
    $org =~ s/$DIR/./g;
    $org =~ s/$VARLOG_DIR/./g if $in_varlog;
    $org =~ s#//#/#g;
    $org =~ s#\./\./#./#g;
    &Debug("                -> $org") if $debug;

    # First Time EXCEPTION;
    &Debug("rename($original, $org.0)") if $debug;

    # link ? unlink : rename; 
    # IF NOT, file -> var/log/file.0 IN var/log(ERROR)
    if (-l $original) {
	unlink $original;
    }
    else {
	rename($original, "$org.0");
    }

    # $org = var/log/file
    # turn over var/log/file(not var/log/file.bak)
    &TurnOver($org);

    ### MUST BE "NO original, file.0 EXISTS" (file = $org)
    # O.K. after turn over var/log/file
    # ln -s var/log/file.0 var/log/file.bak 
    # firstly, check "ln -s" O.K.?
    # NOTICE: symlink(ORGFILE,NEWFILE)
    $symlink_exists = (eval 'symlink("", "");', $@ eq "");

    $org = "$org.0";
    -f $org || &Touch($org);

    # O.K. ln -s file file.0
    if ($symlink_exists) {
	symlink($org, $original) && $ok++;
	&Log("ln -s $org $original".($ok ? "OK" : ". Fails!"));
    }
    else {
	&Log("unlink $org, log -> $target");
    }
}


# Turning Over 
# rm file.4
# file.3 -> file.4 ...
# file(original) -> file.0
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

    # var/log/file(present log file) -> var/log/file.0
    if (-f $file) {
	&Debug("rename($file, $file.0)") if $debug;
	rename($file, "$file.0");
	&Log("Turned over $file");
    }
}


# DEBUG in NewSyslog NAME SPACE;
if ($0 eq __FILE__) {
    $DIR        =  $ENV{'PWD'};
    $TMP_DIR    = $TMP_DIR    || "./tmp" ; # backward compatible
    $VAR_DIR    = $VAR_DIR    || "$DIR/var"; # LOG is /var/log (4.4BSD)
    $VARLOG_DIR = $VARLOG_DIR || "$DIR/var/log"; # absolute for ftpmail

    $debug = 1;

    @ARGV || die "No argv.\n";
    foreach(@ARGV) { &Fml($_);}
    exit 0;

sub Log   { print STDERR "LOG: @_ \n";}
sub Debug { &Log(@_);}
sub Touch { open(F,">> $_[0]"); close(F);}
}

1;
