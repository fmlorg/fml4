#!/usr/local/bin/perl
# Copyright (C) 1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)
# q$Id$;

if ($0 eq __FILE__) {
    $DIR   =  $ENV{'PWD'};
    $debug = 1;

    $ARGV[0] || die "No argv.\n";
    &FmlNewSyslog($ARGV[0]);
    exit 0;

    sub Log { print STDERR "LOG:".@_."\n";}
}
else {
    # Deault when library is 'require'ed;
    &FmlNewSyslog('');
}

sub FmlNewSyslog 
{
    local($f) = @_;
    local($file, $new);

    &DebugNewSyslog("Newsyslog library sets in: for [$f]\n") if $debug;

    # DEFAULT ACTION
    if (! $f) {
	@NEWSYSLOG_FILES = ("$MSEND_RC.bak", 
			    "$MEMBER_LIST.bak", 
			    "$ACTIVE_LIST.bak",
			    $LOG_MESSAGE_ID
			    )
	    unless @NEWSYSLOG_FILES;

	foreach $f (@NEWSYSLOG_FILES) {
	    &DebugNewSyslog("if -f $f") if $debug;
	    next if $f =~ /^\s*$/;
	    next unless -f $f;

	    &DebugNewSyslog("\nCall &FmlNewSyslog($f)") if $debug;
	    &FmlNewSyslog($f);
	}
    }

    # ADJUST defaults
    $VAR_DIR    = $VAR_DIR    || "var";
    $VARLOG_DIR = $VARLOG_DIR || "var/log";
    (-d $VAR_DIR)    || mkdir($VAR_DIR, 0700);
    (-d $VARLOG_DIR) || mkdir($VARLOG_DIR, 0700);

    $new = $f;

    # for FML *.bak files
    if ($new =~ s/\.bak$//) {
	if ($new =~ /$DIR/) {
	    $new =~ s/$DIR/$VARLOG_DIR/;
	}
	else {
	    $new = "$VARLOG_DIR/$new";
	}

	$new =~ s/\.bak$//;

	&DoNewSyslog($new);

	if (-l $f) {
	    open(TOUCH,">> $new.0"); close(TOUCH);
	}
	elsif ($new && $DO_SYMLINK) {
	    $new =~ s/$DIR\//.\//;
	    $new = "$new.0";
	    $symlink_exists = (eval 'symlink("", "");', $@ eq "");
	    
	    open(TOUCH,">> $new"); close(TOUCH);
	    rename($f, $new) if -f $f;

	    if ($symlink_exists && symlink($new, $f)) {
		&DebugNewSyslog("ln -s $new $f") if $debug;
		&Log("ln -s $new $f");
	    }
	    else {
		&Log("unlink $new, log -> $f");
	    }
	};

	&DoNewSyslog($new);
    }
    ###### not .bak file, arbitrary!  
    else {
	&DoNewSyslog($new);
    }

}


#
# return NONE
sub DoNewSyslog 
{
    local($file) = @_;
    local($max) = $NEWSYSLOG_MAX || 4;
    local($new) = "$file.$max";

    if (-f $new) {
	&DebugNewSyslog("unlink $new\n") if $debug;
	unlink $new;
    }

    do { 
	$old = "$file.".($max - 1 > 0 ? $max - 1 : 0);
	$new = "$file.".($max);
	&DebugNewSyslog("rename($old, $new)") if -f $old && $debug;
	-f $old && rename($old, $new);
    }while($max-- > 0);

    if (-f $file) {
	&DebugNewSyslog("rename($file, $file.0)") if $debug;
	rename($file, "$file.0");

	$file =~ s/$DIR//;
	&Log("Turned over $file");
    }
}

sub DebugNewSyslog
{
    local($s) = @_;

    $s =~ s/$DIR\///g;
    print STDERR "$s\n";
}

1;
