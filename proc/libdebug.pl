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

#### SIMULATION DEBUG #####

&Log("-------------------") if $0 =~ /\/fml.pl/;

# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
PERMIT_POST_FROM     $PERMIT_POST_FROM
PERMIT_COMMAND_FROM  $PERMIT_COMMAND_FROM
REJECT_POST          $REJECT_POST_HANDLER
REJECT_COMMAND       $REJECT_COMMAND_HANDLER

FQDN                 $FQDN
DOMAIN               $DOMAINNAME

Mailing List         $MAIL_LIST
Return Path          $UnixFrom
From(Original):      $Envelope{'from:'}
From_address:        $From_address
Original Subject:    $Envelope{'subject:'}
To:                  $Envelope{'trap:rcpt_fields'}
Reply-To:            $Envelope{'h:Reply-To:'}
Addr2Reply:          $Envelope{'Addr2Reply:'}

DIR                  $DIR
LIBDIR               $LIBDIR
ACTIVE_LIST          $ACTIVE_LIST
\@ACTIVE_LIST        @ACTIVE_LIST
MEMBER_LIST          $MEMBER_LIST
\@MEMBER_LIST        @MEMBER_LIST

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip               $Envelope{'mode:uip'}
LOAD_LIBRARY         $LOAD_LIBRARY
"#;

"print STDERR $s";
}

sub OutputEventQueue
{
    local($qp);

    &Debug("---Debug::OutputEventQueue();");
    for ($qp = 1; $qp ne ""; $qp = $EventQueue{"next:${qp}"}) {
	&Debug(sprintf("\tqp=%-2d link->%-2d fp=%s",
		       $qp, $EventQueue{"next:$qp"}, $EventQueue{"fp:$qp"}));
    }
}


### logs STDIN (== mail imports itself);
sub StdinLog
{
    local($date) = sprintf("%04d%02d%02d", 1900 + $year, $mon + 1, $mday);
    local($f)    = "$VARLOG_DIR/STDIN_LOG_$date";

    &HashValueAppend(*Envelope, "Header", $f);
    &Append2("\n", $f);
    &HashValueAppend(*Envelope, "Body", $f);
}


### memory trace 
sub MTrace
{
    for (ADMIN_COMMAND_HOOK,
	 AUTO_REGISTRATION_HOOK,
	 COMMAND_HOOK,
	 DISTRIBUTE_CLOSE_HOOK,
	 DISTRIBUTE_START_HOOK,
	 FML_EXIT_HOOK,
	 HEADER_ADD_HOOK,
	 HTML_TITLE_HOOK,
	 HTML_TITLE_HOOK,
	 MODE_BIFURCATE_HOOK,
	 MSEND_HEADER_HOOK,
	 MSEND_OPT_HOOK,
	 MSEND_START_HOOK,
	 REPORT_HEADER_CONFIG_HOOK,
	 RFC1153_CUSTOM_HOOK,
	 SMTP_CLOSE_HOOK,
	 SMTP_OPEN_HOOK,
	 START_HOOK) {
	eval("\$$_ .= q#&MStat;#");
    }
}

package fmldebug;
sub main'MStat #";
{
    local($xpkg, $xfile, $xln) = @_;
    local($pkg, $file, $ln) = caller;
    $file =~ s#.*/##;

    open(STAT, "ps -u -p $$|"); 
    while (<STAT>) { 
	next if /USER/;
	chop;

	@x = split;
	$p = $x[4] - $px[4];
	$q = $x[5] - $px[5];
	$px[4] = $x[4];
	$px[5] = $x[5];
	print STDERR "--- xpkg=$xpkg pkg=$pkg\n" if $debug; 
	printf STDERR "%1s %4d\t%4d  sum=<%4d %4d> (%s:%d %s:%d)\n", 
	($touch ? "+" : ""), $p, $q, $x[4], $x[5], 
	$xfile, $xln, $file, $ln;
    }
    close(STAT); 

    $touch++;
}

1;
