# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

### Internal Flags 
$UNISTD = 0;

# Architecture Dependence;
$HAS_ALARM = $HAS_GETPWUID = $HAS_GETPWGID = 0;


# set fop (File OPeration) default "MIME/multipart" :-)
$MGET_MODE_DEFAULT  = $MGET_MODE_DEFAULT  || "mp";
$MSEND_MODE_DEFAULT = $MSEND_MODE_DEFAULT || "mp";

# ensurance :)
push(@HOSTS, $HOST);
push(@HOSTS, $FQDN);
push(@HOSTS, $FQDN);

# lock
$FlockFile  = ">> $DIR/lockfile";


# export
sub Archive'Rename     { &main'Rename(@_);}
sub Confirm'Rename     { &main'Rename(@_);}
sub Crosspost'Rename   { &main'Rename(@_);}
sub MIME'Rename        { &main'Rename(@_);}
sub NewSyslog'Rename   { &main'Rename(@_);}
sub Pop'Rename         { &main'Rename(@_);}
sub SyncHtml'Rename    { &main'Rename(@_);}
sub Whois'Rename       { &main'Rename(@_);}
sub ml'Rename          { &main'Rename(@_);}


# remove $to if -f $to on UNIX
# but error if -f $to on MS-DOS
sub Rename
{
    local($from, $to) = @_;

    unlink $to if -f $to;
    rename($from, $to);
}


sub NT4Crypt
{
    return $_[0];
}

1;
