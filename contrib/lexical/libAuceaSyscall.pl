#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");

### package Syscall; ###

sub BestP
{
    local($data) = @_;
    local($arguments);

    print "\tBestP ($data)\n";

    0;
}

sub DoubleMatch
{
    local($type, $entry, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local($arguments);

    while (($k, $v) = each %args) { $arguments .= "$k:$v " if $v;}
    print "\t$type::DoubleMatch[ $arguments]\n";
}

sub ErrLog
{
    &Error(@_);
}

sub Err
{
    local($type, $entry, *args, *Buf, *CF, *rules, *result, *Field) = @_;
    local($arguments);

    while (($k, $v) = each %args) { $arguments .= "$k:$v " if $v;}
    print "\t$type::Error[ $arguments]\n";
    &Error($args{'argv'});
}


########## IPC ##########


1;
