# -*-Perl-*-
#
# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id: libcompat_cf1.pl,v 1.1.1.1 2000/02/20 15:49:55 fukachan Exp $


$DOMAINNAME          || ($DOMAINNAME = "domain.uja");
$FQDN                || ($FQDN = "aoi.domain.uja");
$STRUCT_SOCKADDR     || ($STRUCT_SOCKADDR = "S n a4 x8");
$LANGUAGE            || ($LANGUAGE = "Japanese");
$CFVersion           || ($CFVersion = 2);
$DEFAULT_SUBSCRIBE   || ($DEFAULT_SUBSCRIBE = "subscribe");
$COMMAND_CHECK_LIMIT || ($COMMAND_CHECK_LIMIT = 3);
$GUIDE_CHECK_LIMIT   || ($GUIDE_CHECK_LIMIT = 3);
$MAX_TIMEOUT         || ($MAX_TIMEOUT = 200);
$TZone               || ($TZone = "+0900");
$SLEEPTIME           || ($SLEEPTIME = 300);
$MAIL_LENGTH_LIMIT   || ($MAIL_LENGTH_LIMIT = 1000);
$ADDR_CHECK_MAX      || ($ADDR_CHECK_MAX = 3);
$SPOOL_DIR           || ($SPOOL_DIR = "spool");
$TMP_DIR             || ($TMP_DIR = "tmp");
$VAR_DIR             || ($VAR_DIR = "var");
$VARLOG_DIR          || ($VARLOG_DIR = "var/log");
$VARRUN_DIR          || ($VARRUN_DIR = "var/run");
$VARDB_DIR           || ($VARDB_DIR = "var/db");
$DEFAULT_ARCHIVE_UNIT || ($DEFAULT_ARCHIVE_UNIT = 100);
$INDEX_FILE          || ($INDEX_FILE = "$DIR/index");
$LIBRARY_DIR         || ($LIBRARY_DIR = "var/library");
$LIBRARY_ARCHIVE_DIR || ($LIBRARY_ARCHIVE_DIR = "archive");
$DEFAULT_WHOIS_SERVER || ($DEFAULT_WHOIS_SERVER = "localhost");
$WHOIS_DB            || ($WHOIS_DB = "$VARDB_DIR/whoisdb");
$CRONTAB             || ($CRONTAB = "etc/crontab");
$CRON_PIDFILE        || ($CRON_PIDFILE = "var/run/cron.pid");
$ADMIN_MEMBER_LIST   || ($ADMIN_MEMBER_LIST = "$DIR/members-admin");
$ADMIN_HELP_FILE     || ($ADMIN_HELP_FILE = "$DIR/help-admin");
$PASSWD_FILE         || ($PASSWD_FILE = "$DIR/etc/passwd");
$GUIDE_KEYWORD       || ($GUIDE_KEYWORD = "guide");
$CHADDR_KEYWORD      || ($CHADDR_KEYWORD = "chaddr|change\-address|change");
$FML                 || ($FML = "fml.pl");
$LOG_MESSAGE_ID      || ($LOG_MESSAGE_ID = "$VARRUN_DIR/msgidcache");
$MEMBER_LIST         || ($MEMBER_LIST = "$DIR/members");
$ACTIVE_LIST         || ($ACTIVE_LIST = "$DIR/actives");
$OBJECTIVE_FILE      || ($OBJECTIVE_FILE = "$DIR/objective");
$GUIDE_FILE          || ($GUIDE_FILE = "$DIR/guide");
$HELP_FILE           || ($HELP_FILE = "$DIR/help");
$DENY_FILE           || ($DENY_FILE = "$DIR/deny");
$WELCOME_FILE        || ($WELCOME_FILE = "$DIR/welcome");
$WELCOME_STATEMENT   || ($WELCOME_STATEMENT = "Welcome to our $ML_FN\n         You are added automatically");
$CONFIRMATION_FILE   || ($CONFIRMATION_FILE = "$DIR/confirm");
$LOGFILE             || ($LOGFILE = "$DIR/log");
$MGET_LOGFILE        || ($MGET_LOGFILE = "$DIR/log");
$SMTPLOG             || ($SMTPLOG = "$VARLOG_DIR/_smtplog");
$SUMMARY_FILE        || ($SUMMARY_FILE = "$DIR/summary");
$SEQUENCE_FILE       || ($SEQUENCE_FILE = "$DIR/seq");
$MSEND_RC            || ($MSEND_RC = "$VARLOG_DIR/msendrc");
$LOCK_FILE           || ($LOCK_FILE = "$VARRUN_DIR/lockfile.v7");
$From_address        || ($From_address = "not.found");
$User                || ($User = "not.found");
$Date                || ($Date = "not.found");
$LOCK_SH             || ($LOCK_SH = 1);
$LOCK_EX             || ($LOCK_EX = 2);
$LOCK_NB             || ($LOCK_NB = 4);
$LOCK_UN             || ($LOCK_UN = 8);

###LOCAL_CONFIG
############################################################################
# FML R2 CONFIGURATIONS
# libcompat_cf1.pl is generated from cf/MANIFEST
#    $Id: libcompat_cf1.pl,v 1.1.1.1 2000/02/20 15:49:55 fukachan Exp $
# @ARCHIVE_DIR  = ('var/archive', 'old');


############################################################################



1;
