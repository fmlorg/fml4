#!/usr/local/bin/perl --    # -*-Perl-*-
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

push(@INC, '/usr/_local/fml');


##### KEYWORD and Defaults #####
$HOME               = '/home/kfuka/db/cache/cwhois';
$HIKARI_BIN         = "$HOME/bin";
$CACHE_SEARCH_PROG  = "$HIKARI_BIN/scandb.pl";

$HIKARI_DB          = "/home/kfuka/db/applydb:/home/kfuka/db/whois_cachedb";
$HIKARI_SPOOL       = "/home/office/Mail/apply:/home/kfuka/db/cache/cwhois/spool";

# define local as apply
%WHOIS_CACHE_SPOOL  = ('apply', $HIKARI_SPOOL, 'local', $HIKARI_SPOOL);
%WHOIS_CACHE_DB     = ('apply', $HIKARI_DB, 'local', $HIKARI_DB);

$CHMODE             = '#';
$LOCAL_HELP_KEYWORD = "help$CHMODE";
$LOCAL_CACHE_SEARCH = "$CHMODE(\\S+)";
$LOCAL_COMMAND_MODE = "(\\S+)$CHMODE(\\S+)";

$WHOIS_SERVER       = 'whois.nic.ad.jp';
$From_address       = 'WHOIS';

$debug++;

1;
